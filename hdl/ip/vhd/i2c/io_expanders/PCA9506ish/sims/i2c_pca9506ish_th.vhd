-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.i2c_ctrl_vc_pkg.all;
use work.i2c_pca9506ish_sim_pkg.all;

use work.pca9506_pkg.all;

entity i2c_pca9506ish_th is
end entity;

architecture th of i2c_pca9506ish_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal i2c_bus_scl : std_logic := 'Z';
    signal i2c_bus_sda : std_logic := 'Z';
    signal tgt_scl_o : std_logic;
    signal tgt_scl_oe : std_logic;
    signal tgt_sda_o : std_logic;
    signal tgt_sda_oe : std_logic;

    signal io : pca9506_pin_t := (others => (others => '0'));
    signal io_oe : pca9506_pin_t;
    signal io_o : pca9506_pin_t;
    signal int_n : std_logic;

begin

    -- set up a fastish clock for the sim env
    -- and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    i2c_controller_vc_inst: entity work.i2c_controller_vc
     generic map(
        i2c_ctrl_vc => i2c_ctrl_vc
    )
     port map(
        scl => i2c_bus_scl,
        sda => i2c_bus_sda
    );

    i2c_bus_scl <= tgt_scl_o when tgt_scl_oe = '1' else 'H';
    i2c_bus_sda <= tgt_sda_o when tgt_sda_oe = '1' else 'H';
    
    pca9506_top_inst: entity work.pca9506_top
     generic map(
        i2c_addr => 7x"20",
        giltch_filter_cycles => 3
    )
     port map(
        clk => clk,
        reset => reset,
        scl => i2c_bus_scl,
        scl_o => tgt_scl_o,
        scl_oe => tgt_scl_oe,
        sda => i2c_bus_sda,
        sda_o => tgt_sda_o,
        sda_oe => tgt_sda_oe,
        io => io,
        io_oe => io_oe,
        io_o => io_o,
        int_n => int_n
    );

end th;