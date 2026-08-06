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

-- End to end harness: the hashing engine driving the real spi_nor_top over the
-- command/response FIFO channel, through the actual QSPI link, into a modelled
-- flash part.
--
-- This proves the whole chain: command FIFO, raw_flash_txn_mgr and its splitting
-- of a long read into 256 byte chunks, arbitration for the shared SPI engine, the
-- link, and the bytes finding their way back into the hash. Because the part is
-- modelled rather than faked, the digest depends on the flash contents and on the
-- addresses actually issued, so a chunk boundary that fetches the wrong range
-- shows up as a wrong digest instead of passing unnoticed.
--
-- The launch and capture delays mirror spi_nor_th: RTL simulation has no notion
-- of board delay, but it is a large share of an sclk period and the controller's
-- sample point cannot be exercised honestly without it.
entity hash_spi_nor_th is
    generic (
        -- Slow corner of the delay window the XDC allows, as in spi_nor_th.
        out_delay : time := 3.7 ns;
        in_delay  : time := 1.5 ns
    );
end entity;

architecture th of hash_spi_nor_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal axi_bus     : axil8x32_pkg.axil_t;
    signal spinor_axi  : axil8x32_pkg.axil_t;

    signal cmd_fifo_wdata : std_logic_vector(31 downto 0);
    signal cmd_fifo_write : std_logic;
    signal cmd_fifo_rdata : std_logic_vector(31 downto 0);
    signal cmd_fifo_rdack : std_logic;
    signal cmd_fifo_empty : std_logic;

    signal rsp_fifo_wdata : std_logic_vector(7 downto 0);
    signal rsp_fifo_write : std_logic;
    signal rsp_fifo_rdata : std_logic_vector(7 downto 0);
    signal rsp_fifo_rdack : std_logic;
    signal rsp_fifo_empty : std_logic;

    signal cs_n  : std_logic;
    signal sclk  : std_logic;
    signal io    : std_logic_vector(3 downto 0);
    signal io_o  : std_logic_vector(3 downto 0);
    signal io_oe : std_logic_vector(3 downto 0);

    signal flash_o    : std_logic_vector(3 downto 0);
    signal flash_oe   : std_logic_vector(3 downto 0);
    signal io_flash   : std_logic_vector(3 downto 0);
    signal sclk_flash : std_logic;
    signal csn_flash  : std_logic;

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
            wfull    => open,
            wusedwds => open,
            rclk     => clk,
            rdata    => rsp_fifo_rdata,
            rdreq    => rsp_fifo_rdack,
            rempty   => rsp_fifo_empty,
            rusedwds => open
        );

    -- The SPI controller's own register interface is not exercised here, so park
    -- its initiator side idle. sp5_owns_flash stays at its reset value of zero,
    -- which means the hubris register path is nominally selected and the hash
    -- client has to win the engine on its own.
    spinor_axi.read_address.valid   <= '0';
    spinor_axi.read_address.addr    <= (others => '0');
    spinor_axi.read_data.ready      <= '0';
    spinor_axi.write_address.valid  <= '0';
    spinor_axi.write_address.addr   <= (others => '0');
    spinor_axi.write_data.valid     <= '0';
    spinor_axi.write_data.data      <= (others => '0');
    spinor_axi.write_data.strb      <= (others => '0');
    spinor_axi.write_response.ready <= '0';

    spi_nor: entity work.spi_nor_top
        port map (
            clk                  => clk,
            reset                => reset,
            axi_if               => spinor_axi,
            cs_n                 => cs_n,
            sclk                 => sclk,
            io                   => io,
            io_o                 => io_o,
            io_oe                => io_oe,
            sp5_owns_flash       => open,
            espi_cmd_fifo_rdata  => (others => '0'),
            espi_cmd_fifo_rdack  => open,
            espi_cmd_fifo_rempty => '1',
            espi_data_fifo_wdata => open,
            espi_data_fifo_write => open,
            hash_cmd_fifo_rdata  => cmd_fifo_rdata,
            hash_cmd_fifo_rdack  => cmd_fifo_rdack,
            hash_cmd_fifo_rempty => cmd_fifo_empty,
            hash_data_fifo_wdata => rsp_fifo_wdata,
            hash_data_fifo_write => rsp_fifo_write
        );

    -- Everything the part sees is delayed by out_delay; everything the DUT
    -- captures is delayed again by in_delay coming back.
    sclk_flash <= sclk after out_delay;
    csn_flash  <= cs_n after out_delay;

    flash: entity work.spi_nor_target_vc
        generic map (
            actor_name => "spi_nor_target"
        )
        port map (
            cs_n  => csn_flash,
            sclk  => sclk_flash,
            io    => io_flash,
            io_o  => flash_o,
            io_oe => flash_oe
        );

    -- Both ends contribute to the resolved bus at the part, plus a weak pull-up
    -- for the board's. If both drive a lane the resolution goes to 'X', which the
    -- controller shifts in and the digest check then catches.
    bus_gen: for i in io_flash'range generate
        io_flash(i) <= io_o(i) after out_delay when io_oe(i) = '1' else 'Z' after out_delay;
        io_flash(i) <= flash_o(i) when flash_oe(i) = '1' else 'Z';
        io_flash(i) <= 'H';
    end generate;

    io <= io_flash after in_delay;

end th;
