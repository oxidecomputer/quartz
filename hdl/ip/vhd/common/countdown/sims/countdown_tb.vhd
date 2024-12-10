-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

entity countdown_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of countdown_tb is
    constant CLK_PER    : time      := 8 ns;
    constant SIZE       : positive  := 4;
begin

    th: entity work.countdown_th
        generic map (
            CLK_PER => CLK_PER,
            SIZE    => SIZE
        );

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias count is << signal th.dut_count : std_logic_vector >>;
        alias load is << signal th.dut_load : std_logic >>;
        alias decr is << signal th.dut_decr : std_logic >>;
        alias clear is << signal th.dut_clear : std_logic >>;
        alias done is << signal th.dut_done : std_logic >>;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';

        while test_suite loop
            if run("test_reset") then
                check_true(done = '1', "should be done as it not been loaded");
            elsif run("test_clear") then
                count   <= to_std_logic_vector(3, count'length);
                load    <= '1';
                clear   <= '1';
                wait for CLK_PER;
                check_true(done = '1', "should be done since clear has priority over load");

                -- load the counter
                clear   <= '0';
                wait for CLK_PER;
                check_true(done = '0', "should not be done after load");

                -- clear the counter
                clear   <= '1';
                wait for CLK_PER;
                check_true(done = '1', "should be done after clear");
            elsif run("test_countdown") then
                count   <= to_std_logic_vector(3, count'length);
                load    <= '1';
                wait for CLK_PER;
                check_true(done = '0', "should not be done after load");

                -- count down for a n-1 cycles
                load    <= '0';
                decr    <= '1';
                for i in 0 to 1 loop
                    wait for CLK_PER;
                    check_true(done = '0', "should not be done while counting down");
                end loop;

                -- verify done after the full countdown
                wait for CLK_PER;
                check_true(done = '1', "should be done after countdown");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

end tb;