-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- XEM8320 SGMII <-> RGMII media-converter top level.
--
--   SGMII line  : GTY transceiver on the onboard SMA connectors J15-J18 (GTY
--                 quad 226, channel 2), driving a soft PCS through comma-aligned
--                 10-bit code groups.
--   RGMII line  : SZG-ENET1G (TI DP83867) on SYZYGY Port A (J5), HP bank 66, 1.8 V.
--
-- The DP83867's PAP package has no RGMII DLL-skew straps, so at startup an MDIO
-- master programs it for RGMII internal delay (RGMII-ID): the PHY then centers
-- RXC in the RX data eye and delays its TX sampling. The FPGA therefore captures
-- RX directly and forwards TX edge-aligned -- no FPGA-side IDELAY is needed.
--
-- The XEM8320 has no fabric oscillator: the GT reference clock (onboard 125 MHz)
-- is the only always-on source. The GT wrapper derives an always-on free-run
-- clock (which also clocks the MDIO startup) and the 125 MHz PCS clock.
--
-- Advertised SGMII ability is hardwired; link/GT/init status is on spare Port A
-- pins (no LEDs on this board).

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
        phy_mdc      : out   std_logic;
        phy_mdio     : inout std_logic;

        -- status, brought out on spare Port A pins (active-high)
        status : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of xem8320_sgmii_rgmii_top is

    -- Global clock buffer for the received RGMII clock (declared locally; Vivado
    -- binds to the UNISIM cell by name).
    component bufg is
        port (
            o : out   std_ulogic;
            i : in    std_ulogic
        );
    end component;

    -- ---- clocks / resets -----------------------------------------------------
    signal clk_freerun : std_logic;   -- GT refclk-derived, always on (~62.5 MHz)
    signal clk_125m    : std_logic;   -- GT user clock; the bridge runs here
    signal reset_125m  : std_logic;
    signal gt_ready    : std_logic;
    signal rxc_buf     : std_logic;   -- buffered rxc; clocks the RX IDDRE1s

    -- ---- SGMII code groups ---------------------------------------------------
    signal rx_code       : std_logic_vector(9 downto 0);
    signal rx_code_valid : std_logic;
    signal tx_code       : std_logic_vector(9 downto 0);

    -- ---- bridge status -------------------------------------------------------
    signal link_up    : std_logic;
    signal link_speed : eth_speed_t;
    signal link_dup   : std_logic;
    signal rgmii_info : rgmii_inband_t;

    -- ---- MDIO / DP83867 startup (clk_freerun domain) -------------------------
    signal f_reset    : std_logic := '1';
    signal phy_rstn_i : std_logic := '0';
    signal init_start : std_logic := '0';
    signal init_done  : std_logic;

    signal mi_start : std_logic;
    signal mi_op    : std_logic;
    signal mi_reg   : std_logic_vector(4 downto 0);
    signal mi_wd    : std_logic_vector(15 downto 0);
    signal mi_busy  : std_logic;
    signal mi_done  : std_logic;
    signal mi_rd    : std_logic_vector(15 downto 0);

    signal mdio_o_i  : std_logic;
    signal mdio_oe_i : std_logic;
    signal mdio_in_i : std_logic;

    -- startup sequence
    type su_state_t is (HOLD_RESET, SETTLE, KICK, RUNNING);
    signal su_state : su_state_t := HOLD_RESET;
    signal su_cnt   : integer range 0 to 2**17 - 1 := 0;

    constant RST_CYCLES    : integer := 62500;   -- ~1 ms hold at 62.5 MHz
    constant SETTLE_CYCLES : integer := 62500;   -- ~1 ms before MDIO

    -- Forced link ability (link up, full duplex, 100 Mbps), used when autoneg is
    -- off (INCLUDE_AUTONEG => false). The cosmo VSC8562 does NOT auto-negotiate on
    -- its SGMII MAC side (reg16E3 aneg_ena=0), and the Oxide switch it normally
    -- talks to also runs with autoneg off, forcing the link in software
    -- (VSC7448 PCS1G_ANEG_CFG.sw_resolve_ena). So we match that: no /C/ exchange,
    -- link forced up at a fixed 100 Mbps, which drives the RGMII rate + the 10x
    -- SGMII octet replication.
    constant ADV : sgmii_config_t :=
        (link => '1', ack => '0', duplex => '1', speed => SPEED_100);

    -- ---- ILA debug taps (clk_125m domain) -----------------------------------
    -- enum/record fields converted to vectors so they can be probed; mark_debug
    -- keeps these nets (with their names) so ila.tcl can connect to them without
    -- the "Set Up Debug" GUI. Connect the ILA more/deeper via the hardware manager.
    signal dbg_speed       : std_logic_vector(1 downto 0);
    signal dbg_rgmii_speed : std_logic_vector(1 downto 0);
    signal dbg_rgmii_link  : std_logic;
    signal dbg_init_done   : std_logic_vector(1 downto 0) := "00";  -- init_done sync'd

    -- GT RX alignment/status taps (gtclk domain; probed async on the clk_125m ILA)
    signal dbg_gt_aligned  : std_logic;   -- GT rxbyteisaligned
    signal dbg_gb_aligned  : std_logic;   -- gearbox locked
    signal dbg_bufstatus   : std_logic_vector(2 downto 0);
    signal dbg_clkcorcnt   : std_logic_vector(1 downto 0);
    signal dbg_gt_word     : std_logic_vector(19 downto 0);  -- raw GT word (pre-gearbox)

    -- Refclk sanity: measure clk_125m against the DP83867's independent RX clock
    -- (25 MHz at 100M, from its own crystal). Expect ~1280 = 256 * 125/25 if the
    -- GT refclk is really 125 MHz; a different value means the refclk is wrong.
    signal rxc_div      : unsigned(7 downto 0) := (others => '0');   -- /256 in rxc domain
    signal rxc_tick     : std_logic := '0';
    signal rxc_tick_m   : std_logic := '0';
    signal rxc_tick_s   : std_logic := '0';
    signal rxc_tick_s2  : std_logic := '0';
    signal ref_cnt      : unsigned(15 downto 0) := (others => '0');
    signal dbg_refratio : std_logic_vector(15 downto 0) := (others => '0');

    -- RX code-group health: count illegal-disparity rx_code per 65536 clk_125m.
    -- ~0 = clean 8b10b; ~half = garbage (the "aligned" flags can't be trusted).
    signal rx_ones      : integer range 0 to 10;
    signal win_cnt      : unsigned(15 downto 0) := (others => '0');
    signal bad_cnt      : unsigned(15 downto 0) := (others => '0');
    signal dbg_rxerr    : std_logic_vector(15 downto 0) := (others => '0');

    -- Frame activity: count start-of-packet ordered sets (/S/ = K27.7) seen on the
    -- TX and RX code streams. Non-zero TX = frames are reaching the SGMII TX from
    -- the RGMII side (so the copper/RGMII RX path works and the VSC should be
    -- forwarding them); RX = the VSC is sending us frames. At 100M each code group
    -- is replicated ~10x, so a single frame bumps the count by ~10.
    constant SOP_RD_MINUS : std_logic_vector(9 downto 0) := "0001011011";  -- K27.7 (0x05B)
    constant SOP_RD_PLUS  : std_logic_vector(9 downto 0) := "1110100100";  -- K27.7 (0x3A4)
    signal dbg_txsop    : std_logic_vector(15 downto 0) := (others => '0');
    signal dbg_rxsop    : std_logic_vector(15 downto 0) := (others => '0');
    signal tx_sop_cnt   : unsigned(15 downto 0) := (others => '0');
    signal rx_sop_cnt   : unsigned(15 downto 0) := (others => '0');

    -- ---- VIO live controls (JTAG): GT serial polarity inverts ---------------
    signal invert_rx_i : std_logic;
    signal invert_tx_i : std_logic;
    signal vio_rx_out  : std_logic_vector(0 downto 0);
    signal vio_tx_out  : std_logic_vector(0 downto 0);

    -- GTY TX driver equalization, swept live over the VIO
    signal tx_diffctrl_i   : std_logic_vector(4 downto 0);
    signal tx_precursor_i  : std_logic_vector(4 downto 0);
    signal tx_postcursor_i : std_logic_vector(4 downto 0);

    -- ---- RGMII-RX frame localization taps -----------------------------------
    -- Count frame starts at three points to see where a frame is lost between the
    -- copper pins and the SGMII PCS: the raw RGMII rx_ctl pin, the RGMII MAC's
    -- recovered dv (rxc domain), and dv into the PCS TX after the rate expander
    -- (clk_125m). Whichever count stays 0 during a ping brackets the failure.
    signal rgmii_rx_dv_i    : std_logic;   -- recovered RGMII RX dv (rxc domain)
    signal pcs_tx_dv_i      : std_logic;   -- dv into PCS TX (clk_125m)
    signal rgmii_rxctl_d    : std_logic := '0';
    signal rgmii_rxdv_d     : std_logic := '0';
    signal pcs_dv_d         : std_logic := '0';
    signal rxctl_frames     : unsigned(15 downto 0) := (others => '0');   -- rxc domain
    signal rgmii_frames     : unsigned(15 downto 0) := (others => '0');   -- rxc domain
    signal pcs_frames       : unsigned(15 downto 0) := (others => '0');   -- clk_125m
    signal dbg_rxctl_frames : std_logic_vector(15 downto 0);
    signal dbg_rgmii_frames : std_logic_vector(15 downto 0);
    signal dbg_pcs_frames   : std_logic_vector(15 downto 0);
    signal dbg_pcs_state    : std_logic_vector(3 downto 0);   -- PCS TX state/idle/frame_start

    attribute mark_debug : string;
    attribute mark_debug of rx_code         : signal is "true";
    attribute mark_debug of tx_code         : signal is "true";
    attribute mark_debug of link_up         : signal is "true";
    attribute mark_debug of link_dup        : signal is "true";
    attribute mark_debug of gt_ready        : signal is "true";
    attribute mark_debug of dbg_speed       : signal is "true";
    attribute mark_debug of dbg_rgmii_speed : signal is "true";
    attribute mark_debug of dbg_rgmii_link  : signal is "true";
    attribute mark_debug of dbg_init_done   : signal is "true";
    attribute mark_debug of dbg_gt_aligned  : signal is "true";
    attribute mark_debug of dbg_gb_aligned  : signal is "true";
    attribute mark_debug of dbg_bufstatus   : signal is "true";
    attribute mark_debug of dbg_clkcorcnt   : signal is "true";
    attribute mark_debug of dbg_refratio    : signal is "true";
    attribute mark_debug of dbg_rxerr       : signal is "true";
    attribute mark_debug of dbg_gt_word     : signal is "true";
    attribute mark_debug of dbg_txsop       : signal is "true";
    attribute mark_debug of dbg_rxsop       : signal is "true";
    attribute mark_debug of dbg_rxctl_frames : signal is "true";
    attribute mark_debug of dbg_rgmii_frames : signal is "true";
    attribute mark_debug of dbg_pcs_frames   : signal is "true";
    attribute mark_debug of dbg_pcs_state    : signal is "true";
    attribute mark_debug of pcs_tx_dv_i      : signal is "true";

begin

    -- ===== SGMII line side (GTY) + clock source ==============================
    gt_i: entity work.sgmii_gt
        port map (
            mgtrefclk_p   => mgtrefclk_p,
            mgtrefclk_n   => mgtrefclk_n,
            gt_rxp        => gt_rxp,
            gt_rxn        => gt_rxn,
            gt_txp        => gt_txp,
            gt_txn        => gt_txn,
            reset         => '0',          -- wizard self-sequences off freerun
            -- serial polarity inverts, driven live by the VIO (invert_rx powers up
            -- at 1: the RX P/N is known swapped; invert_tx at 0, still unproven)
            invert_rx     => invert_rx_i,
            invert_tx     => invert_tx_i,
            tx_diffctrl   => tx_diffctrl_i,
            tx_precursor  => tx_precursor_i,
            tx_postcursor => tx_postcursor_i,
            freerun_clk   => clk_freerun,
            usrclk        => clk_125m,
            rx_code       => rx_code,
            rx_code_valid => rx_code_valid,
            tx_code       => tx_code,
            gt_ready      => gt_ready,
            rx_byteisaligned => dbg_gt_aligned,
            gb_aligned       => dbg_gb_aligned,
            rx_bufstatus     => dbg_bufstatus,
            rx_clkcorcnt     => dbg_clkcorcnt,
            dbg_gt_word      => dbg_gt_word
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

    -- ===== RGMII RX clock: buffer rxc; PHY-ID centers the data, so capture
    -- directly (no FPGA IDELAY). =============================================
    rxc_bufg: component bufg
        port map (
            o => rxc_buf,
            i => rgmii_rxc
        );

    -- ===== SGMII <-> RGMII bridge ============================================
    bridge_i: entity work.sgmii_to_rgmii
        generic map (
            -- The Oxide switch (VSC7448) drives this link with autoneg OFF and the
            -- link forced by software (PCS1G_ANEG_CFG.sw_resolve_ena; aneg_ena=0),
            -- so the VSC8562 does not require autoneg -- match that.
            INCLUDE_AUTONEG   => false,
            LINK_TIMER_CYCLES => 1250000,   -- unused when autoneg is off
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
            rgmii_link_info => rgmii_info,
            dbg_rgmii_rx_dv => rgmii_rx_dv_i,
            dbg_pcs_tx_dv   => pcs_tx_dv_i,
            dbg_pcs_tx      => dbg_pcs_state
        );

    -- ===== DP83867 startup: hold reset, release, then run the MDIO init =======
    startup: process (clk_freerun) is
    begin
        if rising_edge(clk_freerun) then
            init_start <= '0';

            case su_state is
                when HOLD_RESET =>
                    phy_rstn_i <= '0';
                    f_reset    <= '1';
                    if su_cnt = RST_CYCLES - 1 then
                        su_cnt   <= 0;
                        su_state <= SETTLE;
                    else
                        su_cnt <= su_cnt + 1;
                    end if;

                when SETTLE =>
                    phy_rstn_i <= '1';    -- PHY out of reset
                    f_reset    <= '0';
                    if su_cnt = SETTLE_CYCLES - 1 then
                        su_cnt   <= 0;
                        su_state <= KICK;
                    else
                        su_cnt <= su_cnt + 1;
                    end if;

                when KICK =>
                    init_start <= '1';
                    su_state   <= RUNNING;

                when RUNNING =>
                    null;
            end case;
        end if;
    end process;

    phy_resetn <= phy_rstn_i;

    init_i: entity work.dp83867_init
        port map (
            clk       => clk_freerun,
            reset     => f_reset,
            start     => init_start,
            done      => init_done,
            m_start   => mi_start,
            m_op_read => mi_op,
            m_reg     => mi_reg,
            m_wr_data => mi_wd,
            m_busy    => mi_busy,
            m_done    => mi_done,
            m_rd_data => mi_rd
        );

    mdio_i: entity work.mdio_master
        port map (
            clk      => clk_freerun,
            reset    => f_reset,
            start    => mi_start,
            op_read  => mi_op,
            phy_addr => "00000",
            reg_addr => mi_reg,
            wr_data  => mi_wd,
            busy     => mi_busy,
            done     => mi_done,
            rd_data  => mi_rd,
            mdc      => phy_mdc,
            mdio_o   => mdio_o_i,
            mdio_oe  => mdio_oe_i,
            mdio_i   => mdio_in_i
        );

    -- MDIO tri-state
    phy_mdio  <= mdio_o_i when mdio_oe_i = '1' else 'Z';
    mdio_in_i <= phy_mdio;

    -- ===== ILA debug taps ====================================================
    dbg_speed       <= speed_to_slv(link_speed);
    dbg_rgmii_speed <= speed_to_slv(rgmii_info.speed);
    dbg_rgmii_link  <= rgmii_info.link;

    -- init_done is in the free-run domain; sync it for the clk_125m ILA
    dbg_sync: process (clk_125m) is
    begin
        if rising_edge(clk_125m) then
            dbg_init_done <= dbg_init_done(0) & init_done;
        end if;
    end process;

    -- ===== Refclk sanity check ===============================================
    -- rxc domain: divide the DP83867 RX clock by 256 and toggle a flag.
    rxc_meas: process (rxc_buf) is
    begin
        if rising_edge(rxc_buf) then
            rxc_div <= rxc_div + 1;
            if rxc_div = 255 then
                rxc_tick <= not rxc_tick;
            end if;
        end if;
    end process;

    -- clk_125m domain: count clk_125m cycles per 256 rxc cycles (~1280 if 125 MHz)
    ref_meas: process (clk_125m) is
    begin
        if rising_edge(clk_125m) then
            rxc_tick_m  <= rxc_tick;
            rxc_tick_s  <= rxc_tick_m;
            rxc_tick_s2 <= rxc_tick_s;
            if rxc_tick_s /= rxc_tick_s2 then
                dbg_refratio <= std_logic_vector(ref_cnt);
                ref_cnt      <= (others => '0');
            else
                ref_cnt <= ref_cnt + 1;
            end if;
        end if;
    end process;

    -- ===== RX code-group error rate ==========================================
    ones_proc: process (rx_code) is
        variable n : integer range 0 to 10;
    begin
        n := 0;
        for i in rx_code'range loop
            if rx_code(i) = '1' then
                n := n + 1;
            end if;
        end loop;
        rx_ones <= n;
    end process;

    rxerr_meas: process (clk_125m) is
    begin
        if rising_edge(clk_125m) then
            win_cnt <= win_cnt + 1;
            if win_cnt = x"FFFF" then
                dbg_rxerr <= std_logic_vector(bad_cnt);
                bad_cnt   <= (others => '0');
            elsif rx_ones < 4 or rx_ones > 6 then
                bad_cnt <= bad_cnt + 1;
            end if;
        end if;
    end process;

    -- ===== Frame activity (start-of-packet counters) =========================
    sop_meas: process (clk_125m) is
    begin
        if rising_edge(clk_125m) then
            if reset_125m = '1' then
                tx_sop_cnt <= (others => '0');
                rx_sop_cnt <= (others => '0');
            else
                if tx_code = SOP_RD_MINUS or tx_code = SOP_RD_PLUS then
                    tx_sop_cnt <= tx_sop_cnt + 1;
                end if;
                if rx_code = SOP_RD_MINUS or rx_code = SOP_RD_PLUS then
                    rx_sop_cnt <= rx_sop_cnt + 1;
                end if;
            end if;
            dbg_txsop <= std_logic_vector(tx_sop_cnt);
            dbg_rxsop <= std_logic_vector(rx_sop_cnt);
        end if;
    end process;

    -- ===== RGMII-RX frame localization counters ==============================
    -- rxc domain: raw rx_ctl pin frame-starts, and the RGMII MAC's recovered dv
    rgmii_rx_dbg: process (rxc_buf) is
    begin
        if rising_edge(rxc_buf) then
            rgmii_rxctl_d <= rgmii_rx_ctl;
            rgmii_rxdv_d  <= rgmii_rx_dv_i;
            if rgmii_rx_ctl = '1' and rgmii_rxctl_d = '0' then
                rxctl_frames <= rxctl_frames + 1;
            end if;
            if rgmii_rx_dv_i = '1' and rgmii_rxdv_d = '0' then
                rgmii_frames <= rgmii_frames + 1;
            end if;
        end if;
    end process;

    -- clk_125m domain: frame-starts arriving at the PCS TX after the rate expander
    pcs_dv_dbg: process (clk_125m) is
    begin
        if rising_edge(clk_125m) then
            pcs_dv_d <= pcs_tx_dv_i;
            if pcs_tx_dv_i = '1' and pcs_dv_d = '0' then
                pcs_frames <= pcs_frames + 1;
            end if;
            -- carry the rxc-domain counts into clk_125m for the ILA/VIO (async
            -- sample of a slow monotonic counter; transient skew is fine to read)
            dbg_rxctl_frames <= std_logic_vector(rxctl_frames);
            dbg_rgmii_frames <= std_logic_vector(rgmii_frames);
            dbg_pcs_frames   <= std_logic_vector(pcs_frames);
        end if;
    end process;

    -- ===== VIO: live polarity control + status over JTAG =====================
    -- Flip invert_rx/invert_tx from the hardware manager and watch link_up /
    -- dbg_txsop / dbg_rxsop react, no rebuild needed. invert_rx powers up at 1.
    invert_rx_i <= vio_rx_out(0);
    invert_tx_i <= vio_tx_out(0);

    vio_i: entity work.vio_polarity
        port map (
            clk        => clk_125m,
            probe_in0  => (0 => link_up),
            probe_in1  => (0 => gt_ready),
            probe_in2  => dbg_speed,
            probe_in3  => dbg_txsop,
            probe_in4  => dbg_rxsop,
            probe_in5  => dbg_rxctl_frames,
            probe_in6  => dbg_rgmii_frames,
            probe_in7  => dbg_pcs_frames,
            probe_out0 => vio_rx_out,
            probe_out1 => vio_tx_out,
            probe_out2 => tx_diffctrl_i,
            probe_out3 => tx_precursor_i,
            probe_out4 => tx_postcursor_i
        );

    -- ===== Status (active-high, on spare Port A pins) ========================
    status(0) <= link_up;
    status(1) <= gt_ready;
    status(2) <= rgmii_info.link;
    status(3) <= init_done;

end architecture;
