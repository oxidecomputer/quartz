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

use work.i2c_link_layer_pkg.all;

entity i2c_th is
end entity;

architecture th of i2c_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

begin

    -- set up a fastish clock for the sim
    -- env and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    dut: entity work.i2c_core
        generic map (
            CLK_PER_NS => 8,
            MODE        => STANDARD
        )
        port map (
            clk         => clk,
            reset   => reset,
            scl_if  => ,
            sda_if  => ,
            cmd     => ,
            cmd_valid   => ,
            core_ready => open,
            tx_st_if =>,
            rx_st_if =>
        );

end th;