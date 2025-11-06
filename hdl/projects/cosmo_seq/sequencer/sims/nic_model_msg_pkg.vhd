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

package nic_model_msg_pkg is

    -- Message types with rail name parameter
    constant disable_rail_msg : msg_type_t := new_msg_type("disable_rail");
    constant enable_rail_msg  : msg_type_t := new_msg_type("enable_rail");

    -- Rail name constants
    constant RAIL_V1P5_NIC_A0HP      : string := "v1p5_nic_a0hp";
    constant RAIL_V1P2_NIC_PCIE_A0HP : string := "v1p2_nic_pcie_a0hp";
    constant RAIL_V1P2_NIC_ENET_A0HP : string := "v1p2_nic_enet_a0hp";
    constant RAIL_V3P3_NIC_A0HP      : string := "v3p3_nic_a0hp";
    constant RAIL_V1P1_NIC_A0HP      : string := "v1p1_nic_a0hp";
    constant RAIL_V1P4_NIC_A0HP      : string := "v1p4_nic_a0hp";
    constant RAIL_V0P96_NIC_VDD_A0HP : string := "v0p96_nic_vdd_a0hp";
    constant RAIL_NIC_HSC_12V        : string := "nic_hsc_12v";
    constant RAIL_NIC_HSC_5V         : string := "nic_hsc_5v";
    constant RAIL_ALL                : string := "all";

    -- Procedure to disable power-good for a specific rail or all rails
    procedure disable_power_good (
        signal net        : inout network_t;
        constant actor    : actor_t;
        constant rail_name : string := RAIL_ALL
    );

    -- Procedure to enable power-good for a specific rail or all rails
    procedure enable_power_good (
        signal net        : inout network_t;
        constant actor    : actor_t;
        constant rail_name : string := RAIL_ALL
    );

end package;

package body nic_model_msg_pkg is

    -- Helper procedure to disable power-good reporting
    procedure disable_power_good (
        signal net        : inout network_t;
        constant actor    : actor_t;
        constant rail_name : string := RAIL_ALL
    ) is
        variable request_msg : msg_t := new_msg(disable_rail_msg);
    begin
        push_string(request_msg, rail_name);
        send(net, actor, request_msg);
    end;

    -- Helper procedure to enable power-good reporting
    procedure enable_power_good (
        signal net        : inout network_t;
        constant actor    : actor_t;
        constant rail_name : string := RAIL_ALL
    ) is
        variable request_msg : msg_t := new_msg(enable_rail_msg);
    begin
        push_string(request_msg, rail_name);
        send(net, actor, request_msg);
    end;

end package body;
