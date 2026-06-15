-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- RGMII adapter (module 2 of the SGMII<->RGMII bridge). Converts between the
-- 8-bit GMII stitch and the 4-bit DDR RGMII link at 10/100/1000 Mbps. The TX
-- side is in the system clock domain; the RX side is in the received rxc domain
-- (r2g is crossed to the system domain at the bridge level).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.rgmii_pkg.all;

entity rgmii_mac is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        speed : in    eth_speed_t;        -- resolved by the PCS auto-neg

        g2r : in    gmii_t;               -- from SGMII RX -> transmit on RGMII
        r2g : out   gmii_t;               -- received from RGMII -> SGMII TX (rxc domain)
        r2g_active : out   std_logic;     -- frame-in-progress for r2g (rxc domain)

        inband : out   rgmii_inband_t;    -- link-partner status from RGMII RX

        -- RGMII pins
        rgmii_txc    : out   std_logic;
        rgmii_tx_ctl : out   std_logic;
        rgmii_txd    : out   std_logic_vector(3 downto 0);
        rgmii_rxc    : in    std_logic;
        rgmii_rx_ctl : in    std_logic;
        rgmii_rxd    : in    std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of rgmii_mac is
begin

    tx_inst: entity work.rgmii_tx
        port map (
            clk          => clk,
            reset        => reset,
            speed        => speed,
            gmii         => g2r,
            rgmii_txc    => rgmii_txc,
            rgmii_tx_ctl => rgmii_tx_ctl,
            rgmii_txd    => rgmii_txd
        );

    rx_inst: entity work.rgmii_rx
        port map (
            reset        => reset,
            speed        => speed,
            rgmii_rxc    => rgmii_rxc,
            rgmii_rx_ctl => rgmii_rx_ctl,
            rgmii_rxd    => rgmii_rxd,
            gmii         => r2g,
            rx_active    => r2g_active,
            inband       => inband
        );

end architecture;
