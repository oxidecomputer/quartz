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
use ieee.math_real.all;

--! Helper functions for turning time values into counter ticks without having to do
--! the math locally, often used for generics or constants. This uses math_real, but
--! can be used for constant determined at compile/elab time.
package time_pkg is
    --! Determine clocks required at `clk_period_ns` to cross `desired_ms` time (in miliseconds)
    function calc_ms(desired_ms : positive; clk_period_ns : positive; returned_size : positive) return unsigned;
    --! Determine clocks required at `clk_period_ns` to cross `desired_us` time (in microseconds)
    function calc_us(desired_us : positive; clk_period_ns : positive; returned_size : positive) return unsigned;
    --! Determine clocks required at `clk_period_ns` to cross `desired_ns` time (in nanoseconds)
    function calc_ns(desired_ns : positive; clk_period_ns : positive; returned_size : positive) return unsigned;

    -- Not intended to be part of the public api, used by above functions
    function private_internal_calc(desired: positive; clk_per_ns: positive; ret_size: positive; sacle_factor: positive) return unsigned;
end package;

package body time_pkg is
    --------------------------------------------------------------------------------
    -- calc_Xx functions. Figure out how many clock periods it takes to represent
    -- the requested number in human-friendly units
    function calc_us(num_us : integer; clk_period_ns : integer; ret_size : integer) return unsigned is
        constant scale_factor: integer := 10**3; --(us to ns = 10^3)
    begin
        return private_internal_calc(num_us, clk_period_ns, ret_size, scale_factor);
    end function;
   
    function calc_ms(num_ms : integer; clk_period_ns : integer; ret_size : integer) return unsigned is
        constant scale_factor: integer := 10**6; --(ms to ns = 10^6)
    begin
        return private_internal_calc(num_ms, clk_period_ns, ret_size, scale_factor);
    end function;


    function calc_ns(num_ns : integer; clk_period_ns : integer; ret_size : integer) return unsigned is
        constant scale_factor: integer := 1; --(ns to ns = 1)
    begin
        return private_internal_calc(num_ns, clk_period_ns, ret_size, scale_factor);
    end function;
    
    -- Private helper function, not intended to be part of the public api, used by above functions
    function private_internal_calc(desired: positive; clk_per_ns: positive; ret_size: positive; sacle_factor: positive) return unsigned is
        variable ret_num : unsigned(ret_size - 1 downto 0);
    begin
         -- Not all values work out evenly since we're dividing, so we round up the value as needed
        -- to be greater than or equal to the requested value 
        ret_num := to_unsigned(natural(ceil(real(desired * sacle_factor) / real(clk_per_ns))), ret_num'length);
        return ret_num;
    end function;
end package body;