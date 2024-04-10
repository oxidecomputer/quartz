-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.stm32h7_fmc_sim_pkg.all;

entity fmc_th is
end entity;

architecture th of fmc_th is
  signal clk   : std_logic := '0';
  signal reset : std_logic := '1';

  signal a : std_logic_vector(25 downto 16);
  signal ad: std_logic_vector(15 downto 0);
  signal ne: std_logic_vector(3 downto 0);
  signal noe: std_logic;
  signal nwe: std_logic;
  signal nl: std_logic;
  signal nwait: std_logic := '1';


begin

    -- set up a fastish, clock for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;


    model: entity work.stm32h7_fmc_model
        generic map(
            BUS_HANDLE => SP_BUS_HANDLE
        )
        port map(
            clk  => clk,
            a    => a,
            ad   => ad,
            ne   => ne,
            noe  => noe,
            nwe  => nwe,
            nl   => nl,
            nwait => nwait
        );

    DUT: entity work.stm32h7_fmc_target
end th;