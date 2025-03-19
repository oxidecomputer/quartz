-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

package i2c_target_vc_pkg is

    -- Message definitions
    constant got_start          : msg_type_t := new_msg_type("got_start");
    constant address_matched    : msg_type_t := new_msg_type("address_matched");
    constant address_different  : msg_type_t := new_msg_type("address_different");
    constant send_ack           : msg_type_t := new_msg_type("send_ack");
    constant got_ack            : msg_type_t := new_msg_type("got_ack");
    constant got_byte           : msg_type_t := new_msg_type("got_byte");
    constant got_stop           : msg_type_t := new_msg_type("got_stop");

    type i2c_target_vc_t is record
        -- private
        p_actor     : actor_t;
        p_buffer    : buffer_t;
        p_logger    : logger_t;
        -- I2C peripheral address
        P_address   : std_logic_vector(6 downto 0);
    end record;

    constant i2c_target_vc_logger : logger_t := get_logger("work:i2c_peripheral_vc");

    impure function new_i2c_target_vc (
        name    : string    := "I2C_TARGET_VC";
        address : std_logic_vector(6 downto 0) := b"1010101";
        logger  : logger_t  := i2c_target_vc_logger
    ) return i2c_target_vc_t;

    impure function address (i2c_periph: i2c_target_vc_t) return std_logic_vector;
    impure function buf (i2c_periph: i2c_target_vc_t) return buffer_t;
    impure function memory (i2c_periph: i2c_target_vc_t) return memory_t;

    procedure expect_message (
        signal net              : inout network_t;
        constant vc             : i2c_target_vc_t;
        constant expected_msg   : msg_type_t;
    );

    procedure expect_start (
        signal net  : inout network_t;
        constant vc : i2c_target_vc_t;
    );

    procedure expect_stop (
        signal net  : inout network_t;
        constant vc : i2c_target_vc_t;
    );

    procedure start_byte_ack (
        signal net      : inout network_t;
        constant vc     : i2c_target_vc_t;
        variable ack    : out boolean;
    );

    procedure check_written_byte (
        signal net      : inout network_t;
        constant vc     : i2c_target_vc_t;
        variable data   : std_logic_vector;
        variable addr   : std_logic_vector;
    );

    procedure expect_abort(
        signal net          : inout network_t;
        constant vc         : i2c_target_vc_t;
        variable aborted    : boolean;
    );

end package;

package body i2c_target_vc_pkg is

    impure function new_i2c_target_vc (
        name    : string    := "I2C_TARGET_VC";
        address : std_logic_vector(6 downto 0) := b"1010101";
        logger  : logger_t  := i2c_target_vc_logger
    ) return i2c_target_vc_t is
        variable buf : buffer_t;
    begin
        -- I2C can address 256 bytes, so construct an internal buffer to reflect that
        buf := allocate(new_memory, 256, name & "_MEM", 8, read_and_write);

        return (
            p_actor     => new_actor(name),
            p_buffer    => buf,
            p_logger    => logger,
            p_address   => address
        );
    end;

    impure function address (i2c_periph: i2c_target_vc_t) return std_logic_vector is
    begin
        return i2c_periph.p_address;
    end function;

    impure function buf (i2c_periph: i2c_target_vc_t) return buffer_t is
    begin
        return i2c_periph.p_buffer;
    end function;

    impure function memory (i2c_periph: i2c_target_vc_t) return memory_t is
    begin
        return i2c_periph.p_buffer.p_memory_ref;
    end function;

    procedure expect_message (
        signal net              : inout network_t;
        constant vc             : i2c_target_vc_t;
        constant expected_msg   : msg_type_t;
    ) is
        variable msg        : msg_t;
        variable matched    : boolean;
    begin
        receive(net, vc.p_actor, msg);
        -- a bit of a hack since check_equal is not implemented for msg_t
        matched := message_type(msg) = expected_msg;
        if not matched then
            unexpected_msg_type(message_type(msg));
        end if;
    end procedure;

    procedure expect_start (
        signal net      : inout network_t;
        constant vc     : i2c_target_vc_t;
    ) is
    begin
        expect_message(net, vc, got_start);
    end procedure;

    procedure expect_stop (
        signal net      : inout network_t;
        constant vc     : i2c_target_vc_t;
    ) is
    begin
        expect_message(net, vc, got_stop);
    end procedure;

    procedure start_byte_ack (
        signal net      : inout network_t;
        constant vc     : i2c_target_vc_t;
        variable ack    : out boolean;
    ) is
        variable msg    : msg_t;
    begin
        -- receive START event
        receive(net, vc.p_actor, msg);
        if message_type(msg) = got_start then
            -- receive START byte ack
            receive(net, vc.p_actor, msg);
            if message_type(msg) = address_matched then
                ack := true;
            elsif message_type(msg) = address_different then
                ack := false;
            end if;
        end if;
    end procedure;

    procedure check_written_byte (
        signal net      : inout network_t;
        constant vc     : i2c_target_vc_t;
        variable data   : std_logic_vector;
        variable addr   : std_logic_vector;
    ) is
        variable msg    : msg_t;
    begin
        set_expected_word(memory(vc), to_integer(addr), data);
        receive(net, vc.p_actor, msg);
        if message_type(msg) = got_byte then
            check_expected_was_written(buf(vc));
        end if;
    end procedure;

    procedure expect_abort (
        signal net          : inout network_t;
        constant vc         : i2c_target_vc_t;
        variable aborted    : boolean;
    ) is
        variable msg : msg_t;
    begin
        if aborted then
            -- if we are aborted, expect the next event to to STOP
            expect_stop(net, vc);
        else
            -- otherwise, pop an event to get it out of the queue
            receive(net, vc.p_actor, msg);
        end if;
    end procedure;

end package body;
