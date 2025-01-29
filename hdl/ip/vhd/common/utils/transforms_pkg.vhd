-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Helper functions for doing various bit transformations.
package transforms_pkg is

    -- Reverse a vector. Based on Jonathan Bromley's vhdl mailing list answer:
    -- https://groups.google.com/g/comp.lang.vhdl/c/eBZQXrw2Ngk/m/4H7oL8hdHMcJ?pli=1
    function reverse (
        a : in std_logic_vector
    ) return std_logic_vector;

    -- Same as above, but overloaded for unsigned types
    function reverse (
        a : in unsigned
    ) return unsigned;

    -- Provides a shift-in at 0 helper for std_logic_vectors.
    -- Returns a vector of the same direction as arg but shifted up 1 bit
    -- with bit shifted in at 0. This will work for both ascending and descending
    -- vectors, always putting the new bit in at 0 and shifting left or right accordingly.
    function shift_in_at_0 (
        arg: in std_logic_vector;
        bit : in std_logic
    ) return std_logic_vector;

    -- Provides a shift-in at high helper for std_logic_vectors.
    -- Returns a vector of the same direction as arg but shifted down 1 bit
    -- with bit shifted in at arg'high. This will work for both ascending and descending
    -- vectors, always putting the new bit in at arg'high and shifting left or right accordingly.
    function shift_in_at_high (
        arg: in std_logic_vector;
        bit : in std_logic
    ) return std_logic_vector;

    -- Same as above, but overloaded for unsigned types
    function shift_in_at_0 (
        arg : in unsigned;
        bit : in std_logic
    ) return unsigned;

     -- Same as above, but overloaded for unsigned types
    function shift_in_at_high (
        arg : in unsigned;
        bit : in std_logic
    ) return unsigned;

end package;

package body transforms_pkg is

    function reverse (
        a : in std_logic_vector
    ) return std_logic_vector is

        variable result : std_logic_vector(a'range);
        alias    aa     : std_logic_vector(a'reverse_range) is a;

    begin
        for i in aa'range loop
            result(i) := aa(i);
        end loop;
        return result;
    end reverse;

    -- Overload for unsigned
    function reverse (
        a : in unsigned
    ) return unsigned is
    begin
        return unsigned(reverse(std_logic_vector(a)));
    end reverse;


    function shift_in_at_0 (
        arg : in unsigned;
        bit : in std_logic
    ) return unsigned is
        variable result : unsigned(arg'range);
    begin
        -- ARG could be ascending or descending, but we're going to
        -- be putting the new bit in at 0 regardless. This means that
        -- new bit 7 is always going to get bit 6 regardless of whether this
        -- ends up being a right or left shift due to vector ordering
        for i in result'high downto result'low + 1 loop
            result(i) := arg(i - 1);
        end loop;
        result(0) := bit;
        return result;
    end function;

    function shift_in_at_high (
        arg : in unsigned;
        bit : in std_logic
    ) return unsigned is
        variable result : unsigned(arg'range);
    begin
         -- ARG could be ascending or descending, but we're going to
        -- be putting the new bit in at high regardless. This means that
        -- new bit 0 is always going to get bit 1 regardless of whether this
        -- ends up being a right or left shift due to vector ordering
        for i in result'high - 1 downto result'low loop
            result(i) := arg(i + 1);
        end loop;
        result(result'high) := bit;
        return result;

    end function;


    function shift_in_at_0 (
        arg : in std_logic_vector;
        bit : in std_logic
    ) return std_logic_vector is
    begin
        return std_logic_vector(shift_in_at_0(unsigned(arg), bit));
    end function;

    function shift_in_at_high (
        arg : in std_logic_vector;
        bit : in std_logic
    ) return std_logic_vector is
    begin
        return std_logic_vector(shift_in_at_high(unsigned(arg), bit));
    end function;

end package body;
