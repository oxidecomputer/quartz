-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
use work.calc_pkg.all;
use work.time_pkg.all;
use work.transforms_pkg.all;

entity utilities_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of utilities_tb is

begin

    bench : process
        variable calc_result : unsigned(31 downto 0);
        variable tmp_flip    : std_logic_vector(7 downto 0);
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("calc_pkg_log2ceil_test") then
                -- log2ceil for 8 should require 3 bits for 8 positions (including 0)
                check(log2ceil(8) = 3, "log2ceil not working");
                -- log2ceil for 1 should require 1 bit for 1 position
                check(log2ceil(1) = 1, "log2ceil not working");
            elsif run("calc_pkg_sel_tests") then
                check(sel(true, "true", "false") = "true");
                check(sel(false, "true", "false") = "false");
            elsif run("time_pkg_tests") then
                calc_result := calc_us(desired_us => 1, clk_period_ns => 10, return_size => 32);
                check_equal(calc_result, 100, "Nope");
                calc_result := calc_ms(desired_ms => 1, clk_period_ns => 10, return_size => 32);
                check_equal(calc_result, 100_000, "Nope");
                calc_result := calc_ns(desired_ns => 10, clk_period_ns => 10, return_size => 32);
                check_equal(calc_result, 1, "Nope");
            elsif run("transform_pkg_test") then
                tmp_flip := reverse(X"0F");
                check_equal(tmp_flip, std_logic_vector'(X"F0"), "Nope");
            end if;
        end loop;

        wait for 100 ns;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;
