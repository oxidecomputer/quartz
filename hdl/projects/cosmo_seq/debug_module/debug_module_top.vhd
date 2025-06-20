-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil8x32_pkg.all;

use work.debug_regs_pkg.all;
use work.sp5_uart_subsystem_pkg.all;

entity debug_module_top is
    port (
        clk : in std_logic;
        reset : in std_logic;

        axi_if : view axil_target;

        uart_dbg_if : view uart_dbg_dbg_if

    );
end entity;

architecture rtl of debug_module_top is
    signal rdata : std_logic_vector(31 downto 0);
    signal active_read : std_logic;
    signal active_write : std_logic;
    signal dbg_uart_control : uart_control_type;
    signal uart_pin_status: uart_pin_status_type;
begin

    -- Assign the output(s):
    uart_dbg_if.sp5_console_uart_to_header <= dbg_uart_control.sp5_to_header;
    uart_pin_status.ipcc_sp_cts_l <= uart_dbg_if.sp_uart1.uart_cts_pin_copy; -- (to SP pins, output from FPGA)
    uart_pin_status.ipcc_sp_rts_l <= uart_dbg_if.sp_uart1.uart_rts_pin_copy; -- (from SP pins, input to FPGA)
    uart_pin_status.console_sp_rts_l <= uart_dbg_if.sp_uart0.uart_rts_pin_copy; -- (from SP pins, input to FPGA)
    uart_pin_status.console_sp_cts_l <= uart_dbg_if.sp_uart0.uart_cts_pin_copy; -- (to SP pins, output from FPGA);
    uart_pin_status.console_sp5_rts_l <= uart_dbg_if.host_uart0.uart_rts_pin_copy; -- (from SP5 pins, input to FPGA)
    uart_pin_status.console_sp5_cts_l <= uart_dbg_if.host_uart0.uart_cts_pin_copy; -- (to SP5 pins, output from FPGA)

     axil_target_txn_inst: entity work.axil_target_txn
     port map(
        clk => clk,
        reset => reset,
        arvalid => axi_if.read_address.valid,
        arready => axi_if.read_address.ready,
        awvalid => axi_if.write_address.valid,
        awready => axi_if.write_address.ready,
        wvalid => axi_if.write_data.valid,
        wready => axi_if.write_data.ready,
        bvalid => axi_if.write_response.valid,
        bready => axi_if.write_response.ready,
        bresp => axi_if.write_response.resp,
        rvalid => axi_if.read_data.valid,
        rready => axi_if.read_data.ready,
        rresp => axi_if.read_data.resp,
        active_read => active_read,
        active_write => active_write
    );
    axi_if.read_data.data <= rdata;

    write_logic: process(clk, reset)
    begin
        if reset then
            dbg_uart_control <= rec_reset;

        elsif rising_edge(clk) then

            if active_write then
                case to_integer(axi_if.write_address.addr) is
                    when UART_CONTROL_OFFSET => dbg_uart_control <= unpack(axi_if.write_data.data);
                    when others => null;
                end case;
            end if;

        end if;
    end process;

    

    read_logic: process(clk, reset)
    begin
        if reset then
            rdata <= (others => '0');
        elsif rising_edge(clk) then
            if active_read then
                case to_integer(axi_if.read_address.addr) is
                    when UART_CONTROL_OFFSET => rdata <= pack(dbg_uart_control);
                    when SP_AXI_TO_CONSOLE_UART_USEDWDS_OFFSET => rdata <= resize(uart_dbg_if.sp_uart0.axi_to_uart_fifo_usedwds, 32);
                    when SP_CONSOLE_UART_TO_AXI_USEDWDS_OFFSET => rdata <= resize(uart_dbg_if.sp_uart0.uart_to_axi_fifo_usedwds, 32);
                    when SP5_AXI_TO_CONSOLE_UART_USEDWDS_OFFSET => rdata <= resize(uart_dbg_if.host_uart0.axi_to_uart_fifo_usedwds, 32);
                    when SP5_CONSOLE_UART_TO_AXI_USEDWDS_OFFSET => rdata <= resize(uart_dbg_if.host_uart0.uart_to_axi_fifo_usedwds, 32);
                    when SP5_AXI_TO_IPCC_UART_USEDWDS_OFFSET => rdata <= resize(uart_dbg_if.sp_uart1.axi_to_uart_fifo_usedwds, 32);
                    when SP5_IPCC_UART_TO_AXI_USEDWDS_OFFSET => rdata <= resize(uart_dbg_if.sp_uart1.uart_to_axi_fifo_usedwds, 32);
                    --when CONSOLE_UART_PIN_STATUS_OFFSET : integer := 20;
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;


end rtl;