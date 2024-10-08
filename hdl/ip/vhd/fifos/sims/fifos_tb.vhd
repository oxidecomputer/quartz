-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
use work.fifos_sim_pkg.all;

entity fifos_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of fifos_tb is

begin

    th: entity work.fifos_th;

    bench: process
        -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
        -- So this sim only works in other simulators, like nvc
        -- reset_a uses the absolute path form (starting with a '.') and
        -- reset_b uses the relative path form of external naming for example purposes.
        alias reset_a is << signal th.reset_a : std_logic >>;
        alias reset_b is << signal th.reset_b : std_logic >>;

        variable write_data : std_logic_vector(7 downto 0);
        variable read_data  : std_logic_vector(7 downto 0);
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);

        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset_b = '0';
        wait for 500 ns;  -- let the resets propagate and clear in the fifo

        while test_suite loop
            if run("basic_fifo_test") then
                -- load fifo with data
                write_data := X"AA";
                push_fifo(net, write_data);
                wait for 1 us;
                pop_fifo(net, read_data);
                -- check read-side data
                check_equal(read_data, write_data, "Mismatch detected");
            elsif run("basic_mixed_fifo_test") then
                -- load fifo with data
                write_data := X"01";
                push_mixed_fifo(net);
                wait for 1 us;
                pop_mixed_fifo(net, read_data);
                -- check read-side data
                check_equal(read_data, std_logic_vector'(X"DD"), "Mismatch detected");
                pop_mixed_fifo(net, read_data);
                -- check read-side data
                check_equal(read_data, std_logic_vector'(X"CC"), "Mismatch detected");
                pop_mixed_fifo(net, read_data);
                -- check read-side data
                check_equal(read_data, std_logic_vector'(X"BB"), "Mismatch detected");
                pop_mixed_fifo(net, read_data);
                -- check read-side data
                check_equal(read_data, std_logic_vector'(X"AA"), "Mismatch detected");
            end if;
        end loop;
        wait for 1 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;
