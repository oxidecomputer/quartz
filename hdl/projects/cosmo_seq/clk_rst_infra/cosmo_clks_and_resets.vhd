-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Instantiate the PLLs and build out reset synchronizers for the various clock domains

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity cosmo_clks_and_resets is
    port (
        board_clk : in std_logic;
        board_reset_l : in std_logic;
        fmc_sp_to_fpga_clk : in std_logic;
        reset_fmc : out std_logic;
        clk_125m : out std_logic;
        reset_125m : out std_logic;
        clk_200m : out std_logic;
        reset_200m : out std_logic
    );
end entity;

architecture rtl of cosmo_clks_and_resets is

    signal pll_locked_async : std_logic;

begin

-- Xilinx IP generated PLL
    pll: entity work.cosmo_pll
    port map ( 
      clk_50m => board_clk,
      clk_125m => clk_125m,
      clk_200m => clk_200m,
      reset => not board_reset_l,
      locked => pll_locked_async
      
    );

    -- Reset synchronizer into the various clock domains
    reset_sync_inst: entity work.reset_sync
    port map(
       pll_locked_async => pll_locked_async,
       clk_125m => clk_125m,
       reset_125m => reset_125m,
       clk_200m => clk_200m,
       reset_200m => reset_200m,
       sp_fmc_clk => fmc_sp_to_fpga_clk,
       reset_fmc_clk => reset_fmc
    );

end architecture;