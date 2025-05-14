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

use work.basic_stream_pkg.all;
use work.ignition_sim_pkg.all;
use work.helper_8b10b_pkg.all;

entity ignition_tgt_sim_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of ignition_tgt_sim_tb is

begin

    th: entity work.ignition_tgt_sim_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias ibc_en_pin is << signal th.ibc_en_pin : std_logic >>;
        alias target_aligned is << signal th.ignition_target_common_inst.is_aligned : std_logic_vector(1 downto 0) >>;
        
        variable cmd : cmd_t;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            -- Some sim cases
            -- restart
            -- controller loss
            -- 1 controller happy
            --   2nd controller un
            if run("defaulted-power-on") then
                -- No controller interaction required the system should turn on
                wait for 500 ns;
                check_equal(ibc_en_pin, '1', "IBC power was not on by default");
            elsif run("stays-powered-off") then
                -- No controller interaction required the system should turn on
                wait until target_aligned(0) = '1'; 
                wait for 500 ns;
                check_equal(ibc_en_pin, '1', "IBC power was not on by default");
                cmd := build_off_cmd;
                send_cmd(net, source0, cmd);
                wait for 30 us;
                check_equal(ibc_en_pin, '0', "IBC power was not off after off command");
                wait for 1 ms;
                check_equal(ibc_en_pin, '0', "IBC power did not stay off after command");
            elsif run("power-on-after-off") then
                -- No controller interaction required the system should turn on
                wait until target_aligned(0) = '1'; 
                wait for 500 ns;
                check_equal(ibc_en_pin, '1', "IBC power was not on by default");
                cmd := build_off_cmd;  -- Turn IBC off
                send_cmd(net, source0, cmd);
                wait for 30 us;
                check_equal(ibc_en_pin, '0', "IBC power was not off after off command");
                cmd := build_on_cmd;
                send_cmd(net, source0, cmd);
                wait for 30 us;
                check_equal(ibc_en_pin, '1', "IBC power was not off after on command");
            elsif run("power-restart") then
                -- No controller interaction required the system should turn on
                wait until target_aligned(0) = '1'; 
                wait for 500 ns;
                check_equal(ibc_en_pin, '1', "IBC power was not on by default");
                cmd := build_restart_cmd;
                send_cmd(net, source0, cmd);
                wait on ibc_en_pin;
                check_equal(ibc_en_pin, '0', "IBC power was not off after restart command");
                wait on ibc_en_pin;
                check_equal(ibc_en_pin, '1', "IBC power was not back on after restart command");
                
            elsif run("single-controller-hello-lock") then
                wait until target_aligned(0) = '1';
                wait for 300 us; -- controller model should issue hellos automatically
                -- todo, this should report control0 present
                wait for 3 ms;
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;