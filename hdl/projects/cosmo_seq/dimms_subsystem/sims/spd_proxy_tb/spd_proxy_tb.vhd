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

use work.spd_proxy_tb_pkg.all;

entity spd_proxy_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of spd_proxy_tb is
begin

    th: entity work.spd_proxy_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        variable rnd    : RandomPType;
        variable i2c_ctrlr_msg : msg_t;

        variable command    : cmd_t;

        variable data       : std_logic_vector(7 downto 0);
        variable exp_addr   : std_logic_vector(7 downto 0);
        variable byte_len   : natural;
        variable byte_idx   : natural;

        variable cpu_tx_q   : queue_t   := new_queue;
        variable cpu_ack_q  : queue_t   := new_queue;
        variable fpga_tx_q  : queue_t   := new_queue;
        variable fpga_exp_q : queue_t   := new_queue;

        -- helper to get the internal FPGA controller doing _something_ before we have the CPU
        -- attempting to interrupt
        procedure init_controller is
        begin
            -- arbitrary for the test
            exp_addr    := X"00";
            byte_len    := 8;
            for i in 0 to byte_len - 1 loop
                push_byte(fpga_tx_q, rnd.RandInt(0, 255));
            end loop;
            fpga_exp_q := copy(fpga_tx_q);

            -- write some data in
            command := (
                op      => WRITE,
                addr    => address(I2C_DIMM1F_TGT_VC),
                reg     => std_logic_vector(exp_addr), 
                len     => to_std_logic_vector(byte_len, command.len'length)
            );
            issue_i2c_cmd(net, command, fpga_tx_q);
        end procedure;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("no_cpu_transaction") then
                init_controller;

                byte_idx := to_integer(exp_addr);
                while not is_empty(fpga_exp_q) loop
                    data        := to_std_logic_vector(pop_byte(fpga_exp_q), data'length);
                    exp_addr    := to_std_logic_vector(byte_idx, exp_addr'length);
                    check_written_byte(net, I2C_DIMM1F_TGT_VC, data, exp_addr);
                    byte_idx := byte_idx + 1;
                end loop;
                expect_stop(net, I2C_DIMM1F_TGT_VC);
            elsif run("cpu_transaction") then
                -- Get the FPGA controller started on a transaction
                init_controller;

                -- At some point into the transaction, have the CPU start its own
                wait for rnd.RandInt(500, 4000) * 1 ns;

                push_byte(cpu_tx_q, to_integer(rnd.RandSlv(0, 255, 8)));
                i2c_write_txn(net, address(I2C_DIMM1F_TGT_VC), cpu_tx_q, cpu_ack_q, I2C_CTRL_VC.p_actor);
             
            elsif run("cpu_transaction_regression") then
                -- Get the FPGA controller started on a transaction
                init_controller;

                -- At some point into the transaction, have the CPU start its own
                wait for rnd.RandInt(500, 4000) * 1 ns;

                push_byte(cpu_tx_q, to_integer(rnd.RandSlv(0, 255, 8)));
                i2c_write_txn(net, address(I2C_DIMM1F_TGT_VC), cpu_tx_q, cpu_ack_q, I2C_CTRL_VC.p_actor);

            elsif run("cpu_with_simulated_start") then
                -- Get the FPGA controller started on a transaction
                init_controller;

                -- At some point into the transaction, have the CPU start its own
                wait for 9500 ns;

                push_byte(cpu_tx_q, to_integer(rnd.RandSlv(0, 255, 8)));
                i2c_write_txn(net, address(I2C_DIMM1F_TGT_VC), cpu_tx_q, cpu_ack_q, I2C_CTRL_VC.p_actor);
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

end architecture;