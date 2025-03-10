-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

-- VCs
use work.basic_stream_pkg.all;
use work.i2c_cmd_vc_pkg.all;
use work.i2c_common_pkg.all;
use work.i2c_ctrl_vc_pkg.all;
use work.i2c_target_vc_pkg.all;

use work.spd_proxy_top_tb_pkg.all;

entity spd_proxy_top_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of spd_proxy_top_tb is
begin

    th: entity work.spd_proxy_top_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        variable rnd    : RandomPType;

        variable command    : cmd_t;
        variable txn_len    : natural   := 8;

        variable cpu_tx_q   : queue_t   := new_queue;
        variable cpu_rx_q   : queue_t   := new_queue;
        variable cpu_ack_q  : queue_t   := new_queue;
        variable fpga_tx_q  : queue_t   := new_queue;
        variable fpga_rx_q  : queue_t   := new_queue;
        variable data_exp_q : queue_t   := new_queue;

        procedure checked_cpu_write_then_read is
        begin
            -- start writing at a random address
            push_byte(cpu_tx_q, rnd.RandInt(0, 255));
            -- generate some random data to write
            push_random_bytes(cpu_tx_q, txn_len);
            -- save off a copy of the data to compare against later
            data_exp_q := copy(cpu_tx_q);
            i2c_write_txn(net, address(I2C_TGT_VC), cpu_tx_q, cpu_ack_q, I2C_CTRL_VC.p_actor);
            -- txn_len + START + register address
            for i in 0 to txn_len + 1 loop
                check_true(pop_boolean(cpu_ack_q), "Expected DIMMs to ack the CPU");
            end loop;
            check_true(is_empty(cpu_ack_q), "Expected CPU ACK queue to be empty");

            push_byte(cpu_tx_q, pop_byte(data_exp_q)); -- start reading at w/e address we wrote to
            i2c_mixed_txn(net, address(I2C_TGT_VC), cpu_tx_q, txn_len, cpu_rx_q, cpu_ack_q, FALSE, I2C_CTRL_VC.p_actor);
            check_true(pop_boolean(cpu_ack_q), "Expected DIMMs to ACK their address on WRITE");
            check_true(pop_boolean(cpu_ack_q), "Expected DIMMs to ACK the the byte we write");
            check_true(pop_boolean(cpu_ack_q), "Expected DIMMs to ACK their address on READ");
            check_true(is_empty(cpu_ack_q), "Expected CPU ACK queue to be empty");

            for i in 0 to txn_len-1 loop
                check_equal(pop_byte(data_exp_q), pop_byte(cpu_rx_q), "Should have read what was written");
            end loop;
            check_true(is_empty(cpu_rx_q), "Expected CPU RX queue to be empty");
        end procedure;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("fpga_only") then
                -- Starting with an idle bus, let the FPGA controller do a transaction without
                -- an interruption from the CPU
                command := build_controller_write(X"00", txn_len, fpga_tx_q);
                -- controller_write(net, command, fpga_tx_q, FALSE);
                controller_write(net, command, fpga_tx_q);
            elsif run("cpu_only") then
                -- Starting with an idle bus, let the CPU do a write transaction then read it all
                -- back out
                checked_cpu_write_then_read;
            elsif run("cpu_interrupt_fpga") then
                -- Starting with an idle bus, get the FPGA moving on a transaction which will then
                -- be interrupted by the CPU
                command := build_controller_write(X"00", 8, fpga_tx_q);
                controller_write(net, command, fpga_tx_q, FALSE); -- non-blocking

                -- At some point into the transaction, have the CPU start its own
                wait for rnd.RandInt(500, 4000) * 1 ns;

                checked_cpu_write_then_read;
            elsif run("cpu_with_simulated_start") then
                -- Starting with an idle bus, get the FPGA moving on a transaction which will then
                -- be interrupted by the CPU
                command := (
                    op => READ,
                    addr => address(I2C_TGT_VC),
                    reg => X"00",
                    len => to_std_logic_vector(txn_len, command.len'length)
                );
                -- we will be reading 0's as nothing has been written yet
                for i in 0 to txn_len - 1 loop
                    push_byte(data_exp_q, 0);
                end loop;
                -- we will issue a non blocking read since we just want to watch the CPU
                -- interrupt it anyway
                controller_read(net, command, fpga_rx_q, data_exp_q, FALSE);

                -- At some point into the transaction, have the CPU start its own
                wait for 9500 ns;
                checked_cpu_write_then_read;
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

end architecture;