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

use work.i2c_ctrl_vc_pkg.all;

entity i2c_mux_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of i2c_mux_tb is
    -- CHB enabled results from sel = 00
    -- CHC enabled results from sel = 01
    -- CHA enabled results from sel = 10
    constant chA_selected : std_logic_vector(1 downto 0) := "10";
    constant chB_selected : std_logic_vector(1 downto 0) := "00";
    constant chC_selected : std_logic_vector(1 downto 0) := "01";
    constant not_selected : std_logic_vector(1 downto 0) := "11";

begin

    th: entity work.i2c_mux_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias mux_sel is << signal th.mux_sel : std_logic_vector(1 downto 0) >>;
        variable tx_queue        : queue_t               := new_queue;
        variable rx_queue        : queue_t               := new_queue;
        variable ack_queue        : queue_t              := new_queue;
        variable expected_ack_queue        : queue_t     := new_queue;
        variable ack_status : boolean := false;

    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("Single-mux-select") then
                check_equal(mux_sel, not_selected, "Mux not disconnected at start");
                -- Enable ch0 of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                i2c_write_txn (net, 7x"70", tx_queue, ack_queue);
                check_true(contains_all_acks(ack_queue), "Either no acks or some Nacks were found");
                -- Verify mux ch0 is selected
                check_equal(mux_sel, chA_selected, "CHA Mux not selected after write");

                -- Now read back the register
                i2c_read_txn(net, 7x"70", 1, rx_queue, ack_status);
                check_true(ack_status, "Target didn't ack during readback");
                check_equal(pop_byte(rx_queue), 1, "CHA Readback didn't return expected value");

            elsif run("nack-wrong-target") then
                check_equal(mux_sel, not_selected, "Mux not disconnected at start");
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                -- Write *something* to the wrong target address, expecting a NACK
                i2c_write_txn (net, 7x"75", tx_queue, ack_queue);
                check_true(target_addr_nack(ack_queue), "Target unexpectedly ACK'd write at wrong address");
                check_equal(mux_sel, not_selected, "Mux not still disconnected after NACK'd write");

                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                -- Write *something* to the wrong target address, expecting a NACK
                i2c_read_txn (net, 7x"75", 1, rx_queue, ack_status);
                check_false(ack_status, "Target ACK'd read at wrong address");

            elsif run("multi-channel-attempt") then
                check_equal(mux_sel, not_selected, "Mux not disconnected at start");
                -- Enable ch0 of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                i2c_write_txn (net, 7x"70", tx_queue, ack_queue);
                -- Verify mux ch0 is selected
                check_equal(mux_sel, chA_selected, "CHA Mux not selected after write");
                -- Now errantly try to enable multiple channels
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"03")));
                i2c_write_txn (net, 7x"70", tx_queue, ack_queue);
                -- We expect a NACK on the control register 2nd byte, and the mux should remain in its previous state
                push_boolean(expected_ack_queue, true);  -- ACK on the target address byte
                push_boolean(expected_ack_queue, false);  -- NACK on the control register 2nd byte
                check_true(ack_queue_matches(ack_queue, expected_ack_queue), "Ack queue does not match expected ack queue");
                -- Verify mux ch0 is selected
                check_equal(mux_sel, chA_selected, "CHA Mux not selected after write");


            elsif run("sunny-day-select-deselect") then
                check_equal(mux_sel, not_selected, "Mux not disconnected at start");
                -- Enable ch0 of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                i2c_write_txn (net, 7x"70", tx_queue, ack_queue);
                -- Verify mux ch0 is selected
                check_equal(mux_sel, chA_selected, "CHA Mux not selected after write");

                -- Now read back the register
                i2c_read_txn(net, 7x"70", 1, rx_queue, ack_status);
                check_true(ack_status, "Target didn't ack during readback");
                check_equal(pop_byte(rx_queue), 1, "CHA Readback didn't return expected value");

                -- Enable ch1 of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"02")));
                i2c_write_txn (net, 7x"70", tx_queue, ack_queue);
                -- Verify mux ch1 is selected
                check_equal(mux_sel, chB_selected, "CHB Mux not selected after write");

                -- Now read back the register
                i2c_read_txn(net, 7x"70", 1, rx_queue, ack_status);
                check_true(ack_status, "Target didn't ack during readback");
                check_equal(pop_byte(rx_queue), 2, "CHB Readback didn't return expected value");

                -- Enable ch2 of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"04")));
                i2c_write_txn (net, 7x"70", tx_queue, ack_queue);
                -- Verify mux ch1 is selected
                check_equal(mux_sel, chC_selected, "CHC Mux not selected after write");

                -- Now read back the register
                i2c_read_txn(net, 7x"70", 1, rx_queue, ack_status);
                check_true(ack_status, "Target didn't ack during readback");
                check_equal(pop_byte(rx_queue), 4, "CHC Readback didn't return expected value");

                -- Disable all of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"00")));
                i2c_write_txn (net, 7x"70", tx_queue, ack_queue);
                -- Verify mux ch1 is selected
                check_equal(mux_sel, not_selected, "Some mux still not selected after write");

                -- Now read back the register
                i2c_read_txn(net, 7x"70", 1, rx_queue, ack_status);
                check_true(ack_status, "Target didn't ack during readback");
                check_equal(pop_byte(rx_queue), 0, "Readback didn't return expected value 0");

            end if;

        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;