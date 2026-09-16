-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

-- Messages for driving the Versal boot model's failure modes. The rails
-- themselves are separate rail_model instances, so this package only covers
-- what the device does after its rails are up.
package versal_model_msg_pkg is

    constant fail_boot_msg : msg_type_t := new_msg_type("fail_boot");
    constant allow_boot_msg : msg_type_t := new_msg_type("allow_boot");
    constant assert_error_out_msg : msg_type_t := new_msg_type("assert_error_out");
    constant clear_error_out_msg : msg_type_t := new_msg_type("clear_error_out");

    -- Stop the model from ever asserting DONE, so the sequencer's boot
    -- timeout is exercised.
    procedure fail_boot (
        signal net     : inout network_t;
        constant actor : actor_t
    );

    procedure allow_boot (
        signal net     : inout network_t;
        constant actor : actor_t
    );

    procedure assert_error_out (
        signal net     : inout network_t;
        constant actor : actor_t
    );

    procedure clear_error_out (
        signal net     : inout network_t;
        constant actor : actor_t
    );

end package;

package body versal_model_msg_pkg is

    procedure fail_boot (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is
        variable request_msg : msg_t := new_msg(fail_boot_msg);
    begin
        send(net, actor, request_msg);
    end;

    procedure allow_boot (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is
        variable request_msg : msg_t := new_msg(allow_boot_msg);
    begin
        send(net, actor, request_msg);
    end;

    procedure assert_error_out (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is
        variable request_msg : msg_t := new_msg(assert_error_out_msg);
    begin
        send(net, actor, request_msg);
    end;

    procedure clear_error_out (
        signal net     : inout network_t;
        constant actor : actor_t
    ) is
        variable request_msg : msg_t := new_msg(clear_error_out_msg);
    begin
        send(net, actor, request_msg);
    end;

end package body;
