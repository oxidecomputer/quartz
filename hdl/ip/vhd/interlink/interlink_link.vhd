-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.interlink_pkg.all;
use work.axi_st8_pkg;

-- The link layer proper: framer, deframer, lock state machine and
-- statistics, meeting the physical layer at a stream of 8b10b characters.
-- Use this directly with a transceiver that has its own 8b10b coder;
-- otherwise interlink_top adds the coding and alignment.
entity interlink_link is
    generic (
        NUM_CHANNELS : positive;
        -- 0 = none; must not name the statistics channel, see the assert
        PREEMPT_CHANNEL : natural;
        IDLE_INTERVAL_LOCKED : positive;
        IDLE_INTERVAL_FAST : positive;
        IDLES_TO_LOCK : positive;
        BAD_IDLES_TO_UNLOCK : positive;
        IDLE_TIMEOUT : positive;
        STATS_INTERVAL_IDLES : natural;
        STATS_RX_ENABLE : boolean
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        scramble_enable : in std_logic;
        link_reset : in std_logic;
        counters_clear : in std_logic;

        tx_chans : view (axi_st8_pkg.axi_st_pkt_source'converse) of axi_st8_pkg.axi_st_pkt_array_t(1 to NUM_CHANNELS);
        rx_chans : view (rx_source) of rx_st_array_t(1 to NUM_CHANNELS);

        link_status : out link_status_t;
        counters : out link_counters_t;
        partner_counters : out link_counters_t;
        partner_counters_valid : out std_logic;

        -- Character boundary to the physical layer
        tx_char : view char_source;
        rx_char : view char_source'converse;
        rx_code_err : in std_logic;
        rx_disp_err : in std_logic;
        rx_aligned : in std_logic;
        -- Polarity is detected here but corrected in the PHY. With
        -- interlink_phy_8b10b that is its 10-bit xor; with a transceiver
        -- doing its own 8b10b, wire this to its receive polarity control
        -- (RXPOLARITY on Xilinx GTs) and realign to its comma aligner.
        polarity_inverted : out std_logic;
        realign : out std_logic
    );
end entity;

architecture rtl of interlink_link is
    -- Channel 0 is the statistics channel and lives inside this block
    signal tx_all : axi_st8_pkg.axi_st_pkt_array_t(0 to NUM_CHANNELS);
    signal rx_all : rx_st_array_t(0 to NUM_CHANNELS);
    signal events : link_events_t;
    signal rx_events : link_events_t;
    signal pkt_sent : std_logic;
    signal preempted : std_logic;
    signal underrun : std_logic;
    signal idle_sent : std_logic;
    signal lock_lost : std_logic;
    signal rx_locked : std_logic;
    signal descramble_enable : std_logic;
    signal idle_good : std_logic;
    signal idle_bad : std_logic;
    signal pol_valid : std_logic;
    signal pol_inverted : std_logic;
    signal partner_flags : std_logic_vector(7 downto 0);
begin

    -- The statistics source is channel 0 and must not be the preemptor
    -- while it is sending. PREEMPT_CHANNEL = 0 means "none", so this only
    -- bites if the sentinel or STATS_CHANNEL ever move.
    assert not (STATS_INTERVAL_IDLES /= 0 and PREEMPT_CHANNEL /= 0 and PREEMPT_CHANNEL = STATS_CHANNEL)
        report "interlink_link: the statistics channel cannot be the preempting channel"
        severity failure;

    link_status.rx_aligned <= rx_aligned;
    link_status.rx_locked <= rx_locked;
    link_status.rx_polarity_inverted <= polarity_inverted;
    link_status.partner_locked <= partner_flags(IDLE_FLAG_LOCKED);
    link_status.partner_polarity_inverted <= partner_flags(IDLE_FLAG_INVERTED);
    link_status.partner_scramble_enabled <= partner_flags(IDLE_FLAG_SCRAMBLE);

    user_chan_gen: for i in 1 to NUM_CHANNELS generate
        tx_all(i).valid <= tx_chans(i).valid;
        tx_all(i).data <= tx_chans(i).data;
        tx_all(i).last <= tx_chans(i).last;
        tx_chans(i).ready <= tx_all(i).ready;

        rx_chans(i).valid <= rx_all(i).valid;
        rx_chans(i).last <= rx_all(i).last;
        rx_chans(i).error <= rx_all(i).error;
        rx_chans(i).data <= rx_all(i).data;
    end generate;

    interlink_tx_inst: entity work.interlink_tx
        generic map (
            NUM_CHANNELS => NUM_CHANNELS,
            PREEMPT_CHANNEL => PREEMPT_CHANNEL,
            IDLE_INTERVAL_LOCKED => IDLE_INTERVAL_LOCKED,
            IDLE_INTERVAL_FAST => IDLE_INTERVAL_FAST
        )
        port map (
            clk => clk,
            reset => reset,
            scramble_enable => scramble_enable,
            rx_locked => rx_locked,
            rx_polarity_inverted => polarity_inverted,
            partner_locked => partner_flags(IDLE_FLAG_LOCKED),
            tx_chans => tx_all,
            tx_char => tx_char,
            pkt_sent => pkt_sent,
            preempted => preempted,
            underrun => underrun,
            idle_sent => idle_sent
        );

    interlink_rx_inst: entity work.interlink_rx
        generic map (
            NUM_CHANNELS => NUM_CHANNELS,
            STATS_RX_ENABLE => STATS_RX_ENABLE
        )
        port map (
            clk => clk,
            reset => reset,
            rx_char => rx_char,
            rx_code_err => rx_code_err,
            rx_locked => rx_locked,
            descramble_enable => descramble_enable,
            idle_good => idle_good,
            idle_bad => idle_bad,
            pol_valid => pol_valid,
            pol_inverted => pol_inverted,
            partner_flags => partner_flags,
            rx_chans => rx_all,
            events => rx_events
        );

    interlink_sync_inst: entity work.interlink_sync
        generic map (
            IDLES_TO_LOCK => IDLES_TO_LOCK,
            BAD_IDLES_TO_UNLOCK => BAD_IDLES_TO_UNLOCK,
            IDLE_TIMEOUT => IDLE_TIMEOUT
        )
        port map (
            clk => clk,
            reset => reset,
            link_reset => link_reset,
            rx_aligned => rx_aligned,
            char_valid => rx_char.valid,
            idle_good => idle_good,
            idle_bad => idle_bad,
            pol_valid => pol_valid,
            pol_inverted => pol_inverted,
            partner_scramble => partner_flags(IDLE_FLAG_SCRAMBLE),
            rx_locked => rx_locked,
            polarity_inverted => polarity_inverted,
            descramble_enable => descramble_enable,
            lock_lost => lock_lost,
            realign => realign
        );

    -- Merge the transmit side's events into the deframer's
    events_merge: process(all)
    begin
        events <= rx_events;
        events(EV_TX_PKTS) <= pkt_sent;
        events(EV_TX_PREEMPTIONS) <= preempted;
        events(EV_TX_UNDERRUNS) <= underrun;
        events(EV_RX_UNLOCKS) <= lock_lost;
        -- A disparity error is a symptom of the same thing a code error is
        events(EV_RX_CODE_ERR) <= rx_events(EV_RX_CODE_ERR) or (rx_char.valid and rx_disp_err);
    end process;

    interlink_stats_inst: entity work.interlink_stats
        generic map (
            STATS_INTERVAL_IDLES => STATS_INTERVAL_IDLES,
            STATS_RX_ENABLE => STATS_RX_ENABLE
        )
        port map (
            clk => clk,
            reset => reset,
            clear => counters_clear,
            events => events,
            status => link_status,
            idle_sent => idle_sent,
            counters => counters,
            stats_tx => tx_all(STATS_CHANNEL),
            stats_rx => rx_all(STATS_CHANNEL),
            partner_counters => partner_counters,
            partner_counters_valid => partner_counters_valid
        );

end rtl;
