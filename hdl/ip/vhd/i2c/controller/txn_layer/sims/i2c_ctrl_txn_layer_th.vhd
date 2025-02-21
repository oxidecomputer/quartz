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
use work.stream8_pkg;

use work.i2c_cmd_vc_pkg.all;
use work.i2c_target_vc_pkg.all;
use work.basic_stream_pkg.all;

entity i2c_ctrl_txn_layer_th is
    generic (
        CLK_PER_NS      : positive;
        TX_SOURCE       : basic_source_t;
        RX_SINK         : basic_sink_t;
        I2C_TARGET_VC   : i2c_target_vc_t;
        I2C_CMD_VC      : i2c_cmd_vc_t
    );
end entity;

architecture th of i2c_ctrl_txn_layer_th is
    constant CLK_PER_TIME : time := CLK_PER_NS * 1 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- Controller Tristate interface
    signal ctrl_scl_tristate    : tristate;
    signal ctrl_sda_tristate    : tristate;

    -- I2C bus
    signal scl  : std_logic;
    signal sda  : std_logic;

    -- command interface
    signal command          : cmd_t;
    signal command_valid    : std_logic;
    signal abort            : std_logic;
    signal core_ready       : std_logic;

    -- streaming interfaces
    signal tx_data_stream   : stream8_pkg.data_channel;
    signal rx_data_stream   : stream8_pkg.data_channel;

begin

    -- set up a fastish clock for the sim
    -- env and release reset after a bit of time
    clk   <= not clk after CLK_PER_TIME / 2;
    reset <= '0' after 200 ns;

    dut: entity work.i2c_ctrl_txn_layer
        generic map (
            CLK_PER_NS  => CLK_PER_NS,
            MODE        => FAST_PLUS
        )
        port map (
            clk             => clk,
            reset           => reset,
            scl_if          => ctrl_scl_tristate,
            sda_if          => ctrl_sda_tristate,
            cmd             => command,
            cmd_valid       => command_valid,
            abort           => abort,
            core_ready      => core_ready,
            tx_st_if        => tx_data_stream,
            rx_st_if        => rx_data_stream
        );

    i2c_cmd_vc_inst: entity work.i2c_cmd_vc
        generic map (
            I2C_CMD_VC => I2C_CMD_VC
        )
        port map (
            cmd     => command,
            valid   => command_valid,
            abort   => abort,
            ready   => core_ready
        );

    target: entity work.i2c_target_vc
        generic map (
            I2C_TARGET_VC => I2C_TARGET_VC
        )
        port map (
            scl => scl,
            sda => sda
        );

    tx_source_vc : entity work.basic_source
        generic map (
            SOURCE  => TX_SOURCE
        )
        port map (
            clk     => clk,
            valid   => tx_data_stream.valid,
            ready   => tx_data_stream.ready,
            data    => tx_data_stream.data
        );

    rx_sink_vc : entity work.basic_sink
        generic map (
            SINK    => RX_SINK
        )
        port map (
            clk     => clk,
            valid   => rx_data_stream.valid,
            ready   => rx_data_stream.ready,
            data    => rx_data_stream.data
        );

    -- wire the bus to the controller's tristate ports
    scl <= ctrl_scl_tristate.o when ctrl_scl_tristate.oe else 'H';
    sda <= ctrl_sda_tristate.o when ctrl_sda_tristate.oe else 'H';
    ctrl_scl_tristate.i     <= scl;
    ctrl_sda_tristate.i     <= sda;

end th;