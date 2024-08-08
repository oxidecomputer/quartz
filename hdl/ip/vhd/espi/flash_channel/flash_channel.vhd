-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_base_types_pkg.all;
use work.flash_channel_pkg.all;

entity flash_channel is
    port (
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        -- eSPI Transaction interface
        request: view flash_chan_req_sink;
        response: view flash_channel_resp_source;

        -- eSPI Status interface
        flash_np_free : out std_logic;
        flash_c_avail : out std_logic;

        -- Flash block interface
        flash_fifo_data : in std_logic_vector(7 downto 0);
        flash_fifo_rdack : out std_logic;
        flash_fifo_rempty: in std_logic;

    );
end;


architecture rtl of flash_channel is
    constant max_txn_size : integer := 1024;
    subtype desc_index_t is natural range 0 to num_descriptors - 1;
    signal dpr_waddr : std_logic_vector(11 downto 0);
    signal dpr_raddr : std_logic_vector(11 downto 0);


    type cmd_state_t is (idle, issue_flash_cmd, wait_for_data);
    type complete_state_t is (idle, read_dpr);

    type reg_type is record
        flash_cmd_state : cmd_state_t;
        compl_state : complete_state_t;
        flash_side_cntr : integer range 0 to 1024;
        compl_side_cntr : integer range 0 to 1024;
        cmd_queue: command_queue_t;
        dpr_write_en: std_logic;
        tail_desc: desc_index_t;
        issue_desc: desc_index_t;
        head_desc: desc_index_t;
        flash_np_free : std_logic;
        flash_c_avail: std_logic;
    end record;
    constant reg_reset : reg_type := (idle, idle, 0, 0, (others => descriptor_init), '0', 0, 0, 0, '0', '0');

    signal r, rin : reg_type;


begin

    -- Always write straight from the FIFO to the dpr so any dpr write is a fifo read ack also
    flash_fifo_rdack <= r.dpr_write_en;
    flash_np_free <= r.flash_np_free;
    flash_c_avail <= r.flash_c_avail;


    -- Let's put a 4kB buffer here as a starting point and see how it goes, this would allow 4 1024Byte max size tansactions
    -- or we could shrink and say 2 2kB etc. We know we're only going read on this interface so we don't ahve to worry so much about
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
        wdata => flash_fifo_data,
        wren => r.dpr_write_en,
        rclk => clk,
        raddr => dpr_raddr,
        rdata => response.data
    );
    response.valid <= '1' when r.compl_state = read_dpr else '0';

    dpr_waddr <= To_Std_Logic_Vector(r.cmd_queue(r.issue_desc).id * max_txn_size  + r.flash_side_cntr, 12);
    dpr_raddr <= To_Std_Logic_Vector(r.cmd_queue(r.tail_desc).id * max_txn_size  + r.flash_side_cntr, 12);

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
        variable any_done_descriptors : boolean;
    begin
        v := r;

        -------
        -- Adding new requestes to the processing queue
        ------
        -- Command processing requests flash command queue, having already filtered 
        -- out any invalid commands such as writes/erases
        -- we have 4 queue (txn) slots and can do 1024 byte per transaction max
        -- We simply carve up the DPR into 4 slots and then use those one for
        -- each descriptor, and we use the descriptors in order.
        if request.flash_np_enqueue_req and r.flash_np_free = '1' then
            v.cmd_queue(r.head_desc).sp5_addr := request.sp5_flash_address;
            v.cmd_queue(r.head_desc).xfr_size_bytes := request.espi_hdr.length;
            v.cmd_queue(r.head_desc).active := true;
            v.cmd_queue(r.head_desc).tag := request.espi_hdr.tag;
            v.cmd_queue(r.head_desc).flash_issued := false;
            v.cmd_queue(r.head_desc).done := false;
            v.head_desc := r.head_desc + 1;

        end if;

        for i in num_descriptors - 1 downto 0 loop
            -- set default, fall-through states
            v.flash_np_free := '0';
            flash_issue_needed := false;
            any_done_descriptors := false;

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
                any_done_descriptors := true;
            end if;
        end loop;

        ------
        -- Issuing queued commands to the flash block, and storing flash data back into the DPR
        ------
        -- Once we have one or more commands enqueued, we need to issue requests to the flash controller
        -- and store the data back in the DPR and then issue a completion request, and hold until
        -- the master does a get to get the data
        v.dpr_write_en := '0';  --only single cycle reads, default to 0
        case r.flash_cmd_state is
            when idle =>
                -- have active command that hasn't been issued to flash
                if flash_issue_needed then
                    v.flash_cmd_state := issue_flash_cmd;
                    
                end if;
            -- issue to flash, and wait until we get all the data back
            -- and have stored it into the DPR. We can't issue more than
            -- on command to the flash controller at a time so we'll spin
            -- here until it finishes. When it finishes, we should have
            -- all the data back in the DPR and we can call it done.
            when issue_flash_cmd =>
                -- Send the address to the flash controller
                v.flash_cmd_state := wait_for_data;
                v.flash_side_cntr := 0;
                v.cmd_queue(r.issue_desc).flash_issued := true;
                
            when wait_for_data =>
                if r.flash_side_cntr =  r.cmd_queue(r.issue_desc).xfr_size_bytes then
                    v.cmd_queue(r.issue_desc).done := true;
                    v.flash_cmd_state := idle;
                    v.flash_side_cntr := 0;
                    v.issue_desc := r.issue_desc + 1;
                elsif not flash_fifo_rempty then
                    v.dpr_write_en := '1';
                    v.flash_side_cntr := r.flash_side_cntr + 1;
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
                   
                end if;
            when read_dpr =>
                -- We have a done descriptor, we need to read the data back out
                -- to the eSPI master
                if r.compl_side_cntr = r.cmd_queue(r.tail_desc).xfr_size_bytes then
                    v.cmd_queue(r.tail_desc).active := false;
                    v.cmd_queue(r.tail_desc).done := false;
                    v.cmd_queue(r.tail_desc).flash_issued := false;
                    v.tail_desc := r.tail_desc + 1;
                    v.compl_state := idle;
                elsif response.ready = '1' and response.valid = '1' then
                    v.compl_side_cntr := r.compl_side_cntr + 1;
                end if;
        end case;


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