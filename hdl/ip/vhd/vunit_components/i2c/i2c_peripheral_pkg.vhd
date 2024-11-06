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
use vunit_lib.sync_pkg.all;

package i2c_peripheral_pkg is

    -- Message definitions
    constant sent_ack   : msg_type_t    := new_msg_type("send_ack");
    constant send_byte  : msg_type_t    := new_msg_type("send_byte");

    type i2c_peripheral_t is record
        p_actor     : actor_t;
        p_ack_actor : actor_t;
        p_logger    : logger_t;
    end record;

    constant i2c_peripheral_vc_logger : logger_t := get_logger("work:i2c_peripheral_vc");

    impure function new_i2c_peripheral_vc (
        name    : string := "";
        logger  : logger_t := i2c_peripheral_vc_logger
    ) return i2c_peripheral_t;

end package;

package body i2c_peripheral_pkg is

    impure function new_i2c_peripheral_vc (
        name    : string := "";
        logger  : logger_t := i2c_peripheral_vc_logger
    ) return i2c_peripheral_t is
    begin
        return (
            p_actor     => new_actor(name),
            p_ack_actor => new_actor(name & " read-ack"),
            p_logger    => logger
        );
    end;

end package body;
