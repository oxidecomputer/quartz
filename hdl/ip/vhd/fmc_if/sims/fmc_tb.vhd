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

use work.stm32h7_fmc_sim_pkg.all;

entity fmc_tb is
  generic
    (runner_cfg : string);
end entity;

architecture tb of fmc_tb is
begin
  th : entity work.fmc_th;

  bench : process
    -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
    -- So this sim only works in other simulators, like nvc
    -- reset_a uses the absolute path form (starting with a '.') and
    -- reset_b uses the relative path form of external naming for example purposes.
    alias reset is << signal th.reset : std_logic >> ;


    variable address : std_logic_vector(25 downto 0) := (others => '0');
    variable data : std_logic_vector(31 downto 0);

  begin
    -- Always the first thing in the process, set up things for the VUnit test runner
    test_runner_setup(runner, runner_cfg);

    -- Reach into the test harness, which generates and de-asserts reset and hold the
    -- test cases off until we're out of reset. This runs for every test case
    wait until reset = '0';
    wait for 500 ns;  -- let the resets propagate

    
    while test_suite loop
      if run("basic_fmc_test") then
         fmc_read32(net, address, data);
         wait for 1 us;
         data := X"DEADBEEF";
         fmc_write32(net, address, data);
      end if;
    end loop;
    wait for 1 us;
    test_runner_cleanup(runner);
    wait;
  end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);
end tb;