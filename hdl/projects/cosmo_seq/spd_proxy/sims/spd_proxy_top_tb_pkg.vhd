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
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.i2c_cmd_vc_pkg.all;
use work.i2c_ctrl_vc_pkg.all;
use work.i2c_target_vc_pkg.all;
use work.basic_stream_pkg.all;

use work.i2c_common_pkg.all;

package spd_proxy_top_tb_pkg is
    -- Constants
    constant CLK_PER_NS : positive := 8;

    -- Verification Components
    constant I2C_CTRL_VC        : i2c_ctrl_vc_t     := new_i2c_ctrl_vc("cpu_i2c_vc");
    constant I2C_TGT_VC         : i2c_target_vc_t   := new_i2c_target_vc("dimm_i2c_vc");
    constant I2C_CMD_VC         : i2c_cmd_vc_t      := new_i2c_cmd_vc;
    constant TX_DATA_SOURCE_VC  : basic_source_t    := new_basic_source(8);
    constant RX_DATA_SINK_VC    : basic_sink_t      := new_basic_sink(8);

    impure function build_controller_write (
        constant reg_addr   : std_logic_vector;
        constant txn_len    : natural;
        constant tx_q       : queue_t;
    ) return cmd_t;

    procedure push_random_bytes (
        constant q      : queue_t;
        constant num    : natural;
    );

    procedure controller_write (
        signal net          : inout network_t;
        constant command    : cmd_t;
        constant tx_q       : queue_t;
        constant blocking   : boolean := TRUE;
    );

    procedure controller_read (
        signal net          : inout network_t;
        constant command    : cmd_t;
        constant rx_q       : queue_t;
        constant exp_q      : queue_t;
        constant blocking   : boolean := TRUE;
    );

end package;

package body spd_proxy_top_tb_pkg is

    impure function build_controller_write (
        constant reg_addr   : std_logic_vector;
        constant txn_len    : natural;
        constant tx_q       : queue_t;
    ) return cmd_t is
        variable r      : cmd_t;
    begin
        push_random_bytes(tx_q, txn_len);

        r := (
            op => WRITE,
            addr => address(I2C_TGT_VC),
            reg => std_logic_vector(reg_addr),
            len => to_std_logic_vector(txn_len, r.len'length)
        );
        return r;
    end function;

    procedure push_random_bytes (
        constant q      : queue_t;
        constant num    : natural;
    ) is
        variable rnd    : RandomPType;
    begin
        for i in 0 to num - 1 loop
            push_byte(q, rnd.RandInt(0, 255));
        end loop;
    end procedure;

    procedure controller_write (
        signal net          : inout network_t;
        constant command    : cmd_t;
        constant tx_q       : queue_t;
        constant blocking : boolean := TRUE;
    ) is
        variable ack        : boolean   := FALSE;
        variable reg_addr   : natural   := 0;
        variable exp_data   : std_logic_vector(7 downto 0) := (others => '0');
        variable exp_addr   : std_logic_vector(7 downto 0) := (others => '0');
        variable exp_q  : queue_t   := new_queue;
    begin
        assert command.op = WRITE;
        -- push the command to the controller
        push_i2c_cmd(net, I2C_CMD_VC, command);

        -- copy TX data to check later
        exp_q := copy(tx_q);

        -- load up the TX data source for the controller
        while not is_empty(tx_q) loop
            push_basic_stream(net, TX_DATA_SOURCE_VC, to_std_logic_vector(pop_byte(tx_q), 8));
        end loop;

        -- block on checking the transaction steps
        if blocking then
            -- make sure the target ACKs the START byte
            start_byte_ack(net, I2C_TGT_VC, ack);
            check_true(ack, "Peripheral did not ACK correct address");

            -- set the starting address to check
            reg_addr := to_integer(command.reg);

            -- check that each byte was successfully written to the target
            while not is_empty(exp_q) loop
                exp_data    := to_std_logic_vector(pop_byte(exp_q), exp_data'length);
                exp_addr    := to_std_logic_vector(reg_addr, exp_addr'length);
                check_written_byte(net, I2C_TGT_VC, exp_data, exp_addr);
                reg_addr    := reg_addr + 1;
            end loop;

            -- after all data has been written expect a STOP to have been received
            expect_stop(net, I2C_TGT_VC);
        end if;
    end procedure;

    procedure controller_read (
        signal net          : inout network_t;
        constant command    : cmd_t;
        constant rx_q       : queue_t;
        constant exp_q      : queue_t;
        constant blocking   : boolean := TRUE;
    ) is
        variable ack        : boolean   := FALSE;
        variable rx_data    : std_logic_vector (7 downto 0);
    begin
        assert command.op = READ;
        -- push the command to the controller
        push_i2c_cmd(net, I2C_CMD_VC, command);

        if blocking then
            -- make sure the target ACKs the START byte
            start_byte_ack(net, I2C_TGT_VC, ack);
            check_true(ack, "Peripheral did not ACK correct address");
            for i in 0 to to_integer(command.len) - 1 loop
                pop_basic_stream(net, RX_DATA_SINK_VC, rx_data);
                check_equal(rx_data, pop_byte(exp_q), "Expected read data to match");
                push_byte(rx_q, to_integer(rx_data));
            end loop;
        end if;

    end procedure;

end package body;