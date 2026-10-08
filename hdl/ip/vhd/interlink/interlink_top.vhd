-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.interlink_pkg.all;
use work.axi_st8_pkg;

-- One end of an RFD 693 interlink, from per-channel packet streams down to
-- 10-bit symbols. The serdes is the integrator's: ls_serdes for a slow
-- oversampled link, or whatever the FPGA offers for a faster one.
entity interlink_top is
    generic (
        -- User channels are ChannelIDs 1 to NUM_CHANNELS; 0 is statistics.
        NUM_CHANNELS : positive;
        -- The one channel allowed to interrupt another's packet, 0 for none.
        -- Channel 0 is statistics and can never be the preemptor; when stats
        -- are enabled it takes its turn in the round-robin like any other.
        PREEMPT_CHANNEL : natural := 0;
        -- IDLE cadence in byte cycles, comma to comma. The locked default is
        -- what fits two maximum packets inside the RFD's 5000 bound.
        IDLE_INTERVAL_LOCKED : positive := 4470;
        IDLE_INTERVAL_FAST : positive := 32;
        -- Lock acquisition and loss
        IDLES_TO_LOCK : positive := 4;
        BAD_IDLES_TO_UNLOCK : positive := 4;
        IDLE_TIMEOUT : positive := 12000;
        -- Statistics packet every n IDLEs sent, 0 disables sending. Goes out
        -- on channel 0, never by preemption (asserted in interlink_link).
        STATS_INTERVAL_IDLES : natural := 16;
        STATS_RX_ENABLE : boolean := true;
        -- Comma aligner. The unlock budget must comfortably exceed the
        -- locked IDLE interval or the aligner lets go between commas.
        ALIGN_PATTERNS_TO_LOCK : positive := 3;
        ALIGN_SYMBOLS_BEFORE_SLIP : positive := 64;
        ALIGN_SYMBOLS_BEFORE_UNLOCK : positive := 3 * IDLE_BOUND_CHARS
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- Sampled at each IDLE, takes effect after it.
        scramble_enable : in std_logic;
        -- Drop lock and re-acquire from scratch.
        link_reset : in std_logic;

        -- A source must hold valid from a packet's first byte through last.
        tx_chans : view (axi_st8_pkg.axi_st_pkt_source'converse) of axi_st8_pkg.axi_st_pkt_array_t(1 to NUM_CHANNELS);
        -- Push-only, cut-through: error is decided on the beat with last.
        rx_chans : view (rx_source) of rx_st_array_t(1 to NUM_CHANNELS);

        link_status : out link_status_t;
        counters : out link_counters_t;
        counters_clear : in std_logic;
        partner_counters : out link_counters_t;
        partner_counters_valid : out std_logic;

        serdes : view serdes_link_side
    );
end entity;

architecture rtl of interlink_top is
    signal tx_char : char_st_t;
    signal rx_char : char_st_t;
    signal rx_code_err : std_logic;
    signal rx_disp_err : std_logic;
    signal rx_aligned : std_logic;
    signal polarity_inverted : std_logic;
    signal realign : std_logic;
begin

    interlink_link_inst: entity work.interlink_link
        generic map (
            NUM_CHANNELS => NUM_CHANNELS,
            PREEMPT_CHANNEL => PREEMPT_CHANNEL,
            IDLE_INTERVAL_LOCKED => IDLE_INTERVAL_LOCKED,
            IDLE_INTERVAL_FAST => IDLE_INTERVAL_FAST,
            IDLES_TO_LOCK => IDLES_TO_LOCK,
            BAD_IDLES_TO_UNLOCK => BAD_IDLES_TO_UNLOCK,
            IDLE_TIMEOUT => IDLE_TIMEOUT,
            STATS_INTERVAL_IDLES => STATS_INTERVAL_IDLES,
            STATS_RX_ENABLE => STATS_RX_ENABLE
        )
        port map (
            clk => clk,
            reset => reset,
            scramble_enable => scramble_enable,
            link_reset => link_reset,
            counters_clear => counters_clear,
            tx_chans => tx_chans,
            rx_chans => rx_chans,
            link_status => link_status,
            counters => counters,
            partner_counters => partner_counters,
            partner_counters_valid => partner_counters_valid,
            tx_char => tx_char,
            rx_char => rx_char,
            rx_code_err => rx_code_err,
            rx_disp_err => rx_disp_err,
            rx_aligned => rx_aligned,
            polarity_inverted => polarity_inverted,
            realign => realign
        );

    interlink_phy_8b10b_inst: entity work.interlink_phy_8b10b
        generic map (
            ALIGN_PATTERNS_TO_LOCK => ALIGN_PATTERNS_TO_LOCK,
            ALIGN_SYMBOLS_BEFORE_SLIP => ALIGN_SYMBOLS_BEFORE_SLIP,
            ALIGN_SYMBOLS_BEFORE_UNLOCK => ALIGN_SYMBOLS_BEFORE_UNLOCK
        )
        port map (
            clk => clk,
            reset => reset,
            tx_char => tx_char,
            rx_char => rx_char,
            rx_code_err => rx_code_err,
            rx_disp_err => rx_disp_err,
            rx_aligned => rx_aligned,
            polarity_inverted => polarity_inverted,
            realign => realign,
            serdes => serdes
        );

end rtl;
