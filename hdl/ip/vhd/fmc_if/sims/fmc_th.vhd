-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

    -- fmc_clk and aclk are deliberately unrelated so the real CDC gets
    -- exercised. fmc_half_period defaults to 50 MHz (the shipped SP CLKDIV)
    -- and is forced by the testbench to 7.5 ns / 5 ns for the 66.67 and
    -- 100 MHz ratio runs.
    signal fmc_half_period : time      := 10 ns;
    signal fmc_clk         : std_logic := '0';
    signal aclk            : std_logic := '0';
    signal reset           : std_logic := '1';

    signal a     : std_logic_vector(25 downto 16);
    signal ad    : std_logic_vector(15 downto 0);
    signal ne    : std_logic_vector(3 downto 0);
    signal noe   : std_logic;
    signal nwe   : std_logic;
    signal nl    : std_logic;
    signal nwait : std_logic := '1';

    signal arid             : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(0, 4));
    signal bid              : std_logic_vector(3 downto 0);
    signal awid             : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(0, 4));
    signal rid              : std_logic_vector(3 downto 0);
    signal data_out_tris     : std_logic_vector(15 downto 0);
    signal data_out_tris_hiz : std_logic_vector(15 downto 0);

    signal timeout_count    : std_logic_vector(7 downto 0);
    signal contention_count : std_logic_vector(7 downto 0);

    signal axi_if : axil_t;

begin

    aclk  <= not aclk after 4 ns;
    reset <= '0' after 200 ns;

    fmc_clk_gen: process
    begin
        wait for fmc_half_period;
        fmc_clk <= not fmc_clk;
    end process;

    -- sim infrastructure from VUnit
    axi_read_sim_infra: entity vunit_lib.axi_read_slave
        generic map (
            axi_slave => axi_read_target
        )
        port map (
            aclk => aclk,

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
            aclk    => aclk,
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
            clk   => fmc_clk,
            a     => a,
            ad    => ad,
            ne    => ne,
            noe   => noe,
            nwe   => nwe,
            nl    => nl,
            nwait => nwait
        );

    ad <= (others => 'Z') when data_out_tris_hiz(0) = '1' else data_out_tris;

    -- Contention tripwire: the model owns the bus during the address phase
    -- (NADV low) and write data beats (NWE low); the DUT driving then means
    -- the two sides disagree about the transaction phase. Every test fails
    -- fast on this instead of silently resolving the fight.
    contention_check: process(fmc_clk)
    begin
        if rising_edge(fmc_clk) then
            assert not (data_out_tris_hiz(0) = '0' and (nl = '0' or nwe = '0'))
                report "BUS CONTENTION: DUT driving during SP address/write phase"
                severity failure;
        end if;
    end process;

    dut: entity work.stm32h7_fmc_target
        generic map (
            -- short enough to keep timeout tests quick, long enough that the
            -- slow-responder (non-timeout) tests stay under it
            timeout_cycles => 512
        )
        port map (
            -- Interface to the STM32H7's FMC periph
            chip_reset   => reset,
            fmc_clk      => fmc_clk,
            fmc_capture_clk => fmc_clk,
            a            => a(24 downto 16),
            addr_data_in => ad,
            data_out     => data_out_tris,
            data_out_hiz => data_out_tris_hiz,
            ne           => ne,
            noe   => noe,
            nwe   => nwe,
            nl    => nl,
            nwait => nwait,

            timeout_count    => timeout_count,
            contention_count => contention_count,
            -- FPGA interface
            aclk    => aclk,
            aresetn => not reset,
            axi_if  => axi_if

        );

end th;
