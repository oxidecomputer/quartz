-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package axilite_if_2008_pkg is

    type tgt_addr8_t is array (natural range <>) of std_logic_vector(7 downto 0);
    type tgt_dat32_t is array (natural range <>) of std_logic_vector(31 downto 0);
    type tgt_strb_t is array (natural range <>) of std_logic_vector(3 downto 0);
    type tgt_resp_t is array (natural range <>) of std_logic_vector(1 downto 0);



end package axilite_if_2008_pkg;