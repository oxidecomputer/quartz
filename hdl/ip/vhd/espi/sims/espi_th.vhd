-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qspi_vc_pkg.all;

entity espi_th is
end entity;

architecture th of espi_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal   ss_n       : std_logic_vector(7 downto 0);
    signal   sclk       : std_logic;
    signal   io         : std_logic_vector(3 downto 0);
    signal   io_o       : std_logic_vector(3 downto 0);
    signal   io_oe      : std_logic_vector(3 downto 0);
    constant qspi_actor : qspi_vc_t := new_qspi_vc("espi_vc");

begin

    -- set up a fastish clock for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    qspi_controller_vc_inst: entity work.qspi_controller_vc
        generic map (
            qspi_vc => qspi_actor
        )
        port map (
            ss_n => ss_n,
            sclk => sclk,
            io   => io
        );

    dut: entity work.espi_target_top
        port map (
            clk   => clk,
            reset => reset,
            cs_n  => ss_n(0),
            sclk  => sclk,
            io    => io,
            io_o  => io_o,
            io_oe => io_oe
        );

    io_tris: process(all)
    begin
        for i in io'range loop
            io(i) <= io_o(i) when io_oe(i) = '1' else 'H';
        end loop;
    end process;

end th;
