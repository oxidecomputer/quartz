-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

--! Bus master model based on ST's RM0433
--! figures 115 and 116

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.espi_protocol_pkg.all;

package espi_tb_pkg is
    type cmd_t is record
        queue : queue_t;
        num_bytes: natural range 0 to 2047;
    end record;

    type resp_t is record
        queue : queue_t;
        num_bytes: natural range 0 to 2047;
        response_code: std_logic_vector(7 downto 0);
        status : std_logic_vector(15 downto 0);
        crc_ok : boolean;
    end record;

    constant bus_handle : bus_master_t := new_bus(data_length => 32,
                                                  address_length => 8);
    
    impure function crc8(data: queue_t) return std_logic_vector;
    -- These functions build the command bytes into a queue and
    -- returns the queue and the number of bytes in the queue
    -- for additional processing in the testbench such as
    -- commanding the qspi VC or using the debug axi interface
    impure function build_get_status_cmd return cmd_t;
    impure function build_get_config_cmd(constant address : natural) return cmd_t;
    impure function build_set_config_cmd(constant address : natural;
                                         constant data : std_logic_vector) return cmd_t;
    impure function build_put_flash_np_cmd(constant address : in std_logic_vector(31 downto 0);
                                           constant num_bytes: integer) return cmd_t;
    -- Need procedures to build expected responses
    impure function check_queue_crc (data: queue_t) return boolean;

end package;

package body espi_tb_pkg is

    -- The non-parallel version of the crc from the datasheet
    -- used to check our parallel hw implementation with a "known-good"
    -- and alternately implemented algo.
    impure function crc8 (
        data: queue_t
    ) return std_logic_vector is

        -- create a copy so we don't destry the input queue here
        constant  crc_queue : queue_t                  := copy(data);
        variable d : std_logic_vector(7 downto 0)      := (others => '0');
        variable next_q : std_logic_vector(7 downto 0) := (others => '0');
        variable last_q : std_logic_vector(7 downto 0) := (others => '0');

    begin
        while not is_empty(crc_queue) loop
            d := To_StdLogicVector(pop_byte(crc_queue), 8);
            for i in 0 to 7 loop
                next_q(0) := last_q(7) xor d(7);
                next_q(1) := last_q(7) xor d(7) xor last_q(0);
                next_q(2) := last_q(7) xor d(7) xor last_q(1);
                next_q(7 downto 3) := last_q(6 downto 2);
                last_q := next_q;
                d := shift_left(d, 1);
            end loop;
        end loop;
        return last_q;
    end;

    impure function check_queue_crc (
        data: queue_t
    ) return boolean is
        -- create a copy so we don't destry the queue here
        constant  copy_queue : queue_t                  := copy(data);
        constant crc_queue: queue_t                  := new_queue;
        variable cur_byte : std_logic_vector(7 downto 0);
        variable crc_byte : std_logic_vector(7 downto 0);
    begin
        while true loop
            cur_byte := To_StdLogicVector(pop_byte(copy_queue), 8);
            report "Data Byte: " & to_hstring(cur_byte);
            -- Last element in queue is the CRC
            if is_empty(copy_queue) then
                crc_byte := crc8(crc_queue);
                report "CRC Byte: " & to_hstring(crc_byte);
                return crc_byte = cur_byte;
            else
                push_byte(crc_queue, to_integer(cur_byte));
            end if;
        end loop;
    end;

    -- This builds the command bytes into a queue and
    -- returns the queue and the number of bytes in the queue
    -- for additional processing
    impure function build_get_status_cmd return cmd_t is
        variable cmd : cmd_t := (new_queue, 0);
    begin
        -- OPCODE_GET_STATUS  (1 byte)
        push_byte(cmd.queue, to_integer(OPCODE_GET_STATUS));
        cmd.num_bytes := cmd.num_bytes + 1;
        -- CRC (1 byte)
        push_byte(cmd.queue, to_integer(crc8(cmd.queue)));
        cmd.num_bytes := cmd.num_bytes + 1;
        return cmd;
    end function;

    impure function build_get_config_cmd(
        constant address : natural
    ) return cmd_t is
        variable tmp_address : std_logic_vector(15 downto 0) := To_Std_Logic_Vector(address, 16);
        variable cmd : cmd_t := (new_queue, 0);
    begin
        -- OPCODE_GET_CONFIG (1 byte)
        push_byte(cmd.queue, to_integer(opcode_get_configuration));
        cmd.num_bytes := cmd.num_bytes + 1;
        -- ADDRESS (2 bytes), MSB 1st
        push_byte(cmd.queue, to_integer(tmp_address(15 downto 8)));
        push_byte(cmd.queue, to_integer(tmp_address(7 downto 0)));
        cmd.num_bytes := cmd.num_bytes + 2;
        -- CRC (1 byte)
        push_byte(cmd.queue, to_integer(crc8(cmd.queue)));
        cmd.num_bytes := cmd.num_bytes + 1;
        return cmd;
    end function;
    
    impure function build_set_config_cmd(
        constant address : natural;
        constant data : std_logic_vector
    ) return cmd_t is
        variable tmp_address : std_logic_vector(15 downto 0) := To_Std_Logic_Vector(address, 16);
        variable cmd : cmd_t := (new_queue, 0);
    begin
        -- OPCODE_SET_CONFIG (1 byte)
        push_byte(cmd.queue, to_integer(opcode_set_configuration));
        cmd.num_bytes := cmd.num_bytes + 1;
        -- ADDRESS (2 bytes), MSB 1st
        push_byte(cmd.queue, to_integer(tmp_address(15 downto 8)));
        push_byte(cmd.queue, to_integer(tmp_address(7 downto 0)));
        cmd.num_bytes := cmd.num_bytes + 2;
        -- DATA (4 bytes), LSB 1st
        push_byte(cmd.queue, to_integer(data(7 downto 0)));
        push_byte(cmd.queue, to_integer(data(15 downto 8)));
        push_byte(cmd.queue, to_integer(data(23 downto 16)));
        push_byte(cmd.queue, to_integer(data(31 downto 24)));
        cmd.num_bytes := cmd.num_bytes + 4;
        -- CRC (1 byte)
        push_byte(cmd.queue, to_integer(crc8(cmd.queue)));
        cmd.num_bytes := cmd.num_bytes + 1;
        return cmd;
    end function;

    impure function build_put_flash_np_cmd(
        constant address : in std_logic_vector(31 downto 0);
        constant num_bytes: integer
    ) return cmd_t is
        variable payload_len : std_logic_vector(11 downto 0) := To_Std_Logic_Vector(num_bytes, 12);
        variable cmd : cmd_t := (new_queue, 0);
    begin
        -- OPCODE_PUT_FLASH_NP (1 byte)
        push_byte(cmd.queue, to_integer(opcode_put_flash_np));
        cmd.num_bytes := cmd.num_bytes + 1;
        -- cycle type (1 byte)
        push_byte(cmd.queue, to_integer(flash_read));
        cmd.num_bytes := cmd.num_bytes + 1;
        -- tag/length high
        push_byte(cmd.queue, to_integer("0000" & payload_len(11 downto 8)));
        cmd.num_bytes := cmd.num_bytes + 1;
        -- length low
        push_byte(cmd.queue, to_integer(payload_len(7 downto 0)));
        cmd.num_bytes := cmd.num_bytes + 1;
        -- ADDRESS (4 bytes), MSB 1st
        push_byte(cmd.queue, to_integer(address(31 downto 24)));
        push_byte(cmd.queue, to_integer(address(23 downto 16)));
        push_byte(cmd.queue, to_integer(address(15 downto 8)));
        push_byte(cmd.queue, to_integer(address(7 downto 0)));
        cmd.num_bytes := cmd.num_bytes + 4;
        -- CRC (1 byte)
        push_byte(cmd.queue, to_integer(crc8(cmd.queue)));
        cmd.num_bytes := cmd.num_bytes + 1;
        return cmd;
    end function;

end package body;