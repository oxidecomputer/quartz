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

-- The engine owns its command and response FIFOs, so this harness only supplies
-- what sits on their far side: a behavioural flash responder where spi_nor_top
-- would be. hash_spi_nor_tb is the one that goes through the real controller.
entity hash_engine_th is
end entity;

architecture th of hash_engine_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal axi_bus : axil8x32_pkg.axil_t;

    signal cmd_fifo_rdata : std_logic_vector(31 downto 0);
    signal cmd_fifo_rdack : std_logic_vector(0 downto 0);
    signal cmd_fifo_empty : std_logic_vector(0 downto 0);

    signal rsp_fifo_wdata : std_logic_vector(7 downto 0);
    signal rsp_fifo_write : std_logic_vector(0 downto 0);
    signal rsp_fifo_wfull : std_logic_vector(0 downto 0);

    -- Hardware request handshake, driven from the testbench
    signal hw_req : std_logic := '0';
    signal hw_ack : std_logic;
    signal hw_err : std_logic;


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
            clk              => clk,
            reset            => reset,
            axi_if           => axi_bus,
            hw_req           => hw_req,
            hw_ack           => hw_ack,
            hw_err           => hw_err,
            flash_cmd_rdata  => cmd_fifo_rdata,
            flash_cmd_rdack  => cmd_fifo_rdack,
            flash_cmd_rempty => cmd_fifo_empty,
            flash_rsp_wdata  => rsp_fifo_wdata,
            flash_rsp_write  => rsp_fifo_write,
            flash_rsp_wfull  => rsp_fifo_wfull
        );

    -- The engine owns the command and response FIFOs now; the responder sits
    -- directly on their far ends, where spi_nor_top would in a real design.
    fake_flash: entity work.fake_flash_responder
        port map (
            clk        => clk,
            reset      => reset,
            cmd_rdata  => cmd_fifo_rdata,
            cmd_rdack  => cmd_fifo_rdack(0),
            cmd_rempty => cmd_fifo_empty(0),
            rsp_wdata  => rsp_fifo_wdata(7 downto 0),
            rsp_write  => rsp_fifo_write(0),
            rsp_wfull  => rsp_fifo_wfull(0)
        );

end th;
