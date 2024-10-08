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


entity strobe_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of strobe_tb is
    constant TB_TICKS : positive := 10;
begin

    th: entity work.strobe_th
        generic map (
            TICKS => TB_TICKS
        );

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias strobe is << signal th.dut_strobe : std_logic >>;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';

        while test_suite loop
            if run("test_strobe") then
                check_equal(strobe, '0', "Strobe should be low after reset");
                wait for 72 ns; -- CLK_PER_NS * (TB_TICKS - 1) ns
                check_equal(strobe, '0', "Strobe should be low after TB_TICKS-1");
                wait for 8 ns; -- wait one more period, bringing us to TB_TICKs
                check_equal(strobe, '1', "Strobe should be high once the TICKS count is reached");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;