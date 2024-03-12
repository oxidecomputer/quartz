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
    port(
        clk  : in std_logic;
        a    : out std_logic_vector(25 downto 16);
        ad   : inout std_logic_vector(15 downto 0);
        ne   : out std_logic_vector(3 downto 0);
        noe  : out std_logic;
        nwe  : out std_logic;
        nl   : out std_logic;
        nwait : in std_logic
    );
end entity;

architecture model of stm32h7_fmc_model is

begin

    bfm : process
        variable request_msg : msg_t;
        variable reply_msg   : msg_t;
        variable msg_type    : msg_type_t;

    begin
        -- TODO: set up the default I/O
        receive(net, bus_handle.p_actor, request_msg);
        msg_type    := message_type(request_msg);
        -- All bus transactions begin with the FMC_CLK
        -- low
        wait until falling_edge(clk);
        if msg_type = bus_burst_write_msg then
            -- Figure 116
            -- activate address, chipsel, write, and latch
            -- on next falling edge of clock, latch clears
            -- on next falling edge of clock, address clears
            -- on next falling edge of clock, apply wdata
            -- tbd waits

        elsif msg_type = bus_burst_read_msg then
            -- Figure 115
            -- activate address, chipsel, and latch
            -- on next falling edge of clock, latch clears
            -- on next falling edge NOE
            -- bus turnaround time
            -- data out
            -- tbd waits
        else
            -- This shouldn't happen but will provide
            -- proper error reporting if it does
            unexpected_msg_type(msg_type);
        end if;

    end process;

end model;