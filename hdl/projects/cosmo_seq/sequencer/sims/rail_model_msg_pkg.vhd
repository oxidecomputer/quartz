-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

package rail_model_msg_pkg is

    constant disable_pg_msg : msg_type_t := new_msg_type("disable_pg");
    constant enable_pg_msg  : msg_type_t := new_msg_type("enable_pg");

    -- Procedure to disable power-good reporting
    procedure disable_power_good (
        signal net     : inout network_t;
        constant actor : actor_t
    );

    -- Procedure to enable power-good reporting
    procedure enable_power_good (
        signal net     : inout network_t;
        constant actor : actor_t
    );

end package;

package body rail_model_msg_pkg is

    -- Helper procedure for testbenches to disable power-good reporting
    procedure disable_power_good (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is
        variable request_msg : msg_t := new_msg(disable_pg_msg);
    begin
        send(net, actor, request_msg);
    end;

    -- Helper procedure for testbenches to enable power-good reporting
    procedure enable_power_good (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is
        variable request_msg : msg_t := new_msg(enable_pg_msg);
    begin
        send(net, actor, request_msg);
    end;

end package body;
