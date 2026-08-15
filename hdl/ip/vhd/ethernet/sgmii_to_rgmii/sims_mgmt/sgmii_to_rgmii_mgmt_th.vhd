-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Integration harness for the management bridge: same shape as
-- sgmii_to_rgmii_th (partner PCS on the SGMII line, RGMII pins looped back,
-- Clause-36 monitors on both TX directions) with the management wrapper as
-- the DUT and a behavioral SPI flash on its QSPI port. With the RGMII
-- loopback, frames injected at the partner reach the DUT's RGMII RX -- the
-- management tap -- and management responses injected toward RGMII loop
-- straight back and arrive at the partner, so the whole management round
-- trip runs over the real wire path.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;
use work.rgmii_pkg.all;
use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;

entity sgmii_to_rgmii_mgmt_th is
    generic (
        LINK_TIMER_CYCLES : positive := 16
    );
end entity;

architecture th of sgmii_to_rgmii_mgmt_th is

    constant TH_MAC : mac_addr_t := X"020A0B0C0D0E";

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal tb_reset  : std_logic := '0';
    signal dut_reset : std_logic;

    signal adv : sgmii_config_t :=
        (link => '1', ack => '0', duplex => '1', speed => SPEED_100);

    signal p2b, b2p     : std_logic_vector(9 downto 0);
    signal p2b_v, b2p_v : std_logic;

    signal s_txc    : std_logic;
    signal s_tx_ctl : std_logic;
    signal s_txd    : std_logic_vector(3 downto 0);

    signal p_r2g       : gmii_t := GMII_IDLE;
    signal p_r2g_ready : std_logic;
    signal p_g2r       : gmii_t;

    signal bridge_link  : std_logic;
    signal bridge_speed : eth_speed_t;
    signal partner_link : std_logic;

    signal mgmt_status : endpoint_status_t;
    signal mgmt_mac    : mac_addr_t;
    signal fwd_drops   : unsigned(7 downto 0);

    signal spi_cs_n  : std_logic;
    signal spi_sclk  : std_logic;
    signal spi_io    : std_logic_vector(3 downto 0);
    signal spi_io_o  : std_logic_vector(3 downto 0);
    signal spi_io_oe : std_logic_vector(3 downto 0);
    signal miso      : std_logic := '0';

begin

    clk       <= not clk after 4 ns;
    reset     <= '0' after 200 ns;
    dut_reset <= reset or tb_reset;

    bridge_tx_mon: entity work.sgmii_conformance_mon
        generic map (
            name => "bridge_tx_mon"
        )
        port map (
            clk        => clk,
            reset      => dut_reset,
            code       => b2p,
            code_valid => b2p_v
        );

    partner_tx_mon: entity work.sgmii_conformance_mon
        generic map (
            name => "partner_tx_mon"
        )
        port map (
            clk        => clk,
            reset      => dut_reset,
            code       => p2b,
            code_valid => p2b_v
        );

    bridge: entity work.sgmii_to_rgmii_mgmt
        generic map (
            INCLUDE_AUTONEG   => true,
            LINK_TIMER_CYCLES => LINK_TIMER_CYCLES,
            TARGET            => "SIM",
            CLIENT_UDP_PORT   => X"6F78",
            DEFAULT_MAC       => TH_MAC,
            DEFAULT_SERIAL    => (others => '0'),
            APP_IMAGE_BASE    => X"00002000",
            APP_IMAGE_SIZE    => X"00002000",
            IDENTITY_BASE     => X"00000000",
            SCLK_DIVISOR      => to_unsigned(2, 16)
        )
        port map (
            clk             => clk,
            reset           => dut_reset,
            fpga_version    => X"DEADBEEF",
            rx_code         => p2b,
            rx_code_valid   => p2b_v,
            tx_code         => b2p,
            tx_code_valid   => b2p_v,
            rgmii_txc       => s_txc,
            rgmii_tx_ctl    => s_tx_ctl,
            rgmii_txd       => s_txd,
            rgmii_rxc       => s_txc,      -- loopback
            rgmii_rx_ctl    => s_tx_ctl,
            rgmii_rxd       => s_txd,
            spi_cs_n        => spi_cs_n,
            spi_sclk        => spi_sclk,
            spi_io          => spi_io,
            spi_io_o        => spi_io_o,
            spi_io_oe       => spi_io_oe,
            an_enable       => '1',
            an_restart      => '0',
            adv_config      => adv,
            link_up         => bridge_link,
            speed           => bridge_speed,
            duplex          => open,
            rgmii_link_info => open,
            mgmt_status      => mgmt_status,
            mgmt_mac         => mgmt_mac,
            mgmt_mac_default => open,
            fwd_drops        => fwd_drops
        );

    spi_io <= "00" & miso & spi_io_o(0);

    flash_model: entity work.sim_spi_flash
        generic map (
            MEM_BYTES => 16384,
            BUSY_TIME => 2 us
        )
        port map (
            cs_n => spi_cs_n,
            sclk => spi_sclk,
            mosi => spi_io_o(0),
            miso => miso
        );

    partner: entity work.sgmii_pcs
        generic map (
            INCLUDE_AUTONEG   => true,
            LINK_TIMER_CYCLES => LINK_TIMER_CYCLES
        )
        port map (
            clk           => clk,
            reset         => dut_reset,
            rx_code       => b2p,
            rx_code_valid => b2p_v,
            tx_code       => p2b,
            tx_code_valid => p2b_v,
            g2r           => p_g2r,
            r2g           => p_r2g,
            r2g_ready     => p_r2g_ready,
            an_enable     => '1',
            an_restart    => '0',
            adv_config    => adv,
            link_up       => partner_link,
            speed         => open,
            duplex        => open
        );

end th;
