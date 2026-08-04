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
use work.spi_nor_tb_pkg.all;
use work.axil_common_pkg.all;
use work.axil8x32_pkg;
use work.axil32x32_pkg;
use work.axil26x32_pkg;
use work.axilite_if_2k19_helper_pkg.all;

entity spi_nor_th is
    generic (
        -- Defaults match the shipped-for-years configuration: 125MHz / 6 =
        -- 20.83MHz sclk with the sample point one clk after the rising edge.
        sclk_divisor   : natural := 2;
        rx_sample_taps : natural := 2;
        -- Delay from a launch flop to the pin at the flash, and from the pin back
        -- to the capture flop, board trace included. RTL simulation has no notion
        -- of either, but together they are a bigger share of a 16ns sclk period
        -- than the flash's own tCLQV, so the sample point cannot be validated
        -- without them. The XDC bounds both (via the output delay window and the
        -- IOB packing); these defaults are the slow corner it allows.
        out_delay : time := 3.7 ns;
        in_delay  : time := 1.5 ns
    );
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
    signal   flash_o      : std_logic_vector(3 downto 0);
    signal   flash_oe     : std_logic_vector(3 downto 0);
    -- The bus and clock as seen at the part, i.e. after the outbound delay
    signal   io_flash   : std_logic_vector(3 downto 0);
    signal   sclk_flash : std_logic;
    signal   csn_flash  : std_logic;
    constant config_array : axil_responder_cfg_array_t(0 downto 0) :=
    (
        0 => resp_cfg(base_addr => x"00000100", addr_span_bits => 8)
    );
    signal  responders   : axil32x32_pkg.axil_array_t(0 downto 0);
    signal  responders_8b : axil8x32_pkg.axil_array_t(0 downto 0);

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

        resiser: entity work.axil8_resizer port map(fabric => responders(0), responder =>responders_8b(0));
    spi_nor_top_inst: entity work.spi_nor_top
        generic map (
            sclk_divisor   => sclk_divisor,
            rx_sample_taps => rx_sample_taps
        )
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
            espi_cmd_fifo_rdata  => (others => '0'),
            espi_cmd_fifo_rdack  => open,
            espi_cmd_fifo_rempty => '1',
            espi_data_fifo_wdata => open,
            espi_data_fifo_write => open
        );

    -- Everything the part sees is delayed by out_delay; everything the DUT
    -- captures is delayed again by in_delay on the way back.
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
    -- standing in for the board's. If both ends drive the same lane the
    -- resolution goes to 'X', which the DUT then shifts in and the data checks
    -- catch.
    bus_gen: for i in io_flash'range generate
        io_flash(i) <= io_o(i) after out_delay when io_oe(i) = '1' else 'Z' after out_delay;
        io_flash(i) <= flash_o(i) when flash_oe(i) = '1' else 'Z';
        io_flash(i) <= 'H';
    end generate;

    io <= io_flash after in_delay;

    -- Contention is a real bug that shows up as marginal reads on hardware, so
    -- name it explicitly rather than leaving it to be inferred from an 'X'.
    contention_check: process(all)
        alias rel is << signal spi_nor_top_inst.release_lanes : std_logic_vector(3 downto 0) >>;
        alias in_tx is << signal spi_nor_top_inst.in_tx_phases : boolean >>;
        alias in_rx is << signal spi_nor_top_inst.in_rx_phases : boolean >>;
    begin
        for i in io'range loop
            assert not (io_oe(i) = '1' and flash_oe(i) = '1')
                report "Bus contention: controller and flash both driving io(" &
                       to_string(i) & "), ctrl_oe=" & to_string(io_oe) &
                       " flash_oe=" & to_string(flash_oe) &
                       " cs_n=" & to_string(cs_n) &
                       " release=" & to_string(rel) &
                       " in_tx=" & to_string(in_tx) &
                       " in_rx=" & to_string(in_rx)
                severity error;
        end loop;
    end process;

end th;
