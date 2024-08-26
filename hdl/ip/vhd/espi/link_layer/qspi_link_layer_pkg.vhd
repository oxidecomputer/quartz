-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package qspi_link_layer_pkg is

    -- Enum for our qspi operating mode
    type qspi_mode_t is (single, dual, quad);

    -- This is relying on the VHDL 2019 feature
    -- for "interfaces"
    type data_channel is record
        data  : std_logic_vector(7 downto 0);
        valid : std_logic;
        ready: std_logic;

    end record;

    view st_source of data_channel is  -- the mode view of the record
        valid, data : out;
        ready       : in;
    end view;

    alias st_sink is st_source'converse;


    function get_shift_amt_by_mode (
        constant mode : qspi_mode_t
    ) return natural;

end package;

package body qspi_link_layer_pkg is

    function get_shift_amt_by_mode (
        constant mode : qspi_mode_t
    ) return natural is
    begin
        case mode is
            when single =>
                return 1;
            when dual =>
                return 2;
            when quad =>
                return 4;
        end case;
    end;

end package body;
