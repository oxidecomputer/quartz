-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sequencer_io_pkg.all;

entity rail_model is
    port (
        clk : in std_logic;
        reset : in std_logic;

        rail : view power_rail_at_reg;
    );
end entity;

architecture model of rail_model is

begin

     -- TODO: we'd like to have some kind of commanded fault injection
    -- and maybe the ability to even fail the sequencing, or adjust the delays.

    -- for now, though we implement the most basic of models where the rails
    -- turn on when requested after some delay

    -- The block we're interfacing with expects to be synchronized
    process(clk)
    begin
        rail.pg <= rail.enable;
    end process;
end model;