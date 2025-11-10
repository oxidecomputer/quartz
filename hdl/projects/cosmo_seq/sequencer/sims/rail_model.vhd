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

use work.sequencer_io_pkg.all;
use work.rail_model_msg_pkg.all;

entity rail_model is
    generic (
        actor_name : string := "rail_model"
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        rail : view power_rail_at_reg
    );
end entity;

architecture model of rail_model is

    signal pg_disabled : boolean := false;

begin

    -- Message handling process for VUnit communication
    msg_handler : process
        variable self        : actor_t;
        variable msg_type    : msg_type_t;
        variable request_msg : msg_t;
    begin
        self := new_actor(actor_name);
        loop
            receive(net, self, request_msg);
            msg_type := message_type(request_msg);
            if msg_type = disable_pg_msg then
                info("Power-good reporting disabled");
                pg_disabled <= true;
            elsif msg_type = enable_pg_msg then
                info("Power-good reporting enabled");
                pg_disabled <= false;
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;
        wait;
    end process;

    -- Power rail model
    -- When pg_disabled is true, pg is forced low
    -- Otherwise, pg follows enable (with potential for future delay modeling)
    rail.pg <= '0' when pg_disabled else rail.enable;

end model;