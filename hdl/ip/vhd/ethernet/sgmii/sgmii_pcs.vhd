-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII PCS (module 1 of the SGMII<->RGMII bridge). Operates on already comma-
-- aligned 10-bit code groups at 125 MHz: decodes the receive stream to a GMII
-- octet stream (g2r) and encodes the transmit GMII octet stream (r2g) back to
-- code groups, with Clause-37 auto-negotiation resolving speed/duplex/link.
--
-- g2r : GMII recovered from the SGMII line, handed to the RGMII transmitter.
-- r2g : GMII received from the RGMII line, encoded onto the SGMII line. The
--       producer must hold r2g stable until r2g_rd pulses (see sgmii_pcs_tx).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;

entity sgmii_pcs is
    generic (
        -- include the auto-neg FSM; when false the link is forced up at adv_config
        INCLUDE_AUTONEG   : boolean  := true;
        LINK_TIMER_CYCLES : positive := 1250000
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- SGMII line side (aligned code groups)
        rx_code       : in    std_logic_vector(9 downto 0);
        rx_code_valid : in    std_logic;
        tx_code       : out   std_logic_vector(9 downto 0);
        tx_code_valid : out   std_logic;

        -- GMII stitch
        g2r       : out   gmii_t;           -- decoded receive -> RGMII TX
        r2g       : in    gmii_t;           -- RGMII RX -> encode/transmit
        r2g_ready : out   std_logic;        -- combinational accept for the r2g producer

        -- auto-neg control / advertised ability (PHY role)
        an_enable  : in    std_logic := '1';
        an_restart : in    std_logic := '0';
        adv_config : in    sgmii_config_t := SGMII_CONFIG_RESET;

        -- resolved status
        link_up : out   std_logic;
        speed   : out   eth_speed_t;
        duplex  : out   std_logic
    );
end entity;

architecture rtl of sgmii_pcs is

    signal xmit           : pcs_xmit_t;
    signal tx_config_word : std_logic_vector(15 downto 0);
    signal rx_config_word : std_logic_vector(15 downto 0);
    signal rx_config_valid : std_logic;
    signal cur_speed      : eth_speed_t;

begin

    speed <= cur_speed;

    rx_inst: entity work.sgmii_pcs_rx
        port map (
            clk             => clk,
            reset           => reset,
            rx_code         => rx_code,
            rx_code_valid   => rx_code_valid,
            gmii            => g2r,
            rx_config_word  => rx_config_word,
            rx_config_valid => rx_config_valid
        );

    tx_inst: entity work.sgmii_pcs_tx
        port map (
            clk            => clk,
            reset          => reset,
            xmit           => xmit,
            tx_config_word => tx_config_word,
            gmii           => r2g,
            gmii_ready     => r2g_ready,
            tx_code        => tx_code,
            tx_code_valid  => tx_code_valid
        );

    an_gen: if INCLUDE_AUTONEG generate
        an_inst: entity work.sgmii_an
            generic map (
                LINK_TIMER_CYCLES => LINK_TIMER_CYCLES
            )
            port map (
                clk             => clk,
                reset           => reset,
                an_enable       => an_enable,
                an_restart      => an_restart,
                adv_config      => adv_config,
                rx_config_word  => rx_config_word,
                rx_config_valid => rx_config_valid,
                xmit            => xmit,
                tx_config_word  => tx_config_word,
                link_up         => link_up,
                speed           => cur_speed,
                duplex          => duplex
            );
    else generate
        -- auto-neg bypassed: force the link up at the advertised ability
        xmit           <= XMIT_DATA;
        tx_config_word <= (others => '0');
        link_up        <= '1';
        cur_speed      <= adv_config.speed;
        duplex         <= adv_config.duplex;
    end generate;

end architecture;
