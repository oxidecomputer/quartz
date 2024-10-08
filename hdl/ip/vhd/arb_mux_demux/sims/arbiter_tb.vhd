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
use work.arbiter_sim_pkg.all;

entity arbiter_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of arbiter_tb is

begin

    th: entity work.arbiter_th;

    bench: process
        -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
        -- So this sim only works in other simulators, like nvc
        -- reset_a uses the absolute path form (starting with a '.') and
        -- reset_b uses the relative path form of external naming for example purposes.
        alias reset is << signal th.reset : std_logic >>;

        variable requests   : std_logic_vector(2 downto 0);
        variable grants     : std_logic_vector(requests'range);
        variable msg_target : actor_t;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);

        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        -- give some time after reset
        wait for 500 ns;

        while test_suite loop
            if run("round_robin_arbiter_test") then
                msg_target := find("rr_arb_ctrl");
                -- put 3 bits active, show only one bit granted
                requests := 3x"7";
                set_arb(net, msg_target, requests);
                wait for 20 ns;
                get_grant(net, msg_target, grants);
                check(grants = 3x"1", "Expected only one grant, lsb");
                -- clear that granted request, should move up to the next
                requests := 3x"6";
                set_arb(net, msg_target, requests);
                wait for 20 ns;
                get_grant(net, msg_target, grants);
                check(grants = 3x"2", "Expected only one grant, middle bit");
                -- clear that granted request, add back original should move up to the next
                requests := 3x"5";
                set_arb(net, msg_target, requests);
                wait for 20 ns;
                get_grant(net, msg_target, grants);
                check(grants = 3x"4", "Expected only one grant, high bit");
                -- clear high should now be low again
                requests := 3x"1";
                set_arb(net, msg_target, requests);
                wait for 20 ns;
                get_grant(net, msg_target, grants);
                check(grants = 3x"1", "Expected only one grant, lsb");
            elsif run("prio_arbiter_test") then
                msg_target := find("pri_arb_ctrl");
                -- put 3 bits active, show only one bit granted, the lsb
                requests := 3x"7";
                set_arb(net, msg_target, requests);
                wait for 20 ns;
                get_grant(net, msg_target, grants);
                check(grants = 3x"1", "Expected only one grant, lsb");
                -- clear that granted request, should move up to the next
                requests := 3x"6";
                set_arb(net, msg_target, requests);
                wait for 20 ns;
                get_grant(net, msg_target, grants);
                check(grants = 3x"2", "Expected only one grant, middle bit");
                -- clear that granted request, add back original should get lsb again as pri
                requests := 3x"5";
                set_arb(net, msg_target, requests);
                wait for 20 ns;
                get_grant(net, msg_target, grants);
                check(grants = 3x"1", "Expected only one grant, lsb pri bit");
                -- clear higher priority so we should see middle bit grant
                requests := 3x"4";
                set_arb(net, msg_target, requests);
                wait for 20 ns;
                get_grant(net, msg_target, grants);
                check(grants = 3x"4", "Expected only one grant, lsb");
            end if;
        end loop;
        wait for 1 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;
