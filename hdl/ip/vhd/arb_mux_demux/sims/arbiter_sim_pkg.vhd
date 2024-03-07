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

use work.gpio_msg_pkg.all;

package arbiter_sim_pkg is

    procedure set_arb(
        signal net : inout network_t;
        variable msg_target :in actor_t;
        variable data: in std_logic_vector
    );
    procedure get_grant(
        signal net : inout network_t;
        variable msg_target :in actor_t;
        variable data: out std_logic_vector
    );

end package;

package body arbiter_sim_pkg is

    procedure set_arb(
        signal net : inout network_t;
        variable msg_target :in actor_t;
        variable data: in std_logic_vector
    ) is
        variable send_data: std_logic_vector(GPIO_MESAGE_DATA_WDITH - 1 downto 0) := (others => '0');
    begin
        send_data(data'range) := data;
        set_gpio(net, msg_target, send_data);
    end;
    procedure get_grant(
        signal net : inout network_t;
        variable msg_target :in actor_t;
        variable data: out std_logic_vector
    ) is
        variable get_data: std_logic_vector(GPIO_MESAGE_DATA_WDITH - 1 downto 0) := (others => '0');
    begin
        get_gpio(net, msg_target, get_data);
        data := get_data(data'range);
    end;
end package body;   