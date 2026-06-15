-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII / 1000BASE-X auto-negotiation (IEEE 802.3 Clause 37, figure 37-6). The
-- PCS exchanges /C/ config ordered sets carrying the SGMII config word, matches
-- the partner's ability over three consecutive receptions, acknowledges, then
-- drops to idle and finally to data once the link is up. The resolved speed and
-- duplex come from the received config word.
--
-- LINK_TIMER_CYCLES is the Clause-37 link timer in clk cycles (10 ms = 1.25e6 at
-- 125 MHz); testbenches shorten it so negotiation completes quickly.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;

entity sgmii_an is
    generic (
        LINK_TIMER_CYCLES : positive := 1250000
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        an_enable  : in    std_logic;
        an_restart : in    std_logic;

        -- ability we advertise (PHY role: link/speed/duplex we report upstream)
        adv_config : in    sgmii_config_t;

        -- received config ordered set from the RX path
        rx_config_word  : in    std_logic_vector(15 downto 0);
        rx_config_valid : in    std_logic;

        -- control to the TX path
        xmit           : out   pcs_xmit_t;
        tx_config_word : out   std_logic_vector(15 downto 0);

        -- resolved status
        link_up : out   std_logic;
        speed   : out   eth_speed_t;
        duplex  : out   std_logic
    );
end entity;

architecture rtl of sgmii_an is

    -- ability field comparison ignores the acknowledge bit (14)
    function ability_bits (w : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable v : std_logic_vector(15 downto 0) := w;
    begin
        v(14) := '0';
        return v;
    end function;

    constant TIMER_MAX : natural := LINK_TIMER_CYCLES - 1;

    signal state      : an_state_t;
    signal link_timer : natural range 0 to TIMER_MAX;
    signal timer_done : std_logic;

    signal rx_prev   : std_logic_vector(15 downto 0);
    signal match_cnt : unsigned(1 downto 0);   -- consecutive ability matches (saturating)
    signal rx_resolved : sgmii_config_t;

    signal ability_match     : std_logic;
    signal acknowledge_match : std_logic;

    signal ack_tx : std_logic;   -- acknowledge bit we drive into tx config

begin

    timer_done <= '1' when link_timer = 0 else '0';

    -- three consecutive ability-matching receptions
    ability_match     <= '1' when match_cnt = 3 else '0';
    acknowledge_match <= '1' when match_cnt = 3 and rx_prev(14) = '1' else '0';

    tx_config_word <= to_config_word((link   => adv_config.link,
                                      ack    => ack_tx,
                                      duplex => adv_config.duplex,
                                      speed  => adv_config.speed));

    fsm: process (clk, reset) is
    begin
        if reset = '1' then
            state       <= AN_ST_ENABLE;
            link_timer  <= TIMER_MAX;
            rx_prev     <= (others => '0');
            match_cnt   <= (others => '0');
            rx_resolved <= SGMII_CONFIG_RESET;
            ack_tx      <= '0';
            xmit        <= XMIT_CONFIG;
            link_up     <= '0';
            speed       <= SPEED_1000;
            duplex      <= '1';
        elsif rising_edge(clk) then
            -- run the link timer down to zero and hold
            if link_timer /= 0 then
                link_timer <= link_timer - 1;
            end if;

            -- track consecutive ability matches as config words arrive
            if rx_config_valid = '1' then
                if ability_bits(rx_config_word) = ability_bits(rx_prev)
                   and rx_config_word(0) = '1' then
                    if match_cnt /= 3 then
                        match_cnt <= match_cnt + 1;
                    end if;
                else
                    match_cnt <= to_unsigned(1, match_cnt'length);
                end if;
                rx_prev     <= rx_config_word;
                rx_resolved <= from_config_word(rx_config_word);
            end if;

            if an_restart = '1' or an_enable = '0' then
                state      <= AN_ST_ENABLE;
                link_up    <= '0';
                match_cnt  <= (others => '0');
                ack_tx     <= '0';
                link_timer <= TIMER_MAX;
            else
                case state is
                    when AN_ST_ENABLE =>
                        xmit       <= XMIT_CONFIG;
                        ack_tx     <= '0';
                        match_cnt  <= (others => '0');
                        link_timer <= TIMER_MAX;
                        state      <= AN_ST_RESTART;

                    when AN_ST_RESTART =>
                        xmit <= XMIT_CONFIG;
                        if timer_done = '1' then
                            state <= AN_ST_ABILITY;
                        end if;

                    when AN_ST_ABILITY =>
                        -- advertise ability with ack clear, wait for partner ability
                        ack_tx <= '0';
                        if ability_match = '1' then
                            state <= AN_ST_ACK;
                        end if;

                    when AN_ST_ACK =>
                        -- echo acknowledge, wait for acknowledged ability
                        ack_tx <= '1';
                        if acknowledge_match = '1' then
                            link_timer <= TIMER_MAX;
                            state      <= AN_ST_COMPLETE;
                        end if;

                    when AN_ST_COMPLETE =>
                        if timer_done = '1' then
                            link_timer <= TIMER_MAX;
                            state      <= AN_ST_IDLE;
                        end if;

                    when AN_ST_IDLE =>
                        xmit <= XMIT_IDLE;
                        if timer_done = '1' then
                            state <= AN_ST_LINK_OK;
                        end if;

                    when AN_ST_LINK_OK =>
                        xmit    <= XMIT_DATA;
                        link_up <= '1';
                        speed   <= rx_resolved.speed;
                        duplex  <= rx_resolved.duplex;
                end case;
            end if;
        end if;
    end process;

end architecture;
