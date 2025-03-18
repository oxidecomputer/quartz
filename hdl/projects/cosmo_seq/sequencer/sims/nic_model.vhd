-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sequencer_io_pkg.all;

entity nic_model is
    port (
        clk : in std_logic;
        reset : in std_logic;

        nic_rails : view nic_power_at_reg;
    );
end entity;

architecture model of nic_model is

begin
    -- TODO: we'd like to have some kind of commanded fault injection
    -- and maybe the ability to even fail the sequencing, or adjust the delays.

    -- for now, though we implement the most basic of models where the rails
    -- turn on when requested after some delay

    -- The block we're interfacing with expects to be synchronized
    process(clk)
    begin
        nic_rails.v1p5_nic_a0hp.pg <= nic_rails.nic_hsc_12v.enable;
        nic_rails.v1p2_nic_pcie_a0hp.pg <= nic_rails.nic_hsc_12v.enable;
        nic_rails.v1p2_nic_enet_a0hp.pg <= nic_rails.nic_hsc_12v.enable;
        nic_rails.v3p3_nic_a0hp.pg <= nic_rails.nic_hsc_12v.enable;
        nic_rails.v1p1_nic_a0hp.pg <= nic_rails.nic_hsc_12v.enable;
        nic_rails.v0p96_nic_vdd_a0hp.pg <= nic_rails.nic_hsc_12v.enable;
        nic_rails.nic_hsc_12v.pg <= nic_rails.nic_hsc_12v.enable;
        nic_rails.nic_hsc_5v.pg <= nic_rails.nic_hsc_12v.enable;
    end process;

end model;