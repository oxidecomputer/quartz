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

library osvvm;
use osvvm.RandomPkg.all;

use work.uart_tb_pkg.all;

entity uart_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of uart_tb is
    shared variable rnd_stimuli, rnd_expected : RandomPType;
    constant tx_uart_stream : stream_master_t := as_stream(tx_uart_bfm);
    constant rx_uart_stream : stream_slave_t := as_stream(rx_uart_bfm);


begin

    th: entity work.uart_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        variable tx_byte : std_logic_vector(7 downto 0) := (others => '0');
        variable rx_byte : std_logic_vector(7 downto 0) := (others => '0');
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);

        -- Initialize to same seed to get same sequence
        rnd_stimuli.InitSeed(rnd_stimuli'instance_name);
        rnd_expected.InitSeed(rnd_stimuli'instance_name);

        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("send_one_byte") then
                tx_byte := rnd_stimuli.RandSlv(8);
                push_stream(net, tx_uart_stream, tx_byte);
                report "Sent byte 0x" & to_hstring(tx_byte);
                pop_stream(net, rx_uart_stream, rx_byte);
                check_equal(rx_byte, tx_byte, "Tx/Rx byte mismatch");
            end if;
        end loop;

        wait for 1 ms;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- -- Example total test timeout dog
    test_runner_watchdog(runner, 2 ms);

end tb;