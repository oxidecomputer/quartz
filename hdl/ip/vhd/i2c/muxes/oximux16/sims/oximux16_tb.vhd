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

use work.i2c_ctrl_vc_pkg.all;

entity oximux16_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of oximux16_tb is
    -- CHB enabled results from sel = 00
    -- CHC enabled results from sel = 01
    -- CHA enabled results from sel = 10
    constant chA_selected : std_logic_vector(1 downto 0) := "10";
    constant chB_selected : std_logic_vector(1 downto 0) := "00";
    constant chC_selected : std_logic_vector(1 downto 0) := "01";
    constant not_selected : std_logic_vector(1 downto 0) := "11";

    constant mux0_addr : std_logic_vector(6 downto 0) := 7x"70";

begin

    th: entity work.oximux16_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias mux0_sel is << signal th.mux0_sel : std_logic_vector(1 downto 0) >>;
        alias mux1_sel is << signal th.mux1_sel : std_logic_vector(1 downto 0) >>;
        alias mux2_sel is << signal th.mux2_sel : std_logic_vector(1 downto 0) >>;
        alias mux3_sel is << signal th.mux3_sel : std_logic_vector(1 downto 0) >>;
        alias mux4_sel is << signal th.mux4_sel : std_logic_vector(1 downto 0) >>;
        variable tx_queue        : queue_t               := new_queue;
        variable rx_queue        : queue_t               := new_queue;
        variable ack_queue        : queue_t              := new_queue;
        variable expected_ack_queue        : queue_t     := new_queue;
        variable ack_status : boolean := false;
        variable expected_reg_data : std_logic_vector(15 downto 0) := (others => '0');
        variable reg_data : std_logic_vector(15 downto 0) := (others => '0');

    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("single-mux-select") then
                check_equal(mux0_sel, not_selected, "Mux not disconnected at start");
                -- Enable ch0 of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"00")));
                blocking_i2c_write_txn (net, mux0_addr, tx_queue, ack_queue);
                check_true(contains_all_acks(ack_queue), "Either no acks or some Nacks were found");
                -- Verify mux ch0 is selected
                check_equal(mux0_sel, chA_selected, "CHA Mux 0 not selected after write");
                check_equal(mux1_sel, not_selected, "CHA Mux 1 not selected after write");
                check_equal(mux2_sel, not_selected, "CHA Mux 2 not selected after write");
                check_equal(mux3_sel, not_selected, "CHA Mux 3 not selected after write");
                check_equal(mux4_sel, not_selected, "CHA Mux 4 not selected after write");

                -- Now read back the register
                blocking_i2c_read_txn(net, mux0_addr, 2, rx_queue, ack_status);
                check_true(ack_status, "Target didn't ack during readback");
                reg_data := (others => '0');
                reg_data(7 downto 0) := to_std_logic_vector(pop_byte(rx_queue), 8);
                reg_data(15 downto 8) := to_std_logic_vector(pop_byte(rx_queue), 8);
                check_equal(reg_data, 1, "CHA Readback didn't return expected value");
            elsif run("nack-wrong-target") then
                check_equal(mux0_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux1_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux2_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux3_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux4_sel, not_selected, "Mux not disconnected at start");

                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"00")));
                -- Write *something* to the wrong target address, expecting a NACK
                blocking_i2c_write_txn(net, 7x"75", tx_queue, ack_queue);
                check_true(target_addr_nack(ack_queue), "Target unexpectedly ACK'd write at wrong address");
                check_equal(mux0_sel, not_selected, "Mux not still disconnected after NACK'd write");
                check_equal(mux1_sel, not_selected, "Mux not still disconnected after NACK'd write");
                check_equal(mux2_sel, not_selected, "Mux not still disconnected after NACK'd write");
                check_equal(mux3_sel, not_selected, "Mux not still disconnected after NACK'd write");
                check_equal(mux4_sel, not_selected, "Mux not still disconnected after NACK'd write");

                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                -- Write *something* to the wrong target address, expecting a NACK
                blocking_i2c_read_txn(net, 7x"75", 1, rx_queue, ack_status);
                check_false(ack_status, "Target ACK'd read at wrong address");

            elsif run("multi-channel-attempt") then
                check_equal(mux0_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux1_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux2_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux3_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux4_sel, not_selected, "Mux not disconnected at start");
                -- Enable ch0 of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"01")));
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"00")));
                blocking_i2c_write_txn (net, mux0_addr, tx_queue, ack_queue);
                -- Verify mux ch0 is selected
                check_equal(mux0_sel, chA_selected, "CHA Mux not selected after write");
                check_equal(mux1_sel, not_selected, "CHA Mux 1 not selected after write");
                check_equal(mux2_sel, not_selected, "CHA Mux 2 not selected after write");
                check_equal(mux3_sel, not_selected, "CHA Mux 3 not selected after write");
                check_equal(mux4_sel, not_selected, "CHA Mux 4 not selected after write");
                -- Now errantly try to enable multiple channels
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"03")));
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"00")));
                blocking_i2c_write_txn (net, mux0_addr, tx_queue, ack_queue);
                -- We expect a NACK on the control register 2nd byte, and the mux should remain in its previous state
                push_boolean(expected_ack_queue, true);  -- ACK on the target address byte
                push_boolean(expected_ack_queue, true);  -- ACK on the first byte
                push_boolean(expected_ack_queue, false);  -- NACK on the control register 2nd byte where we check things
                check_true(ack_queue_matches(ack_queue, expected_ack_queue), "Ack queue does not match expected ack queue");
                -- Verify mux ch0 is selected
                check_equal(mux0_sel, chA_selected, "CHA Mux not selected after write");
                check_equal(mux1_sel, not_selected, "CHA Mux 1 not selected after write");
                check_equal(mux2_sel, not_selected, "CHA Mux 2 not selected after write");
                check_equal(mux3_sel, not_selected, "CHA Mux 3 not selected after write");
                check_equal(mux4_sel, not_selected, "CHA Mux 4 not selected after write");

            elsif run("invalid-channel15-attempt") then
                check_equal(mux0_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux1_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux2_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux3_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux4_sel, not_selected, "Mux not disconnected at start");
                -- Enable ch0 of the mux via i2c command
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"00")));
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"80")));
                blocking_i2c_write_txn (net, mux0_addr, tx_queue, ack_queue);
                push_boolean(expected_ack_queue, true);  -- ACK on the target address byte
                push_boolean(expected_ack_queue, true);  -- ACK on the first byte
                push_boolean(expected_ack_queue, false);  -- NACK on the control register 2nd byte where we check things
                check_true(ack_queue_matches(ack_queue, expected_ack_queue), "Ack queue does not match expected ack queue");
                -- Verify nothing was selected
                check_equal(mux0_sel, not_selected, "Mux 1 not selected after write");
                check_equal(mux1_sel, not_selected, "Mux 1 not selected after write");
                check_equal(mux2_sel, not_selected, "Mux 2 not selected after write");
                check_equal(mux3_sel, not_selected, "Mux 3 not selected after write");
                check_equal(mux4_sel, not_selected, "Mux 4 not selected after write");
                
            elsif run("sunny-day-select-deselect") then
                check_equal(mux0_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux1_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux2_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux3_sel, not_selected, "Mux not disconnected at start");
                check_equal(mux4_sel, not_selected, "Mux not disconnected at start");
                
                -- bit15 is reserved so we don't use it
                for i in 0 to 14 loop
                    reg_data := (others => '0');
                    reg_data(i) := '1';  -- set the i'th bit
                    expected_reg_data := reg_data;

                    push_byte(tx_queue, to_integer(reg_data(7 downto 0)));
                    push_byte(tx_queue, to_integer(reg_data(15 downto 8)));
                    blocking_i2c_write_txn (net, mux0_addr, tx_queue, ack_queue);
                    check_true(contains_all_acks(ack_queue), "Either no acks or some Nacks were found loop: " & integer'image(i));
                -- Verify mux ch0 is selected
                    if i = 0 then
                        check_equal(mux0_sel, chA_selected, "CHA Mux 0 not selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 1 then
                        check_equal(mux0_sel, chB_selected, "CHB Mux 0 not selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 2 then
                        check_equal(mux0_sel, chC_selected, "CHC Mux 0 not selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 3 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, chA_selected, "CHA Mux 1 not selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 4 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, chB_selected, "CHB Mux 1 not selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 5 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, chC_selected, "CHC Mux 1 not selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 6 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, chA_selected, "CHA Mux 2 not selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 7 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, chB_selected, "CHB Mux 2 not selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 8 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, chC_selected, "CHC Mux 2 not selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 9 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");  
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, chA_selected, "CHA Mux 3 not selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 10 then   
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, chB_selected, "CHB Mux 3 not selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 11 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, chC_selected, "CHC Mux 3 not selected after write");
                        check_equal(mux4_sel, not_selected, "Mux 4 selected after write");
                    elsif i = 12 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, chA_selected, "CHA Mux 4 not selected after write");
                    elsif i = 13 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, chB_selected, "CHB Mux 4 not selected after write");
                    elsif i = 14 then
                        check_equal(mux0_sel, not_selected, "Mux 0 selected after write");
                        check_equal(mux1_sel, not_selected, "Mux 1 selected after write");
                        check_equal(mux2_sel, not_selected, "Mux 2 selected after write");
                        check_equal(mux3_sel, not_selected, "Mux 3 selected after write");
                        check_equal(mux4_sel, chC_selected, "CHC Mux 4 not selected after write");
                    end if;

                    -- Now read back the register
                    blocking_i2c_read_txn(net, mux0_addr, 2, rx_queue, ack_status);
                    check_true(ack_status, "Target didn't ack during readback");
                    wait for 1 us;
    
                    reg_data(7 downto 0) := to_std_logic_vector(pop_byte(rx_queue), 8);
                    reg_data(15 downto 8) := to_std_logic_vector(pop_byte(rx_queue), 8);
                    check_equal(reg_data, expected_reg_data, "readback didn't return expected value");

                end loop;
            end if;

        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;