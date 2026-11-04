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

entity tb_basic_stream is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of tb_basic_stream is

    -- Create the source/sinks with relatively low valid/ready probability to help esnure those
    -- signals are being respected.
    constant basic_source_stream : basic_source_t :=
        new_basic_source(data_length => 8, valid_high_probability => 0.5);
    constant basic_sink_stream : basic_sink_t :=
        new_basic_sink(data_length => 8, ready_high_probability => 0.5);
    constant pkt_source_stream : basic_source_t :=
        new_basic_source(data_length => 8, valid_high_probability => 0.5);
    constant pkt_sink_stream : basic_sink_t :=
        new_basic_sink(data_length => 8);

begin

    th: entity work.th_basic_stream
        generic map (
            source  => basic_source_stream,
            sink    => basic_sink_stream,
            pkt_source => pkt_source_stream,
            pkt_sink => pkt_sink_stream
        );

    bench: process
        alias clk is << signal th.clk : std_logic >>;

        variable temp : std_logic_vector(data_length(basic_source_stream)-1 downto 0);
        variable bytes : queue_t;
        variable pkt_error : boolean;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        set_format(display_handler, verbose, true);
        show(basic_sink_stream.p_logger, display_handler, trace);

        while test_suite loop
            if run("test_single_push_and_pop") then
                push_basic_stream(net, basic_source_stream, x"77");
                pop_basic_stream(net, basic_sink_stream, temp);
                check_equal(temp, std_logic_vector'(x"77"), "pop stream data");
            elsif run("test_double_push_and_pop") then
                push_basic_stream(net, basic_source_stream, x"66");
                pop_basic_stream(net, basic_sink_stream, temp);
                check_equal(temp, std_logic_vector'(x"66"), "pop stream first data");
          
                push_basic_stream(net, basic_source_stream, x"55");
                pop_basic_stream(net, basic_sink_stream, temp);
                check_equal(temp, std_logic_vector'(x"55"), "pop stream second data");
            elsif run("push_delay_pop") then
                push_basic_stream(net, basic_source_stream, x"de");
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                pop_basic_stream(net, basic_sink_stream, temp);
                check_equal(temp, std_logic_vector'(x"de"), "pop stream data");
            elsif run("block_push_and_pop") then
                for i in 0 to 7 loop
                    push_basic_stream(net, basic_source_stream, std_logic_vector(to_unsigned(i, 8)));
                    pop_basic_stream(net, basic_sink_stream, temp);
                    check_equal(temp, std_logic_vector(to_unsigned(i, 8)), "pop stream data"&natural'image(i));
                end loop;
            elsif run("pkt_sink_captures_whole_packets") then
                -- Two packets pushed back to back before anything pops, so the
                -- sink has to hold beats it was not asked for yet.
                for i in 0 to 3 loop
                    push_basic_pkt_stream(net, pkt_source_stream, std_logic_vector(to_unsigned(i, 8)), last => i = 3);
                end loop;
                push_basic_pkt_stream(net, pkt_source_stream, x"a5", last => true);
                wait for 1 us;

                -- VUnit's length() is the encoded byte count, not the number
                -- of entries, so packets are walked with is_empty instead.
                pop_basic_pkt(net, pkt_sink_stream, bytes, pkt_error);
                for i in 0 to 3 loop
                    check_false(is_empty(bytes), "first packet ran short");
                    check_equal(pop_std_ulogic_vector(bytes), std_logic_vector(to_unsigned(i, 8)), "first packet byte " & natural'image(i));
                end loop;
                check_true(is_empty(bytes), "first packet ran long");
                check_true(pkt_error, "error flag from the last beat");

                pop_basic_pkt(net, pkt_sink_stream, bytes, pkt_error);
                check_equal(pop_std_ulogic_vector(bytes), std_logic_vector'(x"a5"), "second packet byte");
                check_true(is_empty(bytes), "second packet ran long");
            elsif run("pkt_sink_pop_blocks_until_packet_arrives") then
                push_basic_pkt_stream(net, pkt_source_stream, x"11");
                push_basic_pkt_stream(net, pkt_source_stream, x"22", last => true);
                pop_basic_pkt(net, pkt_sink_stream, bytes, pkt_error);
                check_equal(pop_std_ulogic_vector(bytes), std_logic_vector'(x"11"), "first byte");
                check_equal(pop_std_ulogic_vector(bytes), std_logic_vector'(x"22"), "second byte");
                check_true(is_empty(bytes), "packet ran long");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;