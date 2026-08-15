-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- XEM8320 managed SGMII <-> RGMII media-converter top level: the
-- xem8320_sgmii_rgmii bring-up design with the management wrapper swapped
-- in. Board plumbing (GTY on the SMAs, SZG-ENET1G DP83867 on SYZYGY Port A,
-- MDIO RGMII-ID startup, no fabric oscillator) is identical to that
-- project; see its top for the full story. The GT polarity and TX
-- equalization values are the ones that bring-up established over the VIO
-- (invert_rx = 1: the RX P/N pair is swapped on this board).
--
-- Management additions:
--   * sgmii_to_rgmii_mgmt: IPv6-only NDP/ICMPv6/UDP endpoint at its
--     MAC-derived link-local address, tapping the RGMII RX stream with
--     responses injected toward the RGMII side;
--   * FPGA version register from the git short SHA;
--   * SPI NOR access through STARTUPE3 -- on UltraScale+ the config-flash
--     pins (CCLK, FCS_B, D00-D03) are dedicated and only reachable that
--     way, so the flash needs no pin constraints at all.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;
use work.rgmii_pkg.all;
use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;
use work.git_sha_pkg.all;

entity xem8320_eth_mgmt_top is
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

architecture rtl of xem8320_eth_mgmt_top is

    component bufg is
        port (
            o : out   std_ulogic;
            i : in    std_ulogic
        );
    end component;

    -- config-flash access primitive; Vivado binds the UNISIM cell by name
    component startupe3 is
        generic (
            prog_usr      : string := "FALSE";
            sim_cclk_freq : real := 0.0
        );
        port (
            cfgclk    : out   std_ulogic;
            cfgmclk   : out   std_ulogic;
            di        : out   std_logic_vector(3 downto 0);
            eos       : out   std_ulogic;
            preq      : out   std_ulogic;
            do        : in    std_logic_vector(3 downto 0);
            dts       : in    std_logic_vector(3 downto 0);
            fcsbo     : in    std_ulogic;
            fcsbts    : in    std_ulogic;
            gsr       : in    std_ulogic;
            gts       : in    std_ulogic;
            keyclearb : in    std_ulogic;
            pack      : in    std_ulogic;
            usrcclko  : in    std_ulogic;
            usrcclkts : in    std_ulogic;
            usrdoneo  : in    std_ulogic;
            usrdonets : in    std_ulogic
        );
    end component;

    -- ---- clocks / resets ----------------------------------------------------
    signal clk_freerun : std_logic;
    signal clk_125m    : std_logic;
    signal reset_125m  : std_logic;
    signal gt_ready    : std_logic;
    signal rxc_buf     : std_logic;

    -- ---- SGMII code groups --------------------------------------------------
    signal rx_code       : std_logic_vector(9 downto 0);
    signal rx_code_valid : std_logic;
    signal tx_code       : std_logic_vector(9 downto 0);

    -- ---- bridge status ------------------------------------------------------
    signal link_up     : std_logic;
    signal rgmii_info  : rgmii_inband_t;
    signal mgmt_status : endpoint_status_t;

    -- ---- flash --------------------------------------------------------------
    signal spi_cs_n  : std_logic;
    signal spi_sclk  : std_logic;
    signal spi_io    : std_logic_vector(3 downto 0);
    signal spi_io_o  : std_logic_vector(3 downto 0);
    signal spi_io_oe : std_logic_vector(3 downto 0);
    signal spi_dts   : std_logic_vector(3 downto 0);

    -- ---- MDIO / DP83867 startup (clk_freerun domain) ------------------------
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

    type su_state_t is (HOLD_RESET, SETTLE, KICK, RUNNING);
    signal su_state : su_state_t := HOLD_RESET;
    signal su_cnt   : integer range 0 to 2**17 - 1 := 0;

    constant RST_CYCLES    : integer := 62500;
    constant SETTLE_CYCLES : integer := 62500;

    -- forced 100M full duplex, matching the VSC switch configuration (see the
    -- xem8320_sgmii_rgmii top for the full rationale)
    constant ADV : sgmii_config_t :=
        (link => '1', ack => '0', duplex => '1', speed => SPEED_100);

    -- Fallback identity used when the flash identity sector is blank.
    --
    -- PLACEHOLDER: this address has not been allocated. Both the per-unit
    -- addresses and this default are to be assigned through the OANA
    -- process (RFD 174); until that lands, this is a locally-administered
    -- variant of Oxide's OUI (A8:40:25 with the local bit set) so it
    -- cannot collide with anything OANA hands out in the meantime.
    --
    -- Note that every unprovisioned unit shares this address, and the
    -- link-local address derives from it -- so only one blank board can be
    -- on a link at a time. That is inherent to having a single default and
    -- does not change once the address is allocated.
    constant FALLBACK_MAC : mac_addr_t := X"AA4025000001";

    -- flash map for the XEM8320's config flash (project decision; the
    -- application image and identity live above the golden bitstream)
    constant APP_BASE  : unsigned(31 downto 0) := X"00A00000";
    constant APP_SIZE  : unsigned(31 downto 0) := X"00500000";
    constant IDENT_BASE : unsigned(31 downto 0) := X"00F80000";

    -- ---- ILA debug taps (clk_125m domain); ila.tcl connects by name ---------
    -- the interface-identifier half of the link-local address is the
    -- interesting part on a probe; the fe80:: prefix is constant
    signal dbg_mgmt_iid   : std_logic_vector(31 downto 0);
    signal dbg_mgmt_valid : std_logic;
    signal dbg_mac_default : std_logic;
    signal dbg_fwd_drops  : unsigned(7 downto 0);

    attribute mark_debug : string;
    attribute mark_debug of link_up         : signal is "true";
    attribute mark_debug of gt_ready        : signal is "true";
    attribute mark_debug of init_done       : signal is "true";
    attribute mark_debug of dbg_mgmt_iid    : signal is "true";
    attribute mark_debug of dbg_mgmt_valid  : signal is "true";
    attribute mark_debug of dbg_mac_default : signal is "true";
    attribute mark_debug of dbg_fwd_drops   : signal is "true";
    attribute mark_debug of spi_cs_n        : signal is "true";
    attribute mark_debug of spi_sclk        : signal is "true";

begin

    dbg_mgmt_iid   <= mgmt_status.ip(31 downto 0);
    dbg_mgmt_valid <= mgmt_status.ip_valid;

    -- ===== SGMII line side (GTY) + clock source ==============================
    gt_i: entity work.sgmii_gt
        port map (
            mgtrefclk_p   => mgtrefclk_p,
            mgtrefclk_n   => mgtrefclk_n,
            gt_rxp        => gt_rxp,
            gt_rxn        => gt_rxn,
            gt_txp        => gt_txp,
            gt_txn        => gt_txn,
            reset         => '0',
            -- values established during bring-up (RX P/N is swapped)
            invert_rx     => '1',
            invert_tx     => '0',
            tx_diffctrl   => "11000",
            tx_precursor  => "00000",
            tx_postcursor => "00000",
            freerun_clk   => clk_freerun,
            usrclk        => clk_125m,
            rx_code       => rx_code,
            rx_code_valid => rx_code_valid,
            tx_code       => tx_code,
            gt_ready      => gt_ready,
            rx_byteisaligned => open,
            gb_aligned       => open,
            rx_bufstatus     => open,
            rx_clkcorcnt     => open,
            dbg_gt_word      => open
        );

    bridge_reset_sync: entity work.async_reset_bridge
        generic map (
            async_reset_active_level => '0'
        )
        port map (
            clk         => clk_125m,
            reset_async => gt_ready,
            reset_sync  => reset_125m
        );

    rxc_bufg: component bufg
        port map (
            o => rxc_buf,
            i => rgmii_rxc
        );

    -- ===== managed SGMII <-> RGMII bridge ====================================
    bridge_i: entity work.sgmii_to_rgmii_mgmt
        generic map (
            INCLUDE_AUTONEG   => false,
            LINK_TIMER_CYCLES => 1250000,
            TARGET            => "XILINX",
            CLIENT_UDP_PORT   => X"6F78",
            DEFAULT_MAC       => FALLBACK_MAC,
            DEFAULT_SERIAL    => (others => '0'),
            APP_IMAGE_BASE    => APP_BASE,
            APP_IMAGE_SIZE    => APP_SIZE,
            IDENTITY_BASE     => IDENT_BASE,
            SCLK_DIVISOR      => to_unsigned(4, 16)
        )
        port map (
            clk             => clk_125m,
            reset           => reset_125m,
            fpga_version    => short_sha,
            rx_code         => rx_code,
            rx_code_valid   => rx_code_valid,
            tx_code         => tx_code,
            tx_code_valid   => open,
            rgmii_txc       => rgmii_txc,
            rgmii_tx_ctl    => rgmii_tx_ctl,
            rgmii_txd       => rgmii_txd,
            rgmii_rxc       => rxc_buf,
            rgmii_rx_ctl    => rgmii_rx_ctl,
            rgmii_rxd       => rgmii_rxd,
            spi_cs_n        => spi_cs_n,
            spi_sclk        => spi_sclk,
            spi_io          => spi_io,
            spi_io_o        => spi_io_o,
            spi_io_oe       => spi_io_oe,
            an_enable       => '1',
            an_restart      => '0',
            adv_config      => ADV,
            link_up         => link_up,
            speed           => open,
            duplex          => open,
            rgmii_link_info => rgmii_info,
            mgmt_status      => mgmt_status,
            mgmt_mac         => open,
            mgmt_mac_default => dbg_mac_default,
            fwd_drops        => dbg_fwd_drops
        );

    -- ===== config flash through STARTUPE3 ====================================
    spi_dts <= not spi_io_oe;

    startupe3_i: component startupe3
        generic map (
            prog_usr      => "FALSE",
            sim_cclk_freq => 0.0
        )
        port map (
            cfgclk    => open,
            cfgmclk   => open,
            di        => spi_io,
            eos       => open,
            preq      => open,
            do        => spi_io_o,
            dts       => spi_dts,
            fcsbo     => spi_cs_n,
            fcsbts    => '0',
            gsr       => '0',
            gts       => '0',
            keyclearb => '0',
            pack      => '0',
            usrcclko  => spi_sclk,
            usrcclkts => '0',
            usrdoneo  => '1',
            usrdonets => '0'
        );

    -- ===== DP83867 startup (identical to the bring-up project) ===============
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
                    phy_rstn_i <= '1';
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

    phy_mdio  <= mdio_o_i when mdio_oe_i = '1' else 'Z';
    mdio_in_i <= phy_mdio;

    -- ===== Status (active-high, on spare Port A pins) ========================
    status(0) <= link_up;
    status(1) <= gt_ready;
    status(2) <= rgmii_info.link;
    status(3) <= mgmt_status.ip_valid;

end architecture;
