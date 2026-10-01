-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- This block provides the transaction queueing and management for the flash
-- channel. It is responsible for queueing up transactions, issuing commands to
-- to the spi flash block and providing flash response data to the transaction
-- layer.
--
-- Reads, writes and erases all take a descriptor and a 1kB slot of the DPR.
-- For a read the slot holds the flash data on its way back to the host. For a
-- write it holds the host's payload, captured as the command is still being
-- parsed (before its CRC is known good), and streamed out to the flash block
-- only once the descriptor is enqueued. Writes and erases come back from the
-- flash block as a single status byte, which lands at offset 0 of the slot
-- and only decides whether the completion is reported as successful.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_base_types_pkg.all;
use work.espi_protocol_pkg.all;
use work.flash_channel_pkg.all;

entity flash_channel is
    port (
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        enabled: in boolean;

        -- eSPI Transaction interface
        request: view flash_chan_req_sink;
        response: view flash_chan_resp_source;

        -- eSPI Status interface
        flash_np_free : out std_logic;
        flash_c_avail : out std_logic;

        -- Flash block interface
        -- command fifo
        flash_cfifo_data : out std_logic_vector(31 downto 0);
        flash_cfifo_write: out std_logic;
        flash_fifo_clear : out std_logic;
        -- readback fifo
        flash_rfifo_data : in std_logic_vector(7 downto 0);
        flash_rfifo_rdack : out std_logic;
        flash_rfifo_rempty: in std_logic;
        -- write payload fifo, host to flash. A whole payload is pushed before
        -- the command words for it are, so the flash block never sees a
        -- write command it does not already have all the bytes for.
        flash_wfifo_data : out std_logic_vector(7 downto 0);
        flash_wfifo_write : out std_logic

    );
end;


architecture rtl of flash_channel is

    attribute mark_debug : string;
    constant max_txn_size : integer := 1024;
    subtype desc_index_t is natural range 0 to num_descriptors - 1;
    signal dpr_waddr : std_logic_vector(11 downto 0);
    signal dpr_wdata : std_logic_vector(7 downto 0);
    signal dpr_wren : std_logic;
    signal readdata : std_logic_vector(7 downto 0);

    function add_wrap(a : natural; max: natural) return natural is
    begin
        if a =  max then
            return 0;
        else
            return a + 1;
        end if;
    end function;

    -- Bytes the flash block hands back for a descriptor: the data for a
    -- read, one status byte for anything else.
    function flash_side_bytes(desc : descriptor_t) return std_logic_vector is
    begin
        if desc.kind = flash_rd then
            return desc.xfr_size_bytes;
        else
            return To_Std_Logic_Vector(1, desc.xfr_size_bytes'length);
        end if;
    end function;


    type cmd_state_t is (idle, stream_payload, issue_flash_addr, issue_flash_len, wait_for_data);
    type complete_state_t is (idle, read_dpr);

    type reg_type is record
        flash_cmd_state : cmd_state_t;
        compl_state : complete_state_t;
        flash_side_cntr : integer range 0 to 1024;
        flash_write_addr_offset : integer range 0 to 1024;
        compl_side_cntr : integer range 0 to 1024;
        cmd_queue: command_queue_t;
        dpr_write_en: std_logic;
        dpr_wdata_buf: std_logic_vector(7 downto 0);
        -- host payload capture, registered so it shares the DPR write port
        -- with the flash-side path above without ever colliding with it
        host_wr_en : std_logic;
        host_wdata : std_logic_vector(7 downto 0);
        host_waddr : std_logic_vector(11 downto 0);
        -- payload stream out to the flash block
        wfifo_write : std_logic;
        wfifo_wdata : std_logic_vector(7 downto 0);
        -- DPR read address, registered so the read port sees a flop rather
        -- than a counter, an adder and the reader mux: the LUTRAM read plus
        -- the response processor's own muxing already fills most of a
        -- 125MHz period.
        dpr_raddr : std_logic_vector(11 downto 0);
        -- completion header, latched when the get arrives so the descriptor
        -- can be retired before the header has gone out on the wire
        resp_tag : std_logic_vector(3 downto 0);
        resp_length : std_logic_vector(11 downto 0);
        resp_cycle_type : std_logic_vector(7 downto 0);
        tail_desc: desc_index_t;
        issue_desc: desc_index_t;
        head_desc: desc_index_t;
        flash_np_free : std_logic;
        flash_c_avail: std_logic;
    end record;
    constant reg_reset : reg_type := (
        flash_cmd_state => idle,
        compl_state => idle,
        flash_side_cntr => 0,
        flash_write_addr_offset => 0,
        compl_side_cntr => 0,
        cmd_queue => (others => descriptor_init),
        dpr_write_en => '0',
        dpr_wdata_buf => (others => '0'),
        host_wr_en => '0',
        host_wdata => (others => '0'),
        host_waddr => (others => '0'),
        wfifo_write => '0',
        wfifo_wdata => (others => '0'),
        dpr_raddr => (others => '0'),
        resp_tag => (others => '0'),
        resp_length => (others => '0'),
        resp_cycle_type => success_with_data_only,
        tail_desc => 0,
        issue_desc => 0,
        head_desc => 0,
        flash_np_free => '0',
        flash_c_avail => '0'
    );

    signal r, rin : reg_type;
    signal dpr_wdata_dbg: std_logic_vector(7 downto 0);
    signal dpr_rdata: std_logic_vector(7 downto 0);
    signal dpr_read_ack: std_logic;
    signal dpr_wr_delay: std_logic;

    attribute mark_debug of r : signal is "TRUE";
    attribute mark_debug of dpr_wdata_dbg : signal is "TRUE";
    attribute mark_debug of dpr_rdata : signal is "TRUE";
    attribute mark_debug of dpr_read_ack : signal is "TRUE";
    attribute mark_debug of dpr_wr_delay : signal is "TRUE";    

begin

    flash_fifo_clear <= '1' when not enabled else '0';
    dbg_regs: process (clk, reset)
    begin
        if reset then
            dpr_wdata_dbg <= (others => '0');
            dpr_rdata <= (others => '0');
            dpr_read_ack <= '0';
            dpr_wr_delay <= '0';
        elsif rising_edge(clk) then
            dpr_rdata <= readdata;
            dpr_wdata_dbg <= flash_rfifo_data;
            dpr_read_ack <= response.ready;
            dpr_wr_delay <= r.dpr_write_en;
        end if;
    end process;


    -- Always write straight from the FIFO to the dpr so any dpr write is a fifo read ack also
    flash_rfifo_rdack <= r.dpr_write_en;
    flash_np_free <= r.flash_np_free;

    -- flash_c_avail is set when we have pending data to be read back out, but critically this status needs to represent
    -- the status *after* any current message, so if we're responding now and this response is the only one available,
    -- this needs to be set to 0.

    flash_c_avail <= r.flash_c_avail when enabled else '0';

    -- The length word carries the request kind in its top nibble; reads
    -- encode as zero there so the flash block sees the original two-word
    -- command for them.
    flash_cfifo_data <= r.cmd_queue(r.issue_desc).sp5_addr when r.flash_cmd_state = issue_flash_addr else 
                        to_kind_bits(r.cmd_queue(r.issue_desc).kind) & resize(r.cmd_queue(r.issue_desc).xfr_size_bytes, flash_cfifo_data'length - 4) when r.flash_cmd_state = issue_flash_len else
                        (others => '0');
    flash_cfifo_write <= '1' when r.flash_cmd_state = issue_flash_addr or r.flash_cmd_state = issue_flash_len else '0';

    flash_wfifo_data <= r.wfifo_wdata;
    flash_wfifo_write <= r.wfifo_write;

    -- Let's put a 4kB buffer here as a starting point and see how it goes, this would allow 4 1024Byte max size transactions
    -- or we could shrink and say 2 2kB etc. We know we're only going read on this interface so we don't have to worry so much about
    -- various concurrency issues here. This should fit in a single 32kb block ram on the FPGA
    dual_clock_simple_dpr_inst: entity work.dual_clock_simple_dpr
     generic map(
        data_width => 8,
        num_words => 4096,
        reg_output => false
    )
     port map(
        wclk => clk,
        waddr => dpr_waddr,
        wdata => dpr_wdata,
        wren => dpr_wren,
        rclk => clk,
        raddr => r.dpr_raddr,
        rdata => readdata
    );
    response.data <= readdata;
    response.valid <= '1' when r.compl_state = read_dpr else '0';
    response.tag <= r.resp_tag;
    response.length <= r.resp_length;
    response.cycle_type <= r.resp_cycle_type;

    -- One write port, two writers. The host path is registered off the
    -- incoming stream (which cannot be stalled) and the flash path only
    -- schedules itself on a cycle where the host is not writing, so the two
    -- enables are never set together.
    dpr_wren <= r.host_wr_en or r.dpr_write_en;
    dpr_waddr <= r.host_waddr when r.host_wr_en = '1' else
                 To_Std_Logic_Vector(r.issue_desc * max_txn_size  + r.flash_write_addr_offset, 12);
    dpr_wdata <= r.host_wdata when r.host_wr_en = '1' else r.dpr_wdata_buf;

    -- We have two state machines running here as both need to be able to update
    -- the descriptor queues.
    -- We have 3 pointers into the descriptor array. The "head" pointer is pointing the next
    -- descriptor which we will store so long as it is active.
    -- The "issue" pointer is pointing to the next descriptor for which we need to issue flash
    -- commands to the flash controller.
    -- The "tail" pointer is pointing to the next descriptor for responses, once it is finished.
    -- Unike a traditional queue implementation, don't have to determine empty and full based on
    -- the pointer location, we use the descriptor status for that, and that means that head and 
    -- tail and issue can all be pointing to the same descriptor while it's not active, but while
    -- requests are being processed you'll see the head ptr move to the next descriptor once a 
    -- command has been enqueued, the issue pointer will move once the data has been fetched from
    -- flash and filled into the DPR, and the tail pointer will move once the response has been
    -- set. This ensures in-order responses.
    command_processor_comb : process (all)
        variable v : reg_type;
        variable flash_issue_needed : boolean;
    begin
        v := r;

        -------
        -- Capturing a write payload into the head descriptor's slot
        ------
        -- This happens while the command is still arriving, so nothing is
        -- known about its CRC yet. If the CRC turns out bad the enqueue
        -- below never happens and the next request simply overwrites the
        -- slot. The offset is clamped to the slot so an oversized length
        -- wraps within it rather than trampling a neighbour.
        v.host_wr_en := request.wdata_valid;
        v.host_wdata := request.wdata;
        v.host_waddr := To_Std_Logic_Vector(r.head_desc * max_txn_size + to_integer(request.wdata_idx(9 downto 0)), 12);

        -------
        -- Adding new requestes to the processing queue
        ------
        -- Command processing requests flash command queue. Writes and erases
        -- the command processor was not permitted to accept arrive marked
        -- refused and still take a descriptor, so that the host gets an
        -- unsuccessful completion rather than silence.
        -- we have 4 queue (txn) slots and can do 1024 byte per transaction max
        -- We simply carve up the DPR into 4 slots and then use those one for
        -- each descriptor, and we use the descriptors in order.
        if request.flash_np_enqueue_req and r.flash_np_free = '1' then
            v.cmd_queue(r.head_desc).kind := request.kind;
            v.cmd_queue(r.head_desc).sp5_addr := request.sp5_flash_address;
            v.cmd_queue(r.head_desc).xfr_size_bytes := request.espi_hdr.length;
            v.cmd_queue(r.head_desc).active := true;
            v.cmd_queue(r.head_desc).tag := request.espi_hdr.tag;
            v.cmd_queue(r.head_desc).flash_issued := false;
            v.cmd_queue(r.head_desc).done := false;
            v.cmd_queue(r.head_desc).failed := false;
            v.head_desc := add_wrap(r.head_desc, desc_index_t'high);

        end if;

        for i in num_descriptors - 1 downto 0 loop
            -- set default, fall-through states
            v.flash_np_free := '0';
            v.flash_c_avail := '0';
            flash_issue_needed := false;

            -- Not active means it's free
            -- we can just check the head descriptor and if it's not active, we have at 
            -- least one free descriptor
            if r.cmd_queue(r.head_desc).active = false then
                v.flash_np_free := '1';
            end if;

            -- Active but have not yet issued to flash
            if r.cmd_queue(r.issue_desc).active = true and r.cmd_queue(r.issue_desc).flash_issued = false then
                flash_issue_needed := true;
            end if;

            if r.cmd_queue(r.tail_desc).done = true then
                v.flash_c_avail := '1';
            end if;
        end loop;

        ------
        -- Issuing queued commands to the flash block, and storing flash data back into the DPR
        ------
        -- Once we have one or more commands enqueued, we need to issue requests to the flash controller
        -- and store the data back in the DPR and then issue a completion request, and hold until
        -- the master does a get to get the data
        v.dpr_write_en := '0';  --only single cycle reads, default to 0
        v.wfifo_write := '0';
        case r.flash_cmd_state is
            when idle =>
                -- have active command that hasn't been issued to flash
                if flash_issue_needed then
                    v.flash_side_cntr := 0;
                    case r.cmd_queue(r.issue_desc).kind is
                        when flash_refused =>
                            -- Nothing goes to the flash; it is complete
                            -- (unsuccessfully) as soon as it is looked at.
                            v.cmd_queue(r.issue_desc).flash_issued := true;
                            v.cmd_queue(r.issue_desc).done := true;
                            v.cmd_queue(r.issue_desc).failed := true;
                            v.issue_desc := add_wrap(r.issue_desc, desc_index_t'high);
                        when flash_wr =>
                            v.flash_cmd_state := stream_payload;
                        when others =>
                            v.flash_cmd_state := issue_flash_addr;
                    end case;
                end if;
            -- Push the captured payload out ahead of the command words.
            -- readdata is combinational off dpr_raddr, so the byte for this
            -- cycle's counter is registered on the way out.
            when stream_payload =>
                if r.compl_state /= idle then
                    null;  -- completion owns the read port
                elsif r.flash_side_cntr = r.cmd_queue(r.issue_desc).xfr_size_bytes then
                    v.flash_side_cntr := 0;
                    v.flash_cmd_state := issue_flash_addr;
                else
                    v.wfifo_write := '1';
                    v.wfifo_wdata := readdata;
                    v.flash_side_cntr := r.flash_side_cntr + 1;
                end if;
            -- issue to flash, and wait until we get all the data back
            -- and have stored it into the DPR. We can't issue more than
            -- on command to the flash controller at a time so we'll spin
            -- here until it finishes. When it finishes, we should have
            -- all the data back in the DPR and we can call it done.
            when issue_flash_addr =>
                -- Send the address to the flash controller
                v.flash_cmd_state := issue_flash_len;
            when issue_flash_len =>
                v.flash_cmd_state := wait_for_data;
                v.flash_side_cntr := 0;
                v.cmd_queue(r.issue_desc).flash_issued := true;
                
            when wait_for_data =>
                if r.flash_side_cntr = flash_side_bytes(r.cmd_queue(r.issue_desc)) then
                    v.cmd_queue(r.issue_desc).done := true;
                    v.flash_cmd_state := idle;
                    v.flash_side_cntr := 0;
                    v.issue_desc := add_wrap(r.issue_desc, desc_index_t'high);
                -- "empty" isn't strictly valid if we're acking this cycle since this write could
                -- empty it. We only check for empty on a cycle where we're not acking.
                -- A host payload byte arriving this cycle takes the write port next cycle.
                elsif flash_rfifo_rempty = '0' and r.dpr_write_en = '0' and request.wdata_valid = '0' then
                    v.dpr_write_en := '1';
                    v.dpr_wdata_buf := flash_rfifo_data;
                    v.flash_write_addr_offset := r.flash_side_cntr;
                    v.flash_side_cntr := r.flash_side_cntr + 1;
                    -- for a write or erase the one byte back is a status,
                    -- zero meaning the flash block finished it cleanly
                    if r.cmd_queue(r.issue_desc).kind /= flash_rd then
                        v.cmd_queue(r.issue_desc).failed := flash_rfifo_data /= x"00";
                    end if;
                end if;
        end case;

        ------
        -- Deal with the completion response back out eSPI
        ------
        case r.compl_state is
            when idle =>
                if request.flash_get_req and flash_c_avail = '1' then
                    v.compl_state := read_dpr;
                    v.compl_side_cntr := 0;
                    v.resp_tag := r.cmd_queue(r.tail_desc).tag;
                    if r.cmd_queue(r.tail_desc).kind = flash_rd then
                        v.resp_length := r.cmd_queue(r.tail_desc).xfr_size_bytes;
                        v.resp_cycle_type := success_with_data_only;
                    elsif r.cmd_queue(r.tail_desc).failed then
                        v.resp_length := (others => '0');
                        v.resp_cycle_type := unsuccessful_no_data_only;
                    else
                        v.resp_length := (others => '0');
                        v.resp_cycle_type := success_no_data;
                    end if;
                   
                end if;
            when read_dpr =>
                -- We have a done descriptor, we need to read the data back out
                -- to the eSPI master. A completion without data retires
                -- straight away; the header fields were latched above.
                if r.compl_side_cntr = r.resp_length then
                    v.cmd_queue(r.tail_desc).active := false;
                    v.cmd_queue(r.tail_desc).done := false;
                    v.cmd_queue(r.tail_desc).flash_issued := false;
                    v.tail_desc := add_wrap(r.tail_desc, desc_index_t'high);
                    v.compl_state := idle;
                elsif response.ready = '1' and response.valid = '1' then
                    v.compl_side_cntr := r.compl_side_cntr + 1;
                end if;
        end case;

        ------
        -- One read port, two readers. Completions win; payload streaming
        -- pauses for as long as one is in progress. Computed from the next
        -- state so that the registered address always matches the counter
        -- the reader is on.
        ------
        if v.flash_cmd_state = stream_payload and v.compl_state = idle then
            v.dpr_raddr := To_Std_Logic_Vector(v.issue_desc * max_txn_size + v.flash_side_cntr, 12);
        else
            v.dpr_raddr := To_Std_Logic_Vector(v.tail_desc * max_txn_size + v.compl_side_cntr, 12);
        end if;

        if not enabled then
            -- If we're not enabled, reset the state machine
            v := reg_reset;
        end if;
        rin <= v;
    end process;

    command_processor_reg : process (clk, reset)
    begin
        if reset then
            r <= reg_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;
    

end rtl;
