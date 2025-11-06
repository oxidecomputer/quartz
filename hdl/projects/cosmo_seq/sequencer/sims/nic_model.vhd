-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

use work.sequencer_io_pkg.all;
use work.nic_model_msg_pkg.all;
use work.nic_model_msg_pkg.disable_rail_msg;
use work.nic_model_msg_pkg.enable_rail_msg;

entity nic_model is
    generic (
        actor_name : string := "nic_model"
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        nic_rails : view nic_power_at_reg
    );
end entity;

architecture model of nic_model is

    -- Individual rail disable signals
    signal v1p5_nic_a0hp_disabled      : boolean := false;
    signal v1p2_nic_pcie_a0hp_disabled : boolean := false;
    signal v1p2_nic_enet_a0hp_disabled : boolean := false;
    signal v3p3_nic_a0hp_disabled      : boolean := false;
    signal v1p1_nic_a0hp_disabled      : boolean := false;
    signal v1p4_nic_a0hp_disabled      : boolean := false;
    signal v0p96_nic_vdd_a0hp_disabled : boolean := false;
    signal nic_hsc_12v_disabled        : boolean := false;
    signal nic_hsc_5v_disabled         : boolean := false;

begin

    -- Message handling process for VUnit communication
    msg_handler : process
        variable self        : actor_t;
        variable msg_type    : msg_type_t;
        variable request_msg : msg_t;
        variable rail_name_var : line;
        variable rail_name   : string(1 to 32);
    begin
        self := new_actor(actor_name);
        loop
            receive(net, self, request_msg);
            msg_type := message_type(request_msg);

            if msg_type = disable_rail_msg then
                -- Read string into line, then copy to fixed-size string with padding
                rail_name_var := new string'(pop_string(request_msg));
                rail_name := (others => ' ');  -- Initialize with spaces
                rail_name(1 to rail_name_var'length) := rail_name_var.all;

                if rail_name(1 to 3) = "all" then
                    info("Disabling all NIC rails");
                    v1p5_nic_a0hp_disabled      <= true;
                    v1p2_nic_pcie_a0hp_disabled <= true;
                    v1p2_nic_enet_a0hp_disabled <= true;
                    v3p3_nic_a0hp_disabled      <= true;
                    v1p1_nic_a0hp_disabled      <= true;
                    v1p4_nic_a0hp_disabled      <= true;
                    v0p96_nic_vdd_a0hp_disabled <= true;
                    nic_hsc_12v_disabled        <= true;
                    nic_hsc_5v_disabled         <= true;
                elsif rail_name(1 to 15) = "v1p5_nic_a0hp  " then
                    info("Disabling v1p5_nic_a0hp rail");
                    v1p5_nic_a0hp_disabled <= true;
                elsif rail_name(1 to 20) = "v1p2_nic_pcie_a0hp  " then
                    info("Disabling v1p2_nic_pcie_a0hp rail");
                    v1p2_nic_pcie_a0hp_disabled <= true;
                elsif rail_name(1 to 20) = "v1p2_nic_enet_a0hp  " then
                    info("Disabling v1p2_nic_enet_a0hp rail");
                    v1p2_nic_enet_a0hp_disabled <= true;
                elsif rail_name(1 to 15) = "v3p3_nic_a0hp  " then
                    info("Disabling v3p3_nic_a0hp rail");
                    v3p3_nic_a0hp_disabled <= true;
                elsif rail_name(1 to 15) = "v1p1_nic_a0hp  " then
                    info("Disabling v1p1_nic_a0hp rail");
                    v1p1_nic_a0hp_disabled <= true;
                elsif rail_name(1 to 15) = "v1p4_nic_a0hp  " then
                    info("Disabling v1p4_nic_a0hp rail");
                    v1p4_nic_a0hp_disabled <= true;
                elsif rail_name(1 to 20) = "v0p96_nic_vdd_a0hp  " then
                    info("Disabling v0p96_nic_vdd_a0hp rail");
                    v0p96_nic_vdd_a0hp_disabled <= true;
                elsif rail_name(1 to 13) = "nic_hsc_12v  " then
                    info("Disabling nic_hsc_12v rail");
                    nic_hsc_12v_disabled <= true;
                elsif rail_name(1 to 12) = "nic_hsc_5v  " then
                    info("Disabling nic_hsc_5v rail");
                    nic_hsc_5v_disabled <= true;
                else
                    warning("Unknown rail name: " & rail_name);
                end if;

            elsif msg_type = enable_rail_msg then
                -- Read string into line, then copy to fixed-size string with padding
                rail_name_var := new string'(pop_string(request_msg));
                rail_name := (others => ' ');  -- Initialize with spaces
                rail_name(1 to rail_name_var'length) := rail_name_var.all;

                if rail_name(1 to 3) = "all" then
                    info("Enabling all NIC rails");
                    v1p5_nic_a0hp_disabled      <= false;
                    v1p2_nic_pcie_a0hp_disabled <= false;
                    v1p2_nic_enet_a0hp_disabled <= false;
                    v3p3_nic_a0hp_disabled      <= false;
                    v1p1_nic_a0hp_disabled      <= false;
                    v1p4_nic_a0hp_disabled      <= false;
                    v0p96_nic_vdd_a0hp_disabled <= false;
                    nic_hsc_12v_disabled        <= false;
                    nic_hsc_5v_disabled         <= false;
                elsif rail_name(1 to 15) = "v1p5_nic_a0hp  " then
                    info("Enabling v1p5_nic_a0hp rail");
                    v1p5_nic_a0hp_disabled <= false;
                elsif rail_name(1 to 20) = "v1p2_nic_pcie_a0hp  " then
                    info("Enabling v1p2_nic_pcie_a0hp rail");
                    v1p2_nic_pcie_a0hp_disabled <= false;
                elsif rail_name(1 to 20) = "v1p2_nic_enet_a0hp  " then
                    info("Enabling v1p2_nic_enet_a0hp rail");
                    v1p2_nic_enet_a0hp_disabled <= false;
                elsif rail_name(1 to 15) = "v3p3_nic_a0hp  " then
                    info("Enabling v3p3_nic_a0hp rail");
                    v3p3_nic_a0hp_disabled <= false;
                elsif rail_name(1 to 15) = "v1p1_nic_a0hp  " then
                    info("Enabling v1p1_nic_a0hp rail");
                    v1p1_nic_a0hp_disabled <= false;
                elsif rail_name(1 to 15) = "v1p4_nic_a0hp  " then
                    info("Enabling v1p4_nic_a0hp rail");
                    v1p4_nic_a0hp_disabled <= false;
                elsif rail_name(1 to 20) = "v0p96_nic_vdd_a0hp  " then
                    info("Enabling v0p96_nic_vdd_a0hp rail");
                    v0p96_nic_vdd_a0hp_disabled <= false;
                elsif rail_name(1 to 13) = "nic_hsc_12v  " then
                    info("Enabling nic_hsc_12v rail");
                    nic_hsc_12v_disabled <= false;
                elsif rail_name(1 to 12) = "nic_hsc_5v  " then
                    info("Enabling nic_hsc_5v rail");
                    nic_hsc_5v_disabled <= false;
                else
                    warning("Unknown rail name: " & rail_name);
                end if;

            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;
        wait;
    end process;

    -- NIC power rail model
    -- When individual rail is disabled, its PG signal is forced low (fault injection)
    -- Otherwise, pg follows enable (basic model where rails turn on when requested)
    nic_rails.v1p5_nic_a0hp.pg <= '0' when v1p5_nic_a0hp_disabled else nic_rails.nic_hsc_12v.enable;
    nic_rails.v1p2_nic_pcie_a0hp.pg <= '0' when v1p2_nic_pcie_a0hp_disabled else nic_rails.nic_hsc_12v.enable;
    nic_rails.v1p2_nic_enet_a0hp.pg <= '0' when v1p2_nic_enet_a0hp_disabled else nic_rails.nic_hsc_12v.enable;
    nic_rails.v3p3_nic_a0hp.pg <= '0' when v3p3_nic_a0hp_disabled else nic_rails.nic_hsc_12v.enable;
    nic_rails.v1p1_nic_a0hp.pg <= '0' when v1p1_nic_a0hp_disabled else nic_rails.nic_hsc_12v.enable;
    nic_rails.v1p4_nic_a0hp.pg <= '0' when v1p4_nic_a0hp_disabled else nic_rails.nic_hsc_12v.enable;
    nic_rails.v0p96_nic_vdd_a0hp.pg <= '0' when v0p96_nic_vdd_a0hp_disabled else nic_rails.nic_hsc_12v.enable;
    -- HSC's on board are active low PG signals
    nic_rails.nic_hsc_12v.pg <= '1' when nic_hsc_12v_disabled else not nic_rails.nic_hsc_12v.enable;
    nic_rails.nic_hsc_5v.pg <= '1' when nic_hsc_5v_disabled else not nic_rails.nic_hsc_12v.enable;

end model;
