-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- This package relies on the VHDL 2019 feature for "interfaces"

library ieee;
use ieee.std_logic_1164.all;

package tristate_if_pkg is

    type tristate is record
        i   : std_logic;
        o   : std_logic;
        oe  : std_logic;
    end record;

    view tristate_if of tristate is
        i       : in;
        o, oe   : out;
    end view;

end package;