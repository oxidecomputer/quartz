-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII <-> RGMII media-converter top. Stitches the SGMII PCS (module 1) to the
-- RGMII adapter (module 2) over the internal 8-bit GMII busses.
--
--   g2r : SGMII line -> PCS RX -> RGMII TX -> RGMII line   (all system clk)
--   r2g : RGMII line -> RGMII RX -> [rate expander] -> PCS TX -> SGMII line
--
-- The PCS auto-neg resolves the link speed, which drives the RGMII rate. The
-- RGMII RX recovers octets in the rxc domain at the line rate; the rate expander
-- crosses them into the system clock domain and presents each octet with a
-- continuous data-valid so the rate-agnostic PCS replicates it 10x/100x onto the
-- SGMII line at 100/10 Mbps (a no-op at 1000).
--
-- Note: the rxc->clk handoff assumes rxc is synchronous to clk (true when this
-- bridge sources the RGMII clock). A dual-clock FIFO belongs here when receiving
-- from an RGMII PHY with a fully independent rxc.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;
use work.rgmii_pkg.all;

entity sgmii_to_rgmii is
    generic (
        INCLUDE_AUTONEG   : boolean  := true;
        LINK_TIMER_CYCLES : positive := 1250000;
        TARGET            : string   := "SIM"   -- RGMII DDR primitive target
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- SGMII line side (already comma-aligned 10-bit code groups)
        rx_code       : in    std_logic_vector(9 downto 0);
        rx_code_valid : in    std_logic;
        tx_code       : out   std_logic_vector(9 downto 0);
        tx_code_valid : out   std_logic;

        -- RGMII line side
        rgmii_txc    : out   std_logic;
        rgmii_tx_ctl : out   std_logic;
        rgmii_txd    : out   std_logic_vector(3 downto 0);
        rgmii_rxc    : in    std_logic;
        rgmii_rx_ctl : in    std_logic;
        rgmii_rxd    : in    std_logic_vector(3 downto 0);

        -- auto-neg control / advertised ability (host-configured, PHY role)
        an_enable  : in    std_logic := '1';
        an_restart : in    std_logic := '0';
        adv_config : in    sgmii_config_t := SGMII_CONFIG_RESET;

        -- resolved status
        link_up         : out   std_logic;
        speed           : out   eth_speed_t;
        duplex          : out   std_logic;
        rgmii_link_info : out   rgmii_inband_t;   -- RGMII link-partner in-band status

        -- debug taps for bring-up observability (may be left open): recovered
        -- RGMII RX frame-valid (rxc domain) and frame-valid into the PCS TX after
        -- the rate expander (system clk). Localizes where a frame is lost.
        dbg_rgmii_rx_dv : out   std_logic;
        dbg_pcs_tx_dv   : out   std_logic;
        dbg_pcs_tx      : out   std_logic_vector(3 downto 0)   -- PCS TX state/idle/frame_start
    );
end entity;

architecture rtl of sgmii_to_rgmii is

    signal g2r        : gmii_t;          -- PCS RX -> RGMII TX
    signal r2g_rgmii  : gmii_t;          -- RGMII RX (rxc domain)
    signal r2g_pcs    : gmii_t;          -- expanded octet stream -> PCS TX
    signal r2g_ready  : std_logic;       -- PCS accept for r2g_pcs

    signal cur_speed  : eth_speed_t;
    signal inband     : rgmii_inband_t;

begin

    speed           <= cur_speed;
    rgmii_link_info <= inband;

    -- debug taps: frame-valid at the RGMII RX output and into the PCS TX
    dbg_rgmii_rx_dv <= r2g_rgmii.dv;
    dbg_pcs_tx_dv   <= r2g_pcs.dv;

    pcs_inst: entity work.sgmii_pcs
        generic map (
            INCLUDE_AUTONEG   => INCLUDE_AUTONEG,
            LINK_TIMER_CYCLES => LINK_TIMER_CYCLES
        )
        port map (
            clk           => clk,
            reset         => reset,
            rx_code       => rx_code,
            rx_code_valid => rx_code_valid,
            tx_code       => tx_code,
            tx_code_valid => tx_code_valid,
            g2r           => g2r,
            r2g           => r2g_pcs,
            r2g_ready     => r2g_ready,
            an_enable     => an_enable,
            an_restart    => an_restart,
            adv_config    => adv_config,
            link_up       => link_up,
            speed         => cur_speed,
            duplex        => duplex,
            dbg_tx        => dbg_pcs_tx
        );

    rgmii_inst: entity work.rgmii_mac
        generic map (
            TARGET => TARGET
        )
        port map (
            clk          => clk,
            reset        => reset,
            speed        => cur_speed,
            g2r          => g2r,
            r2g          => r2g_rgmii,
            r2g_active   => open,
            inband       => inband,
            rgmii_txc    => rgmii_txc,
            rgmii_tx_ctl => rgmii_tx_ctl,
            rgmii_txd    => rgmii_txd,
            rgmii_rxc    => rgmii_rxc,
            rgmii_rx_ctl => rgmii_rx_ctl,
            rgmii_rxd    => rgmii_rxd
        );

    -- Rate expander: dual-clock FIFO from the rxc domain into the system clock
    -- domain, presenting each octet for speed_cycles_per_byte accepts so the PCS
    -- replicates it onto the SGMII line.
    expander: entity work.r2g_expander
        port map (
            wr_clk     => rgmii_rxc,
            wr_reset   => reset,
            wr_data    => r2g_rgmii.data,
            wr_er      => r2g_rgmii.er,
            wr_en      => r2g_rgmii.dv,
            rd_clk     => clk,
            rd_reset   => reset,
            speed      => cur_speed,
            gmii       => r2g_pcs,
            gmii_ready => r2g_ready
        );

end architecture;
