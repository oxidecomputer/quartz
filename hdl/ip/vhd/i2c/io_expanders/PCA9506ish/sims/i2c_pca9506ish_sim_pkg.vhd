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
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

use work.i2c_ctrl_vc_pkg.all;

package i2c_pca9506ish_sim_pkg is

    constant i2c_tgt_addr: std_logic_vector(6 downto 0) := 7x"20";

    constant i2c_ctrl_vc : i2c_ctrl_vc_t := new_i2c_ctrl_vc("i2c_ctrl_vc");

    -- Some helper functions for writing test benches.
    -- want to be able to read/write arbitrary registers
    -- want to be able to read/write categories of registers (wrapping)
    procedure single_write_pca9506_reg(
        signal net : inout network_t;
        constant register_addr : in integer range 0 to 16#27#;
        constant write_data: in std_logic_vector(7 downto 0);
        variable did_ack: inout boolean;
        constant auto_inc: in boolean := true;
        constant i2c_addr : in std_logic_vector(6 downto 0) := i2c_tgt_addr
    );
    procedure write_pca9506_reg(
        signal net : inout network_t;
        constant starting_reg : in integer range 0 to 16#27#;
        constant byte_queue: in queue_t;
        constant ack_queue: in queue_t;
        constant auto_inc: in boolean := true;
        constant i2c_addr : in std_logic_vector(6 downto 0) := i2c_tgt_addr
    );

    procedure read_pca9506_reg(
        signal net : inout network_t;
        constant starting_reg : in integer range 0 to 16#27#;
        constant num_regs_to_read : in integer;
        constant response_queue: in queue_t;
        constant ack_queue: in queue_t;
        constant auto_inc: in boolean := true;
        constant i2c_addr : in std_logic_vector(6 downto 0) := i2c_tgt_addr
    );

end package;

package body i2c_pca9506ish_sim_pkg is

    procedure single_write_pca9506_reg(
        signal net : inout network_t;
        constant register_addr : in integer range 0 to 16#27#;
        constant write_data: in std_logic_vector(7 downto 0);
        variable did_ack: inout boolean;
        constant auto_inc: in boolean := true;
        constant i2c_addr : in std_logic_vector(6 downto 0) := i2c_tgt_addr
    ) is
        constant tx_queue : queue_t := new_queue;
        constant ack_queue: queue_t := new_queue;
    begin
        push_byte(tx_queue, to_integer(write_data));
        write_pca9506_reg(net, register_addr, tx_queue, tx_queue, auto_inc, i2c_addr);
        did_ack := true;
        while not is_empty(ack_queue) loop
            if pop_byte(ack_queue) = 0 then
                did_ack := false;
            end if;
        end loop;

    end procedure;

    procedure write_pca9506_reg(
        signal net : inout network_t;
        constant starting_reg : in integer range 0 to 16#27#;
        constant byte_queue: in queue_t;
        constant ack_queue: in queue_t;
        constant auto_inc: in boolean := true;
        constant i2c_addr : in std_logic_vector(6 downto 0) := i2c_tgt_addr
    ) is
        variable cmd_reg : std_logic_vector(7 downto 0);
        constant tx_queue : queue_t := new_queue;
    begin
        -- set up the cmd register
        cmd_reg := std_logic_vector(to_unsigned(starting_reg, 8));
        if auto_inc then
            cmd_reg(7) := '1';
        end if;
        push_byte(tx_queue, to_integer(cmd_reg));
        while not is_empty(byte_queue) loop
            push_byte(tx_queue, pop_byte(byte_queue));
        end loop;
        i2c_write_txn(net, i2c_addr, tx_queue, ack_queue);
    end procedure;

    procedure read_pca9506_reg(
        signal net : inout network_t;
        constant starting_reg : in integer range 0 to 16#27#;
        constant num_regs_to_read : in integer;
        constant response_queue: in queue_t;
        constant ack_queue: in queue_t;
        constant auto_inc: in boolean := true;
        constant i2c_addr : in std_logic_vector(6 downto 0) := i2c_tgt_addr
    ) is
        variable cmd_reg : std_logic_vector(7 downto 0);
        constant tx_queue : queue_t := new_queue;
    begin
        -- set up the cmd register
        cmd_reg := std_logic_vector(to_unsigned(starting_reg, 8));
        if auto_inc then
            cmd_reg(7) := '1';
        end if;
        push_byte(tx_queue, to_integer(cmd_reg));
        i2c_mixed_txn(net, i2c_addr, tx_queue, num_regs_to_read, response_queue, ack_queue);
    end procedure;

end package body;