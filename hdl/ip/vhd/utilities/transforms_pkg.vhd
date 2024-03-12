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

--! Helper functions for doing various bit transformations.
package transforms_pkg is
    --! Reverse a vector. Based on Jonathan Bromley's vhdl mailing list answer:
    --! https://groups.google.com/g/comp.lang.vhdl/c/eBZQXrw2Ngk/m/4H7oL8hdHMcJ?pli=1
    function reverse(a : in std_logic_vector) return std_logic_vector;
    --! Same as above, but overloaded for unsigned types
    function reverse(a : in unsigned) return unsigned;
end package;


package body transforms_pkg is

    function reverse(a : in std_logic_vector) return std_logic_vector is
        variable result : std_logic_vector(a'RANGE);
        alias aa        : std_logic_vector(a'REVERSE_RANGE) is a;
    begin
        for i in aa'RANGE loop
            result(i) := aa(i);
        end loop;
        return result;
    end reverse;
    --! Overload for unsigned
    function reverse(a : in unsigned) return unsigned is
    begin
        return unsigned(reverse(std_logic_vector(a)));
    end reverse;
end package body;
