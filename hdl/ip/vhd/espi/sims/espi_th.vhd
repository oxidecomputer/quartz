-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.qspi_vc_pkg.all;
use work.axil_common_pkg.all;
use work.axil8x32_pkg;
use work.espi_tb_pkg.all;

entity espi_th is
end entity;

architecture th of espi_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal   ss_n       : std_logic_vector(7 downto 0);
    signal   sclk       : std_logic;
    signal   io         : std_logic_vector(3 downto 0);
    signal   io_o       : std_logic_vector(3 downto 0);
    signal   io_oe      : std_logic_vector(3 downto 0);
    constant qspi_actor : qspi_vc_t := new_qspi_vc("espi_vc");

    signal flash_cfifo_data   : std_logic_vector(31 downto 0);
    signal flash_cfifo_write  : std_logic;
    signal flash_rfifo_data   : std_logic_vector(7 downto 0);
    signal flash_rfifo_rdack  : std_logic;
    signal flash_rfifo_rempty : std_logic;
    signal axi_if      : axil8x32_pkg.axil_t;
    signal uart_data_line : std_logic;
    signal uart_handshake : std_logic;
    signal from_sp_uart_ready : std_logic;
    signal to_sp_uart_data : std_logic_vector(7 downto 0);
    signal to_sp_uart_valid : std_logic;
    signal to_sp_uart_ready : std_logic;
    signal from_sp_uart_data: std_logic_vector(7 downto 0);
    signal from_sp_uart_valid : std_logic;

begin

    -- set up a fastish clock for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    qspi_controller_vc_inst: entity work.qspi_controller_vc
        generic map (
            qspi_vc => qspi_actor
        )
        port map (
            ss_n => ss_n,
            sclk => sclk,
            io   => io
        );

    axi_lite_master_inst: entity vunit_lib.axi_lite_master
        generic map (
            bus_handle => bus_handle
        )
        port map (
            aclk    => clk,
            arready => axi_if.read_address.ready,
            arvalid => axi_if.read_address.valid,
            araddr  => axi_if.read_address.addr,
            rready  => axi_if.read_data.ready,
            rvalid  => axi_if.read_data.valid,
            rdata   => axi_if.read_data.data,
            rresp   => axi_if.read_data.resp,
            awready => axi_if.write_address.ready,
            awvalid => axi_if.write_address.valid,
            awaddr  => axi_if.write_address.addr,
            wready  => axi_if.write_data.ready,
            wvalid  => axi_if.write_data.valid,
            wdata   => axi_if.write_data.data,
            wstrb   => axi_if.write_data.strb,
            bvalid  => axi_if.write_response.valid,
            bready  => axi_if.write_response.ready,
            bresp   => axi_if.write_response.resp
        );

    dut: entity work.espi_target_top
        port map (
            clk                => clk,
            reset              => reset,
            axi_clk            => clk,
            axi_reset          => reset,
            cs_n               => ss_n(0),
            sclk               => sclk,
            io                 => io,
            io_o               => io_o,
            io_oe              => io_oe,
            axi_if             => axi_if,
            flash_cfifo_data   => flash_cfifo_data,
            flash_cfifo_write  => flash_cfifo_write,
            flash_rfifo_data   => flash_rfifo_data,
            flash_rfifo_rdack  => flash_rfifo_rdack,
            flash_rfifo_rempty => flash_rfifo_rempty,
            to_sp_uart_data  => to_sp_uart_data,
            to_sp_uart_valid => to_sp_uart_valid,
            to_sp_uart_ready => to_sp_uart_ready,
            from_sp_uart_data  => from_sp_uart_data, 
            from_sp_uart_valid => from_sp_uart_valid,
            from_sp_uart_ready => from_sp_uart_ready
        );

    axi_fifo_st_uart_inst: entity work.axi_fifo_st_uart
     generic map(
        CLK_DIV => 4,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => 1024,
        full_threshold => 1024
    )
     port map(
        clk => clk,
        reset => reset,
        rx_pin => uart_data_line,
        tx_pin => uart_data_line,
        rts_pin => uart_handshake,
        cts_pin => uart_handshake,
        axi_clk => clk,
        axi_reset => reset,
        rx_ready => from_sp_uart_ready,
        rx_data => from_sp_uart_data,
        rx_valid => from_sp_uart_valid,
        tx_data => to_sp_uart_data,
        tx_valid => to_sp_uart_valid,
        tx_ready => to_sp_uart_ready
    );

    fake_flash_txn_mgr_inst: entity work.fake_flash_txn_mgr
        port map (
            clk                 => clk,
            reset               => reset,
            espi_cmd_fifo_data  => flash_cfifo_data,
            espi_cmd_fifo_write => flash_cfifo_write,
            flash_rdata         => flash_rfifo_data,
            flash_rdata_empty   => flash_rfifo_rempty,
            flash_rdata_rdack   => flash_rfifo_rdack
        );

    io_tris: process(all)
    begin
        for i in io'range loop
            io(i) <= io_o(i) when io_oe(i) = '1' else 'H';
        end loop;
    end process;

end th;
