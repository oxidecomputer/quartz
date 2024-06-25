-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.grapefruit_regs_pkg.all;

entity registers is 
    port (
        clk: in std_logic;
        reset: in std_logic;

    );
end entity;