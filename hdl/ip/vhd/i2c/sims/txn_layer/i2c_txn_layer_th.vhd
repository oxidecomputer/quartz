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

use work.i2c_common_pkg.all;
use work.i2c_common_pkg.all;
use work.tristate_if_pkg.all;
use work.stream8_pkg;

use work.i2c_cmd_vc_pkg.all;
use work.i2c_peripheral_pkg.all;
use work.basic_stream_pkg.all;

entity i2c_txn_layer_th is
    generic (
        tx_source       : basic_source_t;
        rx_sink         : basic_sink_t;
        i2c_peripheral  : i2c_peripheral_t;
        i2c_cmd_vc      : i2c_cmd_vc_t
    );
end entity;

architecture th of i2c_txn_layer_th is
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    -- I2C interfaces
    signal ctrl_scl_tristate    : tristate;
    signal ctrl_sda_tristate    : tristate;
    signal periph_scl_tristate  : tristate;
    signal periph_sda_tristate  : tristate;

    -- I2C bus
    signal scl  : std_logic;
    signal sda  : std_logic;

    -- command interface
    signal command          : cmd_t;
    signal command_valid    : std_logic;
    signal core_ready       : std_logic;

    -- streaming interfaces
    signal tx_data_stream   : stream8_pkg.data_channel;
    signal rx_data_stream   : stream8_pkg.data_channel;

begin

    -- set up a fastish clock for the sim
    -- env and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    dut: entity work.i2c_txn_layer
        generic map (
            CLK_PER_NS  => 8,
            MODE        => STANDARD
        )
        port map (
            clk             => clk,
            reset           => reset,
            scl_if          => ctrl_scl_tristate,
            sda_if          => ctrl_sda_tristate,
            cmd             => command,
            cmd_valid       => command_valid,
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
            ready   => core_ready
        );

    peripheral: entity work.i2c_peripheral
        generic map (
            i2c_peripheral_vc => i2c_peripheral
        )
        port map (
            scl_if.i  => periph_scl_tristate.i,
            scl_if.o  => periph_scl_tristate.o,
            scl_if.oe  => periph_scl_tristate.oe,
            sda_if  => periph_sda_tristate
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
    periph_scl_tristate.i   <= scl;
    ctrl_sda_tristate.i     <= sda;
    periph_sda_tristate.i   <= sda;
    i2c_bus_resolver: process(all)
    begin
        if ctrl_scl_tristate.oe = '1' and periph_scl_tristate.oe = '0' then
            -- controller has line
            scl <= ctrl_scl_tristate.o;
        elsif ctrl_scl_tristate.oe = '0' and periph_scl_tristate.oe = '1' then
            -- peripheral has line
            scl <= periph_scl_tristate.o;
        elsif ctrl_scl_tristate.oe = '1' and periph_scl_tristate.oe = '1' then
            -- contention
            scl <= 'Z';
        else
            -- line floats to pull-up
            scl <= '1';
        end if;

        if ctrl_sda_tristate.oe = '1' and periph_sda_tristate.oe = '0' then
            -- controller has line
            sda <= ctrl_sda_tristate.o;
        elsif ctrl_sda_tristate.oe = '0' and periph_sda_tristate.oe = '1' then
            -- peripheral has line
            sda <= periph_sda_tristate.o;
        elsif ctrl_sda_tristate.oe = '1' and periph_sda_tristate.oe = '1' then
            -- contention
            sda <= 'Z';
        else
            -- line floats to pull-up
            sda <= '1';
        end if;
    end process;

end th;