-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
use vunit_lib.sync_pkg.all;

use work.i2c_common_pkg.all;

package i2c_cmd_vc_pkg is

    type i2c_cmd_vc_t is record
        -- private
        p_actor     : actor_t;
        p_logger    : logger_t;
    end record;

    constant i2c_cmd_vc_logger : logger_t := get_logger("work:i2c_cmd_vc_pkg");

    impure function new_i2c_cmd_vc(
        actor   : actor_t   := null_actor;
        logger  : logger_t  := i2c_cmd_vc_logger;
    ) return i2c_cmd_vc_t;

    constant push_i2c_cmd_msg : msg_type_t := new_msg_type("push_i2c_cmd");

    procedure push_i2c_cmd(
        signal net  : inout network_t;
        i2c_cmd_vc  : i2c_cmd_vc_t;
        cmd         : cmd_t;
    );

end package;

package body i2c_cmd_vc_pkg is

    impure function new_i2c_cmd_vc(
        actor   : actor_t   := null_actor;
        logger  : logger_t  := i2c_cmd_vc_logger;
    ) return i2c_cmd_vc_t is 
        variable p_actor : actor_t;
    begin
        p_actor := actor when actor /= null_actor else new_actor;

        return (
            p_actor     => p_actor,
            p_logger    => logger
        );
    end function;

    procedure push_i2c_cmd(
        signal net  : inout network_t;
        i2c_cmd_vc  : i2c_cmd_vc_t;
        cmd         : cmd_t
    ) is
        variable msg        : msg_t := new_msg(push_i2c_cmd_msg);
        variable is_read    : boolean;
        variable is_random  : boolean;
    begin
        -- breaking down our type since we can't push enums in VUnit
        is_read     := false when cmd.op = WRITE else true;
        is_random   := true when cmd.op = RANDOM_READ else false;
        push(msg, is_read);
        push(msg, is_random);
        push(msg, cmd.addr);
        push(msg, cmd.reg);
        push(msg, cmd.len);
        send(net, i2c_cmd_vc.p_actor, msg);
    end;


end package body;