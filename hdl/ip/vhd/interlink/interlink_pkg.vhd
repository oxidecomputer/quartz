-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.helper_8b10b_pkg.all;

-- Shared definitions for the RFD 693 FPGA interlink: the control characters
-- and field layouts the protocol fixes, the interface records the blocks talk
-- over, and the counter set we keep for link monitoring.
package interlink_pkg is

    -- Packet framing. An EOP closes the most recently opened packet, so with
    -- one level of preemption the receiver only ever has two packets open.
    constant SOP_CHAR : std_logic_vector(7 downto 0) := K28_0;
    constant EOP_CHAR : std_logic_vector(7 downto 0) := K23_7;
    constant PREEMPT_CHAR : std_logic_vector(7 downto 0) := K27_7;
    -- IDLE sequence. The comma is polarity symmetric so it decodes either way
    -- and is what the aligner hunts for. The skip is what an elastic buffer
    -- may drop or repeat, which is why the IDLE CRC does not cover it.
    constant COMMA_CHAR : std_logic_vector(7 downto 0) := K28_5;
    constant SKIP_CHAR : std_logic_vector(7 downto 0) := K29_7;

    -- Polarity detection. D10.2 and D19.5 are not polarity symmetric: on an
    -- inverted link they decode as D12.2 and D21.5, so the character after
    -- the comma tells the receiver which way the wires are.
    constant POL_CHAR_A : std_logic_vector(7 downto 0) := 8x"4A";     -- D10.2
    constant POL_CHAR_B : std_logic_vector(7 downto 0) := 8x"B3";     -- D19.5
    constant POL_CHAR_A_INV : std_logic_vector(7 downto 0) := 8x"4C"; -- D12.2
    constant POL_CHAR_B_INV : std_logic_vector(7 downto 0) := 8x"B5"; -- D21.5

    -- IDLE flags byte
    constant IDLE_FLAG_SCRAMBLE : natural := 0;
    constant IDLE_FLAG_LOCKED : natural := 1;
    constant IDLE_FLAG_INVERTED : natural := 2;

    constant STATS_CHANNEL : natural := 0;
    constant MAX_PAYLOAD_BYTES : natural := 255;
    -- SOP + ChannelID + Seq + CRC8 + payload + CRC16 + EOP
    constant MAX_PKT_CHARS : natural := MAX_PAYLOAD_BYTES + 7;
    constant IDLE_CHARS : natural := 6;
    -- The receiver's elastic buffer budget assumes a skip at least this often.
    constant IDLE_BOUND_CHARS : natural := 5000;

    -- Character stream between the link layer and the PHY. One 8b10b symbol
    -- per transfer, control characters flagged by ctrl.
    type char_st_t is record
        valid : std_logic;
        ready : std_logic;
        ctrl : std_logic;
        data : std_logic_vector(7 downto 0);
    end record;
    view char_source of char_st_t is
        valid, ctrl, data : out;
        ready : in;
    end view;

    -- Received packet stream to the user, one per channel. Cut-through and
    -- push-only: there is no ready because the wire cannot be stalled, and
    -- error is only meaningful on the beat that carries last.
    type rx_st_t is record
        valid : std_logic;
        last : std_logic;
        error : std_logic;
        data : std_logic_vector(7 downto 0);
    end record;
    view rx_source of rx_st_t is
        valid, last, error, data : out;
    end view;
    type rx_st_array_t is array (natural range <>) of rx_st_t;

    -- The serdes boundary: 10-bit symbols both ways plus the bit-slip request
    -- from the comma aligner. rx_ready is advisory, the link always takes a
    -- symbol the cycle it is offered.
    type serdes_if_t is record
        tx_data : std_logic_vector(9 downto 0);
        tx_valid : std_logic;
        tx_ready : std_logic;
        rx_data : std_logic_vector(9 downto 0);
        rx_valid : std_logic;
        rx_ready : std_logic;
        bit_slip : std_logic;
    end record;
    view serdes_link_side of serdes_if_t is
        tx_data, tx_valid, rx_ready, bit_slip : out;
        tx_ready, rx_data, rx_valid : in;
    end view;

    type link_status_t is record
        rx_aligned : std_logic;
        rx_locked : std_logic;
        rx_polarity_inverted : std_logic;
        partner_locked : std_logic;
        partner_polarity_inverted : std_logic;
        partner_scramble_enabled : std_logic;
    end record;

    -- Monitoring counters. These are saturating and free-running; whoever
    -- reads them diffs successive samples. The record order is the order
    -- they go out in the statistics packet.
    subtype counter_t is unsigned(15 downto 0);
    type link_counters_t is record
        rx_pkts : counter_t;          -- header and payload both checked good
        rx_crc16_err : counter_t;
        rx_aborted : counter_t;       -- payload CRC carried the abort residue
        rx_crc8_err : counter_t;
        rx_framing_err : counter_t;   -- stray EOP, SOP mid-packet, runt, oversize, bad channel, unknown K
        rx_seq_err : counter_t;
        rx_idle_bad : counter_t;
        rx_code_err : counter_t;      -- 8b10b code or disparity errors
        rx_unlocks : counter_t;
        tx_pkts : counter_t;
        tx_preemptions : counter_t;
        tx_underruns : counter_t;
        rx_preemptions : counter_t;
    end record;
    constant NUM_COUNTERS : natural := 13;
    type counter_array_t is array (0 to NUM_COUNTERS - 1) of counter_t;
    -- One pulse per counter, same order.
    subtype link_events_t is std_logic_vector(0 to NUM_COUNTERS - 1);
    constant EV_RX_PKTS : natural := 0;
    constant EV_RX_CRC16_ERR : natural := 1;
    constant EV_RX_ABORTED : natural := 2;
    constant EV_RX_CRC8_ERR : natural := 3;
    constant EV_RX_FRAMING_ERR : natural := 4;
    constant EV_RX_SEQ_ERR : natural := 5;
    constant EV_RX_IDLE_BAD : natural := 6;
    constant EV_RX_CODE_ERR : natural := 7;
    constant EV_RX_UNLOCKS : natural := 8;
    constant EV_TX_PKTS : natural := 9;
    constant EV_TX_PREEMPTIONS : natural := 10;
    constant EV_TX_UNDERRUNS : natural := 11;
    constant EV_RX_PREEMPTIONS : natural := 12;

    function to_array (counters : link_counters_t) return counter_array_t;
    function to_counters (arr : counter_array_t) return link_counters_t;
    function saturating_inc (count : counter_t; inc : std_logic) return counter_t;

    -- Statistics packet on channel 0 (provisional): a format byte, a status
    -- flags byte, then the counters big-endian in record order.
    constant STATS_FORMAT : std_logic_vector(7 downto 0) := X"01";
    constant STATS_PKT_BYTES : natural := 2 + 2 * NUM_COUNTERS;
    constant STATS_FLAG_LOCKED : natural := 0;
    constant STATS_FLAG_INVERTED : natural := 1;
    constant STATS_FLAG_SCRAMBLE : natural := 2;
    constant STATS_FLAG_ALIGNED : natural := 3;

    function stats_byte (
        counters : counter_array_t;
        flags : std_logic_vector(7 downto 0);
        idx : natural range 0 to STATS_PKT_BYTES - 1
    ) return std_logic_vector;

end package;

package body interlink_pkg is

    function to_array (counters : link_counters_t) return counter_array_t is
    begin
        return (
            EV_RX_PKTS => counters.rx_pkts,
            EV_RX_CRC16_ERR => counters.rx_crc16_err,
            EV_RX_ABORTED => counters.rx_aborted,
            EV_RX_CRC8_ERR => counters.rx_crc8_err,
            EV_RX_FRAMING_ERR => counters.rx_framing_err,
            EV_RX_SEQ_ERR => counters.rx_seq_err,
            EV_RX_IDLE_BAD => counters.rx_idle_bad,
            EV_RX_CODE_ERR => counters.rx_code_err,
            EV_RX_UNLOCKS => counters.rx_unlocks,
            EV_TX_PKTS => counters.tx_pkts,
            EV_TX_PREEMPTIONS => counters.tx_preemptions,
            EV_TX_UNDERRUNS => counters.tx_underruns,
            EV_RX_PREEMPTIONS => counters.rx_preemptions
        );
    end function;

    function to_counters (arr : counter_array_t) return link_counters_t is
    begin
        return (
            rx_pkts => arr(EV_RX_PKTS),
            rx_crc16_err => arr(EV_RX_CRC16_ERR),
            rx_aborted => arr(EV_RX_ABORTED),
            rx_crc8_err => arr(EV_RX_CRC8_ERR),
            rx_framing_err => arr(EV_RX_FRAMING_ERR),
            rx_seq_err => arr(EV_RX_SEQ_ERR),
            rx_idle_bad => arr(EV_RX_IDLE_BAD),
            rx_code_err => arr(EV_RX_CODE_ERR),
            rx_unlocks => arr(EV_RX_UNLOCKS),
            tx_pkts => arr(EV_TX_PKTS),
            tx_preemptions => arr(EV_TX_PREEMPTIONS),
            tx_underruns => arr(EV_TX_UNDERRUNS),
            rx_preemptions => arr(EV_RX_PREEMPTIONS)
        );
    end function;

    function saturating_inc (count : counter_t; inc : std_logic) return counter_t is
    begin
        if inc = '1' and count /= (count'range => '1') then
            return count + 1;
        else
            return count;
        end if;
    end function;

    function stats_byte (
        counters : counter_array_t;
        flags : std_logic_vector(7 downto 0);
        idx : natural range 0 to STATS_PKT_BYTES - 1
    ) return std_logic_vector is
        variable count : counter_t;
    begin
        if idx = 0 then
            return STATS_FORMAT;
        elsif idx = 1 then
            return flags;
        else
            count := counters((idx - 2) / 2);
            if (idx mod 2) = 0 then
                return std_logic_vector(count(15 downto 8));
            else
                return std_logic_vector(count(7 downto 0));
            end if;
        end if;
    end function;

end package body;
