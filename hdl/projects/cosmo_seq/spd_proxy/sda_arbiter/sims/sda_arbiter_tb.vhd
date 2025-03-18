-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;

entity sda_arbiter_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of sda_arbiter_tb is
    constant CLK_PER_TIME       : time      := 8 ns;
    constant HYSTERESIS_CYCLES  : integer   := 10;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal a        : std_logic := '1';
    signal b        : std_logic := '1';
    signal enabled  : std_logic := '1';
    signal a_grant  : std_logic;
    signal b_grant  : std_logic;
begin

    clk     <= not clk after CLK_PER_TIME / 2;
    reset   <= '0' after 100 ns;

    sda_arbiter_inst: entity work.sda_arbiter
     generic map(
        HYSTERESIS_CYCLES => HYSTERESIS_CYCLES
    )
     port map(
        clk     => clk,
        reset   => reset,
        a       => a,
        b       => b,
        enabled => enabled,
        a_grant => a_grant,
        b_grant => b_grant
    );

    bench: process
        variable cycle_counter : integer := 0;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);

        -- wait for reset to clear
        wait until reset = '0';

        while test_suite loop
            if run("grant_a") then
                -- assert A bus
                b <= '1';
                wait for 100 ns;
                a <= '0';

                check_true(a_grant = '0', "Bus A should not be granted the bus.");
                check_true(b_grant = '0', "Bus B should not be granted the bus.");

                -- arbitration grant is registered
                wait for CLK_PER_TIME + 1 ns;

                check_true(a_grant = '1', "Bus A should immediately be granted the bus.");
                check_true(b_grant = '0', "Bus B should not be granted the bus.");
            elsif run("grant_b") then
                -- assert B bus
                a <= '1';
                wait for 100 ns;
                b <= '0';

                check_true(a_grant = '0', "Bus A should not be granted the bus.");
                check_true(b_grant = '0', "Bus B should not be granted the bus.");

                -- arbitration grant is registered
                wait for CLK_PER_TIME + 1 ns;

                check_true(a_grant = '0', "Bus A should not be granted the bus.");
                check_true(b_grant = '1', "Bus B should immediately be granted the bus.");
            elsif run("hysteresis") then
                -- assert A bus
                b <= '1';
                wait for 100 ns;
                a <= '0';
                wait until a_grant = '1';

                -- release A bus and assert B bus, expecting the arbitration not to change before
                -- HYSTERESIS_CYCLES has passed
                a <= '1';
                b <= '0';

                while cycle_counter <= HYSTERESIS_CYCLES loop
                    wait for CLK_PER_TIME;
                    check_true(a_grant = '1', "Bus A should be granted the bus.");
                    check_true(b_grant = '0', "Bus B should not be granted the bus.");
                    cycle_counter := cycle_counter + 1;
                end loop;

                -- after the initial hysteresis period, neither bus should be granted arbitration
                cycle_counter := 0;
                while cycle_counter <= HYSTERESIS_CYCLES loop
                    wait for CLK_PER_TIME;
                    check_true(a_grant = '0', "Bus A should not be granted the bus.");
                    check_true(b_grant = '0', "Bus B should not be granted the bus.");
                    cycle_counter := cycle_counter + 1;
                end loop;

                -- after the second hysteresis period, B should be granted the bus.
                wait until rising_edge(clk);
                check_true(a_grant = '0', "Bus A should not be granted the bus.");
                check_true(b_grant = '1', "Bus B should be granted the bus.");
            elsif run("disable") then
                -- assert A bus
                b <= '1';
                wait for 100 ns;
                a <= '0';
                wait until a_grant = '1';

                enabled <= '0';
                wait for CLK_PER_TIME + 1 ns;
                check_true(a_grant = '0', "Bus A should not be granted the bus.");
                check_true(b_grant = '0', "Bus B should not be granted the bus.");
            end if;
        end loop;

        wait for 1 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 us);
end architecture;