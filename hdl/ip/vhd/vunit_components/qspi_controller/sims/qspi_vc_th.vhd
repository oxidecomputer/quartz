-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qspi_vc_pkg.all;

entity qspi_vc_th is
end entity;

architecture th of qspi_vc_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal ss_n : std_logic_vector(7 downto 0);
    signal sclk : std_logic;
    signal io   : std_logic_vector(3 downto 0);

    constant qspi_vc : qspi_vc_t := new_qspi_vc("espi_vc");

begin

    -- set up a fastish clock for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    qspi_controller_vc_inst: entity work.qspi_controller_vc
        generic map (
            qspi_vc => qspi_vc
        )
        port map (
            ss_n => ss_n,
            sclk => sclk,
            io   => io
        );

end th;
