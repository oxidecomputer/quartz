-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_st8_pkg.all;

entity sp5_uart_subsystem is
    port(
        clk : in std_logic;
        reset : in std_logic;

        -- sp UART pins, ok to be un-syncd
        ipcc_from_sp : in std_logic;
        ipcc_to_sp : out std_logic;
        ipcc_from_sp_rts_l : in std_logic;
        ipcc_to_sp_rts_l : out std_logic;
        -- sp UART pins, ok to be un-syncd
        console_from_sp : in std_logic;
        console_to_sp_dat : out std_logic;
        console_to_sp_rts_l : out std_logic;
        console_from_sp_rts_l : in std_logic;
        -- host UART pins, ok to be un-syncd
        host_from_fpga : out std_logic;
        host_to_fpga : in std_logic;
        host_from_fpga_rts_l : out std_logic;
        host_to_fpga_rts_l : in std_logic;
        -- FPGA UART pins, ok to be un-syncd
        -- mostly un-used right now
        -- console from Sp5 wrapped back out
        uart_from_fpga : out std_logic;
        uart_to_fpga : in std_logic;
        uart_from_fpga_rts_l : out std_logic;
        uart_to_fpga_rts_l : in std_logic;
        -- to/from espi
        ipcc_from_espi : view axi_st_sink;
        ipcc_to_espi : view axi_st_source;

        -- debug UART mux
        dbg_mux_en : in std_logic;
        dbg_pins_uart_out : out std_logic;
        dbg_pins_uart_out_rts_l : in std_logic;
        dbg_pins_uart_in : in std_logic;
        dbg_pins_uart_in_rts_l : out std_logic

    );
end entity;

architecture rtl of sp5_uart_subsystem is
    constant BAUD_3M_AT_125M : integer := 5;

    signal console_host_to_sp : axi_st_t;
    signal console_sp_to_host : axi_st_t;

    signal fgpa_sp_to_host_int : std_logic;
    signal fpga_sp_to_host_int_rts_l : std_logic;

begin

    -- inputs from host, outputs to debug header
    process(clk)
    begin
        if rising_edge(clk) then
            dbg_pins_uart_out <= host_to_fpga when dbg_mux_en = '1' else '1';
            dbg_pins_uart_in_rts_l <= host_to_fpga_rts_l when dbg_mux_en = '1' else '1';
            -- outputs to host, inputs from debug header
            host_from_fpga <= dbg_pins_uart_in when dbg_mux_en = '1' else fgpa_sp_to_host_int;
            host_from_fpga_rts_l <= dbg_pins_uart_out_rts_l when dbg_mux_en = '1' else fpga_sp_to_host_int_rts_l;
        end if;
    end process;
    
    -- UARTs
    -- SP UART #0  -- Expected to be console uart sp-side
    sp_uart0: entity work.axi_fifo_st_uart
     generic map(
        CLK_DIV => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => 256,
        full_threshold => 256
    )
     port map(
        clk => clk,
        reset => reset,
        rx_pin => console_from_sp,
        tx_pin => console_to_sp_dat,
        rts_pin => console_to_sp_rts_l,
        cts_pin => console_from_sp_rts_l,
        axi_clk => clk,
        axi_reset => reset,
        rx_ready => console_sp_to_host.ready,
        rx_data => console_sp_to_host.data,
        rx_valid => console_sp_to_host.valid,
        tx_data => console_host_to_sp.data,
        tx_valid => console_host_to_sp.valid,
        tx_ready => console_host_to_sp.ready
    );

    -- 1 Host UART expected to be console uart, host side
    -- wrapped uart-uart no espi interaction
    host_uart0: entity work.axi_fifo_st_uart
     generic map(
        CLK_DIV => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => 256,
        full_threshold => 256
    )
     port map(
        clk => clk,
        reset => reset,
        rx_pin => host_to_fpga,
        tx_pin => fgpa_sp_to_host_int,
        rts_pin => fpga_sp_to_host_int_rts_l,
        cts_pin => host_to_fpga_rts_l,
        axi_clk => clk,
        axi_reset => reset,
        rx_ready => console_host_to_sp.ready,
        rx_data => console_host_to_sp.data,
        rx_valid => console_host_to_sp.valid,
        tx_data => console_sp_to_host.data,
        tx_valid => console_sp_to_host.valid,
        tx_ready => console_sp_to_host.ready
    );

    -- IPCC UART over eSPI
    sp_uart1: entity work.axi_fifo_st_uart
     generic map(
        CLK_DIV => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => 4096,
        full_threshold => 4096
    )
     port map(
        clk => clk,
        reset => reset,
        rx_pin => ipcc_from_sp,
        tx_pin => ipcc_to_sp,
        rts_pin => ipcc_to_sp_rts_l,
        cts_pin => ipcc_from_sp_rts_l,
        axi_clk => clk,
        axi_reset => reset,
        rx_ready => ipcc_to_espi.ready,
        rx_data => ipcc_to_espi.data,
        rx_valid => ipcc_to_espi.valid,
        tx_data => ipcc_from_espi.data,
        tx_valid => ipcc_from_espi.valid,
        tx_ready => ipcc_from_espi.ready
    );

end rtl;