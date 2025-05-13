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

use work.i2c_common_pkg.all;
use work.tristate_if_pkg.all;
use work.axi_st8_pkg;

use work.spd_proxy_tb_pkg.all;

entity spd_proxy_th is
end entity;

architecture th of spd_proxy_th is
    constant CLK_PER_TIME : time := CLK_PER_NS * 1 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal cpu_scl  : std_logic;
    signal cpu_sda  : std_logic;
    signal dimm_scl : std_logic;
    signal dimm_sda : std_logic;

    signal cpu_proxy_scl_if     : tristate;
    signal cpu_proxy_sda_if     : tristate;
    signal dimm_proxy_scl_if    : tristate;
    signal dimm_proxy_sda_if    : tristate;

    signal command          : cmd_t;
    signal command_valid    : std_logic;
    signal controller_ready : std_logic;
    signal tx_data_stream   : axi_st8_pkg.axi_st_t;
    signal rx_data_stream   : axi_st8_pkg.axi_st_t;
begin

    clk     <= not clk after CLK_PER_TIME / 2;
    reset   <= '0' after 200 ns;

    -- simulated CPU I2C controller
    i2c_controller_vc_inst: entity work.i2c_controller_vc
        generic map(
            I2C_CTRL_VC => I2C_CTRL_VC,
            MODE        => STANDARD
        )
        port map(
            scl => cpu_scl,
            sda => cpu_sda
        );

    -- simulated DIMM I2C target
    i2c_target_vc_inst: entity work.i2c_target_vc
        generic map(
            I2C_TARGET_VC => I2C_DIMM1_TGT_VC
        )
        port map(
            scl => dimm_scl,
            sda => dimm_sda
        );

    -- DUT: the SPD proxy
    spd_proxy_top_inst: entity work.spd_i2c_proxy
        generic map(
            CLK_PER_NS  => CLK_PER_NS,
            I2C_MODE    => FAST_PLUS
        )
        port map(
            clk                 => clk,
            reset               => reset,
            cpu_scl_if          => cpu_proxy_scl_if,
            cpu_sda_if          => cpu_proxy_sda_if,
            dimm_scl_if         => dimm_proxy_scl_if,
            dimm_sda_if         => dimm_proxy_sda_if,
            i2c_command         => command,
            i2c_command_valid   => command_valid,
            i2c_ctrlr_idle      => controller_ready,
            i2c_tx_st_if        => tx_data_stream,
            i2c_rx_st_if        => rx_data_stream
        );

    -- I2C simulation support infrastructure
    i2c_cmd_vc_inst: entity work.i2c_cmd_vc
        generic map (
            I2C_CMD_VC => I2C_CMD_VC
        )
        port map (
            cmd     => command,
            valid   => command_valid,
            abort   => open,
            ready   => controller_ready
        );

    tx_source_vc : entity work.basic_source
        generic map (
            SOURCE  => TX_DATA_SOURCE_VC
        )
        port map (
            clk     => clk,
            valid   => tx_data_stream.valid,
            ready   => tx_data_stream.ready,
            data    => tx_data_stream.data
        );

    rx_sink_vc : entity work.basic_sink
        generic map (
            SINK    => RX_DATA_SINK_VC
        )
        port map (
            clk     => clk,
            valid   => rx_data_stream.valid,
            ready   => rx_data_stream.ready,
            data    => rx_data_stream.data
        );

    -- wire the CPU to the proxy DUT
    cpu_scl <= cpu_proxy_scl_if.o when cpu_proxy_scl_if.oe else 'H';
    cpu_sda <= cpu_proxy_sda_if.o when cpu_proxy_sda_if.oe else 'H';
    cpu_proxy_scl_if.i  <= cpu_scl;
    cpu_proxy_sda_if.i  <= cpu_sda;

    -- wire the proxy DUT to the DIMMs
    dimm_scl <= dimm_proxy_scl_if.o when dimm_proxy_scl_if.oe else 'H';
    dimm_sda <= dimm_proxy_sda_if.o when dimm_proxy_sda_if.oe else 'H';
    dimm_proxy_scl_if.i <= dimm_scl;
    dimm_proxy_sda_if.i <= dimm_sda;

end architecture;