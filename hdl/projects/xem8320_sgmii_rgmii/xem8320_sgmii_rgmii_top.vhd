-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- XEM8320 SGMII <-> RGMII media-converter top level.
--
--   SGMII line  : GTY transceiver on the onboard SMA connectors J15-J18 (GTY
--                 quad 226, channel 2), driving a soft PCS through comma-aligned
--                 10-bit code groups.
--   RGMII line  : SZG-ENET1G (TI DP83867, RGMII-only, auto-neg strapped) on
--                 SYZYGY Port A (J5), HP bank 66, at 1.8 V.
--
-- The XEM8320 has no fabric oscillator: the GT reference clock (from the onboard
-- programmable synth) is the only always-on clock, so all clocking is derived
-- from it. The GT wrapper produces a free-running clock (refclk-derived) and the
-- 125 MHz user clock; the MMCM makes the 200 MHz IDELAYCTRL reference.
--
-- Management is minimal/strapped: the advertised SGMII ability is hardwired and
-- link/speed status is brought out on spare Port A pins (no MDIO, no LEDs). The
-- PHY's RGMII RX clock-to-data skew is supplied on the FPGA side by delaying rxc
-- (IDELAYE3 + IDELAYCTRL) -- the primary bring-up tuning knob (see README).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;
use work.rgmii_pkg.all;

entity xem8320_sgmii_rgmii_top is
    port (
        -- SGMII serial on SMA connectors (GTY quad 226 ch 2); refclk = onboard
        -- 125 MHz on MGTREFCLK0_226
        mgtrefclk_p : in    std_logic;
        mgtrefclk_n : in    std_logic;
        gt_rxp      : in    std_logic;
        gt_rxn      : in    std_logic;
        gt_txp      : out   std_logic;
        gt_txn      : out   std_logic;

        -- RGMII to the SZG-ENET1G (SYZYGY Port A, bank 66, 1.8 V)
        rgmii_txc    : out   std_logic;
        rgmii_tx_ctl : out   std_logic;
        rgmii_txd    : out   std_logic_vector(3 downto 0);
        rgmii_rxc    : in    std_logic;
        rgmii_rx_ctl : in    std_logic;
        rgmii_rxd    : in    std_logic_vector(3 downto 0);
        phy_resetn   : out   std_logic;

        -- status, brought out on spare Port A pins (active-high)
        status : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of xem8320_sgmii_rgmii_top is

    -- ---- Xilinx primitives (declared locally; Vivado binds by name) ----------
    component bufg is
        port (
            o : out   std_ulogic;
            i : in    std_ulogic
        );
    end component;

    component idelayctrl is
        generic (
            sim_device : string := "ULTRASCALE"
        );
        port (
            rdy    : out   std_ulogic;
            refclk : in    std_ulogic;
            rst    : in    std_ulogic
        );
    end component;

    -- UltraScale+ input delay. Fixed TIME mode supplies the RGMII RX skew so the
    -- IDDRE1 samples inside the data eye. DELAY_VALUE is the bring-up tuning knob.
    component idelaye3 is
        generic (
            cascade          : string  := "NONE";
            delay_format     : string  := "TIME";
            delay_src        : string  := "IDATAIN";
            delay_type       : string  := "FIXED";
            delay_value      : integer := 2000;     -- ps
            is_clk_inverted  : bit     := '0';
            is_rst_inverted  : bit     := '0';
            refclk_frequency : real    := 200.0;
            sim_device       : string  := "ULTRASCALE_PLUS";
            update_mode      : string  := "ASYNC"
        );
        port (
            casc_out    : out   std_ulogic;
            cntvalueout : out   std_logic_vector(8 downto 0);
            dataout     : out   std_ulogic;
            casc_in     : in    std_ulogic;
            casc_return : in    std_ulogic;
            ce          : in    std_ulogic;
            clk         : in    std_ulogic;
            cntvaluein  : in    std_logic_vector(8 downto 0);
            datain      : in    std_ulogic;
            en_vtc      : in    std_ulogic;
            idatain     : in    std_ulogic;
            inc         : in    std_ulogic;
            load        : in    std_ulogic;
            rst         : in    std_ulogic
        );
    end component;

    -- ---- clocks / resets -----------------------------------------------------
    signal clk_freerun  : std_logic;   -- GT refclk-derived, always on
    signal clk_200m     : std_logic;   -- IDELAYCTRL reference
    signal pll_locked   : std_logic;
    signal idelay_rdy   : std_logic;

    signal clk_125m     : std_logic;   -- GT user clock; the bridge runs here
    signal reset_125m   : std_logic;
    signal gt_ready     : std_logic;

    -- ---- RGMII RX clock path -------------------------------------------------
    signal rxc_delayed  : std_logic;
    signal rxc_buf      : std_logic;

    -- ---- SGMII code groups ---------------------------------------------------
    signal rx_code       : std_logic_vector(9 downto 0);
    signal rx_code_valid : std_logic;
    signal tx_code       : std_logic_vector(9 downto 0);

    -- ---- bridge status -------------------------------------------------------
    signal link_up    : std_logic;
    signal link_speed : eth_speed_t;
    signal link_dup   : std_logic;
    signal rgmii_info : rgmii_inband_t;

    -- Hardwired advertised ability (PHY role): link up, full duplex, 1000.
    constant ADV : sgmii_config_t :=
        (link => '1', ack => '0', duplex => '1', speed => SPEED_1000);

begin

    -- ===== SGMII line side (GTY) + clock source ==============================
    -- The GT wrapper owns the refclk buffers and emits the always-on free-run
    -- clock as well as the 125 MHz user clock.
    gt_i: entity work.sgmii_gt
        port map (
            mgtrefclk_p   => mgtrefclk_p,
            mgtrefclk_n   => mgtrefclk_n,
            gt_rxp        => gt_rxp,
            gt_rxn        => gt_rxn,
            gt_txp        => gt_txp,
            gt_txn        => gt_txn,
            reset         => '0',          -- wizard self-sequences off freerun
            freerun_clk   => clk_freerun,
            usrclk        => clk_125m,
            rx_code       => rx_code,
            rx_code_valid => rx_code_valid,
            tx_code       => tx_code,
            gt_ready      => gt_ready
        );

    -- ===== IDELAYCTRL reference clock ========================================
    pll_i: entity work.idelay_pll
        port map (
            clk_in   => clk_freerun,
            clk_200m => clk_200m,
            reset    => '0',
            locked   => pll_locked
        );

    idelayctrl_i: component idelayctrl
        generic map (
            sim_device => "ULTRASCALE"
        )
        port map (
            rdy    => idelay_rdy,
            refclk => clk_200m,
            rst    => not pll_locked
        );

    -- bridge reset deasserts once the GT is up (gt_ready = 1 means run)
    bridge_reset_sync: entity work.async_reset_bridge
        generic map (
            async_reset_active_level => '0'
        )
        port map (
            clk         => clk_125m,
            reset_async => gt_ready,
            reset_sync  => reset_125m
        );

    -- ===== RGMII RX clock: delay rxc into the data eye, then global-buffer ====
    rxc_idelay: component idelaye3
        generic map (
            delay_format     => "TIME",
            delay_type       => "FIXED",
            delay_value      => 2000,        -- ~2 ns; tune for the SZG-ENET1G
            refclk_frequency => 200.0,
            sim_device       => "ULTRASCALE_PLUS"
        )
        port map (
            casc_out    => open,
            cntvalueout => open,
            dataout     => rxc_delayed,
            casc_in     => '0',
            casc_return => '0',
            ce          => '0',
            clk         => '0',
            cntvaluein  => (others => '0'),
            datain      => '0',
            en_vtc      => '1',
            idatain     => rgmii_rxc,
            inc         => '0',
            load        => '0',
            rst         => '0'
        );

    rxc_bufg: component bufg
        port map (
            o => rxc_buf,
            i => rxc_delayed
        );

    -- ===== SGMII <-> RGMII bridge ============================================
    bridge_i: entity work.sgmii_to_rgmii
        generic map (
            INCLUDE_AUTONEG   => true,
            LINK_TIMER_CYCLES => 1250000,   -- ~10 ms at 125 MHz
            TARGET            => "XILINX"
        )
        port map (
            clk           => clk_125m,
            reset         => reset_125m,
            rx_code       => rx_code,
            rx_code_valid => rx_code_valid,
            tx_code       => tx_code,
            tx_code_valid => open,
            rgmii_txc     => rgmii_txc,
            rgmii_tx_ctl  => rgmii_tx_ctl,
            rgmii_txd     => rgmii_txd,
            rgmii_rxc     => rxc_buf,
            rgmii_rx_ctl  => rgmii_rx_ctl,
            rgmii_rxd     => rgmii_rxd,
            an_enable     => '1',
            an_restart    => '0',
            adv_config    => ADV,
            link_up         => link_up,
            speed           => link_speed,
            duplex          => link_dup,
            rgmii_link_info => rgmii_info
        );

    -- hold the PHY in reset until the local clocks are up
    phy_resetn <= pll_locked;

    -- ===== Status (active-high, on spare Port A pins) ========================
    status(0) <= link_up;
    status(1) <= gt_ready;
    status(2) <= rgmii_info.link;
    status(3) <= pll_locked;

end architecture;
