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

use work.i2c_cmd_vc_pkg.all;
use work.i2c_target_vc_pkg.all;
use work.basic_stream_pkg.all;

use work.i2c_common_pkg.all;

entity i2c_ctrl_txn_layer_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of i2c_ctrl_txn_layer_tb is
    constant CLK_PER_NS         : positive          := 8;
    constant I2C_TARGET_VC      : i2c_target_vc_t   := new_i2c_target_vc;
    constant TX_DATA_SOURCE_VC  : basic_source_t    := new_basic_source(8);
    constant RX_DATA_SINK_VC    : basic_sink_t      := new_basic_sink(8);
    constant I2C_CMD_VC         : i2c_cmd_vc_t      := new_i2c_cmd_vc;
begin

    th: entity work.i2c_ctrl_txn_layer_th
        generic map (
            CLK_PER_NS      => CLK_PER_NS,
            TX_SOURCE       => TX_DATA_SOURCE_VC,
            RX_SINK         => RX_DATA_SINK_VC,
            I2C_TARGET_VC   => I2C_TARGET_VC,
            I2C_CMD_VC      => I2C_CMD_VC
        );

    bench: process
        alias reset is << signal th.reset : std_logic >>;

        variable command    : cmd_t;
        variable ack        : boolean := false;

        variable data       : std_logic_vector(7 downto 0);
        variable exp_addr   : std_logic_vector(7 downto 0);
        variable exp_data   : std_logic_vector(7 downto 0);
        variable byte_len   : natural;

        variable rnd            : RandomPType;

        procedure generate_abort is
        begin
            -- DUT is operating in Fast Mode+, so the fscl period is 1000ns. Send the abort at
            -- some point during the byte transfer. Begin halfway through the first bit period
            -- (500 ns) to avoid a potential ACK conflict
            wait for rnd.RandInt(550, 6000) * 1 ns;
            push_abort(net, I2C_CMD_VC);
            expect_stop(net, I2C_TARGET_VC);
        end procedure;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("nack_wrong_address") then
                command := CMD_RESET;
                push_i2c_cmd(net, I2C_CMD_VC, command);
                start_byte_ack(net, I2C_TARGET_VC, ack);
                check_false(ack, "Peripheral did not NACK incorrect address");
                -- transaction is over, receive STOP event
                expect_stop(net, I2C_TARGET_VC);
            elsif run("write_and_read_one_byte") then
                -- arbitrary for the test
                exp_addr    := X"9E";
                exp_data    := X"A5";

                -- write some data in
                command := (
                    op      => WRITE,
                    addr    => address(I2C_TARGET_VC),
                    reg     => exp_addr, 
                    len     => to_std_logic_vector(1, command.len'length)
                );
                push_i2c_cmd(net, I2C_CMD_VC, command);

                start_byte_ack(net, I2C_TARGET_VC, ack);
                check_true(ack, "Peripheral did not ACK correct address");

                push_basic_stream(net, TX_DATA_SOURCE_VC, exp_data);
                check_written_byte(net, I2C_TARGET_VC, exp_data, exp_addr);

                expect_stop(net, I2C_TARGET_VC);

                -- read it back out
                command := (
                    op      => READ,
                    addr    => address(I2C_TARGET_VC),
                    reg     => X"--", -- READ uses internal address set by a WRITE to the peripheral
                    len     => to_std_logic_vector(1, command.len'length)
                );
                push_i2c_cmd(net, I2C_CMD_VC, command);

                start_byte_ack(net, I2C_TARGET_VC, ack);
                check_true(ack, "Peripheral did not ACK correct address");

                pop_basic_stream(net, RX_DATA_SINK_VC, data);
                check_equal(data, exp_data, "Expected read data to match");

                expect_stop(net, I2C_TARGET_VC);
            elsif run("write_and_read_many_bytes") then
                -- arbitrary for the test
                exp_addr    := X"00";
                byte_len    := 8;

                -- write some data in
                command := (
                    op      => WRITE,
                    addr    => address(I2C_TARGET_VC),
                    reg     => std_logic_vector(exp_addr), 
                    len     => to_std_logic_vector(byte_len, command.len'length)
                );
                push_i2c_cmd(net, I2C_CMD_VC, command);

                start_byte_ack(net, I2C_TARGET_VC, ack);
                check_true(ack, "Peripheral did not ACK correct address");

                for byte_idx in 0 to byte_len - 1 loop
                    data        := std_logic_vector(to_std_logic_vector(byte_idx, data'length));
                    exp_addr    := to_std_logic_vector(byte_idx, exp_addr'length);
                    push_basic_stream(net, TX_DATA_SOURCE_VC, data);
                end loop;

                for byte_idx in 0 to byte_len - 1 loop
                    data        := std_logic_vector(to_std_logic_vector(byte_idx, data'length));
                    exp_addr    := to_std_logic_vector(byte_idx, exp_addr'length);
                    check_written_byte(net, I2C_TARGET_VC, data, exp_addr);
                end loop;

                expect_stop(net, I2C_TARGET_VC);

                -- read it back out
                exp_addr    := X"00";
                command     := (
                    op      => RANDOM_READ,
                    addr    => address(I2C_TARGET_VC),
                    reg     => std_logic_vector(exp_addr),
                    len     => to_std_logic_vector(byte_len, command.len'length)
                );
                push_i2c_cmd(net, I2C_CMD_VC, command);

                -- ACK WRITE portion of the random read
                start_byte_ack(net, I2C_TARGET_VC, ack);
                check_true(ack, "Peripheral did not ACK correct address");

                -- ACK READ portion of the random read
                start_byte_ack(net, I2C_TARGET_VC, ack);
                check_true(ack, "Peripheral did not ACK correct address");

                for byte_idx in 0 to byte_len - 1 loop
                    exp_data := std_logic_vector(to_std_logic_vector(byte_idx, exp_data'length));
                    pop_basic_stream(net, RX_DATA_SINK_VC, data);
                    wait for 1 us;
                    check_equal(data, exp_data, "Expected read data to match");
                end loop;

                expect_stop(net, I2C_TARGET_VC);
            elsif run("abort_transaction") then
                -- create a command
                exp_addr    := X"00";
                byte_len    := 8;
                command := (
                    op      => RANDOM_READ,
                    addr    => address(I2C_TARGET_VC),
                    reg     => std_logic_vector(exp_addr),
                    len     => to_std_logic_vector(byte_len, command.len'length)
                );

                -- Abort first START byte
                push_i2c_cmd(net, I2C_CMD_VC, command);
                -- receive and drop the START event
                expect_message(net, I2C_TARGET_VC, got_start);
                -- abort first start byte
                generate_abort;

                -- Abort write byte
                push_i2c_cmd(net, I2C_CMD_VC, command);
                -- receive and drop the START event
                expect_message(net, I2C_TARGET_VC, got_start);
                -- receive and drop the START byte
                expect_message(net, I2C_TARGET_VC, address_matched);
                -- abort during write byte
                generate_abort;

                -- Abort repeated start byte
                push_i2c_cmd(net, I2C_CMD_VC, command);
                -- receive and drop the START event
                expect_message(net, I2C_TARGET_VC, got_start);
                -- receive and drop the START byte
                expect_message(net, I2C_TARGET_VC, address_matched);
                -- receive and drop the START event
                expect_message(net, I2C_TARGET_VC, got_start);
                -- abort during repeated start byte
                generate_abort;

                -- Abort repeated start byte
                push_i2c_cmd(net, I2C_CMD_VC, command);
                -- receive and drop the START event
                expect_message(net, I2C_TARGET_VC, got_start);
                -- receive and drop the START byte
                expect_message(net, I2C_TARGET_VC, address_matched);
                -- receive and drop the START event
                expect_message(net, I2C_TARGET_VC, got_start);
                -- receive and drop the START byte
                expect_message(net, I2C_TARGET_VC, address_matched);
                -- abort during read byte
                generate_abort;
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 1 ms);

end tb;