-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

package i2c_peripheral_pkg is

    -- Message definitions
    constant got_start          : msg_type_t := new_msg_type("got_start");
    constant address_matched    : msg_type_t := new_msg_type("address_matched");
    constant address_different  : msg_type_t := new_msg_type("address_different");
    constant send_ack           : msg_type_t := new_msg_type("send_ack");
    constant got_ack            : msg_type_t := new_msg_type("got_ack");
    constant send_byte          : msg_type_t := new_msg_type("send_byte");
    constant got_byte           : msg_type_t := new_msg_type("got_byte");
    constant got_stop           : msg_type_t := new_msg_type("got_stop");

    type i2c_peripheral_t is record
        -- I2C peripheral address
        address     : std_logic_vector(6 downto 0);
        -- private
        p_actor     : actor_t;
        p_memory    : memory_t;
        p_logger    : logger_t;
    end record;

    constant i2c_peripheral_vc_logger : logger_t := get_logger("work:i2c_peripheral_vc");

    impure function new_i2c_peripheral_vc (
        name    : string;
        address : std_logic_vector(6 downto 0);
        memory  : memory_t;
        logger  : logger_t := i2c_peripheral_vc_logger
    ) return i2c_peripheral_t;

    procedure expect_message (
        signal net              : inout network_t;
        constant vc             : i2c_peripheral_t;
        constant expected_msg   : msg_type_t;
    );

    procedure expect_stop (
        signal net  : inout network_t;
        constant vc : i2c_peripheral_t;
    );

    procedure start_byte_ack (
        signal net      : inout network_t;
        constant vc     : i2c_peripheral_t;
        variable ack    : out boolean;
    );

end package;

package body i2c_peripheral_pkg is

    impure function new_i2c_peripheral_vc (
        name    : string;
        address : std_logic_vector(6 downto 0);
        memory  : memory_t;
        logger  : logger_t := i2c_peripheral_vc_logger
    ) return i2c_peripheral_t is
    begin
        return (
            address     => address,
            p_actor     => new_actor(name),
            p_memory    => to_vc_interface(memory, logger),
            p_logger    => logger
        );
    end;

    procedure expect_message (
        signal net              : inout network_t;
        constant vc             : i2c_peripheral_t;
        constant expected_msg   : msg_type_t;
    ) is
        variable msg        : msg_t;
        variable matched    : boolean;
    begin
        receive(net, vc.p_actor, msg);
        matched := message_type(msg) = expected_msg;
        check_true(matched, "Received message did not match expected message.");
    end procedure;

    procedure expect_stop (
        signal net      : inout network_t;
        constant vc     : i2c_peripheral_t;
    ) is
    begin
        expect_message(net, vc, got_stop);
    end procedure;

    procedure start_byte_ack (
        signal net      : inout network_t;
        constant vc     : i2c_peripheral_t;
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

end package body;
