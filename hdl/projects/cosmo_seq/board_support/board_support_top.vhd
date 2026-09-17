-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
        -- deskewed/phase-shifted FMC clock from the FMC MMCM; everything in
        -- the FMC domain must use this, not the raw pin
        fmc_clk_buf : out std_logic;
        -- later-phased sibling for the FMC input capture registers only
        fmc_capture_clk_buf : out std_logic;
        reset_fmc : out std_logic;
        -- misc board signals
        fpga1_status_led : out std_logic;
        hubris_compat_ver : in std_logic_vector(2 downto 0);
        -- AXI interface for the "info" block
        info_axi_if : view axil_target;
        is_rev1 : out std_logic;  -- tied high if rev1 board
        is_rev2 : out std_logic  -- tied high if rev2 board
    );
end entity;


architecture rtl of board_support is

    signal sp_system_reset_syncd : std_logic;
    signal pll_locked_async : std_logic;
    signal led_counter : unsigned(27 downto 0);
    signal fmc_clk_g : std_logic;
    signal fmc_capture_clk_g : std_logic;
    signal fmc_mmcm_locked : std_logic;
    signal fmc_mmcm_reset : std_logic;

begin

    -- Tie off the board revision outputs
    -- skipping meta sync here b/c stuff is strapped on board.
    -- Providing registers here since there could be some fan-out.
    rev_indicators: process(clk_125m)
    begin
        if rising_edge(clk_125m) then
            is_rev1 <= '1' when unsigned(hubris_compat_ver) = 0 else '0';  -- rev1 board
            is_rev2 <= '1' when unsigned(hubris_compat_ver) = 1 else '0';  -- rev2 board
        end if;
    end process;

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
    pll: entity work.sys_pll
    port map ( 
        clk_50m => board_50mhz_clk,
        clk_125m => clk_125m,
        clk_200m => clk_200m,
        reset => sp_system_reset_syncd,
        locked => pll_locked_async
      
    );

    -- MMCM on the SP's (continuous) FMC clock: BUFG-in-feedback deskew plus
    -- a small phase shift, which is what closes the single-cycle FMC pin
    -- timing at 10 ns. See xilinx_ip_gen/fmc_pll_ip.tcl for the VCO and
    -- phase reasoning.
    fmc_pll_inst: entity work.fmc_pll
     port map(
        clk_fmc_in => sp_fmc_clk,
        clk_fmc => fmc_clk_g,
        clk_fmc_capture => fmc_capture_clk_g,
        reset => fmc_mmcm_reset,
        locked => fmc_mmcm_locked
    );

    -- Hold the MMCM in reset while the SP's clock is stopped (SP reset or
    -- reconfiguration) and retry the lock if the input frequency changes.
    fmc_clk_monitor_inst: entity work.fmc_clk_monitor
     port map(
        clk => clk_125m,
        reset => reset_125m,
        fmc_clk_raw => sp_fmc_clk,
        mmcm_locked => fmc_mmcm_locked,
        mmcm_reset => fmc_mmcm_reset
    );

    fmc_clk_buf         <= fmc_clk_g;
    fmc_capture_clk_buf <= fmc_capture_clk_g;

    -- Reset synchronizer into the clock domains. The FMC branch is clocked
    -- by the MMCM output and additionally gated on MMCM lock: while
    -- unlocked there are no FMC-domain clock edges and the async assert is
    -- what keeps the FMC target's bus drive released.
    reset_sync_inst: entity work.reset_sync
    port map(
        pll_locked_async => pll_locked_async,
        aux_locked_async => fmc_mmcm_locked,
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        sp_fmc_clk => fmc_clk_g,
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