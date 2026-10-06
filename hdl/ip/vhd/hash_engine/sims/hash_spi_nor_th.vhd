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

    -- Two flashes, indexed the way the engine's flash ports are: 0 is the
    -- host's, 1 the auxiliary one CONFIG.source = AUX_QSPI selects.
    constant NUM_FLASHES : natural := 2;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal axi_bus     : axil8x32_pkg.axil_t;
    type spinor_axi_t is array (0 to NUM_FLASHES - 1) of axil8x32_pkg.axil_t;
    signal spinor_axi  : spinor_axi_t;

    signal cmd_fifo_rdata : std_logic_vector(31 downto 0);
    signal cmd_fifo_rdack : std_logic_vector(NUM_FLASHES - 1 downto 0);
    signal cmd_fifo_empty : std_logic_vector(NUM_FLASHES - 1 downto 0);
    signal rsp_fifo_wdata : std_logic_vector(NUM_FLASHES * 8 - 1 downto 0);
    signal rsp_fifo_write : std_logic_vector(NUM_FLASHES - 1 downto 0);

    type lanes_t is array (0 to NUM_FLASHES - 1) of std_logic_vector(3 downto 0);
    signal cs_n  : std_logic_vector(NUM_FLASHES - 1 downto 0);
    signal sclk  : std_logic_vector(NUM_FLASHES - 1 downto 0);
    signal io    : lanes_t;
    signal io_o  : lanes_t;
    signal io_oe : lanes_t;

    signal flash_o    : lanes_t;
    signal flash_oe   : lanes_t;
    signal io_flash   : lanes_t;
    signal sclk_flash : std_logic_vector(NUM_FLASHES - 1 downto 0);
    signal csn_flash  : std_logic_vector(NUM_FLASHES - 1 downto 0);

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
        generic map (
            NUM_FLASHES => NUM_FLASHES
        )
        port map (
            clk              => clk,
            reset            => reset,
            axi_if           => axi_bus,
            flash_cmd_rdata  => cmd_fifo_rdata,
            flash_cmd_rdack  => cmd_fifo_rdack,
            flash_cmd_rempty => cmd_fifo_empty,
            flash_rsp_wdata  => rsp_fifo_wdata,
            flash_rsp_write  => rsp_fifo_write,
            flash_rsp_wfull  => open
        );

    -- One spi_nor_top and one modelled part per flash, each hung off its own
    -- pair of the engine's flash ports. The parts are told apart by actor
    -- name; which of them a run reads is the whole point of the aux tests.
    flashes: for f in 0 to NUM_FLASHES - 1 generate
        constant actor : string := "spi_nor_target" & integer'image(f);
    begin
        -- The SPI controller's own register interface is not exercised here,
        -- so park its initiator side idle. sp5_owns_flash stays at its reset
        -- value of zero, which means the hubris register path is nominally
        -- selected and the hash client has to win the engine on its own.
        spinor_axi(f).read_address.valid   <= '0';
        spinor_axi(f).read_address.addr    <= (others => '0');
        spinor_axi(f).read_data.ready      <= '0';
        spinor_axi(f).write_address.valid  <= '0';
        spinor_axi(f).write_address.addr   <= (others => '0');
        spinor_axi(f).write_data.valid     <= '0';
        spinor_axi(f).write_data.data      <= (others => '0');
        spinor_axi(f).write_data.strb      <= (others => '0');
        spinor_axi(f).write_response.ready <= '0';

        spi_nor: entity work.spi_nor_top
            port map (
                clk                  => clk,
                reset                => reset,
                axi_if               => spinor_axi(f),
                cs_n                 => cs_n(f),
                sclk                 => sclk(f),
                io                   => io(f),
                io_o                 => io_o(f),
                io_oe                => io_oe(f),
                sp5_owns_flash       => open,
                espi_cmd_fifo_rdata  => (others => '0'),
                espi_cmd_fifo_rdack  => open,
                espi_cmd_fifo_rempty => '1',
                espi_data_fifo_wdata => open,
                espi_data_fifo_write => open,
                hash_cmd_fifo_rdata  => cmd_fifo_rdata,
                hash_cmd_fifo_rdack  => cmd_fifo_rdack(f),
                hash_cmd_fifo_rempty => cmd_fifo_empty(f),
                hash_data_fifo_wdata => rsp_fifo_wdata(f * 8 + 7 downto f * 8),
                hash_data_fifo_write => rsp_fifo_write(f)
            );

        -- Everything the part sees is delayed by out_delay; everything the DUT
        -- captures is delayed again by in_delay coming back.
        sclk_flash(f) <= sclk(f) after out_delay;
        csn_flash(f)  <= cs_n(f) after out_delay;

        flash: entity work.spi_nor_target_vc
            generic map (
                actor_name => actor
            )
            port map (
                cs_n  => csn_flash(f),
                sclk  => sclk_flash(f),
                io    => io_flash(f),
                io_o  => flash_o(f),
                io_oe => flash_oe(f)
            );

        -- Both ends contribute to the resolved bus at the part, plus a weak
        -- pull-up for the board's. If both drive a lane the resolution goes to
        -- 'X', which the controller shifts in and the digest check then catches.
        bus_gen: for i in 0 to 3 generate
            io_flash(f)(i) <= io_o(f)(i) after out_delay when io_oe(f)(i) = '1' else 'Z' after out_delay;
            io_flash(f)(i) <= flash_o(f)(i) when flash_oe(f)(i) = '1' else 'Z';
            io_flash(f)(i) <= 'H';
        end generate;

        io(f) <= io_flash(f) after in_delay;
    end generate;

end th;
