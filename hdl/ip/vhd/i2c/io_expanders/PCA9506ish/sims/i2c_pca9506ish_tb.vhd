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
use work.i2c_pca9506ish_sim_pkg.all;
use work.pca9506_regs_pkg.all;
use work.pca9506_pkg.all;

entity i2c_pca9506ish_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of i2c_pca9506ish_tb is

    constant addr0 : std_logic_vector(6 downto 0) := 7x"20";
    constant addr1 : std_logic_vector(6 downto 0) := 7x"21";

begin

    th: entity work.i2c_pca9506ish_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias int0_n is << signal th.int0_n : std_logic >>;
        alias io0 is << signal th.io0 : pca9506_pin_t >>;
        alias io0_o is << signal th.io0_o: pca9506_pin_t >>;
        alias io0_oe is << signal th.io0_oe: pca9506_pin_t >>;
        variable exp_queue : queue_t := new_queue;
        variable tx_queue        : queue_t               := new_queue;
        variable rx_queue        : queue_t               := new_queue;
        variable ack_queue        : queue_t              := new_queue;
        variable expected_ack_queue        : queue_t     := new_queue;
        variable ack_status : boolean := false;
        variable user_int       : integer;
        variable user_slv8      : std_logic_vector(7 downto 0);
        variable data_32         : std_logic_vector(31 downto 0);

    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("check-read") then
                -- read a default value from an internal register
                read_pca9506_reg(net, addr0, IP0_OFFSET, 1, rx_queue, ack_queue);
                check_equal(pop_byte(rx_queue), 0, "Non-reset value read from IP0_OFFSET expander 0");
                check_true(is_empty(rx_queue), "rx queue not empty");
                -- check one of the default 1 registers
                read_pca9506_reg(net, addr0, IOC0_OFFSET, 1, rx_queue, ack_queue);
                check_equal(pop_byte(rx_queue), 255, "Non-reset value read from IOC0_OFFSET expander 0");
                check_true(is_empty(rx_queue), "rx queue not empty");
                -- check via axi also
                read_bus(net, bus_handle, To_StdLogicVector(IOC0_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(X"000000FF"), "Non-reset value read from IOC0_OFFSET expander 0 via axi");

                -- check other device
                -- read a default value from an internal register
                read_pca9506_reg(net, addr1, IP0_OFFSET, 1, rx_queue, ack_queue);
                check_equal(pop_byte(rx_queue), 0, "Non-reset value read from IP0_OFFSET expander 1");
                check_true(is_empty(rx_queue), "rx queue not empty");
                -- check one of the default 1 registers
                read_pca9506_reg(net, addr1, IOC0_OFFSET, 1, rx_queue, ack_queue);
                check_equal(pop_byte(rx_queue), 255, "Non-reset value read from IOC0_OFFSET expander 1");
                check_true(is_empty(rx_queue), "rx queue not empty");
            elsif run("check-write") then
                -- write something else to a register that defaults to 1's
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"aa")));
                write_pca9506_reg(net, addr0, IOC0_OFFSET, tx_queue, ack_queue);
                flush(ack_queue);  -- don't want lingering acks from this transaction
                -- read it back and check
                read_pca9506_reg(net, addr0, IOC0_OFFSET, 1, rx_queue, ack_queue);
                check_equal(pop_byte(rx_queue), 16#AA#, "Non-matching register at IOC0_OFFSET expander 0");
                check_true(is_empty(rx_queue), "rx queue not empty");
                -- check other channel
               -- read a default value from an internal register
               read_pca9506_reg(net, addr1, IOC0_OFFSET, 1, rx_queue, ack_queue);
               check_equal(pop_byte(rx_queue), 255, "Non-reset value read from IOC0_OFFSET expander 1");
               check_true(is_empty(rx_queue), "rx queue not empty");

                -- write something else to a register that defaults to 1's
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"aa")));
                write_pca9506_reg(net, addr1, IOC0_OFFSET, tx_queue, ack_queue);
                flush(ack_queue);  -- don't want lingering acks from this transaction
                -- read it back and check
                read_pca9506_reg(net, addr1, IOC0_OFFSET, 1, rx_queue, ack_queue);
                check_equal(pop_byte(rx_queue), 16#AA#, "Non-matching register at IOC0_OFFSET");
                check_true(is_empty(rx_queue), "rx queue not empty");
            elsif run("check-auto-inc-no-sub-cat-no-wrap") then
                -- write something else to a register that defaults to 1's
                -- category size is 5 register, we'll write all 3 so we don't write 
                -- all and don't wrap
                -- also put bytes in an expected queue so we can check them later
                user_int := 16#a#;
                for i in 0 to 2 loop
                    push_byte(tx_queue, to_integer(To_StdLogicVector(user_int+i, 4) & To_StdLogicVector(user_int+i, 4)));
                    push_byte(exp_queue, to_integer(To_StdLogicVector(user_int+i, 4) & To_StdLogicVector(user_int+i, 4)));
                end loop;
                write_pca9506_reg(net, addr0, IOC0_OFFSET, tx_queue, ack_queue);
                flush(ack_queue);  -- don't want lingering acks from this transaction

                -- we'll read them out 1-by-one so we're not confounding any 
                -- auto-inc or wrap issues
                for i in 0 to 2 loop
                    -- read it back and check
                    read_pca9506_reg(net, addr0, IOC0_OFFSET + i, 1, rx_queue, ack_queue);
                    check_equal(pop_byte(rx_queue), pop_byte(exp_queue), "Non-matching register at IOC" & to_string(i) & "_OFFSET");
                end loop;
            elsif run("check-auto-inc-no-full-cat-no-wrap") then
                -- verify write category with auto increment, write-size < full category
                -- write something else to a register that defaults to 1's
                -- category size is 5 register, we'll write all 5 so we don't write 
                -- all and don't wrap
                -- also put bytes in an expected queue so we can check them later
                user_int := 16#a#;
                for i in 0 to 4 loop
                    push_byte(tx_queue, to_integer(To_StdLogicVector(user_int+i, 4) & To_StdLogicVector(user_int+i, 4)));
                    push_byte(exp_queue, to_integer(To_StdLogicVector(user_int+i, 4) & To_StdLogicVector(user_int+i, 4)));
                end loop;
                write_pca9506_reg(net, addr0, IOC0_OFFSET, tx_queue, ack_queue);
                flush(ack_queue);  -- don't want lingering acks from this transaction

                -- we'll read them out 1-by-one so we're not confounding any 
                -- auto-inc or wrap issues
                for i in 0 to 4 loop
                    -- read it back and check
                    read_pca9506_reg(net, addr0, IOC0_OFFSET + i, 1, rx_queue, ack_queue);
                    check_equal(pop_byte(rx_queue), pop_byte(exp_queue), "Non-matching register at IOC" & to_string(i) & "_OFFSET");
                end loop;

            elsif run("check-auto-inc-cat-wrap") then
                -- verify write category with auto increment, write-size > full category
                -- write something else to a register that defaults to 1's
                -- category size is 5 register, we'll write all 6 so we don't write 
                -- all and don't wrap
                -- also put bytes in an expected queue so we can check them later
                user_int := 16#a#;
                push_byte(tx_queue, to_integer(To_StdLogicVector(user_int, 4) & To_StdLogicVector(user_int, 4)));
                -- we expect this value to be wrapped and over-written so we're going to not push it into the expected queue
                user_int := user_int + 1;
                -- loop through (and wrap) the final 5 bytes
                for i in 0 to 4 loop
                    push_byte(tx_queue, to_integer(To_StdLogicVector(user_int+i, 4) & To_StdLogicVector(user_int+i, 4)));
                    push_byte(exp_queue, to_integer(To_StdLogicVector(user_int+i, 4) & To_StdLogicVector(user_int+i, 4)));
                end loop;
                write_pca9506_reg(net, addr0, IOC0_OFFSET, tx_queue, ack_queue);
                flush(ack_queue);  -- don't want lingering acks from this transaction
    
                -- we'll read them out 1-by-one so we're not confounding any 
                -- auto-inc or wrap issues.  we also expect a wrap here so the last expected value
                -- should be at the first register due to the wrap. We'll read that at the end out
                -- of the loop
                for i in 1 to 4 loop
                    -- read it back and check
                    read_pca9506_reg(net, addr0, IOC0_OFFSET + i, 1, rx_queue, ack_queue);
                    check_equal(pop_byte(rx_queue), pop_byte(exp_queue), "Non-matching register at IOC" & to_string(i) & "_OFFSET");
                end loop;
                read_pca9506_reg(net, addr0, IOC0_OFFSET, 1, rx_queue, ack_queue);
                check_equal(pop_byte(rx_queue), pop_byte(exp_queue), "Non-matching register at IOC0_OFFSET");

            elsif run("check-no-inc-cat-writes") then
                -- verify write category without auto increment, write-size > full category
                user_int := 16#a#;
                -- Put 3 non-wrapping bytes in, expect only the last one at the og register
                for i in 0 to 2 loop
                    push_byte(tx_queue, to_integer(To_StdLogicVector(user_int+i, 4) & To_StdLogicVector(user_int+i, 4)));
                end loop;
                push_byte(exp_queue, to_integer(To_StdLogicVector(user_int+2, 4) & To_StdLogicVector(user_int+2, 4)));
                push_byte(exp_queue, 16#FF#);  -- expect reset vals for the remaining registers
                push_byte(exp_queue, 16#FF#);  -- expect reset vals for the remaining registers
                push_byte(exp_queue, 16#FF#);  -- expect reset vals for the remaining registers
                push_byte(exp_queue, 16#FF#);  -- expect reset vals for the remaining registers

                write_pca9506_reg(net, addr0, IOC0_OFFSET, tx_queue, ack_queue, auto_inc => false);
                flush(ack_queue);  -- don't want lingering acks from this transaction

                for i in 0 to 4 loop
                    -- read it back and check
                    read_pca9506_reg(net, addr0, IOC0_OFFSET + i, 1, rx_queue, ack_queue);
                    check_equal(pop_byte(rx_queue), pop_byte(exp_queue), "Non-matching register at IOC" & to_string(i) & "_OFFSET");
                end loop;
            elsif run("check-basic-irq") then
                -- verify basic irq functionality
                check_equal('1', int0_n, "irq is asserted incorrectly at reset");
                -- everything is an input and driven to '0' by the th initialization, but all irqs should be masked, 
                -- toggle an input and we should still see no irq fire.
                io0(0)(0) <= '1';
                wait for 200 ns; -- allow synchronization etc
                check_equal('1', int0_n, "irq is asserted incorrectly after i/o toggle while masked");
                io0(0)(0) <= '0'; -- set back to default
                wait for 200 ns; -- allow synchronization etc

                -- de-mask this irq
                single_write_pca9506_reg(net, addr0, MSK0_OFFSET, X"FE", ack_status);
                wait for 200 ns; -- make sure things propagate.
                check_equal('1', int0_n, "irq is asserted incorrectly after de-masking with no toggle");
                io0(0)(0) <= '1';  -- toggle pin
                wait for 200 ns; -- allow synchronization etc
                check_equal('0', int0_n, "irq did not assert after de-masking and i/o toggle");

                -- return the I/O to its previous state, irq should go away
                io0(0)(0) <= '0';  -- toggle pin
                wait for 200 ns; -- allow synchronization etc
                check_equal('1', int0_n, "irq still asserted after returning I/O to previous state");
            elsif run("irq-clears-on-read") then
                -- de-mask this irq
                single_write_pca9506_reg(net, addr0, MSK0_OFFSET, X"FE", ack_status);
                wait for 200 ns; -- make sure things propagate.
                check_equal('1', int0_n, "irq is asserted incorrectly after de-masking with no toggle");
                io0(0)(0) <= '1';  -- toggle pin
                wait for 200 ns; -- allow synchronization etc
                check_equal('0', int0_n, "irq did not assert after de-masking and i/o toggle");

                -- now read the register, this should clear the irq
                read_pca9506_reg(net, addr0, IP0_OFFSET, 1, rx_queue, ack_queue);
                check_equal('1', int0_n, "irq still asserted (incorrectly) after reading IP0_OFFSET");

                -- now toggle i/o again this should generate a new irq
                io0(0)(0) <= '0';  -- toggle pin low again
                wait for 200 ns; -- allow synchronization etc
                check_equal('0', int0_n, "irq did not assert after i/o toggle");

            elsif run("multi-register-irq") then
                -- verify multi-register irq functionality
                -- de-mask i/o (0,0)
                single_write_pca9506_reg(net, addr0, MSK0_OFFSET, X"FE", ack_status);
                -- de-mask i/o (4,0)
                single_write_pca9506_reg(net, addr0, MSK4_OFFSET, X"FE", ack_status);
                check_equal('1', int0_n, "irq is asserted incorrectly after de-masking with no toggle");
                io0(0)(0) <= '1';  -- toggle pin
                io0(4)(0) <= '1';  -- toggle pin
                wait for 200 ns; -- allow synchronization etc
                check_equal('0', int0_n, "irq did not assert after de-masking and i/o toggle");
                
                -- read one of the registers, not the other, irq should still be asserted
                read_pca9506_reg(net, addr0, IP0_OFFSET, 1, rx_queue, ack_queue);
                check_equal('0', int0_n, "irq incorrectly de-asserted after reading only IP0_OFFSET");

                -- now read other register, irq should clear
                read_pca9506_reg(net, addr0, IP4_OFFSET, 1, rx_queue, ack_queue);
                check_equal('1', int0_n, "irq still asserted (incorrectly) after reading IP4_OFFSET");
            -- verify all inputs are read
            elsif run("read_inputs") then
                -- verify all inputs are read
                -- going to do this bit-wise per port so we make sure everything is matching correctly
                for i in 0 to 4 loop  -- Loop each port
                    for j in 0 to 7 loop  -- Loop each bit
                        -- everything is an input so we should not see any io0_oebits set
                        check_equal(io0_oe(i)(j), '0', "io0_oebit " & to_string(j) & " on port " & to_string(i) & " is set for an input");
                        -- Set the bit under test to '1'
                        io0(i)(j) <= '1';
                        wait for 200 ns; -- allow synchronization etc
                        -- Read the corresponding input register and check the value
                        read_pca9506_reg(net, addr0, IP0_OFFSET + i, 1, rx_queue, ack_queue);
                        flush(ack_queue);  -- don't want lingering acks from this transaction
                        user_int := to_integer(shift_left(std_logic_vector'("00000001"), j));
                        check_equal(pop_byte(rx_queue), user_int, "Input bit " & to_string(j) & " on port " & to_string(i) & " not reading correctly");
                        -- Reset the input to its default state
                        io0(i)(j) <= '0';
                        wait for 200 ns; -- allow synchronization etc
                    end loop;
                end loop;
            elsif run("set_outputs") then
                -- verify all outputs can be set to both 1 and 0
                -- turn all the ports to outputs
                for i in 0 to 4 loop
                    -- set port under test to all outputs
                    single_write_pca9506_reg(net, addr0, IOC0_OFFSET + i, X"00", ack_status);

                    for j in 0 to 7 loop
                        check_equal(io0_oe(i)(j), '1', "Output enable bit " & to_string(j) & " on port " & to_string(i) & " not set correctly for output pin");
                        -- Set the bit under test to '1'
                        user_int := to_integer(shift_left(std_logic_vector'("00000001"), j));
                        single_write_pca9506_reg(net, addr0, OP0_OFFSET + i, to_std_logic_vector(user_int, 8), ack_status);
                        wait for 200 ns; -- allow synchronization etc
                        -- check the output port
                        check_equal(io0_o(i)(j), '1', "Output bit " & to_string(j) & " on port " & to_string(i) & " not setting correctly");
                        -- check the readback matches
                        read_pca9506_reg(net, addr0, IP0_OFFSET + i, 1, rx_queue, ack_queue);
                        check_equal(pop_byte(rx_queue), user_int, "IP0_OFFSET expander 0 doesn't read back output state");

                        -- set back to 0
                        single_write_pca9506_reg(net, addr0, OP0_OFFSET + i, to_std_logic_vector(0, 8), ack_status);
                        wait for 200 ns; -- allow synchronization etc
                        -- check the output port
                        check_equal(io0_o(i)(j), '0', "Output bit " & to_string(j) & " on port " & to_string(i) & " not clearing correctly");
                        read_pca9506_reg(net, addr0, IP0_OFFSET + i, 1, rx_queue, ack_queue);
                        check_equal(pop_byte(rx_queue), 0, "IP0_OFFSET expander 0 doesn't read back output state");
                    end loop;
                    
                end loop; --     
                    
            elsif run("read_inputs_inverted") then
                -- verify all inputs are read
                -- going to do this bit-wise per port so we make sure everything is matching correctly
                for i in 0 to 4 loop  -- Loop each port
                    -- invert all inputs
                    single_write_pca9506_reg(net, addr0, PI0_OFFSET + i, X"FF", ack_status);

                    for j in 0 to 7 loop  -- Loop each bit
                        -- everything is an input so we should not see any io0_oebits set
                        check_equal(io0_oe(i)(j), '0', "io0_oebit " & to_string(j) & " on port " & to_string(i) & " is set for an input");
                        -- Set the bit under test to '1'
                        io0(i)(j) <= '1';
                        wait for 200 ns; -- allow synchronization etc
                        -- Read the corresponding input register and check the value
                        read_pca9506_reg(net, addr0, IP0_OFFSET + i, 1, rx_queue, ack_queue);
                        flush(ack_queue);  -- don't want lingering acks from this transaction
                        user_slv8 := (others => '1');
                        user_slv8(j) := '0';
                        user_int := to_integer(user_slv8);
                        check_equal(pop_byte(rx_queue), user_int, "Input bit " & to_string(j) & " on port " & to_string(i) & " not reading correctly");
                        -- Reset the input to its default state
                        io0(i)(j) <= '0';
                        wait for 200 ns; -- allow synchronization etc
                    end loop;
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