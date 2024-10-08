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

package fifos_sim_pkg is

    procedure push_fifo (
        signal net    : inout network_t;
        variable data : in std_logic_vector(7 downto 0)
    );

    procedure pop_fifo (
        signal net    : inout network_t;
        variable data : out std_logic_vector(7 downto 0)
    );

    procedure push_mixed_fifo (
        signal net : inout network_t
    );

    procedure pop_mixed_fifo (
        signal net    : inout network_t;
        variable data : out std_logic_vector(7 downto 0)
    );

end package;

package body fifos_sim_pkg is

    procedure push_fifo (
        signal net    : inout network_t;
        variable data : in std_logic_vector(7 downto 0)
    ) is

        variable msg_target : actor_t;
        variable send_data  : std_logic_vector(31 downto 0) := (others => '0');

    begin
        msg_target            := find("write_side");
        send_data(7 downto 0) := data;
        send_data(8)          := '1';  -- bit 8 acts as write strobe
        set_gpio(net, msg_target, send_data);
        -- clear write strobe, leave data driven even though we don't really care
        send_data(8) := '0';
        set_gpio(net, msg_target, send_data);
    end;

    procedure pop_fifo (
        signal net    : inout network_t;
        variable data : out std_logic_vector(7 downto 0)
    ) is

        variable msg_target : actor_t;
        variable send_data  : std_logic_vector(31 downto 0) := (others => '0');
        variable get_data   : std_logic_vector(31 downto 0) := (others => '0');

    begin
        msg_target := find("read_side");
        -- showahead so grab data (and flags), then rd_ack
        get_gpio(net, msg_target, get_data);
        send_data(0) := '1';
        set_gpio(net, msg_target, send_data);
        send_data(0) := '0'; -- clear strobe
        set_gpio(net, msg_target, send_data);
        data         := get_data(7 downto 0);
    end;

    procedure push_mixed_fifo (
        signal net : inout network_t
    ) is

        variable msg_target : actor_t;
        variable send_data  : std_logic_vector(31 downto 0) := (others => '0');

    begin
        msg_target            := find("mixed_write_side");
        send_data(0)          := '1';
        set_gpio(net, msg_target, send_data);
        -- clear write strobe, leave data driven even though we don't really care
        send_data(0) := '0';
        set_gpio(net, msg_target, send_data);
    end;

    procedure pop_mixed_fifo (
        signal net    : inout network_t;
        variable data : out std_logic_vector(7 downto 0)
    ) is

        variable msg_target : actor_t;
        variable send_data  : std_logic_vector(31 downto 0) := (others => '0');
        variable get_data   : std_logic_vector(31 downto 0) := (others => '0');

    begin
        msg_target := find("mixed_read_side");
        -- showahead so grab data (and flags), then rd_ack
        get_gpio(net, msg_target, get_data);
        send_data(0) := '1';
        set_gpio(net, msg_target, send_data);
        send_data(0) := '0'; -- clear strobe
        set_gpio(net, msg_target, send_data);
        data         := get_data(7 downto 0);
    end;

end package body;
