-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
use work.stm32h7_fmc_sim_pkg.all;
use work.fmc_tb_pkg.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

entity fmc_th is
end entity;

architecture th of fmc_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal a     : std_logic_vector(25 downto 16);
    signal ad    : std_logic_vector(15 downto 0);
    signal ne    : std_logic_vector(3 downto 0);
    signal noe   : std_logic;
    signal nwe   : std_logic;
    signal nl    : std_logic;
    signal nwait : std_logic := '1';

    signal awvalid : std_logic;
    signal awready : std_logic;
    signal awaddr  : std_logic_vector(25 downto 0);
    signal awprot  : std_logic_vector(2 downto 0);
    signal wvalid  : std_logic;
    signal wready  : std_logic;
    signal wstrb   : std_logic_vector(3 downto 0);
    signal wdata   : std_logic_vector(31 downto 0);
    signal bvalid  : std_logic;
    signal bready  : std_logic;
    signal arvalid : std_logic;
    signal araddr  : std_logic_vector(25 downto 0);
    signal arready : std_logic;
    signal rvalid  : std_logic;
    signal rready  : std_logic;
    signal rdata   : std_logic_vector(31 downto 0);

    signal arid : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(0, 4));
    signal bid  : std_logic_vector(3 downto 0);
    signal awid : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(0, 4));
    signal rid  : std_logic_vector(3 downto 0);

begin

    -- set up a fastish, clock for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    -- sim infrastructure from VUnit
    axi_read_sim_infra: entity vunit_lib.axi_read_slave
        generic map(
            axi_slave => axi_read_target
        )
        port map(
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
            rresp  => open,
            rlast  => open
        );

    axi_write_sim_infra: entity vunit_lib.axi_write_slave
        generic map(
            axi_slave => axi_write_target
        )
        port map(
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

    -- Our STM32 fmc model

    model: entity work.stm32h7_fmc_model
        generic map(
            bus_handle => SP_BUS_HANDLE
        )
        port map(
            clk   => clk,
            a     => a,
            ad    => ad,
            ne    => ne,
            noe   => noe,
            nwe   => nwe,
            nl    => nl,
            nwait => nwait
        );

    dut: entity work.stm32h7_fmc_target
        port map(
            -- Interface to the STM32H7's FMC periph
            --! Write full flag, sync to write clock domain
            chip_reset => reset,
            fmc_clk    => clk,
            a          => a(24 downto 16),
            ad         => ad,
            ne         => ne,
            -- todo missing byte enables?
            noe   => noe,
            nwe   => nwe,
            nl    => nl,
            nwait => nwait,
            -- FPGA interface
            aclk    => clk,
            aresetn => not reset,
            -- Write addr channel
            awvalid => awvalid,
            awready => awready,
            awaddr  => awaddr,
            awprot  => awprot,
            -- Write data channel
            wvalid => wvalid,
            wready => wready,
            wstrb  => wstrb,
            wdata  => wdata,
            -- Write response channel
            bvalid => bvalid,
            bready => bready,
            -- Read address channel
            arvalid => arvalid,
            araddr  => araddr,
            arready => arready,
            -- Read data channel
            rvalid => rvalid,
            rready => rready,
            rdata  => rdata

        );

end th;
