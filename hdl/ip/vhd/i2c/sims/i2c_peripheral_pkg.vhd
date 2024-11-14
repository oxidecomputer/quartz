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
    constant start_byte         : msg_type_t := new_msg_type("start_byte");
    constant address_matched    : msg_type_t := new_msg_type("address_matched");
    constant send_ack           : msg_type_t := new_msg_type("send_ack");
    constant got_ack            : msg_type_t := new_msg_type("got_ack");
    constant send_byte          : msg_type_t := new_msg_type("send_byte");
    constant got_byte           : msg_type_t := new_msg_type("got_byte");

    type i2c_peripheral_t is record
        -- I2C peripheral address
        address     : std_logic_vector(6 downto 0);
        -- private
        p_actor     : actor_t;
        p_ack_actor : actor_t;
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
            p_ack_actor => new_actor(name & "_ack"),
            p_memory    => to_vc_interface(memory, logger),
            p_logger    => logger
        );
    end;

end package body;
