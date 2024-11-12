-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright  Oxide Computer Company

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

    constant basic_source_stream : basic_source_t :=
        new_basic_source(data_length => 8, valid_high_probability => 0.5);

    constant basic_sink_stream : basic_sink_t :=
        new_basic_sink(data_length => 8, ready_high_probability => 0.5);

begin

    th: entity work.th_basic_stream
        generic map (
            source  => basic_source_stream,
            sink    => basic_sink_stream
        );

    bench: process
        alias clk is << signal th.clk : std_logic >>;

        variable temp : std_logic_vector(data_length(basic_source_stream)-1 downto 0);
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
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;