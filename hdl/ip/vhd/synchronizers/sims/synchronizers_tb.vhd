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

use work.gpio_msg_pkg.all;

entity synchronizers_tb is
    generic(runner_cfg : string);
end entity;

architecture tb of synchronizers_tb is
begin
    th: entity work.synchronizers_th;
        
  bench:process
    -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
    -- So this sim only works in other simulators, like nvc
    -- reset_a uses the absolute path form (starting with a '.') and
    -- reset_b uses the relative path form of external naming for example purposes.
    alias reset_a is <<signal .synchronizers_tb.th.reset_a : std_logic>>;
    alias reset_b is <<signal th.reset_b : std_logic>>;


    -- An example of reaching into the testharness with alias. Sort of a naive way of doing things
    -- but functional and often useful for some basic things
    alias bacd1_write is <<signal th.bacd1_write : std_logic>>;
    alias bacd1_launch_bus is <<signal th.bacd1_launch_bus : std_logic_vector(7 downto 0)>>;
    alias bacd1_datavalid is <<signal th.bacd1_datavalid : std_logic>>;
    alias bacd1_latch_bus is <<signal th.bacd1_latch_bus : std_logic_vector(7 downto 0)>>;

    alias tacd_latch_out is <<signal th.tacd_latch_out : std_logic>>;

    variable test_byte : std_logic_vector(7 downto 0) := (others => '0');
    variable test_data : std_logic_vector(31 downto 0) := (others => '0');
    variable gpio_data : std_logic_vector(31 downto 0) := (others => '0');

    variable msg_target : actor_t;

  begin
    -- Always the first thing in the process, set up things for the VUnit test runner
    test_runner_setup(runner, runner_cfg);

    -- Reach into the test harness, which generates and de-asserts reset and hold the
    -- test cases off until we're out of reset. This runs for every test case
    wait until reset_b = '0';
    
    -- This is how vunit controls test execution, we loop on the `test_suite` and then
    -- use the `run` function to name our test cases. When the user selects a specific
    -- test case by name, the testrunner fixes things up so that only that test runs,
    -- otherwise they all will run. Wildcards etc supported for test names so by naming
    -- related tests properly, we can group test runs in convinient ways.
    while test_suite loop
        if run("bacd_basic_alias") then
            test_byte := X"00";
            check_equal(bacd1_latch_bus, test_byte, "Bus unexpectedly not 0's at reset");
            check_equal(bacd1_datavalid, '0', "Datavalid unexpectedly 1 at reset");
            -- This test just bit-bangs things using the alias and then checks things
            test_byte := X"AA";
            bacd1_launch_bus <= force test_byte;  -- force the launch value
            bacd1_write <= force '1'; --force the write
            --now we need to hold these for at least a clock cycle, and then let the bus
            --propagate. For this test we'll just wait until datavalid is high and sample it
            --not worrying about clocks, and since we know if we leave write asserted it
            --will propagate at least once
            -- Note:
            -- This is kind of an annoying way to write a testbench, especially if you
            -- wanted clock-synchronous behavior, but it's here as an example of reading 
            -- and driving external names.
            wait until bacd1_datavalid = '1' for 100 ns;
            check_equal(bacd1_datavalid, '1', "Datavalid unexpectedly 0 so we timed out");
            check_equal(bacd1_latch_bus, test_byte, "Expected bus value did not propagate");
        elsif run("tacd_msg_passing") then
            msg_target := find("tacd_stim");  -- get actor for the tacd_gpio block
            check_equal(tacd_latch_out, '0', "TACD output pulse unexpectedly 1 at reset");

            -- Set bit0 of the GPIO which will trigger the tacd to fire and cross domains
            gpio_data := X"ffffffff";
            set_gpio(net, msg_target, gpio_data);
            wait until tacd_latch_out = '1' for 100 ns;
            check_equal(tacd_latch_out, '1', "TACD output pulse 0 so we timed out");
            -- Unnecessary since we used an external name check, 
            -- but provided as an example of reading back the gpio using the network
            get_gpio(net, msg_target, gpio_data);
            test_data := X"00000001";
            check_equal(gpio_data, test_data, "TACD output pulse as read by bfm had incorrect value");

        end if;
    end loop;
       
       
    wait for 1 us;
    test_runner_cleanup(runner);
    wait;
    end process;
    
    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);
end tb;