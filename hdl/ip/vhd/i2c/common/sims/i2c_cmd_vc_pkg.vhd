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

    constant push_i2c_cmd_msg   : msg_type_t := new_msg_type("push_i2c_cmd");
    constant abort_msg          : msg_type_t := new_msg_type("abort");

    procedure push_i2c_cmd(
        signal net  : inout network_t;
        i2c_cmd_vc  : i2c_cmd_vc_t;
        cmd         : cmd_t;
    );

    procedure push_abort(
        signal net  : inout network_t;
        i2c_cmd_vc  : i2c_cmd_vc_t;
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

        -- We break down cmd_t into it's primitive types to push them into the message where we will
        -- pop them off when we receive it in order to reconstruct a cmd_t.
        -- TODO: implement push/pop for our custom type so we wouldn't have to do this?
        push(msg, is_read);     -- boolean
        push(msg, is_random);   -- boolean
        push(msg, cmd.addr);    -- std_logic_vector
        push(msg, cmd.reg);     -- std_logic_vector
        push(msg, cmd.len);     -- std_logic_vector
        send(net, i2c_cmd_vc.p_actor, msg);
    end;

    procedure push_abort(
        signal net  : inout network_t;
        i2c_cmd_vc  : i2c_cmd_vc_t;
    ) is
        variable msg : msg_t := new_msg(abort_msg);
    begin
        send(net, i2c_cmd_vc.p_actor, msg);
    end;

end package body;