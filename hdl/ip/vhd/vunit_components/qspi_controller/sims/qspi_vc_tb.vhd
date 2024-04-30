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
use vunit_lib.sync_pkg.all;
use work.qspi_vc_pkg.all;

entity qspi_vc_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of qspi_vc_tb is

    constant tx_queue : queue_t := new_queue;

begin

    th: entity work.qspi_vc_th;

    bench: process
        alias    sim_reset  is <<signal th.reset : std_logic>>;
        alias    ss_n       is <<signal th.ss_n : std_logic_vector(7 downto 0)>>;
        variable msg_target : actor_t;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);

        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until sim_reset = '0';
        msg_target := find("espi_vc");  -- get actor for the qspi block

        while test_suite loop
            if run("shift_bytes_single") then
                -- set_mode(net, msg_target, QUAD);
                push_byte(tx_queue, 16#A5#);
                enqueue_tx_data_bytes(net, msg_target,  1, tx_queue);
                enqueue_transaction(net, msg_target, 1, 1);
            -- cear the chipsel
            -- wait for 0 ns;
            -- elsif run("shift_bytes_dual") then
            -- elsif run("shift_bytes_quad") then
            end if;
        end loop;
        wait for 4 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 4 us);

end tb;
