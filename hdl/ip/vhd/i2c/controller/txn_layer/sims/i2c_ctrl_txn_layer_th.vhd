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
use work.i2c_common_pkg.all;
use work.tristate_if_pkg.all;
use work.stream8_pkg;

use work.i2c_cmd_vc_pkg.all;
use work.i2c_target_vc_pkg.all;
use work.basic_stream_pkg.all;

entity i2c_ctrl_txn_layer_th is
    generic (
        CLK_PER_NS      : positive;
        tx_source       : basic_source_t;
        rx_sink         : basic_sink_t;
        i2c_target_vc   : i2c_target_vc_t;
        i2c_cmd_vc      : i2c_cmd_vc_t
    );
end entity;

architecture th of i2c_ctrl_txn_layer_th is
    constant CLK_PER_TIME : time := CLK_PER_NS * 1 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- I2C interfaces
    signal ctrl_scl_tristate    : tristate;
    signal ctrl_sda_tristate    : tristate;
    signal target_scl_tristate  : tristate;
    signal target_sda_tristate  : tristate;

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
            i2c_cmd_vc => i2c_cmd_vc
        )
        port map (
            cmd     => command,
            valid   => command_valid,
            abort   => abort,
            ready   => core_ready
        );

    target: entity work.i2c_target_vc
        generic map (
            i2c_target_vc => i2c_target_vc
        )
        port map (
            scl_if.i    => target_scl_tristate.i,
            scl_if.o    => target_scl_tristate.o,
            scl_if.oe   => target_scl_tristate.oe,
            sda_if      => target_sda_tristate
        );

    tx_source_vc : entity work.basic_source
        generic map (
            source  => tx_source
        )
        port map (
            clk     => clk,
            valid   => tx_data_stream.valid,
            ready   => tx_data_stream.ready,
            data    => tx_data_stream.data
        );

    rx_sink_vc : entity work.basic_sink
        generic map (
            sink    => rx_sink
        )
        port map (
            clk     => clk,
            valid   => rx_data_stream.valid,
            ready   => rx_data_stream.ready,
            data    => rx_data_stream.data
        );

    -- wire the bus to the tristate inputs
    ctrl_scl_tristate.i     <= scl;
    target_scl_tristate.i   <= scl;
    ctrl_sda_tristate.i     <= sda;
    target_sda_tristate.i   <= sda;
    i2c_bus_resolver: process(all)
    begin
        if ctrl_scl_tristate.oe = '1' and target_scl_tristate.oe = '0' then
            -- controller has line
            scl <= ctrl_scl_tristate.o;
        elsif ctrl_scl_tristate.oe = '0' and target_scl_tristate.oe = '1' then
            -- targeteral has line
            scl <= target_scl_tristate.o;
        elsif ctrl_scl_tristate.oe = '1' and target_scl_tristate.oe = '1' then
            -- contention
            scl <= 'Z';
        else
            -- line floats to pull-up
            scl <= '1';
        end if;

        if ctrl_sda_tristate.oe = '1' and target_sda_tristate.oe = '0' then
            -- controller has line
            sda <= ctrl_sda_tristate.o;
        elsif ctrl_sda_tristate.oe = '0' and target_sda_tristate.oe = '1' then
            -- targeteral has line
            sda <= target_sda_tristate.o;
        elsif ctrl_sda_tristate.oe = '1' and target_sda_tristate.oe = '1' then
            -- contention
            sda <= 'Z';
        else
            -- line floats to pull-up
            sda <= '1';
        end if;
    end process;

end th;