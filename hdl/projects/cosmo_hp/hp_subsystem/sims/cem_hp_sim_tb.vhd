-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;


entity cem_hp_sim_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of cem_hp_sim_tb is

begin

    th: entity work.cem_hp_sim_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias hp_pwren_l is << signal th.mdl.hp_pwren_l : std_logic >>;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("test") then
                wait for 5 us;
                hp_pwren_l <= '0';  -- power on the HP
                wait for 100 us;  -- wait for the HP to come up
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;