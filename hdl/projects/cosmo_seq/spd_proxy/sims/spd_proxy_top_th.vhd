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

use work.axil8x32_pkg;
use work.i2c_common_pkg.all;
use work.tristate_if_pkg.all;
use work.spd_proxy_tb_pkg.all;

entity spd_proxy_top_th is
end entity;

architecture th of spd_proxy_top_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal axi_if      : axil8x32_pkg.axil_t;
    signal dimm_abcdef_scl : std_logic;
    signal dimm_abcdef_sda : std_logic;
    signal dimm_ghijkl_scl : std_logic;
    signal dimm_ghijkl_sda : std_logic;
    signal cpu_abcdef_scl : std_logic;
    signal cpu_abcdef_sda : std_logic;
    signal cpu_ghijkl_scl : std_logic;
    signal cpu_ghijkl_sda : std_logic;
    signal cpu_scl_if0  : tristate;
    signal cpu_sda_if0  : tristate;
    signal cpu_scl_if1  : tristate;
    signal cpu_sda_if1  : tristate;
    signal dimm_scl_if0  : tristate;
    signal dimm_sda_if0  : tristate;
    signal dimm_scl_if1  : tristate;
    signal dimm_sda_if1  : tristate;

begin

    -- set up a fastish clock for the sim env
    -- and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    axi_lite_master_inst: entity vunit_lib.axi_lite_master
        generic map (
            bus_handle => bus_handle
        )
        port map (
            aclk    => clk,
            arready => axi_if.read_address.ready,
            arvalid => axi_if.read_address.valid,
            araddr  => axi_if.read_address.addr,
            rready  => axi_if.read_data.ready,
            rvalid  => axi_if.read_data.valid,
            rdata   => axi_if.read_data.data,
            rresp   => axi_if.read_data.resp,
            awready => axi_if.write_address.ready,
            awvalid => axi_if.write_address.valid,
            awaddr  => axi_if.write_address.addr,
            wready  => axi_if.write_data.ready,
            wvalid  => axi_if.write_data.valid,
            wdata   => axi_if.write_data.data,
            wstrb   => axi_if.write_data.strb,
            bvalid  => axi_if.write_response.valid,
            bready  => axi_if.write_response.ready,
            bresp   => axi_if.write_response.resp
        );

     -- simulated CPU I2C controller
    cpu_abcdef_vc: entity work.i2c_controller_vc
    generic map(
        I2C_CTRL_VC => I2C_CTRL_VC,
        MODE        => SIMULATION
    )
    port map(
        scl => cpu_abcdef_scl,
        sda => cpu_abcdef_sda
    );

    cpu_abcdef_scl <= cpu_scl_if0.o when cpu_scl_if0.oe else 'H';
    cpu_scl_if0.i <= cpu_abcdef_scl;

    cpu_abcdef_sda <= cpu_sda_if0.o when cpu_sda_if0.oe else 'H';
    cpu_sda_if0.i <= cpu_abcdef_sda;

     -- simulated DIMM I2C target
    dimm_abcdef_vc: entity work.i2c_target_vc
    generic map(
        I2C_TARGET_VC => I2C_DIMM1_TGT_VC
    )
    port map(
        scl => dimm_abcdef_scl,
        sda => dimm_abcdef_sda
    );

    dimm_abcdef_scl <= dimm_scl_if0.o when dimm_scl_if0.oe else 'H';
    dimm_scl_if0.i <= dimm_abcdef_scl;
    
    dimm_abcdef_sda <= dimm_sda_if0.o when dimm_sda_if0.oe else 'H';
    dimm_sda_if0.i <= dimm_abcdef_sda;

    cpu_ghijkl_vc: entity work.i2c_controller_vc
    generic map(
        I2C_CTRL_VC => I2C_CTRL_VC,
        MODE        => SIMULATION
    )
    port map(
        scl => cpu_ghijkl_scl,
        sda => cpu_ghijkl_sda
    );

    cpu_ghijkl_scl <= cpu_scl_if1.o when cpu_scl_if1.oe else 'H';
    cpu_scl_if1.i <= cpu_ghijkl_scl;
    cpu_ghijkl_sda <= cpu_sda_if1.o when cpu_sda_if1.oe else 'H';
    cpu_sda_if1.i <= cpu_ghijkl_sda;

    dimm_ghijkl_vc: entity work.i2c_target_vc
    generic map(
        I2C_TARGET_VC => I2C_DIMM2_TGT_VC
    )
    port map(
        scl => dimm_ghijkl_scl,
        sda => dimm_ghijkl_sda
    );

    dimm_ghijkl_scl <= dimm_scl_if1.o when dimm_scl_if1.oe else 'H';
    dimm_scl_if1.i <= dimm_ghijkl_scl;
    
    dimm_ghijkl_sda <= dimm_sda_if1.o when dimm_sda_if1.oe else 'H';
    dimm_sda_if1.i <= dimm_ghijkl_sda;


    DUT: entity work.spd_proxy_top
     generic map(
        CLK_PER_NS => CLK_PER_NS,
        I2C_MODE => SIMULATION
    )
     port map(
        clk => clk,
        reset => reset,
        axi_if => axi_if,
        cpu_scl_if0 => cpu_scl_if0,
        cpu_sda_if0 => cpu_sda_if0,
        cpu_scl_if1 => cpu_scl_if1,
        cpu_sda_if1 => cpu_sda_if1,
        dimm_scl_if0 => dimm_scl_if0,
        dimm_sda_if0 => dimm_sda_if0,
        dimm_scl_if1 => dimm_scl_if1,
        dimm_sda_if1 => dimm_sda_if1
    );
    

end th;