-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.axil8x32_pkg.all;

-- Basic board support blocks including clock and reset generation
-- board LEDs, and debugging I/O etc.

entity board_support is
    port (
        -- Board level clocks and resets
        board_50mhz_clk : in std_logic;
        sp_fmc_clk : in std_logic;
        sp_system_reset_l : in std_logic;
        -- PLL outputs and synchronized resets
        clk_125m : out std_logic;
        reset_125m : out std_logic;
        clk_200m : out std_logic;
        reset_200m : out std_logic;
        reset_fmc : out std_logic;
        -- misc board signals
        fpga1_status_led : out std_logic;
        hubris_compat_ver : in std_logic_vector(2 downto 0);
        -- AXI interface for the "info" block
        info_axi_if : view axil_target;
    );
end entity;


architecture rtl of board_support is

    signal sp_system_reset_syncd : std_logic;
    signal pll_locked_async : std_logic;
    signal led_counter : unsigned(27 downto 0);

begin

    -- We have a reset pin coming in from the SP.  Synchronize it first
    -- using the "raw" board clock, pre-PLL. We'll use this as the 
    -- reset to the PLL, and the aclr the down-stream clocks
    clk50m_base_reset_sync: entity work.async_reset_bridge
     generic map(
        async_reset_active_level => '0'
    )
     port map(
        clk => board_50mhz_clk,
        reset_async => sp_system_reset_l,
        reset_sync => sp_system_reset_syncd -- polarity flip inside, now active high
    );

    -- Xilinx PLL instantiation
    pll: entity work.cosmo_pll
    port map ( 
        clk_50m => board_50mhz_clk,
        clk_125m => clk_125m,
        clk_200m => clk_200m,
        reset => sp_system_reset_syncd,
        locked => pll_locked_async
      
    );

    -- Reset synchronizer into the clock domains
    reset_sync_inst: entity work.reset_sync
    port map(
        pll_locked_async => pll_locked_async,
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        sp_fmc_clk => sp_fmc_clk,
        reset_fmc_clk => reset_fmc
    );

    -- Blink an LED at some rate
    led: process(clk_125m, reset_125m)
    begin
        if reset_125m then
            led_counter <= (others => '0');
        elsif rising_edge(clk_125m) then
            led_counter <= led_counter + 1;
        end if;
    end process;
    fpga1_status_led <= led_counter(25);

    -- Put the "info" common block here
    info_inst: entity work.info
     generic map(
        hubris_compat_num_bits => 3
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        hubris_compat_pins => hubris_compat_ver,
        axi_if => info_axi_if
    );

end rtl;