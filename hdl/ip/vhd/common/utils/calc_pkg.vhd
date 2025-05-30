-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Helper functions for doing caclulations and some basic logic for
--! parameterization of logic based on generics or other information
--! known by the time elaboration happens
package calc_pkg is

    --! This function does a log2ceil without using the math.real package
    --! It is generally used for generically sizing vectors based on the
    --! largest value they will contain. This gives us the number of bits
    --! required to represent the given number `n`.
    --! This is generally not synthesizable but can be used for constant
    --! calculations in synthesizable modules since the math will be
    --! executed at compile time in these cases.
    function log2ceil (
        n : natural
    ) return natural;

    --! This function provides a way of selecting between to naturals based
    --! on a condition. Frequently used during constant definition of parameterized
    --! modules, giving ternary-like selection in constant definition
    function sel (
        cond : boolean;
        if_true: natural;
        if_false: natural
    ) return natural;

    function sel (
        cond : boolean;
        if_true: string;
        if_false: string
    ) return string;

    --! Mixed width usedwds calculation
    --! Mixed fifos have different usedwds sizes for read and write
    function usedwds_size (
        bit_width : natural;
        byte_depth : natural
    ) return natural;

    function num_bits_needed(value : natural) return positive;

    function count_ones(value : std_logic_vector) return natural;
    function count_zeros(value : std_logic_vector) return natural;

end package;

package body calc_pkg is

    function num_bits_needed(value : natural) return positive is
    begin
        return log2ceil(value);
    end function;

    function log2ceil (
        n : natural
    ) return natural is

        variable bits_required : natural := 1;
        variable count         : natural := 1;

    begin
        -- simple log calculation algo, see how many times we can
        -- multiply by two before getting larger than our input value
        while (count < n) loop
            count         := count * 2;
            bits_required := bits_required + 1;
        end loop;
        -- Because 0 counts, as long as we have more than 1 bit required,
        -- we need to subtract 1 from the number found above since 8 bits
        -- can represent 256 values
        if bits_required > 1 then
            return bits_required - 1;
        -- If the calculation above got us 1 bit or 0 bits, we set
        -- a minimum of 1 bit
        else
            return 1;
        end if;
    end log2ceil;

    function sel (
        cond : boolean;
        if_true: natural;
        if_false: natural
    ) return natural is
    begin
        if cond then
            return if_true;
        else
            return if_false;
        end if;
    end;

    function sel (
        cond : boolean;
        if_true: string;
        if_false: string
    ) return string is
    begin
        if cond then
            return if_true;
        else
            return if_false;
        end if;
    end;

    function usedwds_size (
        bit_width : natural;
        byte_depth : natural
    ) return natural is
    begin
        return log2ceil(byte_depth / (bit_width * 8));
    end;

    function count_ones(value : std_logic_vector) return natural is
        variable count : natural := 0;
    begin
        for i in value'range loop
            if value(i) = '1' then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function;
    function count_zeros(value : std_logic_vector) return natural is
        variable count : natural := 0;
    begin 
        for i in value'range loop
            if value(i) = '0' then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function;

end package body;
