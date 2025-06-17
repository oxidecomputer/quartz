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

use work.uart_tb_pkg.all;

entity uart_th is
end entity;

architecture th of uart_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal dut_rts_pin : std_logic;
    signal dut_cts_pin : std_logic := '0';
    signal dut_rx_ready : std_logic;
    signal dut_rx_data : std_logic_vector(7 downto 0);
    signal dut_rx_valid : std_logic;
    signal dut_tx_data : std_logic_vector(7 downto 0);
    signal dut_tx_valid : std_logic;
    signal dut_tx_ready : std_logic;
    signal dut_rx_pin : std_logic;
    signal dut_tx_pin : std_logic;

begin

     -- set up a fastish, clock for the sim
    -- env and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    uart_master_inst: entity vunit_lib.uart_master
     generic map(
        uart => tx_uart_bfm
    )
     port map(
        tx => dut_rx_pin
    );

    uart_slave_inst: entity vunit_lib.uart_slave
     generic map(
        uart => rx_uart_bfm
    )
     port map(
        rx => dut_tx_pin
    );

    dut: entity work.axi_fifo_st_uart
     generic map(
        CLKS_PER_BIT => 41,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => 16,
        full_threshold => 16
    )
     port map(
        clk => clk,
        reset => reset,
        rx_pin => dut_rx_pin,
        tx_pin => dut_tx_pin,
        rts_pin => dut_rts_pin,
        cts_pin => dut_cts_pin,
        axi_clk => clk,
        axi_reset => reset,
        rx_ready => dut_rx_ready,
        rx_data => dut_rx_data,
        rx_valid => dut_rx_valid,
        tx_data => dut_tx_data,
        tx_valid => dut_tx_valid,
        tx_ready => dut_tx_ready
    );

    -- loop streaming interface back on itself
    dut_rx_ready <= dut_tx_ready;
    dut_tx_data <= dut_rx_data;
    dut_tx_valid <= dut_rx_valid;
end th;