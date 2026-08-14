-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Integration harness for the SGMII<->RGMII bridge. The bridge's RGMII pins are
-- looped back externally, and a second SGMII PCS instance acts as the SGMII link
-- partner. A frame injected at the partner's r2g GMII is encoded onto the SGMII
-- line, decoded by the bridge, sent out the RGMII link, looped back, decoded
-- again and re-encoded onto the SGMII line, then recovered at the partner's g2r
-- GMII -- exercising both bridge modules and both directions.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;
use work.rgmii_pkg.all;

entity sgmii_to_rgmii_th is
    generic (
        LINK_TIMER_CYCLES : positive := 16
    );
end entity;

architecture th of sgmii_to_rgmii_th is

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal tb_reset  : std_logic := '0';
    signal dut_reset : std_logic;

    -- advertised ability for both ends (driven by the testbench to pick speed)
    signal adv : sgmii_config_t :=
        (link => '1', ack => '0', duplex => '1', speed => SPEED_1000);

    -- SGMII line between the bridge and the partner
    signal p2b, b2p     : std_logic_vector(9 downto 0);
    signal p2b_v, b2p_v : std_logic;

    -- RGMII loopback
    signal s_txc    : std_logic;
    signal s_tx_ctl : std_logic;
    signal s_txd    : std_logic_vector(3 downto 0);

    -- partner GMII (injection / capture)
    signal p_r2g       : gmii_t := GMII_IDLE;  -- driven by the testbench
    signal p_r2g_ready : std_logic;
    signal p_g2r       : gmii_t;

    signal bridge_link  : std_logic;
    signal bridge_speed : eth_speed_t;
    signal partner_link : std_logic;

begin

    clk       <= not clk after 4 ns;
    reset     <= '0' after 200 ns;
    dut_reset <= reset or tb_reset;

    -- Clause-36 conformance checks on both transmit directions (the bridge's
    -- SGMII TX is the stream a hard partner PCS judges; the partner instance is
    -- the same soft PCS, so check it too)
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

    bridge: entity work.sgmii_to_rgmii
        generic map (
            INCLUDE_AUTONEG   => true,
            LINK_TIMER_CYCLES => LINK_TIMER_CYCLES
        )
        port map (
            clk             => clk,
            reset           => dut_reset,
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
            an_enable       => '1',
            an_restart      => '0',
            adv_config      => adv,
            link_up         => bridge_link,
            speed           => bridge_speed,
            duplex          => open,
            rgmii_link_info => open
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
