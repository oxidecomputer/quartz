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
use work.stm32h7_fmc_sim_pkg.all;
use work.fmc_tb_pkg.all;

entity fmc_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of fmc_tb is

begin

    th: entity work.fmc_th;

    bench : process
        -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
        -- So this sim only works in other simulators, like nvc
        -- reset_a uses the absolute path form (starting with a '.') and
        -- reset_b uses the relative path form of external naming for example purposes.
        alias reset is << signal th.reset : std_logic >>;

        variable address       : std_logic_vector(25 downto 0) := (others => '0');
        variable data          : std_logic_vector(31 downto 0) := (others => '0');
        variable expected_data : std_logic_vector(31 downto 0) := (others => '0');
        variable buf           : buffer_t;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        show_all(rd_logger, display_handler);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("basic_fmc_write_test") then
                data := X"DEADBEEF";
                -- Set up the buffer used by the AXI write target
                buf := allocate(wmemory, 4 * 2, alignment => 32);
                -- Only going to allow writes, and set the expected data
                -- using the simulation interface
                set_permissions(wmemory, to_integer(address), write_only);
                set_expected_word(wmemory, to_integer(address), data);
                -- Do the FMC -> AXI write transaction
                fmc_write32(net, address, data);
                check_expected_was_written(buf);
                -- Do a second transaction
                data := X"ADEADBAD";
                set_expected_word(wmemory, to_integer(address), data);
                fmc_write32(net, address, data);
                check_expected_was_written(buf);
            elsif run("basic_fmc_read_test") then
                buf := allocate(rmemory, 4 * 2, alignment => 32);
                -- Use the simulation interface to set the data we're going to read back
                expected_data := X"DEADBEEF";
                write_word(rmemory, base_address(buf), expected_data);
                -- TB will fault if DUT tries to write to this memory
                set_permissions(rmemory, base_address(buf), read_only);
                -- Read back written word via sim interface and check it matches
                data := read_word(rmemory, base_address(buf), 4);
                check_equal(data, expected_data, "Sim I/F Read data did not match exptected");
                -- Now do the FMC transaction, and check that returned data matches
                fmc_read32(net, address, data);
                check_equal(data, expected_data, "Read data did not match exptected");
                -- Do a second transaction
                expected_data := X"ADEADBAD";
                write_word(rmemory, base_address(buf), expected_data);
                fmc_read32(net, address, data);
                check_equal(data, expected_data, "Read data did not match exptected");
            end if;
        end loop;
        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- -- Example total test timeout dog
    test_runner_watchdog(runner, 1 ms);

end tb;
