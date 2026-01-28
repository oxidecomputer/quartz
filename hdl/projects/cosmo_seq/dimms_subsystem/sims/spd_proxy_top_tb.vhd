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

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.spd_proxy_tb_pkg.all;
use work.i2c_ctrl_vc_pkg.all;
use work.i2c_target_vc_pkg.all;
use work.dimm_regs_pkg.all;



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
        variable cmd : cmd_type;
        variable data32 : std_logic_vector(31 downto 0);
        variable rnd    : RandomPType;
        variable cpu_tx_q   : queue_t   := new_queue;
        variable cpu_ack_q  : queue_t   := new_queue;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("sp_txn_short_read_ch0") then
                -- We want to use the new SPD interface via axi to issue
                -- a simple read to the DIMM as a starting point.
                -- Set up the buffer in the DIMM with a response
                write_word(memory(I2C_DIMM1F_TGT_VC), 0, X"AA");
                write_word(memory(I2C_DIMM1F_TGT_VC), 1, X"BB");
                write_word(memory(I2C_DIMM1F_TGT_VC), 2, X"CC");
                -- Set up i2c command and issue it
                -- 3 byte read from spd and addr 0
                cmd :=(
                    op => "00", -- READ
                    bus_addr => address(I2C_DIMM1F_TGT_VC),
                    reg_addr => X"00",
                    len => X"03"
                );
                wait for 15 us; --allow power up clear
                write_bus(net, bus_handle, To_StdLogicVector(BUS0_CMD_OFFSET, bus_handle.p_address_length), pack(cmd));
                -- Wait for the response
                -- Expect to get 3 bytes back, so poll until we see that in the FIFO
                data32 := 32x"3";
                wait_until_read_equals(net, bus_handle, To_StdLogicVector(BUS0_RX_BYTE_COUNT_OFFSET, bus_handle.p_address_length), data32, 6 ms);
                -- check the response.
                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"--CCBBAA"), "Read data mismatch");
                write_bus(net, bus_handle, To_StdLogicVector(FIFO_CTRL_OFFSET, bus_handle.p_address_length), X"FFFF_FFFF");

                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RADDR_OFFSET, bus_handle.p_address_length), data32);

            elsif run("sp_txn_random_read_ch0") then
                -- We want to use the new SPD interface via axi to issue
                -- a simple read to the DIMM as a starting point.
                -- Set up the buffer in the DIMM with a response
                write_word(memory(I2C_DIMM1F_TGT_VC), 0, X"AA");
                write_word(memory(I2C_DIMM1F_TGT_VC), 1, X"BB");
                write_word(memory(I2C_DIMM1F_TGT_VC), 2, X"CC");
                -- Set up i2c command and issue it
                -- 3 byte read from spd and addr 0
                cmd :=(
                    op => "10", -- RANDOM_READ
                    bus_addr => address(I2C_DIMM1F_TGT_VC),
                    reg_addr => X"00",
                    len => X"03"
                );
                wait for 15 us; --allow power up clear
                write_bus(net, bus_handle, To_StdLogicVector(BUS0_CMD_OFFSET, bus_handle.p_address_length), pack(cmd));
                -- Wait for the response
                -- Expect to get 3 bytes back, so poll until we see that in the FIFO
                data32 := 32x"3";
                wait_until_read_equals(net, bus_handle, To_StdLogicVector(BUS0_RX_BYTE_COUNT_OFFSET, bus_handle.p_address_length), data32, 6 ms);
                -- check the response.
                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"--CCBBAA"), "Read data mismatch");
                write_bus(net, bus_handle, To_StdLogicVector(FIFO_CTRL_OFFSET, bus_handle.p_address_length), X"FFFF_FFFF");

                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RADDR_OFFSET, bus_handle.p_address_length), data32);
            elsif run("sp_txn_short_read_ch1") then
                -- We want to use the new SPD interface via axi to issue
                -- a simple read to the DIMM as a starting point.
                -- Set up the buffer in the DIMM with a response
                write_word(memory(I2C_DIMM2L_TGT_VC), 0, X"AA");
                write_word(memory(I2C_DIMM2L_TGT_VC), 1, X"BB");
                write_word(memory(I2C_DIMM2L_TGT_VC), 2, X"CC");
                -- Set up i2c command and issue it
                -- 3 byte read from spd and addr 0
                cmd :=(
                    op => "00", -- READ
                    bus_addr => address(I2C_DIMM2L_TGT_VC),
                    reg_addr => X"00",
                    len => X"03"
                );
                wait for 15 us; --allow power up clear
                write_bus(net, bus_handle, To_StdLogicVector(BUS1_CMD_OFFSET, bus_handle.p_address_length), pack(cmd));
                -- Wait for the response
                -- Expect to get 3 bytes back, so poll until we see that in the FIFO
                data32 := 32x"3";
                wait_until_read_equals(net, bus_handle, To_StdLogicVector(BUS1_RX_BYTE_COUNT_OFFSET, bus_handle.p_address_length), data32, 6 ms);
                -- check the response.
                read_bus(net, bus_handle, To_StdLogicVector(BUS1_RX_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"--CCBBAA"), "Read data mismatch");
                write_bus(net, bus_handle, To_StdLogicVector(FIFO_CTRL_OFFSET, bus_handle.p_address_length), X"FFFF_FFFF");

                read_bus(net, bus_handle, To_StdLogicVector(BUS1_RX_RADDR_OFFSET, bus_handle.p_address_length), data32);
            elsif run("sp_read_sp5_conflict") then
                -- We want to use the new SPD interface via axi to issue
                -- a simple read to the DIMM as a starting point.
                -- Set up the buffer in the DIMM with a response
                write_word(memory(I2C_DIMM1F_TGT_VC), 0, X"AA");
                write_word(memory(I2C_DIMM1F_TGT_VC), 1, X"BB");
                write_word(memory(I2C_DIMM1F_TGT_VC), 2, X"CC");
                -- Set up i2c command and issue it
                -- 3 byte read from spd and addr 0
                cmd :=(
                    op => "10", -- RANDOM_READ, b/c the address could have been moved by the SP5
                    bus_addr => address(I2C_DIMM1F_TGT_VC),
                    reg_addr => X"00",
                    len => X"03"
                );
                wait for 15 us; --allow power up clear
                -- initiate hubris transaction
                write_bus(net, bus_handle, To_StdLogicVector(BUS0_CMD_OFFSET, bus_handle.p_address_length), pack(cmd));
                -- wait for transaction to start, then issue a conflicting SP5 access.
                wait for 100 us;
                push_byte(cpu_tx_q, to_integer(std_logic_vector'(X"DE")));
                i2c_write_txn(net, address(I2C_DIMM1F_TGT_VC), cpu_tx_q, cpu_ack_q, I2C_CTRL_VC0.p_actor);
                -- Wait for the response
                -- Expect to get 3 bytes back, so poll until we see that in the FIFO
                data32 := 32x"3";
                wait_until_read_equals(net, bus_handle, To_StdLogicVector(BUS0_RX_BYTE_COUNT_OFFSET, bus_handle.p_address_length), data32, 2 ms);
           
                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"--CCBBAA"), "Read data mismatch");
                write_bus(net, bus_handle, To_StdLogicVector(FIFO_CTRL_OFFSET, bus_handle.p_address_length), X"FFFF_FFFF");

                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RADDR_OFFSET, bus_handle.p_address_length), data32);

            elsif run("sp_read_sp5_conflict_a") then
                -- We want to use the new SPD interface via axi to issue
                -- a simple read to the DIMM as a starting point.
                -- Set up the buffer in the DIMM with a response
                write_word(memory(I2C_DIMM1F_TGT_VC), 0, X"00");
                write_word(memory(I2C_DIMM1F_TGT_VC), 1, X"01");
                write_word(memory(I2C_DIMM1F_TGT_VC), 2, X"02");
                -- Set up i2c command and issue it
                -- 3 byte read from spd and addr 0
                cmd :=(
                    op => "10", -- RANDOM_READ, b/c the address could have been moved by the SP5
                    bus_addr => address(I2C_DIMM1F_TGT_VC),
                    reg_addr => X"00",
                    len => X"03"
                );
                wait for 15 us; --allow power up clear
                -- initiate hubris transaction
                write_bus(net, bus_handle, To_StdLogicVector(BUS0_CMD_OFFSET, bus_handle.p_address_length), pack(cmd));
                -- wait for transaction to start, then issue a conflicting SP5 access.
                wait for 27 us;
                push_byte(cpu_tx_q, to_integer(std_logic_vector'(X"DE")));
                i2c_write_txn(net, address(I2C_DIMM1F_TGT_VC), cpu_tx_q, cpu_ack_q, I2C_CTRL_VC0.p_actor);
                -- Wait for the response
                -- Expect to get 3 bytes back, so poll until we see that in the FIFO
                data32 := 32x"3";
                wait_until_read_equals(net, bus_handle, To_StdLogicVector(BUS0_RX_BYTE_COUNT_OFFSET, bus_handle.p_address_length), data32, 2 ms);
           
                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"--020100"), "Read data mismatch");
                write_bus(net, bus_handle, To_StdLogicVector(FIFO_CTRL_OFFSET, bus_handle.p_address_length), X"FFFF_FFFF");

                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RADDR_OFFSET, bus_handle.p_address_length), data32);

             elsif run("sp_read_sp5_conflict_b") then
                -- We want to use the new SPD interface via axi to issue
                -- a simple read to the DIMM as a starting point.
                -- Set up the buffer in the DIMM with a response
                write_word(memory(I2C_DIMM1F_TGT_VC), 0, X"00");
                write_word(memory(I2C_DIMM1F_TGT_VC), 1, X"01");
                write_word(memory(I2C_DIMM1F_TGT_VC), 2, X"02");
                -- Set up i2c command and issue it
                -- 3 byte read from spd and addr 0
                cmd :=(
                    op => "10", -- RANDOM_READ, b/c the address could have been moved by the SP5
                    bus_addr => address(I2C_DIMM1F_TGT_VC),
                    reg_addr => X"00",
                    len => X"03"
                );
                wait for 15 us; --allow power up clear
                -- initiate hubris transaction
                write_bus(net, bus_handle, To_StdLogicVector(BUS0_CMD_OFFSET, bus_handle.p_address_length), pack(cmd));
                -- wait for transaction to start, then issue a conflicting SP5 access.
                push_byte(cpu_tx_q, to_integer(std_logic_vector'(X"AA")));
                wait for 300 ns + 20 us;
                i2c_write_txn(net, address(I2C_DIMM1F_TGT_VC), cpu_tx_q, cpu_ack_q, I2C_CTRL_VC0.p_actor);
                -- Wait for the response
                -- Expect to get 3 bytes back, so poll until we see that in the FIFO
                data32 := 32x"3";
                wait_until_read_equals(net, bus_handle, To_StdLogicVector(BUS0_RX_BYTE_COUNT_OFFSET, bus_handle.p_address_length), data32, 2 ms);
           
                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"--020100"), "Read data mismatch");
                write_bus(net, bus_handle, To_StdLogicVector(FIFO_CTRL_OFFSET, bus_handle.p_address_length), X"FFFF_FFFF");

                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RADDR_OFFSET, bus_handle.p_address_length), data32);

                -- TODO need to read what the SP5 stuck there too

             elsif run("sp_read_pend_sp5_conflict") then
                -- We want to use the new SPD interface via axi to issue
                -- a simple read to the DIMM as a starting point.
                -- Set up the buffer in the DIMM with a response
                write_word(memory(I2C_DIMM1F_TGT_VC), 0, X"AA");
                write_word(memory(I2C_DIMM1F_TGT_VC), 1, X"BB");
                write_word(memory(I2C_DIMM1F_TGT_VC), 2, X"CC");
                -- Set up i2c command and issue it
                -- 3 byte read from spd and addr 0
                cmd :=(
                    op => "10", -- RANDOM_READ, b/c the address could have been moved by the SP5
                    bus_addr => address(I2C_DIMM1F_TGT_VC),
                    reg_addr => X"00",
                    len => X"03"
                );
                wait for 15 us; --allow power up clear
                -- wait for transaction to start, then issue a conflicting SP5 access.
               
                push_byte(cpu_tx_q, to_integer(std_logic_vector'(X"DE")));
                i2c_write_txn(net, address(I2C_DIMM1F_TGT_VC), cpu_tx_q, cpu_ack_q, I2C_CTRL_VC0.p_actor);
                 wait for 20 us;
                -- initiate hubris transaction
                write_bus(net, bus_handle, To_StdLogicVector(BUS0_CMD_OFFSET, bus_handle.p_address_length), pack(cmd));
                -- Wait for the response
                -- Expect to get 3 bytes back, so poll until we see that in the FIFO
                data32 := 32x"3";
                wait_until_read_equals(net, bus_handle, To_StdLogicVector(BUS0_RX_BYTE_COUNT_OFFSET, bus_handle.p_address_length), data32, 2 ms);
           
                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"--CCBBAA"), "Read data mismatch");
                write_bus(net, bus_handle, To_StdLogicVector(FIFO_CTRL_OFFSET, bus_handle.p_address_length), X"FFFF_FFFF");

                read_bus(net, bus_handle, To_StdLogicVector(BUS0_RX_RADDR_OFFSET, bus_handle.p_address_length), data32);

            elsif run("spd_sm_prefetch") then
                wait for 15 us; --allow power up clear
                write_word(memory(I2C_DIMM1F_TGT_VC), 16#80#, X"AA");
                write_word(memory(I2C_DIMM1F_TGT_VC), 16#81#, X"BB");
                write_word(memory(I2C_DIMM1F_TGT_VC), 16#82#, X"CC");
                write_word(memory(I2C_DIMM1F_TGT_VC), 16#83#, X"DD");
                write_bus(net, bus_handle, To_StdLogicVector(SPD_CTRL_OFFSET, bus_handle.p_address_length), 32x"1");
                wait for 60 ms;
                -- Pick DIMM 5 on channel 0
                data32 := pack(spd_select_type'(bus0_f => '1', others => '0'));
                write_bus(net, bus_handle, To_StdLogicVector(SPD_SELECT_OFFSET, bus_handle.p_address_length), data32);
                read_bus(net, bus_handle, To_StdLogicVector(SPD_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"DDCCBBAA"), "Read data mismatch");

            elsif run("spd_sm_prefetch_again") then
                wait for 15 us; --allow power up clear
                write_word(memory(I2C_DIMM1F_TGT_VC), 16#80#, X"AA");
                write_word(memory(I2C_DIMM1F_TGT_VC), 16#81#, X"BB");
                write_word(memory(I2C_DIMM1F_TGT_VC), 16#82#, X"CC");
                write_word(memory(I2C_DIMM1F_TGT_VC), 16#83#, X"DD");
                write_bus(net, bus_handle, To_StdLogicVector(SPD_CTRL_OFFSET, bus_handle.p_address_length), 32x"1");
                wait for 60 ms;
                -- Pick DIMM 5 on channel 0
                data32 := pack(spd_select_type'(bus0_f => '1', others => '0'));
                write_bus(net, bus_handle, To_StdLogicVector(SPD_SELECT_OFFSET, bus_handle.p_address_length), data32);
                read_bus(net, bus_handle, To_StdLogicVector(SPD_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"DDCCBBAA"), "Read data mismatch");

                write_bus(net, bus_handle, To_StdLogicVector(SPD_CTRL_OFFSET, bus_handle.p_address_length), 32x"1");
                wait for 60 ms;
                -- Pick DIMM 5 on channel 0
                -- reset the read pointer
                write_bus(net, bus_handle, To_StdLogicVector(SPD_RD_PTR_OFFSET, bus_handle.p_address_length), X"00000000");
                data32 := pack(spd_select_type'(bus0_f => '1', others => '0'));
                write_bus(net, bus_handle, To_StdLogicVector(SPD_SELECT_OFFSET, bus_handle.p_address_length), data32);
                read_bus(net, bus_handle, To_StdLogicVector(SPD_RDATA_OFFSET, bus_handle.p_address_length), data32);
                check_match(data32, std_logic_vector'(X"DDCCBBAA"), "Read data mismatch");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 200 ms);

end tb;