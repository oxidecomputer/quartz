-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- This package relies on the VHDL 2019 feature for "interfaces"

library ieee;
use ieee.std_logic_1164.all;

package streaming_if_pkg is
    generic (
        DATA_WIDTH : integer
    );

    type data_channel is record
        data    : std_logic_vector(DATA_WIDTH - 1 downto 0);
        valid   : std_logic;
        ready   : std_logic;
    end record;

    view st_source of data_channel is
        valid, data : out;
        ready       : in;
    end view;

    alias st_sink is st_source'converse;

end package;

-- Common sizes of streams we expect to have
package stream8_pkg is new work.streaming_if_pkg generic map (DATA_WIDTH => 8);
package stream16_pkg is new work.streaming_if_pkg generic map (DATA_WIDTH => 16);
package stream32_pkg is new work.streaming_if_pkg generic map (DATA_WIDTH => 32);