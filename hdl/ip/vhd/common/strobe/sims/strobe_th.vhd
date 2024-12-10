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
        CLK_PER : time;
        TICKS   : positive
    );
end entity;

architecture th of strobe_th is

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';
    signal dut_enable   : std_logic := '0';
    signal dut_strobe   : std_logic;

begin

    clk   <= not clk after CLK_PER / 2;
    reset <= '0' after 200 ns;

    strobe_inst: entity work.strobe
        generic map (
            TICKS => TICKS
        )
        port map (
            clk     => clk,
            reset   => reset,
            enable  => dut_enable,
            strobe  => dut_strobe
        );

end th;