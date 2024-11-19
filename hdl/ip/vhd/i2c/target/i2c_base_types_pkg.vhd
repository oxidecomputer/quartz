-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Shared base types for i2c components

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package i2c_base_types_pkg is

    type i2c_header is record
        tgt_addr : std_logic_vector(6 downto 0);
        read_write_n : std_logic;
        valid : std_logic;
    end record;

end package;