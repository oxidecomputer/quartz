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

use work.i2c_common_pkg.all;
use work.i2c_cmd_vc_pkg.all;

entity i2c_cmd_vc is
    generic (
        i2c_cmd_vc : i2c_cmd_vc_t
    );
    port (
        cmd     : out cmd_t     := CMD_RESET;
        valid   : out std_logic := '0';
        ready   : in std_logic;
    );
end entity;

architecture model of i2c_cmd_vc is
begin

    handle_messages: process
        variable msg        : msg_t;
        variable msg_type   : msg_type_t;
        variable command    : cmd_t;
        variable is_read    : boolean;
        variable is_random  : boolean;
    begin
        receive(net, i2c_cmd_vc.p_actor, msg);
        msg_type := message_type(msg);

        if msg_type = push_i2c_cmd_msg then
            is_read     := pop(msg);
            is_random   := pop(msg);
            if is_read then
                if is_random then
                    command.op  := RANDOM_READ;
                else
                    command.op  := READ;
                end if;
            else
                command.op  := WRITE;
            end if;
            command.addr    := pop(msg);
            command.reg     := pop(msg);
            command.len     := pop(msg);
            cmd     <= command;
            valid   <= '1';
            wait until ready;
            valid   <= '0';
        else
            unexpected_msg_type(msg_type);
        end if;
    end process;

end architecture;