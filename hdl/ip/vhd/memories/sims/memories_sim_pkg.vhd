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

package memories_sim_pkg is

    procedure write_dpr (
        signal net    : inout network_t;
        variable addr : in std_logic_vector(3 downto 0);
        variable data : in std_logic_vector(7 downto 0)
    );

    procedure read_dpr (
        signal net    : inout network_t;
        variable addr : in  std_logic_vector(3 downto 0);
        variable data : out std_logic_vector(7 downto 0)
    );

end package;

package body memories_sim_pkg is

    procedure write_dpr (
        signal net    : inout network_t;
        variable addr : in std_logic_vector(3 downto 0);
        variable data : in std_logic_vector(7 downto 0)
    ) is

        variable msg_target : actor_t;
        variable send_data  : std_logic_vector(31 downto 0) := (others => '0');

    begin
        msg_target             := find("dpr_write_side");
        send_data(12 downto 0) := "1" & addr & data;
        set_gpio(net, msg_target, send_data);
        send_data(12)          := '0';
        set_gpio(net, msg_target, send_data);
    end;

    procedure read_dpr (
        signal net    : inout network_t;
        variable addr : in  std_logic_vector(3 downto 0);
        variable data : out std_logic_vector(7 downto 0)
    ) is

        variable msg_target : actor_t;
        variable send_data  : std_logic_vector(31 downto 0) := (others => '0');
        variable get_data   : std_logic_vector(31 downto 0) := (others => '0');

    begin
        msg_target            := find("dpr_read_side");
        send_data(3 downto 0) := addr;
        set_gpio(net, msg_target, send_data);
        get_gpio(net, msg_target, get_data);
        data                  := get_data(7 downto 0);
    end;

end package body;
