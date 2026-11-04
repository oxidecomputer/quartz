-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;
use work.interlink_pkg.all;
use work.interlink_sim_pkg.all;

-- The same two link ends joined by ls_serdes and real serial wires. Slow,
-- so this only covers what the bypass harness cannot: bit alignment from an
-- arbitrary phase, and inversion on the actual wire. This bench also runs
-- without a preemptor, the interlink_top default, which the bypass bench
-- never does.
entity interlink_serial_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of interlink_serial_tb is
begin

    th: entity work.interlink_th
        generic map (
            SERIAL => true,
            PREEMPT_CHANNEL => 0
        );

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias a_status is << signal th.a_status : link_status_t >>;
        alias b_status is << signal th.b_status : link_status_t >>;
        alias a_counters is << signal th.a_counters : link_counters_t >>;
        alias b_counters is << signal th.b_counters : link_counters_t >>;
        alias b_partner_valid is << signal th.b_partner_valid : std_logic >>;
        alias invert_serial_ab is << signal th.invert_serial_ab : std_logic >>;
        alias ab_max_gap is << signal th.wire_ab.max_comma_gap : natural >>;
        alias ab_monitor_errors is << signal th.wire_ab.monitor_errors : natural >>;
        alias ba_monitor_errors is << signal th.wire_ba.monitor_errors : natural >>;

        procedure wait_for_lock is
        begin
            wait until a_status.rx_locked = '1' and b_status.rx_locked = '1' for 20 ms;
            check_equal(a_status.rx_locked, '1', "A did not lock");
            check_equal(b_status.rx_locked, '1', "B did not lock");
            wait until a_status.partner_locked = '1' and b_status.partner_locked = '1' for 5 ms;
        end procedure;
    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 100 ns;

        while test_suite loop
            if run("serial_lock_and_packets") then
                wait_for_lock;
                check_equal(b_status.rx_polarity_inverted, '0', "B polarity");
                send_packet(net, a_sources(2), make_payload(32, 1));
                send_packet(net, b_sources(3), make_payload(32, 2));
                check_packet(net, b_sinks(2), make_payload(32, 1), msg => "A to B");
                check_packet(net, a_sinks(3), make_payload(32, 2), msg => "B to A");
                wait for 50 us;
                check_equal(b_counters.rx_crc16_err, 0, "B crc errors");
                check_equal(b_counters.rx_seq_err, 0, "B seq errors");
                -- With no preemptor the statistics channel has to come through
                -- the round-robin like any other.
                wait until b_partner_valid = '1' for 30 ms;
                check_equal(b_partner_valid, '1', "B received a statistics packet with no preemptor configured");

            elsif run("serial_inverted_wire") then
                invert_serial_ab <= force '1';
                wait_for_lock;
                check_equal(b_status.rx_polarity_inverted, '1', "B sees the inverted wire");
                check_equal(a_status.rx_polarity_inverted, '0', "A wire is not inverted");
                send_packet(net, a_sources(2), make_payload(32, 1));
                check_packet(net, b_sinks(2), make_payload(32, 1), msg => "A to B over the inverted wire");

            elsif run("serial_idle_cadence") then
                -- A few locked-rate IDLE intervals with traffic in them
                wait_for_lock;
                for i in 1 to 4 loop
                    send_packet(net, a_sources(2), make_payload(MAX_PAYLOAD_BYTES, i));
                    check_packet(net, b_sinks(2), make_payload(MAX_PAYLOAD_BYTES, i), msg => "pkt " & to_string(i));
                end loop;
                wait for 2 * 4470 * 30 * 20 ns;
                check(ab_max_gap <= IDLE_BOUND_CHARS, "comma gap " & to_string(ab_max_gap));
                check_equal(b_status.rx_locked, '1', "B stayed locked");
            end if;

            check_equal(ab_monitor_errors, 0, "wire A to B monitor");
            check_equal(ba_monitor_errors, 0, "wire B to A monitor");
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 200 ms);

end tb;
