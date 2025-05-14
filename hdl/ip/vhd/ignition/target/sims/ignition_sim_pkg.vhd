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

use work.basic_stream_pkg.all;
use work.ignition_pkg.all;
use work.crc_sim_pkg.all;

package ignition_sim_pkg is

    constant source0 : basic_source_t := new_basic_source(data_length => 9, valid_high_probability => 1.0);
    constant source1 : basic_source_t := new_basic_source(data_length => 9, valid_high_probability => 1.0);

    -- Represent a "command" as a queue of bytes and a size
    -- annoyingly VUnit's queue method does not have a proper way
    -- of getting the size of the queue in terms of "entries"
    type cmd_t is record
        queue : queue_t;
        num_bytes: natural range 0 to 2047;
    end record;

    procedure send_cmd(
        signal net : inout network_t;
        handle : basic_source_t;
        cmd : cmd_t
    );

    impure function build_ignition_msg(constant payload : queue_t; constant invalid_crc: boolean := false) return cmd_t;
    impure function build_hello_cmd(constant invalid_crc: boolean := false) return cmd_t;
    impure function build_off_cmd(constant invalid_crc: boolean := false) return cmd_t;
    impure function build_on_cmd(constant invalid_crc: boolean := false) return cmd_t;
    impure function build_restart_cmd(constant invalid_crc: boolean := false) return cmd_t;

end package;

package body ignition_sim_pkg is

     procedure send_cmd(
        signal net : inout network_t;
        handle : basic_source_t;
        cmd : cmd_t
    ) is
        variable cur_word : std_logic_vector(8 downto 0);
    begin
        while not is_empty(cmd.queue) loop
            cur_word := pop(cmd.queue);
            push_basic_stream(net, handle, cur_word);
        end loop;
    end procedure;

    -- Default, generic command builder used by other builders.
    impure function build_ignition_msg(
        constant payload : queue_t; 
        constant invalid_crc: boolean := false
    ) return cmd_t is
         variable cmd : cmd_t := (new_queue, 0);
         variable cur_word : std_logic_vector(8 downto 0);
         variable crc : std_logic_vector(7 downto 0);

    begin
        -- Assume all data in payload is actual data no control characters.
        -- Build CRC of the payload provided
        -- Ignition 1.0 uses a bonus xor with 0xFF at the output of the
        -- CRC so we do that here.
        crc := crc8_autostar(payload, X"FF", invalid_crc);
        -- Push the start of message control character
        push(cmd.queue, '1' & START_OF_MESSAGE);
        cmd.num_bytes := cmd.num_bytes + 1;
        while not is_empty(payload) loop
            -- these are non-control registers
            cur_word := '0' & to_std_logic_vector(pop_byte(payload), 8);
            -- Push into the queue
            push(cmd.queue, cur_word);
            cmd.num_bytes := cmd.num_bytes + 1;
        end loop;
        -- Push the CRC into the queue
        cur_word := '0' & crc;
        -- Push into the queue
        push(cmd.queue, cur_word);
        cmd.num_bytes := cmd.num_bytes + 1;

        -- Deal with end of message. Send K27.3 as end of message
        push(cmd.queue, '1' & END_OF_MESSAGE);
        cmd.num_bytes := cmd.num_bytes + 1;
        if cmd.num_bytes mod 2 /= 0 then
            -- If the number of bytes is odd, we need to add an extra
            -- K29.7 character to the end of the message
            push(cmd.queue, '1' & BONUS_END_CHAR);
            cmd.num_bytes := cmd.num_bytes + 1;
        end if;
        return cmd;
    end function;

    impure function build_hello_cmd(
        constant invalid_crc: boolean := false
    ) return cmd_t is
        variable payload : queue_t := new_queue;
    begin
        -- version (always 1)
        push_byte(payload, 1);
        -- hello message type
        push_byte(payload, 2);
        -- That's it
        return build_ignition_msg(payload, invalid_crc);
    end function;

    impure function build_off_cmd(
        constant invalid_crc: boolean := false
    ) return cmd_t is
        variable payload : queue_t := new_queue;
    begin
        -- version (always 1)
        push_byte(payload, 1);
        -- request message type
        push_byte(payload, 3);
        -- system power off
        push_byte(payload, 1);
        -- That's it
        return build_ignition_msg(payload, invalid_crc);
    end function;

    impure function build_on_cmd(
        constant invalid_crc: boolean := false
    ) return cmd_t is
        variable payload : queue_t := new_queue;
    begin
        -- version (always 1)
        push_byte(payload, 1);
        -- request message type
        push_byte(payload, 3);
        -- system power on
        push_byte(payload, 2);
        -- That's it
        return build_ignition_msg(payload, invalid_crc);
    end function;

    impure function build_restart_cmd(
        constant invalid_crc: boolean := false
    ) return cmd_t is
        variable payload : queue_t := new_queue;
    begin
        -- version (always 1)
        push_byte(payload, 1);
        -- request message type
        push_byte(payload, 3);
        -- system power on
        push_byte(payload, 3);
        -- That's it
        return build_ignition_msg(payload, invalid_crc);
    end function;

end package body;