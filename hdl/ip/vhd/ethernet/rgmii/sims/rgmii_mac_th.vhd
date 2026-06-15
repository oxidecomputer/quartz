-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Test harness for the RGMII adapter. The RGMII transmit pins are wired straight
-- back to the receive pins (txc->rxc, tx_ctl->rx_ctl, txd->rxd), so an octet
-- driven on g2r is transmitted onto the DDR link and recovered on r2g. The
-- testbench drives g2r/speed and observes r2g via hierarchical names.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.rgmii_pkg.all;

entity rgmii_mac_th is
end entity;

architecture th of rgmii_mac_th is

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal tb_reset : std_logic := '0';   -- driven by the testbench
    signal dut_reset : std_logic;

    signal speed : eth_speed_t := SPEED_1000;  -- driven by the testbench

    signal g2r    : gmii_t := GMII_IDLE;       -- driven by the testbench
    signal r2g    : gmii_t;
    signal inband : rgmii_inband_t;

    signal s_txc    : std_logic;
    signal s_tx_ctl : std_logic;
    signal s_txd    : std_logic_vector(3 downto 0);

begin

    clk       <= not clk after 4 ns;   -- 125 MHz
    reset     <= '0' after 200 ns;
    dut_reset <= reset or tb_reset;

    dut: entity work.rgmii_mac
        port map (
            clk          => clk,
            reset        => dut_reset,
            speed        => speed,
            g2r          => g2r,
            r2g          => r2g,
            inband       => inband,
            rgmii_txc    => s_txc,
            rgmii_tx_ctl => s_tx_ctl,
            rgmii_txd    => s_txd,
            rgmii_rxc    => s_txc,        -- loopback
            rgmii_rx_ctl => s_tx_ctl,
            rgmii_rxd    => s_txd
        );

end th;
