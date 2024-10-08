-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

entity strobe_th is
    generic (
        TICKS : natural
    );
end entity;

architecture th of strobe_th is

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';
    signal dut_strobe   : std_logic;

begin

    -- set up a fastish clock for the sim env
    -- and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    strobe_inst: entity work.strobe
        generic map (
            TICKS => TICKS
        )
        port map (
            clk     => clk,
            reset   => reset,
            strobe  => dut_strobe
        );

end th;