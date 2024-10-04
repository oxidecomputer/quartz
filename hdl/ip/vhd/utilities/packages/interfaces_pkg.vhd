-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- This package relies on the VHDL 2019 feature for "interfaces"

library ieee;
use ieee.std_logic_1164.all;

package interfaces_pkg is

    type data_channel is record
        data    : std_logic_vector(7 downto 0);
        valid   : std_logic;
        ready   : std_logic;
    end record;

    view st_source of data_channel is
        valid, data : out;
        ready       : in;
    end view;

    alias st_sink is st_source'converse;

end package;