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


entity tb_synchronizers is
    generic(runner_cfg : string);
end entity;

architecture tb of tb_synchronizers is
begin
    th: entity work.th_synchronizers;
        
  bench:process
    -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
    -- So this sim only works in other simulators, like nvc
    alias reset_a is <<signal .tb_synchronizers.th.reset_a : std_logic>>;
    alias reset_b is <<signal .tb_synchronizers.th.reset_b : std_logic>>;


    -- An example of reaching into the testharness with alias. Sort of a naive way of doing things
    -- but functional and often useful for some basic things
    alias bacd1_write is <<signal .tb_synchronizers.th.bacd1_write : std_logic>>;
    alias bacd1_launch_bus is <<signal .tb_synchronizers.th.bacd1_launch_bus : std_logic_vector(7 downto 0)>>;
    alias bacd1_write_allowed is <<signal .tb_synchronizers.th.bacd1_write_allowed : std_logic>>;
    alias bacd1_datavalid is <<signal .tb_synchronizers.th.bacd1_datavalid : std_logic>>;
    alias bacd1_latch_bus is <<signal .tb_synchronizers.th.bacd1_latch_bus : std_logic_vector(7 downto 0)>>;

    variable test_byte : std_logic_vector(7 downto 0) := (others => '0');

  begin
    -- Always the first thing in the process, set up things for the VUnit test runner
    test_runner_setup(runner, runner_cfg);

    -- Reach into the test harness, which generates and de-asserts reset and hold the
    -- test cases off until we're out of reset. This runs for every test case
    wait until reset_b = '0';
    wait for 200 ns;
    
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
        end if;
    end loop;
       
       
    wait for 1 us;
    test_runner_cleanup(runner);
    wait;
    end process;
    
end tb;