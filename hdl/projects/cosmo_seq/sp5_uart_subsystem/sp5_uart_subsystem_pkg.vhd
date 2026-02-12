-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.calc_pkg.all;

package sp5_uart_subsystem_pkg is

    constant CONSOLE_FIFO_DEPTH : integer := 256; -- FIFO depth for UARTs
    constant CONSOLE_FIFO_ALMOST_FULL : integer := CONSOLE_FIFO_DEPTH - 8; -- Threshold for "almost full" status signal
    constant IPCC_FIFO_DEPTH : integer := 32; -- FIFO depth for IPCC UART
    constant IPCC_FIFO_ALMOST_FULL : integer := IPCC_FIFO_DEPTH - 8; -- Threshold for "almost full" status signal

    -- To the debug interface
    type console_uart_dbg_t is record
        uart_to_axi_fifo_usedwds : std_logic_vector(log2ceil(CONSOLE_FIFO_DEPTH) downto 0);
        axi_to_uart_fifo_usedwds : std_logic_vector(log2ceil(CONSOLE_FIFO_DEPTH) downto 0);
        uart_rts_pin_copy : std_logic;
        uart_cts_pin_copy : std_logic; 
    end record;
    view console_uart_ss of console_uart_dbg_t is
        uart_to_axi_fifo_usedwds : out;
        axi_to_uart_fifo_usedwds : out;
        uart_rts_pin_copy : out;
        uart_cts_pin_copy : out; 
    end view;
    alias console_uart_dbg is console_uart_ss'converse;

    type ipcc_uart_dbg_t is record
        uart_to_axi_fifo_usedwds : std_logic_vector(log2ceil(IPCC_FIFO_DEPTH) downto 0);
        axi_to_uart_fifo_usedwds : std_logic_vector(log2ceil(IPCC_FIFO_DEPTH) downto 0);
        uart_rts_pin_copy : std_logic;
        uart_cts_pin_copy : std_logic; 
    end record;
    view ipcc_uart1_ss of ipcc_uart_dbg_t is
        uart_to_axi_fifo_usedwds : out;
        axi_to_uart_fifo_usedwds : out;
        uart_rts_pin_copy : out;
        uart_cts_pin_copy : out; 
    end view;
    alias ipcc_uart1_dbg is ipcc_uart1_ss'converse;

    -- Now wrap all of that up into one big record
    type uart_dbg_t is record
        sp5_console_uart_to_header : std_logic;
        sp_uart0 : console_uart_dbg_t;
        host_uart0 : console_uart_dbg_t;
        sp_uart1 : ipcc_uart_dbg_t;
    end record;
    view uart_dbg_ss_if of uart_dbg_t is
        sp5_console_uart_to_header : in;
        sp_uart0 : view console_uart_ss;
        host_uart0 : view console_uart_ss;
        sp_uart1 : view ipcc_uart1_ss;
    end view;
    alias uart_dbg_dbg_if is uart_dbg_ss_if'converse;

end package;