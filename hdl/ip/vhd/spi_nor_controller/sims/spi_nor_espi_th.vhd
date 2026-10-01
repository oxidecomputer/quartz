-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Harness for the eSPI client side of spi_nor_top: the three FIFOs the eSPI
-- wrapper would put between the flash channel and this block, with their far
-- ends left for the testbench to drive directly, and the real flash VC on
-- the other side. spi_nor_th covers the hubris register path; this is the
-- path the SP5's SAFS reads, writes and erases take.

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
use work.axil32x32_pkg;
use work.axil26x32_pkg;
use work.axilite_if_2k19_helper_pkg.all;

entity spi_nor_espi_th is
end entity;

architecture th of spi_nor_espi_th is

    signal   clk          : std_logic                              := '0';
    signal   reset        : std_logic                              := '1';
    signal   axi_bus      : axil26x32_pkg.axil_t;
    signal   cs_n         : std_logic;
    signal   sclk         : std_logic;
    signal   io           : std_logic_vector(3 downto 0);
    signal   io_o         : std_logic_vector(3 downto 0);
    signal   io_oe        : std_logic_vector(3 downto 0);
    signal   flash_o      : std_logic_vector(3 downto 0);
    signal   flash_oe     : std_logic_vector(3 downto 0);
    constant config_array : axil_responder_cfg_array_t(0 downto 0) :=
    (
        0 => resp_cfg(base_addr => x"00000100", addr_span_bits => 8)
    );
    signal  responders   : axil32x32_pkg.axil_array_t(0 downto 0);
    signal  responders_8b : axil8x32_pkg.axil_array_t(0 downto 0);

    -- Far ends of the FIFOs, driven and read by the testbench
    signal cmd_wdata : std_logic_vector(31 downto 0) := (others => '0');
    signal cmd_write : std_logic := '0';
    signal payload_wdata : std_logic_vector(7 downto 0) := (others => '0');
    signal payload_write : std_logic := '0';
    signal data_rdata : std_logic_vector(7 downto 0);
    signal data_rdack : std_logic := '0';
    signal data_rempty : std_logic;

    -- Near ends, into the DUT
    signal espi_cmd_fifo_rdata : std_logic_vector(31 downto 0);
    signal espi_cmd_fifo_rdack : std_logic;
    signal espi_cmd_fifo_rempty : std_logic;
    signal espi_data_fifo_wdata : std_logic_vector(7 downto 0);
    signal espi_data_fifo_write : std_logic;
    signal espi_wfifo_rdata : std_logic_vector(7 downto 0);
    signal espi_wfifo_rdack : std_logic;
    signal espi_wfifo_rempty : std_logic;

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
        generic map(
            config_array => config_array
        )
        port map(
            clk => clk,
            reset => reset,
            initiator => axi_bus,
            responders => responders
        );

    resiser: entity work.axil8_resizer port map(fabric => responders(0), responder =>responders_8b(0));

    cmd_fifo: entity work.dcfifo_xpm
        generic map(
            fifo_write_depth => 256,
            data_width => 32,
            showahead_mode => true
        )
        port map(
            wclk => clk,
            reset => reset,
            write_en => cmd_write,
            wdata => cmd_wdata,
            wfull => open,
            wusedwds => open,
            rclk => clk,
            rdata => espi_cmd_fifo_rdata,
            rdreq => espi_cmd_fifo_rdack,
            rempty => espi_cmd_fifo_rempty,
            rusedwds => open
        );

    payload_fifo: entity work.dcfifo_xpm
        generic map(
            fifo_write_depth => 1024,
            data_width => 8,
            showahead_mode => true
        )
        port map(
            wclk => clk,
            reset => reset,
            write_en => payload_write,
            wdata => payload_wdata,
            wfull => open,
            wusedwds => open,
            rclk => clk,
            rdata => espi_wfifo_rdata,
            rdreq => espi_wfifo_rdack,
            rempty => espi_wfifo_rempty,
            rusedwds => open
        );

    data_fifo: entity work.dcfifo_xpm
        generic map(
            fifo_write_depth => 4096,
            data_width => 8,
            showahead_mode => true
        )
        port map(
            wclk => clk,
            reset => reset,
            write_en => espi_data_fifo_write,
            wdata => espi_data_fifo_wdata,
            wfull => open,
            wusedwds => open,
            rclk => clk,
            rdata => data_rdata,
            rdreq => data_rdack,
            rempty => data_rempty,
            rusedwds => open
        );

    spi_nor_top_inst: entity work.spi_nor_top
        port map (
            clk                  => clk,
            reset                => reset,
            axi_if               => responders_8b(0),
            cs_n                 => cs_n,
            sclk                 => sclk,
            io                   => io,
            io_o                 => io_o,
            io_oe                => io_oe,
            sp5_owns_flash       => open,
            espi_cmd_fifo_rdata  => espi_cmd_fifo_rdata,
            espi_cmd_fifo_rdack  => espi_cmd_fifo_rdack,
            espi_cmd_fifo_rempty => espi_cmd_fifo_rempty,
            espi_data_fifo_wdata => espi_data_fifo_wdata,
            espi_data_fifo_write => espi_data_fifo_write,
            espi_wfifo_rdata     => espi_wfifo_rdata,
            espi_wfifo_rdack     => espi_wfifo_rdack,
            espi_wfifo_rempty    => espi_wfifo_rempty
        );

    flash: entity work.spi_nor_target_vc
        generic map (
            actor_name => "spi_nor_target"
        )
        port map (
            cs_n  => cs_n,
            sclk  => sclk,
            io    => io,
            io_o  => flash_o,
            io_oe => flash_oe
        );

    bus_gen: for i in io'range generate
        io(i) <= io_o(i) when io_oe(i) = '1' else 'Z';
        io(i) <= flash_o(i) when flash_oe(i) = '1' else 'Z';
        io(i) <= 'H';
    end generate;

    contention_check: process(all)
    begin
        for i in io'range loop
            assert not (io_oe(i) = '1' and flash_oe(i) = '1')
                report "Bus contention: controller and flash both driving io(" & to_string(i) & ")"
                severity error;
        end loop;
    end process;

end th;
