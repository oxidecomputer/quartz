-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package i2c_core_pkg is

    type op_t is (READ, WRITE, RANDOM_READ);

    type cmd_t is record
        op      : op_t;
        addr    : std_logic_vector(6 downto 0);
        reg     : std_logic_vector(7 downto 0);
        len     : unsigned(7 downto 0);
    end record;

    constant CMD_RESET  : cmd_t := (READ, (others => '0'), (others => '0'), (others => '0'));

end package;