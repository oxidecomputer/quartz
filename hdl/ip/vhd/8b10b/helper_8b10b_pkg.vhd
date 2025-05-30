-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.calc_pkg.all;
use work.transforms_pkg.all;

package helper_8b10b_pkg is

-- 8b10b encoding constants in decoded form
constant K28_0                  : std_logic_vector(7 downto 0) := X"1C";
constant K28_1                  : std_logic_vector(7 downto 0) := X"3C";
constant K28_2                  : std_logic_vector(7 downto 0) := X"5C";
constant K28_3                  : std_logic_vector(7 downto 0) := X"7C";
constant K28_4                  : std_logic_vector(7 downto 0) := X"9C";
constant K28_5                  : std_logic_vector(7 downto 0) := X"BC";
constant K28_6                  : std_logic_vector(7 downto 0) := X"DC";
constant K28_7                  : std_logic_vector(7 downto 0) := X"FC";
constant K23_7                  : std_logic_vector(7 downto 0) := X"F7";
constant K27_7                  : std_logic_vector(7 downto 0) := X"FB";
constant K29_7                  : std_logic_vector(7 downto 0) := X"FD";
constant K30_7                  : std_logic_vector(7 downto 0) := X"FE";
constant KERR                   : std_logic_vector(7 downto 0) := X"FF";

type encoded_8b10b_t is record
    data : std_logic_vector(9 downto 0);
    disparity : std_logic;
end record;

type encode_lkup_table_t is array(0 to 255) of std_logic_vector(9 downto 0);


-- a CAM table for 8b10b encoding. This likely should not be used in hw
-- but is useful for verification
-- This is to be used when you're running a negative disparity
-- in abcdeifghj
 -- Most tables show data LSB..MSB when showing k tables
-- so we put stuff in that way here and will reverse when needed.
constant RD_MINUS_LSB1ST : encode_lkup_table_t := (
    10x"274", 10x"1d4", 10x"2d4", 10x"31b", 10x"354", 10x"29b", 10x"19b", 10x"38b",
    10x"394", 10x"25b", 10x"15b", 10x"34b", 10x"0db", 10x"2cb", 10x"1cb", 10x"174",
    10x"1b4", 10x"23b", 10x"13b", 10x"32b", 10x"0bb", 10x"2ab", 10x"1ab", 10x"3a4",
    10x"334", 10x"26b", 10x"16b", 10x"364", 10x"0eb", 10x"2e4", 10x"1e4", 10x"2b4",
    10x"279", 10x"1d9", 10x"2d9", 10x"319", 10x"359", 10x"299", 10x"199", 10x"389",
    10x"399", 10x"259", 10x"159", 10x"349", 10x"0d9", 10x"2c9", 10x"1c9", 10x"179",
    10x"1b9", 10x"239", 10x"139", 10x"329", 10x"0b9", 10x"2a9", 10x"1a9", 10x"3a9",
    10x"339", 10x"269", 10x"169", 10x"369", 10x"0e9", 10x"2e9", 10x"1e9", 10x"2b9",
    10x"275", 10x"1d5", 10x"2d5", 10x"315", 10x"355", 10x"295", 10x"195", 10x"385",
    10x"395", 10x"255", 10x"155", 10x"345", 10x"0d5", 10x"2c5", 10x"1c5", 10x"175",
    10x"1b5", 10x"235", 10x"135", 10x"325", 10x"0b5", 10x"2a5", 10x"1a5", 10x"3a5",
    10x"335", 10x"265", 10x"165", 10x"365", 10x"0e5", 10x"2e5", 10x"1e5", 10x"2b5",
    10x"273", 10x"1d3", 10x"2d3", 10x"31c", 10x"353", 10x"29c", 10x"19c", 10x"38c",
    10x"393", 10x"25c", 10x"15c", 10x"34c", 10x"0dc", 10x"2cc", 10x"1cc", 10x"173",
    10x"1b3", 10x"23c", 10x"13c", 10x"32c", 10x"0bc", 10x"2ac", 10x"1ac", 10x"3a3",
    10x"333", 10x"26c", 10x"16c", 10x"363", 10x"0ec", 10x"2e3", 10x"1e3", 10x"2b3",
    10x"272", 10x"1d2", 10x"2d2", 10x"31d", 10x"352", 10x"29d", 10x"19d", 10x"38d",
    10x"392", 10x"25d", 10x"15d", 10x"34d", 10x"0dd", 10x"2cd", 10x"1cd", 10x"172",
    10x"1b2", 10x"23d", 10x"13d", 10x"32d", 10x"0bd", 10x"2ad", 10x"1ad", 10x"3a2",
    10x"332", 10x"26d", 10x"16d", 10x"362", 10x"0ed", 10x"2e2", 10x"1e2", 10x"2b2",
    10x"27a", 10x"1da", 10x"2da", 10x"31a", 10x"35a", 10x"29a", 10x"19a", 10x"38a",
    10x"39a", 10x"25a", 10x"15a", 10x"34a", 10x"0da", 10x"2ca", 10x"1ca", 10x"17a",
    10x"1ba", 10x"23a", 10x"13a", 10x"32a", 10x"0ba", 10x"2aa", 10x"1aa", 10x"3aa",
    10x"33a", 10x"26a", 10x"16a", 10x"36a", 10x"0ea", 10x"2ea", 10x"1ea", 10x"2ba",
    10x"276", 10x"1d6", 10x"2d6", 10x"316", 10x"356", 10x"296", 10x"196", 10x"386",
    10x"396", 10x"256", 10x"156", 10x"346", 10x"0d6", 10x"2c6", 10x"1c6", 10x"176",
    10x"1b6", 10x"236", 10x"136", 10x"326", 10x"0b6", 10x"2a6", 10x"1a6", 10x"3a6",
    10x"336", 10x"266", 10x"166", 10x"366", 10x"0e6", 10x"2e6", 10x"1e6", 10x"2b6",
    10x"271", 10x"1d1", 10x"2d1", 10x"31e", 10x"351", 10x"29e", 10x"19e", 10x"38e",
    10x"391", 10x"25e", 10x"15e", 10x"34e", 10x"0de", 10x"2ce", 10x"1ce", 10x"171",
    10x"1b1", 10x"237", 10x"137", 10x"32e", 10x"0b7", 10x"2ae", 10x"1ae", 10x"3a1",
    10x"331", 10x"26e", 10x"16e", 10x"361", 10x"0ee", 10x"2e1", 10x"1e1", 10x"2b1");

constant RD_PLUS_LSB1ST : encode_lkup_table_t := (
    10x"18b", 10x"22b", 10x"12b", 10x"314", 10x"0ab", 10x"294", 10x"194", 10x"074",
    10x"06b", 10x"254", 10x"154", 10x"344", 10x"0d4", 10x"2c4", 10x"1c4", 10x"28b",
    10x"24b", 10x"234", 10x"134", 10x"324", 10x"0b4", 10x"2a4", 10x"1a4", 10x"05b",
    10x"0cb", 10x"264", 10x"164", 10x"09b", 10x"0e4", 10x"11b", 10x"21b", 10x"14b",
    10x"189", 10x"229", 10x"129", 10x"319", 10x"0a9", 10x"299", 10x"199", 10x"079",
    10x"069", 10x"259", 10x"159", 10x"349", 10x"0d9", 10x"2c9", 10x"1c9", 10x"289",
    10x"249", 10x"239", 10x"139", 10x"329", 10x"0b9", 10x"2a9", 10x"1a9", 10x"059",
    10x"0c9", 10x"269", 10x"169", 10x"099", 10x"0e9", 10x"119", 10x"219", 10x"149",
    10x"185", 10x"225", 10x"125", 10x"315", 10x"0a5", 10x"295", 10x"195", 10x"075",
    10x"065", 10x"255", 10x"155", 10x"345", 10x"0d5", 10x"2c5", 10x"1c5", 10x"285",
    10x"245", 10x"235", 10x"135", 10x"325", 10x"0b5", 10x"2a5", 10x"1a5", 10x"055",
    10x"0c5", 10x"265", 10x"165", 10x"095", 10x"0e5", 10x"115", 10x"215", 10x"145",
    10x"18c", 10x"22c", 10x"12c", 10x"313", 10x"0ac", 10x"293", 10x"193", 10x"073",
    10x"06c", 10x"253", 10x"153", 10x"343", 10x"0d3", 10x"2c3", 10x"1c3", 10x"28c",
    10x"24c", 10x"233", 10x"133", 10x"323", 10x"0b3", 10x"2a3", 10x"1a3", 10x"05c",
    10x"0cc", 10x"263", 10x"163", 10x"09c", 10x"0e3", 10x"11c", 10x"21c", 10x"14c",
    10x"18d", 10x"22d", 10x"12d", 10x"312", 10x"0ad", 10x"292", 10x"192", 10x"072",
    10x"06d", 10x"252", 10x"152", 10x"342", 10x"0d2", 10x"2c2", 10x"1c2", 10x"28d",
    10x"24d", 10x"232", 10x"132", 10x"322", 10x"0b2", 10x"2a2", 10x"1a2", 10x"05d",
    10x"0cd", 10x"262", 10x"162", 10x"09d", 10x"0e2", 10x"11d", 10x"21d", 10x"14d",
    10x"18a", 10x"22a", 10x"12a", 10x"31a", 10x"0aa", 10x"29a", 10x"19a", 10x"07a",
    10x"06a", 10x"25a", 10x"15a", 10x"34a", 10x"0da", 10x"2ca", 10x"1ca", 10x"28a",
    10x"24a", 10x"23a", 10x"13a", 10x"32a", 10x"0ba", 10x"2aa", 10x"1aa", 10x"05a",
    10x"0ca", 10x"26a", 10x"16a", 10x"09a", 10x"0ea", 10x"11a", 10x"21a", 10x"14a",
    10x"186", 10x"226", 10x"126", 10x"316", 10x"0a6", 10x"296", 10x"196", 10x"076",
    10x"066", 10x"256", 10x"156", 10x"346", 10x"0d6", 10x"2c6", 10x"1c6", 10x"286",
    10x"246", 10x"236", 10x"136", 10x"326", 10x"0b6", 10x"2a6", 10x"1a6", 10x"056",
    10x"0c6", 10x"266", 10x"166", 10x"096", 10x"0e6", 10x"116", 10x"216", 10x"146",
    10x"18e", 10x"22e", 10x"12e", 10x"311", 10x"0ae", 10x"291", 10x"191", 10x"071",
    10x"06e", 10x"251", 10x"151", 10x"348", 10x"0d1", 10x"2c8", 10x"1c8", 10x"28e",
    10x"24e", 10x"231", 10x"131", 10x"321", 10x"0b1", 10x"2a1", 10x"1a1", 10x"05e",
    10x"0ce", 10x"261", 10x"161", 10x"09e", 10x"0e1", 10x"11e", 10x"21e", 10x"14e");
-- Note: this is only useful for simulation/test.  Use proper hardware 8b10b encoders
-- for logic designs.  This function uses both the lookup arrays above and count_ones
-- and count_zeros functions to determine the new disparity, and is not intended to be
-- efficiently synthesized.
function encode_data(
    data_in : std_logic_vector(7 downto 0);
    running_disparity : std_logic
) return encoded_8b10b_t;

function encode_k(
    data_in : std_logic_vector(7 downto 0);
    running_disparity : std_logic
) return encoded_8b10b_t;

function encode(
    data_in : std_logic_vector(7 downto 0);
    control : std_logic;
    running_disparity : std_logic
) return encoded_8b10b_t;

end package;

package body helper_8b10b_pkg is

    function encode_data(
        data_in : std_logic_vector(7 downto 0);
        running_disparity : std_logic
    ) return encoded_8b10b_t is
        variable encoded : encoded_8b10b_t;
        variable encoded_val : std_logic_vector(9 downto 0);
    begin
        if running_disparity = '0' then
            encoded_val := reverse(RD_MINUS_LSB1ST(to_integer(data_in)));
        else
            encoded_val := reverse(RD_PLUS_LSB1ST(to_integer(data_in)));
        end if;

        encoded.data := encoded_val;
        -- Now figure out the new disparity based on our chosen word
        if count_ones(encoded_val) = count_zeros(encoded_val) then
            encoded.disparity := running_disparity;  -- hold the same
        else
            encoded.disparity := not running_disparity;  -- flip
        end if;
        return encoded;
    end function;

    function encode_k(
    data_in : std_logic_vector(7 downto 0);
    running_disparity : std_logic
) return encoded_8b10b_t is
    variable encoded : encoded_8b10b_t;
begin
    encoded.disparity := running_disparity;  -- default to hold
    case data_in is
        -- Most tables show data LSB..MSB when showing k tables
        -- so we put stuff in that way here and will reverse at the end.
        when K28_0 =>
            encoded.data := 10x"0f4" when running_disparity = '0' else 10x"30b";
        when K28_1 =>
            encoded.data := 10x"0f9" when running_disparity = '0' else 10x"306";
            encoded.disparity := not encoded.disparity;
        when K28_2 =>
            encoded.data := 10x"0f5" when running_disparity = '0' else 10x"30a";
            encoded.disparity := not encoded.disparity;
        when K28_3 =>
            encoded.data := 10x"0f3" when running_disparity = '0' else 10x"30c";
            encoded.disparity := not encoded.disparity;
        when K28_4 =>
            encoded.data := 10x"0f2" when running_disparity = '0' else 10x"30d";
        when K28_5 =>
            encoded.data := 10x"0fa" when running_disparity = '0' else 10x"305";
            encoded.disparity := not encoded.disparity;
        when K28_6 =>
            encoded.data := 10x"0f6" when running_disparity = '0' else 10x"309";
            encoded.disparity := not encoded.disparity;
        when K28_7 =>
            encoded.data := 10x"0f8" when running_disparity = '0' else 10x"307";
        when K23_7 =>
            encoded.data := 10x"3a8" when running_disparity = '0' else 10x"057";
        when K27_7 =>
            encoded.data := 10x"368" when running_disparity = '0' else 10x"97";
        when K29_7 =>
            encoded.data := 10x"2e8" when running_disparity = '0' else 10x"117";
        when K30_7 =>
            encoded.data := 10x"1e8" when running_disparity = '0' else 10x"217";
        when others =>
            encoded.data := (others => '1');
            assert false report "Can't encode invalid K character" severity error;
    end case;
    encoded.data := reverse(encoded.data); -- See above want LSB on the right.
    return encoded;
end function;

function encode(
    data_in : std_logic_vector(7 downto 0);
    control : std_logic;
    running_disparity : std_logic
) return encoded_8b10b_t is
begin
    if control = '1' then
        return encode_k(data_in, running_disparity);
    else
        return encode_data(data_in, running_disparity);
    end if;
end function;

end package body;