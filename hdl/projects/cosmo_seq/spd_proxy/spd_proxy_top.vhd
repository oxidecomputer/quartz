-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

use work.i2c_common_pkg.all;
use work.stream8_pkg;
use work.tristate_if_pkg.all;

entity spd_proxy_top is
    generic (
        CLK_PER_NS: positive;
        I2C_MODE: mode_t;
    )
    port (
        clk         : in std_logic;
        reset       : in std_logic;

        -- CPU <-> FPGA
        cpu_scl_if  : view tristate_if;
        cpu_sda_if  : view tristate_if;

        -- FPGA <-> DIMMs
        dimm_scl_if : view tristate_if;
        dimm_sda_if : view tristate_if;
    );
end entity;

architecture rtl of spd_proxy_top is
    signal cpu_scl_filt         : std_logic;
    signal cpu_scl_fedge        : std_logic;
    signal cpu_sda_fedge        : std_logic;
    signal cpu_sda_redge        : std_logic;
    signal cpu_start_detected   : std_logic;
    signal cpu_stop_detected    : std_logic;
    signal cpu_busy             : boolean;
    signal cpu_has_mux          : boolean;

    signal need_start : boolean;
    signal start_simulated      : boolean;

    signal fpga_idle    : std_logic;
    signal fpga_scl_if  : tristate;
    signal fpga_sda_if  : tristate;

    signal tx_st_if : stream8_pkg.data_channel;
    signal rx_st_if : stream8_pkg.data_channel;
begin
    --
    -- CPU bus monitoring
    --
    i2c_glitch_filter_inst: entity work.i2c_glitch_filter
        generic map(
            filter_cycles   => 5 -- todo math this
        )
        port map(
            clk             => clk,
            reset           => reset,
            raw_scl         => cpu_scl_if.i,
            raw_sda         => cpu_sda_if.i,
            filtered_scl    => cpu_scl_filt,
            scl_redge       => open,
            scl_fedge       => cpu_scl_fedge,
            filtered_sda    => open,
            sda_redge       => cpu_sda_redge,
            sda_fedge       => cpu_sda_fedge
        );

    -- on a START we need to request the controller abort any in-progress transaction
    cpu_start_detected  <= '1' when cpu_scl_filt = '1' and cpu_sda_fedge = '1' else '0';
    -- on a STOP we know the CPU is done and we can resume our work
    cpu_stop_detected   <= '1' when cpu_scl_filt = '1' and cpu_sda_redge = '1' else '0';

    bus_monitor: process(clk, reset)
    begin
        if reset then
            cpu_busy                <= false;
            cpu_has_mux             <= false;
            need_start              <= false;
        elsif rising_edge(clk) then
            if cpu_start_detected then
                cpu_busy    <= true;
            elsif cpu_stop_detected then
                cpu_busy    <= false;
            end if;

            -- The FPGA still owns the bus and the START hold time as elapsed. This means before
            -- the mux is swapped we need to simulate a START condition.
            if fpga_idle = '0' and cpu_scl_fedge = '1' then
                need_start  <= true;
            elsif start_simulated then
                need_start  <= false;
            end if;
        end if;
    end process;

    -- Mux control
    cpu_has_mux <= cpu_busy and fpga_idle = '1' and not need_start;

    -- FPGA I2C controller
    i2c_ctrl_txn_layer_inst: entity work.i2c_ctrl_txn_layer
        generic map(
            CLK_PER_NS  => CLK_PER_NS,
            MODE        => I2C_MODE
        )
        port map(
            clk         => clk,
            reset       => reset,
            scl_if      => fpga_scl_if,
            sda_if      => fpga_sda_if,
            cmd         => (
                op      => RANDOM_READ,
                addr    => b"1010000", -- 0x50
                reg     => x"80",
                len     => x"10"
            ),
            cmd_valid   => '1',
            abort       => cpu_start_detected,
            core_ready  => fpga_idle,
            tx_st_if    => tx_st_if,
            rx_st_if    => rx_st_if
        );

    -- CPU and FPGA to DIMM bus mux
    dimm_scl_if.o   <= cpu_scl_if.i when cpu_has_mux else fpga_scl_if.o;
    dimm_scl_if.oe  <= not cpu_scl_if.i when cpu_has_mux else fpga_scl_if.oe;
    dimm_sda_if.o   <= cpu_sda_if.i when cpu_has_mux else fpga_sda_if.o;
    dimm_sda_if.oe  <= not cpu_sda_if.i when cpu_has_mux else fpga_sda_if.oe;

    -- Break the controller input from the bus when it doesn't have the bus
    fpga_scl_if.i   <= '1' when cpu_has_mux else dimm_scl_if.i;
    fpga_sda_if.i   <= '1' when cpu_has_mux else dimm_sda_if.i;

end architecture;