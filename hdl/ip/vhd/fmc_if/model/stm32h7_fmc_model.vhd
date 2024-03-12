-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


--! Bus master model based on ST's RM0433
--! figures 115 and 116
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use vunit_lib.bus_master_pkg.all;

entity stm32h7_fmc_model is
    generic(
        BUS_HANDLE : bus_master_t
    );
    port(
        clk  : in std_logic;
        a    : out std_logic_vector(address_length(BUS_HANDLE) - 1 downto 16);
        ad   : inout std_logic_vector(data_length(BUS_HANDLE) - 1 downto 0);
        ne   : out std_logic_vector(3 downto 0);
        --todo missing byte enables?
        noe  : out std_logic;
        nwe  : out std_logic;
        nl   : out std_logic;
        nwait : in std_logic
    );
end entity;

architecture model of stm32h7_fmc_model is
    type txn_type is (READ_TXN, WRITE_TXN);
    signal delayed_wait : std_logic;
begin

    wait_delay:process(clk)
    begin
        if rising_edge(clk) then
            delayed_wait <= not nl;
        end if;
    end process;

    bfm : process
        variable request_msg : msg_t;
        variable reply_msg   : msg_t;
        variable msg_type    : msg_type_t;

        variable addr        : std_logic_vector(address_length(bus_handle) - 1 downto 0);
        variable data        : std_logic_vector(data_length(bus_handle) - 1 downto 0);
        variable rem_data_cnt : integer;
        procedure bus_idle is
        begin
            ne <= (others => '1');
            a <= (others => 'X');
            ad <= (others => 'Z');
            nl <= '1';
            nwe <= '1';
            noe <= '1';
        end procedure;

        procedure transaction_start(constant kind: txn_type) is
        begin
            addr := pop_std_ulogic_vector(request_msg);
            rem_data_cnt := pop_integer(request_msg);
            ne(0) <= '0';
            a <= addr(a'range);
            ad <= addr(ad'range);
            nl <= '0';
            if kind = WRITE_TXN then
                nwe <= '0'; -- write strobe starts at beginning
            end if;
            -- on next falling edge of clock, latch clears
            wait until falling_edge(clk);
            nl <= '1';
            -- on next falling edge of clock, address clears
            wait until falling_edge(clk);
            a <= (others => 'X');
            ad <= (others => 'Z');
            if kind = READ_TXN then
                noe <= '0';
            end if;
        end procedure;

    begin
        bus_idle;
        receive(net, BUS_HANDLE.p_actor, request_msg);
        msg_type    := message_type(request_msg);
        -- All bus transactions begin with the FMC_CLK
        -- low
        wait until falling_edge(clk);
        if msg_type = bus_burst_write_msg then
            -- Figure 116
            -- activate address, chipsel, write, and latch
            transaction_start(WRITE_TXN);
            -- on next falling edge of clock, apply wdata
            wait until falling_edge(clk);
            data := pop_std_ulogic_vector(request_msg);
            ad <= data;
            wait until rising_edge(clk);
            while rem_data_cnt > 0 loop
                wait on clk;
                -- on every rising edge that delayed wait isn't asserted,
                -- we've done a transfer
                if rising_edge(clk) and delayed_wait = '0' then
                    data := pop_std_ulogic_vector(request_msg);
                    rem_data_cnt := rem_data_cnt - 1;
                    ad <= data;
                end if;
            end loop;

        elsif msg_type = bus_burst_read_msg then
            reply_msg := new_msg;
            -- Figure 115
            -- activate address, chipsel, and latch
            transaction_start(READ_TXN);
            push_integer(reply_msg, rem_data_cnt);
            -- on next falling edge of clock, data could be on the bus
            wait until falling_edge(clk);
            wait until rising_edge(clk);
            while rem_data_cnt > 0 loop
                wait on clk;
                if rising_edge(clk) and delayed_wait = '0' then
                    -- sample data, dec remaining data
                    push_std_ulogic_vector(reply_msg, ad);
                    rem_data_cnt := rem_data_cnt - 1;
                end if;
            end loop;
            -- data out
            -- tbd waits
            reply(net, request_msg, reply_msg);
        else
            -- This shouldn't happen but will provide
            -- proper error reporting if it does
            unexpected_msg_type(msg_type);
        end if;

    end process;

end model;