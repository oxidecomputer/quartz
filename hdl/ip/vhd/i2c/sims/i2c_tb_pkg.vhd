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

use work.i2c_peripheral_pkg.all;

package i2c_tb_pkg is

    procedure start_byte_ack (
        signal net                  : inout network_t;
        constant i2c_peripheral_vc  : i2c_peripheral_t;
        variable ack                : inout boolean;
    );

end package;

package body i2c_tb_pkg is

    procedure start_byte_ack (
        signal net                  : inout network_t;
        constant i2c_peripheral_vc  : i2c_peripheral_t;
        variable ack                : inout boolean;
    ) is
        variable msg    : msg_t;
    begin
        receive(net, i2c_peripheral_vc.p_actor, msg);
        if message_type(msg) = got_start then
            
        end if;
    end procedure;

end package body;