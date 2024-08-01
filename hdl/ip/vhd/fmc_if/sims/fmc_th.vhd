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

use work.axil26x32_pkg.all;

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

    signal rdata   : std_logic_vector(31 downto 0);

    signal arid : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(0, 4));
    signal bid  : std_logic_vector(3 downto 0);
    signal awid : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(0, 4));
    signal rid  : std_logic_vector(3 downto 0);

    signal axi_if : axil_t;

begin

    -- set up a fastish, clock for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    -- sim infrastructure from VUnit
    axi_read_sim_infra: entity vunit_lib.axi_read_slave
        generic map (
            axi_slave => axi_read_target
        )
        port map (
            aclk => clk,

            arvalid => axi_if.read_address.valid,
            arready => axi_if.read_address.ready,
            arid    => arid,
            araddr  => axi_if.read_address.addr,
            arlen   => "00000000",
            arsize  => "010",
            arburst => "00",

            rvalid => axi_if.read_data.valid,
            rready => axi_if.read_data.ready,
            rid    => rid,
            rdata  => axi_if.read_data.data,
            rresp  => axi_if.read_data.resp,
            rlast  => open
        );

    axi_write_sim_infra: entity vunit_lib.axi_write_slave
        generic map (
            axi_slave => axi_write_target
        )
        port map (
            aclk    => clk,
            awvalid => axi_if.write_address.valid,
            awready => axi_if.write_address.ready,
            awid    => awid,
            awaddr  => axi_if.write_address.addr,
            awlen   => "00000000",
            awsize  => "010",
            awburst => "00",
            wvalid  => axi_if.write_data.valid,
            wready  => axi_if.write_data.ready,
            wdata   => axi_if.write_data.data,
            wstrb   => axi_if.write_data.strb,
            wlast   => '1',
            bvalid  => axi_if.write_response.valid,
            bready  => axi_if.write_response.ready,
            bid     => bid,
            bresp   => open
        );

    -- Our STM32 fmc model

    model: entity work.stm32h7_fmc_model
        generic map (
            bus_handle => SP_BUS_HANDLE
        )
        port map (
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
        port map (
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
            axi_if => axi_if
          

        );

end th;
