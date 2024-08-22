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
use work.spi_nor_tb_pkg.all;
use work.axil_common_pkg.all;
use work.axil8x32_pkg;
use work.axil26x32_pkg;

entity spi_nor_th is
end entity;

architecture th of spi_nor_th is

    signal   clk          : std_logic                              := '0';
    signal   reset        : std_logic                              := '1';
    signal   axi_bus      : axil26x32_pkg.axil_t;
    signal   cs_n         : std_logic;
    signal   sclk         : std_logic;
    signal   io           : std_logic_vector(3 downto 0);
    signal   io_o         : std_logic_vector(3 downto 0);
    signal   io_oe        : std_logic_vector(3 downto 0);
    constant config_array : axil_responder_cfg_array_t(1 downto 0) :=
    (
        0 => (base_addr => x"00000000", addr_span_bits => 8),
        1 => (base_addr => x"00000100", addr_span_bits => 8)
    );
    signal   responders   : axil8x32_pkg.axil_array_t(1 downto 0);

begin

    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    axi_lite_master_inst: entity vunit_lib.axi_lite_master
        generic map (
            bus_handle => bus_handle
        )
        port map (
            aclk    => clk,
            arready => axi_bus.read_address.ready,
            arvalid => axi_bus.read_address.valid,
            araddr  => axi_bus.read_address.addr,
            rready  => axi_bus.read_data.ready,
            rvalid  => axi_bus.read_data.valid,
            rdata   => axi_bus.read_data.data,
            rresp   => axi_bus.read_data.resp,
            awready => axi_bus.write_address.ready,
            awvalid => axi_bus.write_address.valid,
            awaddr  => axi_bus.write_address.addr,
            wready  => axi_bus.write_data.ready,
            wvalid  => axi_bus.write_data.valid,
            wdata   => axi_bus.write_data.data,
            wstrb   => axi_bus.write_data.strb,
            bvalid  => axi_bus.write_response.valid,
            bready  => axi_bus.write_response.ready,
            bresp   => axi_bus.write_response.resp
        );

    axil_interconnect_inst: entity work.axil_interconnect
        generic map (
            config_array => config_array
        )
        port map (
            clk        => clk,
            reset      => reset,
            initiator  => axi_bus,
            responders => responders
        );

    spi_nor_top_inst: entity work.spi_nor_top
        port map (
            clk    => clk,
            reset  => reset,
            axi_if => responders(1),
            cs_n   => cs_n,
            sclk   => sclk,
            io     => io,
            io_o   => io_o,
            io_oe  => io_oe
        );

    io_tris: process(all)
    begin
        for i in io'range loop
            io(i) <= io_o(i) when io_oe(i) = '1' else 'H';
        end loop;
    end process;

end th;
