-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Inspired by Intel's Avalon-ST Bytes to Packets and Packets to Bytes
-- cores, but not using channels

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package axi_bytes_pkg is

    constant start_char : std_logic_vector(7 downto 0) := x"7A";
    constant end_char : std_logic_vector(7 downto 0) := x"7B";
    constant escape_char : std_logic_vector(7 downto 0) := x"7D";
    constant escape_xor : std_logic_vector(7 downto 0) := x"20";

    function do_escape(input : std_logic_vector(7 downto 0)) return std_logic_vector;
    function matches_ctrl_char(input : std_logic_vector(7 downto 0)) return boolean;


end package axi_bytes_pkg;

package body axi_bytes_pkg is
    function do_escape(input : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        return input xor escape_xor;
    end function;
    function matches_ctrl_char(input : std_logic_vector(7 downto 0)) return boolean is
    begin
        return input = start_char or input = end_char or input = escape_char;
    end function;
end package body axi_bytes_pkg;