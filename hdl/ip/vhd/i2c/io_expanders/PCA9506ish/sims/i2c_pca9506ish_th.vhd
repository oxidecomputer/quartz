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
    signal i2c_bus_scl_o : std_logic;
    signal i2c_bus_scl_oe : std_logic;
    signal i2c_bus_sda : std_logic := 'Z';
    signal i2c_bus_sda_o : std_logic;
    signal i2c_bus_sda_oe : std_logic;

    signal tgt_scl : std_logic_vector(1 downto 0);
    signal tgt_scl_o : std_logic_vector(1 downto 0);
    signal tgt_scl_oe : std_logic_vector(1 downto 0);
    signal tgt_sda : std_logic_vector(1 downto 0);
    signal tgt_sda_o : std_logic_vector(1 downto 0);
    signal tgt_sda_oe : std_logic_vector(1 downto 0);

    signal io0 : pca9506_pin_t := (others => (others => '0'));
    signal io0_oe : pca9506_pin_t;
    signal io0_o : pca9506_pin_t;
    signal int0_n : std_logic;

    signal io1 : pca9506_pin_t := (others => (others => '0'));
    signal io1_oe : pca9506_pin_t;
    signal io1_o : pca9506_pin_t;
    signal int1_n : std_logic;

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

    i2c_bus_scl <= i2c_bus_scl_o when i2c_bus_scl_oe = '1' else 'H';
    i2c_bus_sda <= i2c_bus_sda_o when i2c_bus_sda_oe = '1' else 'H';
    
    DUT0: entity work.pca9506_top
     generic map(
        i2c_addr => 7x"20",
        giltch_filter_cycles => 3
    )
     port map(
        clk => clk,
        reset => reset,
        scl => tgt_scl(0),
        scl_o => tgt_scl_o(0),
        scl_oe => tgt_scl_oe(0),
        sda => tgt_sda(0),
        sda_o => tgt_sda_o(0),
        sda_oe => tgt_sda_oe(0),
        io => io0,
        io_oe => io0_oe,
        io_o => io0_o,
        int_n => int0_n
    );

    DUT1: entity work.pca9506_top
     generic map(
        i2c_addr => 7x"21",
        giltch_filter_cycles => 3
    )
     port map(
        clk => clk,
        reset => reset,
        scl => tgt_scl(1),
        scl_o => tgt_scl_o(1),
        scl_oe => tgt_scl_oe(1),
        sda => tgt_sda(1),
        sda_o => tgt_sda_o(1),
        sda_oe => tgt_sda_oe(1),
        io => io1,
        io_oe => io1_oe,
        io_o => io1_o,
        int_n => int1_n
    );

    bus_consolidator: entity work.i2c_phy_consolidator
     generic map(
        TARGET_NUM => 2
    )
     port map(
        clk => clk,
        reset => reset,
        scl => i2c_bus_scl,
        scl_o => i2c_bus_scl_o,
        scl_oe => i2c_bus_scl_oe,
        sda => i2c_bus_sda,
        sda_o => i2c_bus_sda_o,
        sda_oe => i2c_bus_sda_oe,
        tgt_scl => tgt_scl,
        tgt_scl_o => tgt_scl_o,
        tgt_scl_oe => tgt_scl_oe,
        tgt_sda => tgt_sda,
        tgt_sda_o => tgt_sda_o,
        tgt_sda_oe => tgt_sda_oe
    );


end th;