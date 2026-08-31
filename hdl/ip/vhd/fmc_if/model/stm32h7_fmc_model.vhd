-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- FMC controller model based on ST's RM0433 rev8
-- figures 115 and 116 for simulation of the
-- FPGA's target interface
-- Oxide's internal doc mirror link:
-- https://drive.google.com/file/d/1wPaZAHS3-0HdMkXOC8tvGYgOPOrM0qRQ/view?usp=drive_link
--
-- Timing semantics modeled here (WAITCFG=1, DATLAT=0, the configuration
-- hubris programs): NWAIT is sampled on rising clock edges once the address
-- phase is over. For writes, each NWAIT-released rising edge advances one
-- data beat onto the bus at the following falling edge, so the beat is
-- captured by the target on the rising edge after the release was sampled.
-- For reads, data is sampled on the same rising edge where NWAIT is seen
-- released. This matches the cadence proven on hardware against the
-- pre-streaming target FSM; if hardware ILA captures ever disagree with
-- this contract, fix it here first.
--
-- ES0491 (dummy read cycles): after every burst read the controller
-- performs two dummy read accesses with the chip still selected; the model
-- reproduces them so the target's idle-return is exercised under them.
--
-- Also handled on the bus actor: wait_until_idle (making writes blockable),
-- and the control messages in stm32h7_fmc_model_pkg (inter-transaction gap,
-- one-shot mid-transaction abort).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.sync_pkg.all;

use work.stm32h7_fmc_model_pkg.all;

entity stm32h7_fmc_model is
    generic (
        bus_handle : bus_master_t
    );
    port (
        clk : in    std_logic;
        a   : out   std_logic_vector(address_length(bus_handle) - 1 downto 16);
        ad  : inout std_logic_vector(data_length(bus_handle) - 1 downto 0);
        ne  : out   std_logic_vector(3 downto 0);
        noe   : out   std_logic;
        nwe   : out   std_logic;
        nl    : out   std_logic;
        nwait : in    std_logic
    );
end entity;

architecture model of stm32h7_fmc_model is

    type txn_type is (read_txn, write_txn);

begin

    bfm: process
        variable request_msg : msg_t;
        variable reply_msg   : msg_t;
        variable msg_type    : msg_type_t;

        variable addr         : std_logic_vector(address_length(bus_handle) - 1 downto 0);
        variable data         : std_logic_vector(data_length(bus_handle) - 1 downto 0);
        variable rem_data_cnt : integer;
        variable beats_done   : natural;
        variable aborted      : boolean;
        -- extra idle cycles between transactions; 0 = back-to-back
        variable gap_cycles : natural := 0;
        -- one-shot: abort the next transaction after this many beats
        -- (negative = disarmed)
        variable abort_beats : integer := -1;

        procedure bus_idle is
        begin
            ne  <= (others => '1');
            a   <= (others => 'X');
            ad  <= (others => 'Z');
            nl  <= '1';
            nwe <= '1';
            noe <= '1';
        end;

        procedure transaction_start (
            constant kind : txn_type
        ) is
        begin
            addr := pop_std_ulogic_vector(request_msg);
            -- In 16 bit mode, so we need to shift the address to the right by one
            -- per table 156 in the ref manual (RM0433 rev 8, page 803)
            addr := "0" & addr(addr'left downto 1);
            rem_data_cnt := pop_integer(request_msg);
            ne(0) <= '0';
            nl <= '0';
            a <= addr(a'range);
            ad <= addr(ad'range);
            if kind = WRITE_TXN then
                nwe <= '0'; -- write strobe starts at beginning
            end if;
            -- on next falling edge of clock, latch clears
            wait until falling_edge(clk);
            nl <= '1';
            -- on next falling edge of clock, address clears
            wait until falling_edge(clk);
            a  <= (others => 'X');
            ad <= (others => 'Z');
            if kind = READ_TXN then
                noe <= '0';
            end if;
        end;
    begin
        bus_idle;
        loop
            receive(net, BUS_HANDLE.p_actor, request_msg);
            msg_type := message_type(request_msg);
            if msg_type = set_txn_gap_msg then
                gap_cycles := pop_integer(request_msg);
            elsif msg_type = abort_next_msg then
                abort_beats := pop_integer(request_msg);
            elsif msg_type = wait_until_idle_msg then
                -- Messages are handled in order, so reaching this one means
                -- every previously requested bus cycle has completed; this is
                -- what makes fmc_write32 blockable.
                handle_wait_until_idle(net, msg_type, request_msg);
            elsif msg_type = bus_burst_write_msg then
                -- Figure 116: all bus transactions begin with FMC_CLK low
                wait until falling_edge(clk);
                beats_done := 0;
                aborted    := false;
                transaction_start(WRITE_TXN);
                -- NWAIT sampling starts on the first rising edge after the
                -- address phase. The abort check sits after the edge wait so
                -- an already-applied beat is held through its capture edge
                -- before the bus deasserts.
                while rem_data_cnt > 0 loop
                    wait until rising_edge(clk);
                    if abort_beats >= 0 and beats_done = abort_beats then
                        aborted     := true;
                        abort_beats := -1;
                        exit;
                    end if;
                    if nwait = '1' then
                        wait until falling_edge(clk);
                        data         := pop_std_ulogic_vector(request_msg);
                        rem_data_cnt := rem_data_cnt - 1;
                        ad           <= data;
                        beats_done   := beats_done + 1;
                    end if;
                end loop;
                if aborted then
                    -- drain the un-sent beats so the message queue stays
                    -- consistent
                    while rem_data_cnt > 0 loop
                        data         := pop_std_ulogic_vector(request_msg);
                        rem_data_cnt := rem_data_cnt - 1;
                    end loop;
                    bus_idle;
                    -- The target takes a few cycles to notice the deselect
                    -- (its view of the bus is one capture-register cycle
                    -- behind) and clean up; a real SP cannot restart within
                    -- one cycle of an abort either, so give it room before
                    -- the next transaction.
                    for i in 1 to 4 loop
                        wait until falling_edge(clk);
                    end loop;
                else
                    -- hold the final beat through its capture edge
                    wait until falling_edge(clk);
                    bus_idle;
                end if;
            elsif msg_type = bus_burst_read_msg then
                wait until falling_edge(clk);
                beats_done := 0;
                aborted    := false;
                reply_msg  := new_msg;
                -- Figure 115
                transaction_start(READ_TXN);
                push_integer(reply_msg, rem_data_cnt);
                -- data cannot be valid before the edge after the address
                -- phase completes
                wait until falling_edge(clk);
                while rem_data_cnt > 0 loop
                    wait until rising_edge(clk);
                    if abort_beats >= 0 and beats_done = abort_beats then
                        aborted     := true;
                        abort_beats := -1;
                        exit;
                    end if;
                    if nwait = '1' then
                        -- sample data on the same edge the released wait is
                        -- sampled
                        push_std_ulogic_vector(reply_msg, ad);
                        rem_data_cnt := rem_data_cnt - 1;
                        beats_done   := beats_done + 1;
                    end if;
                end loop;
                if aborted then
                    -- fill the reply so burst_read_bus completes; the values
                    -- are meaningless by construction (note: must carry a
                    -- downto range to match the reader's slice)
                    data := (others => '0');
                    while rem_data_cnt > 0 loop
                        push_std_ulogic_vector(reply_msg, data);
                        rem_data_cnt := rem_data_cnt - 1;
                    end loop;
                else
                    -- ES0491: two dummy read cycles, chip still selected
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                end if;
                reply(net, request_msg, reply_msg);
                wait until falling_edge(clk);
                bus_idle;
                if aborted then
                    -- as for writes: let the target finish its abort cleanup
                    for i in 1 to 4 loop
                        wait until falling_edge(clk);
                    end loop;
                end if;
            else
                -- This shouldn't happen but will provide
                -- proper error reporting if it does
                unexpected_msg_type(msg_type);
            end if;
            for i in 1 to gap_cycles loop
                wait until falling_edge(clk);
            end loop;
        end loop;
    end process;

end model;
