-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- A no synth, no sim, black entity to make analysis happy

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity gfruit_pll is
    port (
        clk_50m : in std_logic;
        clk_125m : out std_logic;
        clk_200m : out std_logic;
        reset : in std_logic;
        locked : out std_logic 
);

end entity;