-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Test harness for the SGMII PCS. The 1.25 Gbaud code-group line is looped back
-- on itself (tx_code -> rx_code), so the PCS runs auto-negotiation against its
-- own transmitter and, once the link is up, frames transmitted on r2g are
-- decoded back out on g2r. The testbench drives r2g and observes g2r via
-- hierarchical names.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;

entity sgmii_pcs_th is
    generic (
        LINK_TIMER_CYCLES : positive := 16
    );
end entity;

architecture th of sgmii_pcs_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal line       : std_logic_vector(9 downto 0);
    signal line_valid : std_logic;

    signal g2r       : gmii_t;
    signal r2g       : gmii_t := GMII_IDLE;   -- driven by the testbench
    signal r2g_ready : std_logic;

    signal link_up : std_logic;
    signal speed   : eth_speed_t;
    signal duplex  : std_logic;

    constant ADV : sgmii_config_t :=
        (link => '1', ack => '0', duplex => '1', speed => SPEED_1000);

begin

    clk   <= not clk after 4 ns;   -- 125 MHz
    reset <= '0' after 200 ns;

    -- every code group the PCS transmits is checked for Clause-36 conformance
    -- (legality/disparity, even-odd alignment, ordered-set structure, EPD rules)
    conf_mon: entity work.sgmii_conformance_mon
        generic map (
            name => "pcs_tb_mon"
        )
        port map (
            clk        => clk,
            reset      => reset,
            code       => line,
            code_valid => line_valid
        );

    dut: entity work.sgmii_pcs
        generic map (
            INCLUDE_AUTONEG   => true,
            LINK_TIMER_CYCLES => LINK_TIMER_CYCLES
        )
        port map (
            clk           => clk,
            reset         => reset,
            rx_code       => line,
            rx_code_valid => line_valid,
            tx_code       => line,
            tx_code_valid => line_valid,
            g2r           => g2r,
            r2g           => r2g,
            r2g_ready     => r2g_ready,
            an_enable     => '1',
            an_restart    => '0',
            adv_config    => ADV,
            link_up       => link_up,
            speed         => speed,
            duplex        => duplex
        );

end th;
