-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.spi_axi_tb_pkg.all;

entity spi_axi_th is
end entity;

architecture th of spi_axi_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal csn : std_logic := '1';
    signal sclk : std_logic;
    signal copi : std_logic;
    signal cipo : std_logic;
    signal awvalid : std_logic;
    signal awready : std_logic;
    signal awaddr : std_logic_vector(15 downto 0);
    signal wvalid : std_logic;
    signal wready : std_logic;
    signal wdata : std_logic_vector(31 downto 0);
    signal wstrb : std_logic_vector(3 downto 0);
    signal bvalid : std_logic;
    signal bready : std_logic;
    signal bresp : std_logic_vector(1 downto 0);
    signal arvalid : std_logic;
    signal arready : std_logic;
    signal araddr : std_logic_vector(15 downto 0);
    signal rvalid : std_logic;
    signal rready : std_logic;
    signal rdata : std_logic_vector(31 downto 0);
    signal rresp : std_logic_vector(1 downto 0);

    signal arid             : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(0, 4));
    signal bid              : std_logic_vector(3 downto 0);
    signal awid             : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(0, 4));
    signal rid              : std_logic_vector(3 downto 0);

begin

    -- set up a fastish clock for the sim env
    -- and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;


    DUT: entity work.spi_axi_controller
     port map(
        clk => clk,
        reset => reset,
        csn => csn,
        sclk => sclk,
        copi => copi,
        cipo => cipo,
        awvalid => awvalid,
        awready => awready,
        awaddr => awaddr,
        wvalid => wvalid,
        wready => wready,
        wdata => wdata,
        wstrb => wstrb,
        bvalid => bvalid,
        bready => bready,
        bresp => bresp,
        arvalid => arvalid,
        arready => arready,
        araddr => araddr,
        rvalid => rvalid,
        rready => rready,
        rdata => rdata,
        rresp => rresp
    );

    -- sim infrastructure from VUnit
    axi_read_sim_infra: entity vunit_lib.axi_read_slave
        generic map (
            axi_slave => axi_read_target
        )
        port map (
            aclk => clk,

            arvalid => arvalid,
            arready => arready,
            arid    => arid,
            araddr  => araddr,
            arlen   => "00000000",
            arsize  => "010",
            arburst => "00",

            rvalid => rvalid,
            rready => rready,
            rid    => rid,
            rdata  => rdata,
            rresp  => rresp,
            rlast  => open
        );

    axi_write_sim_infra: entity vunit_lib.axi_write_slave
        generic map (
            axi_slave => axi_write_target
        )
        port map (
            aclk    => clk,
            awvalid => awvalid,
            awready => awready,
            awid    => awid,
            awaddr  => awaddr,
            awlen   => "00000000",
            awsize  => "010",
            awburst => "00",
            wvalid  => wvalid,
            wready  => wready,
            wdata   => wdata,
            wstrb   => wstrb,
            wlast   => '1',
            bvalid  => bvalid,
            bready  => bready,
            bid     => bid,
            bresp   => open
        );

    spi_controller: entity vunit_lib.spi_master
    generic map(
        spi => master_spi
    )
    port map (
        sclk => sclk,
        mosi => copi,
        miso => cipo
    );


end th;