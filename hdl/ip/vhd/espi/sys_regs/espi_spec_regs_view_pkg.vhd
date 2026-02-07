-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Composite record and views for exposing eSPI spec register
-- values as a read-only interface in the sys_regs address space.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.espi_spec_regs_pkg.all;

package espi_spec_regs_view_pkg is

    type spec_regs_t is record
        device_id            : device_id_type;
        general_capabilities : general_capabilities_type;
        ch0_capabilities     : ch0_capabilities_type;
        ch1_capabilities     : ch1_capabilities_type;
        ch2_capabilities     : ch2_capabilities_type;
        ch3_capabilities     : ch3_capabilities_type;
        ch3_capabilities2    : ch3_capabilities2_type;
    end record;

    view spec_regs_source of spec_regs_t is
        device_id            : out;
        general_capabilities : out;
        ch0_capabilities     : out;
        ch1_capabilities     : out;
        ch2_capabilities     : out;
        ch3_capabilities     : out;
        ch3_capabilities2    : out;
    end view;

    alias spec_regs_sink is spec_regs_source'converse;

end package;
