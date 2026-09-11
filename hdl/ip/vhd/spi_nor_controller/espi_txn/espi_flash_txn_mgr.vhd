-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Flash client for the eSPI flash channel. Commands arrive as two words: the
-- SP5's address, then a length word whose top nibble says what kind of
-- request it is (see flash_channel_pkg in the eSPI IP). Reads come back on
-- the data FIFO as flash bytes. Writes and erases run the whole flash side
-- sequence here (write enable, program or erase, poll until not busy) and
-- come back as a single status byte, zero for success, so the eSPI side can
-- form a completion without knowing anything about the flash part.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.spi_nor_pkg.all;

entity espi_flash_txn_mgr is
    port(
        clk : in std_logic;
        reset: in std_logic;
        -- From Hubris control
        espi_reads_allowed: in std_logic;
        -- SP-controlled absolute flash address for the desired host image base address.
        -- We have 2 image slots, SP choses which of these is the starting address. This is signed
        -- and the value is added directly to the incomming raw AMD addresses to get a physical flash address, mapped into
        -- the right image region.
        sp_host_image_flash_addr_offset: in signed(31 downto 0);
        -- APOB region moves around in a given host image. The location of this is pre-determined (and stored in metadata)
        -- the SP provides this absolute flash address for the start of the APOB region for the current image, 
        --and we use this to determine if a given transaction is targeting the APOB region or not so we can adjust addresses accordingly.
        amd_begin_apob_flash_addr: in std_logic_vector(31 downto 0);
        -- SP provides the length of the remapping window to cover the APOB region that AMD will be fetching.
        apob_window_len: in std_logic_vector(31 downto 0);
        -- Absolute address of the desired APOB region in flash, used for address translation. 
        -- This is the base address that corresponds to the start of the APOB region, which is what the SP provides to us, 
        -- and then we add offsets to it based on the incoming transaction addresses to figure out where in flash we're actually reading from.
        sp_apob_base_flash_addr: in std_logic_vector(31 downto 0);
        -- espi cmd fifo interface
        espi_cmd_fifo_rdata: in std_logic_vector(31 downto 0);
        espi_cmd_fifo_rdack: out std_logic;
        espi_cmd_fifo_rempty: in std_logic;-- FIFO the command, which is simply an 32bit address
        -- espi command
        espi_cmd: out spi_nor_cmd_t;
        spi_hw_busy : in std_logic;
        -- High while the bytes the engine shifts out have to come from the
        -- eSPI write payload FIFO rather than the hubris TX FIFO.
        tx_from_espi : out std_logic;
        -- espi data fifo interface
        espi_flash_data_byte : out std_logic_vector(7 downto 0);
        flash_data_byte_write : out std_logic;
        -- Raw flash read_data
        flash_rdata : in std_logic_vector(7 downto 0);
        flash_rdata_write : in std_logic
    );
end entity;

architecture rtl of espi_flash_txn_mgr is
    attribute mark_debug : string;

    constant max_flash_read_size : natural := 255;
    constant page_bytes : natural := 256;
    constant fast_read_dummy_cycles : natural := 8;
    -- Request kinds, matching flash_channel_pkg.to_kind_bits
    constant kind_read : std_logic_vector(3 downto 0) := x"0";
    constant kind_write : std_logic_vector(3 downto 0) := x"1";
    constant kind_erase : std_logic_vector(3 downto 0) := x"2";
    -- eSPI SAFS erase size codes carried in the length field
    constant erase_4k : std_logic_vector(11 downto 0) := x"001";
    constant erase_64k : std_logic_vector(11 downto 0) := x"003";
    -- Status bytes reported back for writes and erases
    constant status_ok : std_logic_vector(7 downto 0) := x"00";
    constant status_unsupported : std_logic_vector(7 downto 0) := x"01";
    constant status_timeout : std_logic_vector(7 downto 0) := x"02";
    -- Polls before a program or erase is given up on. Each poll is a short
    -- transaction, hundreds of ns, so this is several seconds: comfortably
    -- past a worst case 64kB block erase, but not forever if the part is
    -- absent.
    constant max_polls : natural := 2**24 - 1;

    type state_t is (idle, read_cmd_addr, read_cmd_len, wait_for_data,
                     wait_idle, issue_cmd, wait_done, report_status);
    -- Which flash transaction the current request is up to
    type step_t is (step_read, step_wren, step_program, step_erase, step_poll);

    type reg_t is record
        state : state_t;
        step : step_t;
        cmd_rdack: std_logic;
        data_bytes: natural range 0 to 256;
        dummy_cycles: natural range 0 to 256;
        txn_bytes : natural range 0 to 255;
        rem_bytes: natural range 0 to 4096;
        raw_addr : std_logic_vector(31 downto 0);
        apob_addr : std_logic_vector(31 downto 0);
        image_addr : std_logic_vector(31 downto 0);
        cur_flash_addr : std_logic_vector(31 downto 0);
        apob_end_addr : std_logic_vector(31 downto 0);
        next_flash_addr: std_logic_vector(31 downto 0);
        len: std_logic_vector(31 downto 0);
        erase_op : std_logic_vector(7 downto 0);
        is_erase : boolean;
        status : std_logic_vector(7 downto 0);
        polls : natural range 0 to max_polls;
    end record;
    constant reg_reset : reg_t := (
        state => idle,
        step => step_read,
        cmd_rdack => '0',
        data_bytes => 0,
        dummy_cycles => 0,
        txn_bytes => 0,
        rem_bytes => 0,
        raw_addr => (others => '0'),
        apob_addr => (others => '0'),
        image_addr => (others => '0'),
        cur_flash_addr => (others => '0'),
        apob_end_addr => (others => '0'),
        next_flash_addr => (others => '0'),
        len => (others => '0'),
        erase_op => SECTOR_ERASE_4BYTE_OP,
        is_erase => false,
        status => status_ok,
        polls => 0
    );

    signal r, rin: reg_t;

    attribute mark_debug of r : signal is "TRUE";

    -- Bytes left in the page cur_addr sits in; a page program wraps inside
    -- its page on the part, so a chunk never crosses one.
    function bytes_to_page_end(addr : std_logic_vector(31 downto 0)) return natural is
    begin
        return page_bytes - to_integer(addr(7 downto 0));
    end function;

begin

    espi_cmd.addr <=r.cur_flash_addr;
    espi_cmd.data_bytes <= To_Std_Logic_Vector(r.data_bytes, espi_cmd.data_bytes'length);
    espi_cmd.dummy_cycles <= To_Std_Logic_Vector(fast_read_dummy_cycles,  espi_cmd.dummy_cycles'length);
    espi_cmd.instr <= FAST_READ_4BYTE_QUAD_OP when r.step = step_read else
                      WRITE_ENABLE_OP when r.step = step_wren else
                      QUAD_INPUT_PAGE_PROGRAM_4BYTE_OP when r.step = step_program else
                      r.erase_op when r.step = step_erase else
                      READ_STATUS_REG1_OP;
    espi_cmd.go_flag <= '1' when r.state = issue_cmd else '0';
    tx_from_espi <= '1' when r.step = step_program and (r.state = issue_cmd or r.state = wait_done) else '0';

    -- Turn the flash data we read back around into the data fifo going to the espi,
    -- but only when we're expecting data going to the espi block and not hubris FIFOs.
    -- The status byte for a write or erase goes out the same way.
    espi_flash_data_byte <= flash_rdata when r.state = wait_for_data else r.status;
    flash_data_byte_write <= flash_rdata_write when r.state = wait_for_data else
                             '1' when r.state = report_status else
                             '0';
    espi_cmd_fifo_rdack <= r.cmd_rdack;

    -- state machine that will pull 2 words from the command fifo.
    -- Word1: is the 32bit SP5 address, which we'll adjust to be the flash address when we pop it
    -- Word2: is the transaction length in byte-count, with the request kind in the top nibble.
    -- We're going to do page reads, so we'll need to do this in 256byte chunks so long as we have room
    -- in the data fifo. When we get to rem_bytes < 256 we'll do a final read of the remaining bytes.
    sm: process(all)
        variable v: reg_t;
        variable kind : std_logic_vector(3 downto 0);
    begin
        v := r;
        -- single cycle flag(s)
        v.cmd_rdack := '0';
        kind := espi_cmd_fifo_rdata(31 downto 28);
        
        case r.state is
            when idle =>
                if espi_cmd_fifo_rempty = '0' and espi_reads_allowed = '1' then
                    v.state := read_cmd_addr;
                    -- This is a show-ahead fifo so it's no problem, espi_cmd_fifo_rdata is valid
                    -- here. Thus, we take the opportunity to precompute a couple different
                    -- addresses before deciding which one to use next cycle.
                    v.raw_addr := espi_cmd_fifo_rdata;

                    -- Option 1: Host flash slot 0 or 1, where images are stored
                    -- We know the SP5 is only sending positive addresses, but cur_flash_addr_offset is signed so we need to cast the v.raw_addr
                    -- to unsigned also to do the math, so we add a leading zero bit, and then resize back down to 32bits.
                    -- normal flash address, just adjust by the offset
                    assert unsigned(v.raw_addr) < x"10000000" report "Address must be less than 256MB" severity failure;
                    v.image_addr := std_logic_vector(resize(signed('0' & v.raw_addr) + sp_host_image_flash_addr_offset, 32));

                    -- Option 2: APOB slot 0 or 1
                    v.apob_addr := std_logic_vector(
                        unsigned(sp_apob_base_flash_addr) + -- an absolute offset in flash
                        unsigned(v.raw_addr) - 
                        unsigned(amd_begin_apob_flash_addr)
                    );

                    -- pre-calculate the end address of the APOB region so we can check against it later (again for timing)
                    v.apob_end_addr := std_logic_vector((unsigned(amd_begin_apob_flash_addr) + unsigned(apob_window_len)));
                end if;
            when read_cmd_addr =>
                -- The SP5 only knows about one flash slot, and hubris controls which
                -- flash slot we're actually talking to so we adjust the commands from
                -- the SP5 right here one time so that we're in real flash addresses from there
                -- on out.
                -- Now check if the registered address lands in the active APOB region. If not,
                -- use the active image address.
                if unsigned(r.raw_addr) >= unsigned(amd_begin_apob_flash_addr) and
                   unsigned(r.raw_addr) <  unsigned(r.apob_end_addr)then
                    v.cur_flash_addr := r.apob_addr;
                   else
                    v.cur_flash_addr := r.image_addr;
                end if;
                v.state := read_cmd_len;

            when read_cmd_len =>
                v.status := status_ok;
                v.polls := 0;
                v.is_erase := kind = kind_erase;
                case kind is
                    when kind_write =>
                        -- 1-indexed byte count; the payload is already sitting
                        -- in the write FIFO in full.
                        v.rem_bytes := to_integer(espi_cmd_fifo_rdata(11 downto 0));
                        v.step := step_wren;
                        v.data_bytes := 0;
                        if v.rem_bytes = 0 then
                            v.state := report_status;
                        else
                            v.state := wait_idle;
                        end if;
                    when kind_erase =>
                        -- Length is the SAFS erase size code. Only the sizes
                        -- with a 4-byte-address opcode are offered; anything
                        -- else is reported back as unsupported.
                        v.step := step_wren;
                        v.data_bytes := 0;
                        v.state := wait_idle;
                        case espi_cmd_fifo_rdata(11 downto 0) is
                            when erase_4k =>
                                v.erase_op := SECTOR_ERASE_4BYTE_OP;
                            when erase_64k =>
                                v.erase_op := BLOCK_ERASE_64K_4BYTE_OP;
                            when others =>
                                v.status := status_unsupported;
                                v.state := report_status;
                        end case;
                    when others =>
                        -- This comes 1-indexed from the eSPI block, so we need to subtract 1 below.
                        -- The guard is for simulation: the fifo's showahead word is
                        -- still the address for a delta after the pop, and a zero
                        -- length would otherwise put -1 in a natural.
                        if espi_cmd_fifo_rdata(11 downto 0) = 0 then
                            v.rem_bytes := 0;
                        else
                            v.rem_bytes := to_integer(espi_cmd_fifo_rdata(11 downto 0)) - 1;
                        end if;
                        v.step := step_read;
                        v.state := wait_idle;
                        -- We're either going to issue the max page size, or the 0-indexed remaining bytes
                        -- which ever is smaller.
                        v.txn_bytes := minimum(v.rem_bytes, max_flash_read_size);
                        -- spi is 1-indexed still, so we need to add 1 here
                        v.data_bytes := v.txn_bytes + 1;
                end case;

            when wait_for_data =>
                -- count down when we load data into the fifo
                if flash_rdata_write = '1' and r.txn_bytes > 0 then
                    v.txn_bytes := r.txn_bytes - 1;
                -- on final write decide where we're going
                elsif flash_rdata_write = '1' then
                    -- last data, no more parts of the full read to do
                    if r.rem_bytes = 0 then
                        v.state := idle;
                    -- last data for this part of the transaction
                    else
                        v.state := wait_idle;
                        v.cur_flash_addr := r.next_flash_addr;
                        v.txn_bytes := minimum(v.rem_bytes, max_flash_read_size);
                        v.data_bytes := v.txn_bytes + 1;
                    end if;
                end if;

            -- Each flash transaction is one trip around wait_idle ->
            -- issue_cmd -> wait_done (or wait_for_data for a read chunk),
            -- with r.step saying which one it is.
            when wait_idle =>
                -- The previous transaction has to be completely finished
                -- before asking for the next one, otherwise the busy rise
                -- waited on below would be its cs_n, not ours.
                if spi_hw_busy = '0' then
                    case r.step is
                        when step_program =>
                            v.data_bytes := minimum(r.rem_bytes, bytes_to_page_end(r.cur_flash_addr));
                        when step_poll =>
                            v.data_bytes := 1;
                        when step_read =>
                            null;  -- already sized for this chunk
                        when others =>
                            v.data_bytes := 0;
                    end case;
                    v.state := issue_cmd;
                end if;
            when issue_cmd =>
                -- Hold go until the engine pulls cs_n low. It ignores go during
                -- its minimum cs_n high time, and busy is already low then, so
                -- leaving on "not busy" would drop the command.
                if spi_hw_busy = '1' then
                    case r.step is
                        when step_read =>
                            v.state := wait_for_data;
                            -- Adjust info for a potential next read or so we can decide we're done later
                            v.rem_bytes := r.rem_bytes - r.txn_bytes;
                            v.next_flash_addr := r.cur_flash_addr + (r.txn_bytes + 1);
                        when step_program =>
                            v.state := wait_done;
                            v.rem_bytes := r.rem_bytes - r.data_bytes;
                            v.next_flash_addr := r.cur_flash_addr + r.data_bytes;
                        when others =>
                            v.state := wait_done;
                    end case;
                end if;
            when wait_done =>
                -- The one byte back from a status poll shows up here; the
                -- part reports write-in-progress in bit 0.
                if flash_rdata_write = '1' then
                    v.status := flash_rdata;
                end if;
                if spi_hw_busy = '0' then
                    case r.step is
                        when step_read =>
                            null;  -- reads finish out of wait_for_data
                        when step_wren =>
                            if r.is_erase then
                                v.step := step_erase;
                            else
                                v.step := step_program;
                            end if;
                            v.state := wait_idle;
                        when step_program | step_erase =>
                            v.step := step_poll;
                            v.state := wait_idle;
                        when step_poll =>
                            if r.status(0) = '1' then
                                if r.polls = max_polls then
                                    v.status := status_timeout;
                                    v.state := report_status;
                                else
                                    v.polls := r.polls + 1;
                                    v.state := wait_idle;
                                end if;
                            elsif r.rem_bytes > 0 then
                                -- more pages of this write to go, each one
                                -- needs its own write enable
                                v.status := status_ok;
                                v.cur_flash_addr := r.next_flash_addr;
                                v.step := step_wren;
                                v.state := wait_idle;
                            else
                                v.status := status_ok;
                                v.state := report_status;
                            end if;
                    end case;
                end if;
            when report_status =>
                -- one status byte goes out on the data fifo this cycle
                v.state := idle;

        end case;

        -- easier to set up the combo stuff here so that we
        -- read the fifo in these two states.
        if v.state = read_cmd_addr or v.state = read_cmd_len then
            v.cmd_rdack := '1';
        end if;

        rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset then
            r <= reg_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;
