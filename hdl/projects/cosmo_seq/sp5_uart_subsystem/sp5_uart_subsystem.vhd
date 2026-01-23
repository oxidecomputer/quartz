-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_st8_pkg.all;
use work.debug_regs_pkg.all;
use work.sp5_uart_subsystem_pkg.all;

entity sp5_uart_subsystem is
    port(
        clk : in std_logic;
        reset : in std_logic;

        dbg_if : view  uart_dbg_ss_if;
        in_a0 : in  std_logic;
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
        dbg_pins_uart_out : out std_logic;
        dbg_pins_uart_out_rts_l : in std_logic;
        dbg_pins_uart_in : in std_logic;
        dbg_pins_uart_in_rts_l : out std_logic

    );
end entity;

architecture rtl of sp5_uart_subsystem is
    constant BAUD_3M_AT_125M : integer := 41; -- 125 MHz / 3 MHz = 41.6667, so round to 41

    signal console_host_to_sp : axi_st_t;
    signal console_sp_to_host : axi_st_t;

    signal fgpa_sp_to_host_int : std_logic;
    signal fpga_sp_to_host_int_rts_l : std_logic;
    signal ipcc_reset : std_logic;

begin

    -- inputs from host, outputs to debug header
    process(clk)
    begin
        if rising_edge(clk) then
            if dbg_if.sp5_console_uart_to_header = '1' then
                -- We want to wrap the SP5's host UART out to the debug header.
                -- outputs to the debug header, bypassing FIFOs
                dbg_pins_uart_out <= host_to_fpga;
                dbg_pins_uart_in_rts_l <= host_to_fpga_rts_l;
                -- outputs to host, inputs from debug header
                -- we need the signals from the debug header to go to the SP5
                -- bypassing the FIFOs.
                host_from_fpga <= dbg_pins_uart_in;
                host_from_fpga_rts_l <= dbg_pins_uart_out_rts_l;
            else
                -- Send output of the host uart to the host bits.
                host_from_fpga <= fgpa_sp_to_host_int;
                host_from_fpga_rts_l <= fpga_sp_to_host_int_rts_l;
                -- Mux being flipped this way means we're not using the debug header
                -- so we shove these pins to '1' (idle, not accepting data).
                dbg_pins_uart_out <= '1';
                dbg_pins_uart_in_rts_l <= '1';
            end if;
        end if;
    end process;
    
    -- UARTs
    -- SP UART #0  -- Expected to be console uart sp-side
    sp_uart0: entity work.axi_fifo_st_uart
     generic map(
        CLKS_PER_BIT => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => CONSOLE_FIFO_DEPTH,
        full_threshold => CONSOLE_FIFO_DEPTH
    )
     port map(
        clk => clk,
        reset => reset,
        rx_pin => console_from_sp,
        tx_pin => console_to_sp_dat,
        rts_pin => console_to_sp_rts_l,
        cts_pin => console_from_sp_rts_l,
        drop_silently => dbg_if.sp5_console_uart_to_header, -- drop rx data silently if we'reusing the debug header
        allow_rx => in_a0, -- allow rx only if in_a0 is set
        uart_to_axi_fifo_usedwds => dbg_if.sp_uart0.uart_to_axi_fifo_usedwds,
        axi_to_uart_fifo_usedwds => dbg_if.sp_uart0.axi_to_uart_fifo_usedwds,
        uart_rts_pin_copy => dbg_if.sp_uart0.uart_rts_pin_copy,
        uart_cts_pin_copy => dbg_if.sp_uart0.uart_cts_pin_copy,
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
        CLKS_PER_BIT => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => CONSOLE_FIFO_DEPTH,
        full_threshold => CONSOLE_FIFO_DEPTH
    )
     port map(
        clk => clk,
        reset => reset,
        rx_pin => host_to_fpga,
        tx_pin => fgpa_sp_to_host_int,
        rts_pin => fpga_sp_to_host_int_rts_l,
        cts_pin => host_to_fpga_rts_l,
        -- allow rx only if in_a0 is set, and only if we're not using the debug header
        -- No need to fill up the FIFO if we're not using it.
        allow_rx => in_a0 and (not dbg_if.sp5_console_uart_to_header),
        uart_to_axi_fifo_usedwds => dbg_if.host_uart0.uart_to_axi_fifo_usedwds,
        axi_to_uart_fifo_usedwds => dbg_if.host_uart0.axi_to_uart_fifo_usedwds,
        uart_rts_pin_copy => dbg_if.host_uart0.uart_rts_pin_copy,
        uart_cts_pin_copy => dbg_if.host_uart0.uart_cts_pin_copy,
        axi_clk => clk,
        axi_reset => reset,
        rx_ready => console_host_to_sp.ready,
        rx_data => console_host_to_sp.data,
        rx_valid => console_host_to_sp.valid,
        tx_data => console_sp_to_host.data,
        tx_valid => console_sp_to_host.valid,
        tx_ready => console_sp_to_host.ready
    );

    process(clk, reset)
    begin
        if reset = '1' then
            ipcc_reset <= '1';

        elsif rising_edge(clk) then
            if in_a0 = '0' then
                ipcc_reset <= '1';
            else
                ipcc_reset <= '0';
            end if;
        end if;
    end process;

    -- IPCC UART over eSPI
    sp_uart1: entity work.axi_fifo_st_uart
     generic map(
        CLKS_PER_BIT => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => IPCC_FIFO_DEPTH,
        full_threshold => IPCC_FIFO_DEPTH
    )
     port map(
        clk => clk,
        reset => ipcc_reset,
        rx_pin => ipcc_from_sp,
        tx_pin => ipcc_to_sp,
        rts_pin => ipcc_to_sp_rts_l,
        cts_pin => ipcc_from_sp_rts_l,
        allow_rx => in_a0, -- allow rx only if in_a0 is set
        uart_to_axi_fifo_usedwds => dbg_if.sp_uart1.uart_to_axi_fifo_usedwds,
        axi_to_uart_fifo_usedwds => dbg_if.sp_uart1.axi_to_uart_fifo_usedwds,
        uart_rts_pin_copy => dbg_if.sp_uart1.uart_rts_pin_copy,
        uart_cts_pin_copy => dbg_if.sp_uart1.uart_cts_pin_copy,
        axi_clk => clk,
        axi_reset => ipcc_reset,
        rx_ready => ipcc_to_espi.ready,
        rx_data => ipcc_to_espi.data,
        rx_valid => ipcc_to_espi.valid,
        tx_data => ipcc_from_espi.data,
        tx_valid => ipcc_from_espi.valid,
        tx_ready => ipcc_from_espi.ready
    );

end rtl;