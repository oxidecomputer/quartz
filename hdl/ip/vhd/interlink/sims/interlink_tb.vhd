-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;
use work.interlink_pkg.all;
use work.interlink_sim_pkg.all;

-- Link layer tests over the direct 10-bit connection. Everything here runs
-- at one character per clock, which is also the most demanding case for the
-- receiver's handshakes.
entity interlink_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of interlink_tb is
begin

    th: entity work.interlink_th;

    bench: process
        alias clk is << signal th.clk : std_logic >>;
        alias reset is << signal th.reset : std_logic >>;
        alias a_status is << signal th.a_status : link_status_t >>;
        alias b_status is << signal th.b_status : link_status_t >>;
        alias a_counters is << signal th.a_counters : link_counters_t >>;
        alias b_counters is << signal th.b_counters : link_counters_t >>;
        alias a_partner is << signal th.a_partner : link_counters_t >>;
        alias b_partner is << signal th.b_partner : link_counters_t >>;
        alias a_partner_valid is << signal th.a_partner_valid : std_logic >>;
        alias b_partner_valid is << signal th.b_partner_valid : std_logic >>;
        alias a_scramble is << signal th.a_scramble : std_logic >>;
        alias b_scramble is << signal th.b_scramble : std_logic >>;
        alias b_link_reset is << signal th.b_link_reset : std_logic >>;
        alias counters_clear is << signal th.counters_clear : std_logic >>;
        alias ab_max_gap is << signal th.wire_ab.max_comma_gap : natural >>;
        alias ab_monitor_errors is << signal th.wire_ab.monitor_errors : natural >>;
        alias ba_monitor_errors is << signal th.wire_ba.monitor_errors : natural >>;

        constant wire_ab : actor_t := find("wire_ab");
        constant wire_ba : actor_t := find("wire_ba");

        variable payload : queue_t;
        variable payload2 : queue_t;
        variable payload3 : queue_t;
        variable chars : queue_t;
        variable got : queue_t;
        variable err : boolean;
        variable chan : integer;
        variable snapshot : link_counters_t;
        variable n : natural;

        procedure wait_for_lock is
        begin
            wait until a_status.rx_locked = '1' and b_status.rx_locked = '1' for 2 ms;
            check_equal(a_status.rx_locked, '1', "A did not lock");
            check_equal(b_status.rx_locked, '1', "B did not lock");
            -- Let both ends hear the other's lock flag so the IDLE cadence
            -- settles, then start every test from clean counters.
            wait until a_status.partner_locked = '1' and b_status.partner_locked = '1' for 1 ms;
            wait until rising_edge(clk);
            counters_clear <= force '1';
            wait until rising_edge(clk);
            counters_clear <= force '0';
            wait until rising_edge(clk);
        end procedure;

        -- Settle time for a packet to cross the wire and come out of the sink
        procedure settle (chars : natural := 600) is
        begin
            wait for chars * 20 ns;
        end procedure;

        procedure check_no_errors (counters : link_counters_t; who : string) is
        begin
            check_equal(counters.rx_crc16_err, 0, who & " rx_crc16_err");
            check_equal(counters.rx_crc8_err, 0, who & " rx_crc8_err");
            check_equal(counters.rx_framing_err, 0, who & " rx_framing_err");
            check_equal(counters.rx_seq_err, 0, who & " rx_seq_err");
            check_equal(counters.rx_idle_bad, 0, who & " rx_idle_bad");
            check_equal(counters.rx_code_err, 0, who & " rx_code_err");
            check_equal(counters.rx_aborted, 0, who & " rx_aborted");
            check_equal(counters.tx_underruns, 0, who & " tx_underruns");
        end procedure;
    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 100 ns;

        while test_suite loop
            if run("link_lock") then
                wait_for_lock;
                check_equal(a_status.rx_polarity_inverted, '0', "A polarity");
                check_equal(b_status.rx_polarity_inverted, '0', "B polarity");
                check_equal(a_status.partner_scramble_enabled, '1', "A sees partner scrambling");
                check_equal(b_status.partner_scramble_enabled, '1', "B sees partner scrambling");
                -- Run through a couple of locked-rate IDLE intervals
                wait for 10000 * 20 ns;
                check_no_errors(a_counters, "A");
                check_no_errors(b_counters, "B");
                check_equal(a_status.rx_locked, '1', "A stayed locked");
                check_equal(b_status.rx_locked, '1', "B stayed locked");

            elsif run("single_packet_each_direction") then
                wait_for_lock;
                payload := make_payload(16, 1);
                payload2 := make_payload(16, 100);
                send_packet(net, a_sources(2), payload);
                send_packet(net, b_sources(3), payload2);
                check_packet(net, b_sinks(2), payload, msg => "A to B");
                check_packet(net, a_sinks(3), payload2, msg => "B to A");
                settle;
                check_no_errors(a_counters, "A");
                check_no_errors(b_counters, "B");
                check(a_counters.tx_pkts >= 1, "A tx_pkts");
                check(b_counters.rx_pkts >= 1, "B rx_pkts");

            elsif run("payload_lengths") then
                -- The delay line edges: 1, 2, 3 and 4 bytes, and the maximum
                wait_for_lock;
                for len in 1 to 5 loop
                    payload := make_payload(len, len);
                    send_packet(net, a_sources(2), payload);
                    check_packet(net, b_sinks(2), payload, msg => "length " & to_string(len));
                end loop;
                payload := make_payload(MAX_PAYLOAD_BYTES, 7);
                send_packet(net, a_sources(2), payload);
                check_packet(net, b_sinks(2), payload, msg => "max length");
                settle;
                check_no_errors(b_counters, "B");

            elsif run("round_robin_fairness") then
                wait_for_lock;
                -- Three channels with three packets each queued at once. The
                -- wire should see them rotate rather than one channel drain.
                for i in 1 to 3 loop
                    send_packet(net, a_sources(2), make_payload(20, i));
                    send_packet(net, a_sources(3), make_payload(20, 10 + i));
                    send_packet(net, a_sources(4), make_payload(20, 20 + i));
                end loop;
                for i in 1 to 3 loop
                    check_packet(net, b_sinks(2), make_payload(20, i), msg => "chan 2 pkt " & to_string(i));
                    check_packet(net, b_sinks(3), make_payload(20, 10 + i), msg => "chan 3 pkt " & to_string(i));
                    check_packet(net, b_sinks(4), make_payload(20, 20 + i), msg => "chan 4 pkt " & to_string(i));
                end loop;
                -- Order on the wire, skipping statistics packets
                n := 0;
                for i in 1 to 9 loop
                    loop
                        wire_pop_chan(net, wire_ab, chan);
                        exit when chan /= STATS_CHANNEL;
                    end loop;
                    check_equal(chan, 2 + ((i - 1) mod 3), "wire order, packet " & to_string(i));
                end loop;
                settle;
                check_no_errors(b_counters, "B");

            elsif run("preemption_basic") then
                wait_for_lock;
                payload := make_payload(200, 3);
                payload2 := make_payload(10, 50);
                send_packet(net, a_sources(2), payload);
                -- Let the long packet get well into its payload first
                wait for 40 * 20 ns;
                send_packet(net, a_sources(1), payload2);
                check_packet(net, b_sinks(1), payload2, msg => "preempting packet");
                check_packet(net, b_sinks(2), payload, msg => "interrupted packet");
                settle;
                check_equal(a_counters.tx_preemptions, 1, "A tx_preemptions");
                check_equal(b_counters.rx_preemptions, 1, "B rx_preemptions");
                check_no_errors(b_counters, "B");
                -- The wire saw channel 2 open first, then channel 1 inside it
                loop
                    wire_pop_chan(net, wire_ab, chan);
                    exit when chan /= STATS_CHANNEL;
                end loop;
                check_equal(chan, 2, "outer packet first");
                loop
                    wire_pop_chan(net, wire_ab, chan);
                    exit when chan /= STATS_CHANNEL;
                end loop;
                check_equal(chan, 1, "preemptor second");

            elsif run("preempt_at_every_offset") then
                -- Slide the preemptor across the whole of a short packet so it
                -- lands on the header, the first payload byte, the CRC and
                -- the EOP, and make sure both packets always come out whole.
                wait_for_lock;
                for d in 0 to 32 loop
                    payload := make_payload(20, d);
                    payload2 := make_payload(3, 100 + d);
                    send_packet(net, a_sources(2), payload);
                    wait for d * 20 ns;
                    send_packet(net, a_sources(1), payload2);
                    check_packet(net, b_sinks(1), payload2, msg => "preemptor, delay " & to_string(d));
                    check_packet(net, b_sinks(2), payload, msg => "outer, delay " & to_string(d));
                end loop;
                settle;
                check_no_errors(b_counters, "B");

            elsif run("preemptor_saturation") then
                -- The preemptor has strict priority at a packet boundary, so
                -- a saturated one is served first (a known limitation); what
                -- must hold is that an interrupted packet is only interrupted
                -- once and the IDLE cadence survives.
                wait_for_lock;
                for i in 1 to 20 loop
                    send_packet(net, a_sources(1), make_payload(30, i));
                end loop;
                for i in 1 to 3 loop
                    send_packet(net, a_sources(2), make_payload(MAX_PAYLOAD_BYTES, 40 + i));
                end loop;
                for i in 1 to 20 loop
                    check_packet(net, b_sinks(1), make_payload(30, i), msg => "preemptor pkt " & to_string(i));
                end loop;
                for i in 1 to 3 loop
                    check_packet(net, b_sinks(2), make_payload(MAX_PAYLOAD_BYTES, 40 + i), msg => "outer pkt " & to_string(i));
                end loop;
                settle;
                check(a_counters.tx_preemptions <= 3, "at most one preemption per outer packet");
                check(ab_max_gap <= IDLE_BOUND_CHARS, "comma gap " & to_string(ab_max_gap));
                check_no_errors(b_counters, "B");

            elsif run("idle_cadence_saturated") then
                -- Maximum packets on two channels with preemptions sprinkled
                -- in, at the real locked IDLE interval.
                wait_for_lock;
                for i in 1 to 12 loop
                    send_packet(net, a_sources(2), make_payload(MAX_PAYLOAD_BYTES, i));
                    send_packet(net, a_sources(3), make_payload(MAX_PAYLOAD_BYTES, 50 + i));
                end loop;
                for i in 1 to 30 loop
                    send_packet(net, a_sources(1), make_payload(100, 100 + i));
                end loop;
                for i in 1 to 12 loop
                    check_packet(net, b_sinks(2), make_payload(MAX_PAYLOAD_BYTES, i), msg => "chan 2 pkt " & to_string(i));
                    check_packet(net, b_sinks(3), make_payload(MAX_PAYLOAD_BYTES, 50 + i), msg => "chan 3 pkt " & to_string(i));
                end loop;
                for i in 1 to 30 loop
                    check_packet(net, b_sinks(1), make_payload(100, 100 + i), msg => "chan 1 pkt " & to_string(i));
                end loop;
                settle;
                check(ab_max_gap <= IDLE_BOUND_CHARS, "comma gap " & to_string(ab_max_gap));
                check(ab_max_gap > 4470, "the cadence test never reached the locked interval, gap " & to_string(ab_max_gap));
                check_no_errors(b_counters, "B");

            elsif run("scramble_toggle_under_traffic") then
                wait_for_lock;
                for i in 1 to 10 loop
                    send_packet(net, a_sources(2), make_payload(100, i));
                end loop;
                wait for 300 * 20 ns;
                a_scramble <= force '0';
                for i in 1 to 10 loop
                    check_packet(net, b_sinks(2), make_payload(100, i), msg => "pkt " & to_string(i));
                end loop;
                -- The partner only hears at the next IDLE
                wait until b_status.partner_scramble_enabled = '0' for 1 ms;
                check_equal(b_status.partner_scramble_enabled, '0', "B heard scrambling went off");
                for i in 11 to 15 loop
                    send_packet(net, a_sources(2), make_payload(100, i));
                end loop;
                a_scramble <= force '1';
                for i in 11 to 15 loop
                    check_packet(net, b_sinks(2), make_payload(100, i), msg => "pkt " & to_string(i));
                end loop;
                wait until b_status.partner_scramble_enabled = '1' for 1 ms;
                settle;
                check_no_errors(b_counters, "B");

            elsif run("bit_error_header") then
                wait_for_lock;
                -- One clean packet first so the receiver has a sequence
                -- expectation, then corrupt the ChannelID byte of the next;
                -- it must be dropped and the one after delivered cleanly.
                send_packet(net, a_sources(2), make_payload(20, 0));
                check_packet(net, b_sinks(2), make_payload(20, 0), msg => "packet before the bad header");
                wire_flip_bit(net, wire_ab, ANCHOR_SOP, 1, 3, chan => 2);
                send_packet(net, a_sources(2), make_payload(20, 1));
                wire_wait_idle(net, wire_ab);
                settle;
                send_packet(net, a_sources(2), make_payload(20, 2));
                check_packet(net, b_sinks(2), make_payload(20, 2), msg => "packet after the bad header");
                settle;
                check(b_counters.rx_crc8_err + b_counters.rx_code_err + b_counters.rx_framing_err >= 1, "header error counted");
                check_equal(b_counters.rx_seq_err, 1, "the dropped packet shows up as a sequence gap");

            elsif run("bit_error_payload") then
                wait_for_lock;
                wire_flip_bit(net, wire_ab, ANCHOR_SOP, 6, 4, chan => 2);
                send_packet(net, a_sources(2), make_payload(20, 1));
                pop_basic_pkt(net, b_sinks(2), got, err);
                check_true(err, "corrupted packet flagged");
                send_packet(net, a_sources(2), make_payload(20, 2));
                check_packet(net, b_sinks(2), make_payload(20, 2), msg => "packet after the corruption");
                settle;
                check(b_counters.rx_crc16_err + b_counters.rx_code_err >= 1, "payload error counted");
                check_equal(b_counters.rx_seq_err, 0, "no sequence gap");

            elsif run("bit_error_crc") then
                wait_for_lock;
                -- SOP + 3 header + 20 payload: offset 24 is the CRC high byte
                wire_flip_bit(net, wire_ab, ANCHOR_SOP, 24, 0, chan => 2);
                send_packet(net, a_sources(2), make_payload(20, 1));
                pop_basic_pkt(net, b_sinks(2), got, err);
                check_true(err, "packet with a bad CRC flagged");
                send_packet(net, a_sources(2), make_payload(20, 2));
                check_packet(net, b_sinks(2), make_payload(20, 2), msg => "packet after the corruption");
                settle;
                check(b_counters.rx_crc16_err + b_counters.rx_code_err >= 1, "CRC error counted");

            elsif run("bit_error_idle") then
                wait_for_lock;
                wire_flip_bit(net, wire_ab, ANCHOR_COMMA, 2, 5);
                wire_wait_idle(net, wire_ab);
                settle;
                check(b_counters.rx_idle_bad + b_counters.rx_code_err >= 1, "bad IDLE counted");
                check_equal(b_status.rx_locked, '1', "one bad IDLE does not drop lock");
                send_packet(net, a_sources(2), make_payload(20, 2));
                check_packet(net, b_sinks(2), make_payload(20, 2), msg => "packet after the bad IDLE");

            elsif run("skip_delete_duplicate") then
                -- What an elastic buffer would do to the skip character
                wait_for_lock;
                wire_delete(net, wire_ab, ANCHOR_COMMA, 4);
                wire_wait_idle(net, wire_ab);
                wire_duplicate(net, wire_ab, ANCHOR_COMMA, 4);
                wire_wait_idle(net, wire_ab);
                settle;
                check_equal(b_counters.rx_idle_bad, 0, "skips are not part of the IDLE CRC");
                check_equal(b_counters.rx_framing_err, 0, "extra skips are harmless");
                send_packet(net, a_sources(2), make_payload(20, 2));
                check_packet(net, b_sinks(2), make_payload(20, 2), msg => "packet after the skips");

            elsif run("underrun") then
                wait_for_lock;
                -- Half a packet, then nothing for a while: the source drops
                -- valid and the framer has to abandon the packet.
                payload := make_payload(5, 1);
                for i in 0 to 4 loop
                    push_basic_pkt_stream(net, a_sources(2), to_std_logic_vector(i + 1, 8), last => false);
                end loop;
                pop_basic_pkt(net, b_sinks(2), got, err);
                check_true(err, "abandoned packet flagged");
                settle;
                check_equal(a_counters.tx_underruns, 1, "A tx_underruns");
                check_equal(b_counters.rx_aborted, 1, "B rx_aborted");
                check_equal(b_counters.rx_crc16_err, 0, "an abort is not a CRC error");
                -- The rest of the bytes go out as a packet of their own
                send_packet(net, a_sources(2), make_payload(5, 10));
                check_packet(net, b_sinks(2), make_payload(5, 10), msg => "packet after the underrun");

            elsif run("seq_error_dropped_packet") then
                wait_for_lock;
                send_packet(net, a_sources(2), make_payload(8, 1));
                check_packet(net, b_sinks(2), make_payload(8, 1), msg => "first packet");
                -- Lose the SOP of the next one: the receiver sees filler
                -- then a stray EOP, and the packet after has a gap.
                wire_delete(net, wire_ab, ANCHOR_SOP, 0, chan => 2);
                send_packet(net, a_sources(2), make_payload(8, 2));
                wire_wait_idle(net, wire_ab);
                settle;
                send_packet(net, a_sources(2), make_payload(8, 3));
                check_packet(net, b_sinks(2), make_payload(8, 3), msg => "packet after the gap");
                settle;
                check_equal(b_counters.rx_seq_err, 1, "sequence gap counted");
                check(b_counters.rx_framing_err >= 1, "stray EOP counted");

            elsif run("zero_length_rx_only") then
                -- The transmit interface cannot make one, so splice a raw
                -- packet into the filler. Needs scrambling off so the
                -- injected bytes arrive as sent.
                wait_for_lock;
                a_scramble <= force '0';
                wait until b_status.partner_scramble_enabled = '0' for 1 ms;
                snapshot := b_counters;
                chars := build_packet_chars(2, 0, new_queue);
                wire_insert(net, wire_ab, ANCHOR_COMMA, 8, chars);
                wire_wait_idle(net, wire_ab);
                settle;
                -- Statistics packets count too, so only a lower bound is exact
                check(b_counters.rx_pkts - snapshot.rx_pkts >= 1, "empty packet counted as received");
                check_equal(b_counters.rx_framing_err, 0, "no framing error");
                check_equal(b_counters.rx_crc16_err, 0, "no CRC error");
                -- Nothing was delivered: the next real packet is the first thing out
                send_packet(net, a_sources(2), make_payload(4, 9));
                check_packet(net, b_sinks(2), make_payload(4, 9), msg => "packet after the empty one");

            elsif run("oversize_rx_only") then
                wait_for_lock;
                a_scramble <= force '0';
                wait until b_status.partner_scramble_enabled = '0' for 1 ms;
                -- One byte over is the hardest case to tell from a maximum
                -- packet: only the character after it gives it away.
                chars := build_packet_chars(2, 0, make_payload(MAX_PAYLOAD_BYTES + 1, 1));
                wire_insert(net, wire_ab, ANCHOR_COMMA, 8, chars);
                pop_basic_pkt(net, b_sinks(2), got, err);
                check_true(err, "oversize packet flagged");
                n := 0;
                while not is_empty(got) loop
                    chan := to_integer(pop_std_ulogic_vector(got));
                    n := n + 1;
                end loop;
                check_equal(n, MAX_PAYLOAD_BYTES, "stream cut at the limit");
                settle;
                check(b_counters.rx_framing_err >= 1, "oversize counted");
                send_packet(net, a_sources(2), make_payload(4, 9));
                check_packet(net, b_sinks(2), make_payload(4, 9), msg => "packet after the oversize one");

            elsif run("raw_error_paths") then
                wait_for_lock;
                a_scramble <= force '0';
                wait until b_status.partner_scramble_enabled = '0' for 1 ms;

                -- SOP in the middle of a packet closes it and starts the next
                chars := new_queue;
                push_char(chars, '1', SOP_CHAR);
                push_char(chars, '0', X"03");
                push_char(chars, '0', X"00");
                payload := new_queue;
                push_byte(payload, 3);
                push_byte(payload, 0);
                push_char(chars, '0', crc8_atm_byte(payload));
                for i in 1 to 6 loop
                    push_char(chars, '0', to_std_logic_vector(i, 8));
                end loop;
                payload2 := build_packet_chars(3, 1, make_payload(4, 20));
                while not is_empty(payload2) loop
                    push(chars, pop_std_ulogic_vector(payload2));
                end loop;
                snapshot := b_counters;
                wire_insert(net, wire_ab, ANCHOR_COMMA, 8, chars);
                pop_basic_pkt(net, b_sinks(3), got, err);
                check_true(err, "cut-off packet flagged");
                check_packet(net, b_sinks(3), make_payload(4, 20), msg => "packet after the cut-off one");
                settle;
                check_equal(b_counters.rx_framing_err - snapshot.rx_framing_err, 1, "SOP mid-packet counted");

                -- Preempt character with nothing to preempt is just a start
                snapshot := b_counters;
                chars := build_packet_chars(1, 0, make_payload(5, 30), preempt => true);
                wire_insert(net, wire_ab, ANCHOR_COMMA, 8, chars);
                check_packet(net, b_sinks(1), make_payload(5, 30), msg => "lone preempt packet delivered");
                settle;
                check_equal(b_counters.rx_framing_err - snapshot.rx_framing_err, 1, "lone preempt counted");
                check_equal(b_counters.rx_preemptions - snapshot.rx_preemptions, 0, "lone preempt is not a preemption");

                -- Nested preemption: the inner-most packet is the one lost.
                -- It was cut before any of it reached the consumer, so it
                -- only shows up in the counters.
                snapshot := b_counters;
                chars := new_queue;
                payload := build_packet_chars(4, 0, make_payload(6, 40));
                for i in 1 to 7 loop  -- SOP, chan, seq, crc8, 3 payload bytes
                    push(chars, pop_std_ulogic_vector(payload));
                end loop;
                payload2 := build_packet_chars(1, 0, make_payload(6, 50), preempt => true);
                for i in 1 to 7 loop
                    push(chars, pop_std_ulogic_vector(payload2));
                end loop;
                payload3 := build_packet_chars(1, 1, make_payload(6, 60), preempt => true);
                while not is_empty(payload3) loop
                    push(chars, pop_std_ulogic_vector(payload3));
                end loop;
                while not is_empty(payload) loop
                    push(chars, pop_std_ulogic_vector(payload));
                end loop;
                wire_insert(net, wire_ab, ANCHOR_COMMA, 8, chars);
                check_packet(net, b_sinks(1), make_payload(6, 60), msg => "second preempt packet is the first delivered");
                check_packet(net, b_sinks(4), make_payload(6, 40), msg => "outer packet survives nested preempt");
                settle;
                check_equal(b_counters.rx_framing_err - snapshot.rx_framing_err, 1, "nested preempt counted");
                check_equal(b_counters.rx_preemptions - snapshot.rx_preemptions, 1, "one real preemption");

                -- A comma inside a packet ends it
                snapshot := b_counters;
                chars := new_queue;
                payload := build_packet_chars(4, 1, make_payload(6, 70));
                for i in 1 to 8 loop
                    push(chars, pop_std_ulogic_vector(payload));
                end loop;
                push_char(chars, '1', COMMA_CHAR);
                push_char(chars, '0', POL_CHAR_A);
                push_char(chars, '0', X"FF");
                push_char(chars, '0', X"03");
                push_char(chars, '1', SKIP_CHAR);
                payload := new_queue;
                push_byte(payload, to_integer(POL_CHAR_A));
                push_byte(payload, 16#FF#);
                push_byte(payload, 3);
                push_char(chars, '0', crc8_atm_byte(payload));
                wire_insert(net, wire_ab, ANCHOR_COMMA, 8, chars);
                pop_basic_pkt(net, b_sinks(4), got, err);
                check_true(err, "packet cut by a comma flagged");
                settle;
                check_equal(b_counters.rx_framing_err - snapshot.rx_framing_err, 1, "comma mid-packet counted");

                -- Runt: EOP straight after the header
                snapshot := b_counters;
                chars := new_queue;
                payload := build_packet_chars(4, 2, make_payload(1, 0));
                for i in 1 to 4 loop
                    push(chars, pop_std_ulogic_vector(payload));
                end loop;
                push_char(chars, '1', EOP_CHAR);
                -- and a stray EOP on its own
                push_char(chars, '0', X"00");
                push_char(chars, '1', EOP_CHAR);
                wire_insert(net, wire_ab, ANCHOR_COMMA, 8, chars);
                wire_wait_idle(net, wire_ab);
                settle;
                check_equal(b_counters.rx_framing_err - snapshot.rx_framing_err, 2, "runt and stray EOP counted");

                -- Still healthy
                send_packet(net, a_sources(2), make_payload(4, 9));
                check_packet(net, b_sinks(2), make_payload(4, 9), msg => "packet after the error paths");

            elsif run("lock_drop_mid_packet") then
                wait_for_lock;
                send_packet(net, a_sources(2), make_payload(200, 1));
                wait for 60 * 20 ns;
                b_link_reset <= force '1';
                wait for 5 * 20 ns;
                b_link_reset <= force '0';
                pop_basic_pkt(net, b_sinks(2), got, err);
                check_true(err, "interrupted packet terminated with an error");
                wait until b_status.rx_locked = '1' for 2 ms;
                check_equal(b_status.rx_locked, '1', "B re-locked");
                check_equal(b_counters.rx_unlocks, 1, "unlock counted");
                wait until a_status.partner_locked = '1' for 1 ms;
                send_packet(net, a_sources(2), make_payload(20, 2));
                check_packet(net, b_sinks(2), make_payload(20, 2), msg => "packet after re-lock");
                settle;
                check_equal(b_counters.rx_seq_err, 0, "sequence re-synchronised silently");

            elsif run("stats_exchange") then
                wait_for_lock;
                send_packet(net, a_sources(2), make_payload(20, 1));
                check_packet(net, b_sinks(2), make_payload(20, 1), msg => "a packet to count");
                -- B preempts a packet to A so the last counter in A's
                -- statistics packet, rx_preemptions, is non-zero: its low
                -- byte is the final byte on the wire.
                send_packet(net, b_sources(2), make_payload(200, 2));
                wait for 40 * 20 ns;
                send_packet(net, b_sources(1), make_payload(10, 3));
                check_packet(net, a_sinks(1), make_payload(10, 3), msg => "preemptor at A");
                check_packet(net, a_sinks(2), make_payload(200, 2), msg => "interrupted packet at A");
                settle;
                check_equal(a_counters.rx_preemptions, 1, "A rx_preemptions");
                -- A statistics packet snapshotted before the preemption may
                -- already be in flight, so allow for one stale one.
                for i in 1 to 2 loop
                    wait until b_partner_valid = '1' for 20 ms;
                    check_equal(b_partner_valid, '1', "B received a statistics packet from A");
                    exit when b_partner.rx_preemptions = 1;
                end loop;
                check_equal(b_partner.rx_preemptions, 1, "last counter decoded from the final byte");
                check_equal(b_partner.rx_framing_err, a_counters.rx_framing_err, "framing errors match");
                check_equal(b_partner.rx_crc16_err, a_counters.rx_crc16_err, "crc errors match");
                check(b_partner.tx_pkts >= 1, "A reported sending packets");
                check(b_partner.tx_pkts <= a_counters.tx_pkts, "snapshot is no newer than live");
                wait until a_partner_valid = '1' for 20 ms;
                check_equal(a_partner_valid, '1', "A received a statistics packet from B");
                check(a_partner.rx_pkts >= 1, "B reported receiving packets");

            elsif run("polarity_each_end") then
                -- Flip the wires while running: the receiver loses lock,
                -- reads the new polarity off the IDLEs and comes back.
                wait_for_lock;
                wire_set_invert(net, wire_ab, true);
                wait until b_status.rx_locked = '0' for 2 ms;
                check_equal(b_status.rx_locked, '0', "B dropped lock on inversion");
                wait until b_status.rx_locked = '1' for 2 ms;
                check_equal(b_status.rx_locked, '1', "B re-locked inverted");
                check_equal(b_status.rx_polarity_inverted, '1', "B sees inversion");
                wait until a_status.partner_polarity_inverted = '1' for 1 ms;
                check_equal(a_status.partner_polarity_inverted, '1', "A hears B is inverted");
                wire_set_invert(net, wire_ba, true);
                wait until a_status.rx_locked = '0' for 2 ms;
                wait until a_status.rx_locked = '1' for 2 ms;
                check_equal(a_status.rx_locked, '1', "A re-locked inverted");
                check_equal(a_status.rx_polarity_inverted, '1', "A sees inversion");
                wait until a_status.partner_locked = '1' and b_status.partner_locked = '1' for 1 ms;
                send_packet(net, a_sources(2), make_payload(20, 1));
                send_packet(net, b_sources(2), make_payload(20, 2));
                check_packet(net, b_sinks(2), make_payload(20, 1), msg => "A to B inverted");
                check_packet(net, a_sinks(2), make_payload(20, 2), msg => "B to A inverted");

            elsif run("random_bit_error_soak") then
                -- Flip a bit somewhere in each of many packets, covering the
                -- SOP and EOP as well as every header and payload position.
                -- Whatever the receiver makes of each one, it must keep working.
                wait_for_lock;
                for i in 1 to 60 loop
                    wire_flip_bit(net, wire_ab, ANCHOR_SOP, (i * 7) mod 30, (i * 3) mod 10, chan => 2);
                    send_packet(net, a_sources(2), make_payload(24, i));
                    wire_wait_idle(net, wire_ab);
                    settle(100);
                    check_equal(b_status.rx_locked, '1', "B locked after soak " & to_string(i));
                end loop;
                -- A corrupted control character is indistinguishable from a
                -- corrupted data character, and the receiver advances its
                -- descrambler on it as if it were data. When the victim was
                -- in fact the SOP or EOP that leaves the keystream one step
                -- off until the next IDLE reloads the seed, so give one a
                -- chance to go by before expecting clean delivery.
                wait for 2 * 4470 * 20 ns;
                send_packet(net, a_sources(3), make_payload(16, 200));
                check_packet(net, b_sinks(3), make_payload(16, 200), msg => "clean channel after the soak");
                check_equal(b_status.rx_locked, '1', "B still locked");
                check_equal(a_status.rx_locked, '1', "A still locked");
            end if;

            check_equal(ab_monitor_errors, 0, "wire A to B monitor");
            check_equal(ba_monitor_errors, 0, "wire B to A monitor");
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 ms);

end tb;
