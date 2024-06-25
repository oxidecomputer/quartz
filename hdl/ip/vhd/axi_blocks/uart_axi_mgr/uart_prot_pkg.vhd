-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package uart_prot_pkg is
    type class_t is (connect, read, write);
    type header_t is record
        class  : class_t;
        tid    : unsigned(7 downto 0);
        size   : unsigned(7 downto 0);
    end record;

    -- MVP here is very simple, read-write with address and payload, single 32bit words only

end package uart_prot_pkg;