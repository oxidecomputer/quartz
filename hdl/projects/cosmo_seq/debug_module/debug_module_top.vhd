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

        in_a0 : in std_logic;
        sp5_debug2_pin : in std_logic;

        uart_dbg_if : view uart_dbg_dbg_if

    );
end entity;

architecture rtl of debug_module_top is
    constant TOGGLE_MAX : std_logic_vector(31 downto 0) := (others => '1'); -- Max toggle count before we stop counting
    signal rdata : std_logic_vector(31 downto 0);
    signal active_read : std_logic;
    signal active_write : std_logic;
    signal dbg_uart_control : uart_control_type;
    signal uart_pin_status: uart_pin_status_type;
    signal sp5_debug2_pin_syncd : std_logic;
    signal in_a0_last : std_logic;
    signal pin_toggle_cnts : std_logic_vector(31 downto 0);
    signal dbg_pin_last : std_logic;
    signal clks_since_last_toggle : std_logic_vector(31 downto 0);
    signal pin_has_toggled_atleast_once : std_logic;
begin

    -- Some functional stuff for this block
    -- Meta sync for input from SP5
    meta_sync_inst: entity work.meta_sync
     port map(
        async_input => sp5_debug2_pin,
        clk => clk,
        sycnd_output => sp5_debug2_pin_syncd
    );

    sp5_dbg_proc: process(clk, reset)
        variable a0_start : std_logic;
        variable pin_toggled : std_logic;
    begin
        if reset then
            in_a0_last <= '0';
            dbg_pin_last <= '0';
            pin_has_toggled_atleast_once <= '0';
            pin_toggle_cnts <= (others => '0');
            clks_since_last_toggle <= (others => '0');

        elsif rising_edge(clk) then
            -- last state flip flops
            dbg_pin_last <= sp5_debug2_pin_syncd;
            in_a0_last <= in_a0;
            -- Detect the start of a0 for clearing registers
            a0_start := '1' when in_a0_last = '0' and in_a0 = '1' else '0';
            -- detect the pin toggling
            pin_toggled := dbg_pin_last xor sp5_debug2_pin_syncd;

            
            -- deal with toggle counter
            if a0_start then
                pin_toggle_cnts <= (others => '0');
                pin_has_toggled_atleast_once <= '0';
            else
                if in_a0 = '1' and pin_toggled = '1' and pin_toggle_cnts <= TOGGLE_MAX then
                    pin_toggle_cnts <= pin_toggle_cnts + 1;
                    pin_has_toggled_atleast_once <= '1';
                end if;
            end if;

            -- deal with toggle timer
            if a0_start then
                clks_since_last_toggle <= (others => '0');
            else
                if in_a0 and pin_toggled then
                    clks_since_last_toggle <= (others => '0');
                elsif in_a0 = '1' and pin_has_toggled_atleast_once = '1' and clks_since_last_toggle < TOGGLE_MAX then
                        clks_since_last_toggle <= clks_since_last_toggle + 1;
                end if;
            end if;
           
        end if;
    end process;

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
                    when UART_PIN_STATUS_OFFSET => rdata <= pack(uart_pin_status);
                    when SP5_DBG2_TOGGLE_COUNTER_OFFSET => rdata <= pin_toggle_cnts;
                    when SP5_DBG2_TOGGLE_TIMER_OFFSET => rdata <= clks_since_last_toggle;
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;


end rtl;