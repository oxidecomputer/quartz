-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.axil8x32_pkg;
use work.hash_engine_sim_pkg.all;

-- The command and response FIFOs are real dcfifo_xpm instances here, not
-- behavioural stand-ins, because an integrating design owns them exactly like the
-- eSPI subsystem does. Neither is reset by the DUT: the engine resynchronises the
-- response channel by draining it, not by flushing.
entity hash_engine_th is
end entity;

architecture th of hash_engine_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal axi_bus : axil8x32_pkg.axil_t;

    signal cmd_fifo_wdata : std_logic_vector(31 downto 0);
    signal cmd_fifo_write : std_logic;
    signal cmd_fifo_rdata : std_logic_vector(31 downto 0);
    signal cmd_fifo_rdack : std_logic;
    signal cmd_fifo_empty : std_logic;

    signal rsp_fifo_wdata : std_logic_vector(7 downto 0);
    signal rsp_fifo_write : std_logic;
    signal rsp_fifo_wfull : std_logic;
    signal rsp_fifo_rdata : std_logic_vector(7 downto 0);
    signal rsp_fifo_rdack : std_logic;
    signal rsp_fifo_empty : std_logic;


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

    dut: entity work.hash_engine_top
        port map (
            clk             => clk,
            reset           => reset,
            axi_if          => axi_bus,
            cmd_fifo_wdata  => cmd_fifo_wdata,
            cmd_fifo_write  => cmd_fifo_write,
            rsp_fifo_rdata  => rsp_fifo_rdata,
            rsp_fifo_rdack  => rsp_fifo_rdack,
            rsp_fifo_rempty => rsp_fifo_empty
        );

    cmd_fifo: entity work.dcfifo_xpm
        generic map (
            fifo_write_depth => 256,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            wclk     => clk,
            reset    => reset,
            write_en => cmd_fifo_write,
            wdata    => cmd_fifo_wdata,
            wfull    => open,
            wusedwds => open,
            rclk     => clk,
            rdata    => cmd_fifo_rdata,
            rdreq    => cmd_fifo_rdack,
            rempty   => cmd_fifo_empty,
            rusedwds => open
        );

    rsp_fifo: entity work.dcfifo_xpm
        generic map (
            fifo_write_depth => 256,
            data_width       => 8,
            showahead_mode   => true
        )
        port map (
            wclk     => clk,
            reset    => reset,
            write_en => rsp_fifo_write,
            wdata    => rsp_fifo_wdata,
            wfull    => rsp_fifo_wfull,
            wusedwds => open,
            rclk     => clk,
            rdata    => rsp_fifo_rdata,
            rdreq    => rsp_fifo_rdack,
            rempty   => rsp_fifo_empty,
            rusedwds => open
        );

    fake_flash: entity work.fake_flash_responder
        port map (
            clk        => clk,
            reset      => reset,
            cmd_rdata  => cmd_fifo_rdata,
            cmd_rdack  => cmd_fifo_rdack,
            cmd_rempty => cmd_fifo_empty,
            rsp_wdata  => rsp_fifo_wdata,
            rsp_write  => rsp_fifo_write,
            rsp_wfull  => rsp_fifo_wfull
        );

end th;
