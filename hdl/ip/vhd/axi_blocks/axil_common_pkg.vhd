-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package axil_common_pkg is

    -- Interconnect configuration
    type axil_responder_config is record
        base_addr : std_logic_vector(31 downto 0);
        addr_span_bits : integer;
    end record;

    type axil_responder_cfg_array_t is array (natural range <>) of axil_responder_config;

    type int_array is array (natural range <>) of integer;

    constant OKAY : std_logic_vector(1 downto 0) := "00";
    constant EXOKAY : std_logic_vector(1 downto 0) := "01";
    constant SLVERR : std_logic_vector(1 downto 0) := "10";


end package;