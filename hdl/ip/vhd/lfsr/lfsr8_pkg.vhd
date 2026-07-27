-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Galois LFSR bits for the 8-bit additive scrambler, polynomial
-- x^8 + x^6 + x^5 + x^4 + 1. Bit i holds the coefficient of x^i, so bit 0 is
-- the LSB. We keep these as pure functions so the same code can be the golden
-- model in a testbench and the synthesizable next-state logic in
-- scrambler_lfsr8.
package lfsr8_pkg is

    -- The low 8 bits of the polynomial, x^6 + x^5 + x^4 + 1. The x^8 term is
    -- the implicit feedback bit so it doesn't show up here.
    constant lfsr8_poly : std_logic_vector(7 downto 0) := X"71";

    -- Cold-start seed, used on a link reset. Any non-zero value works: the
    -- step below is one-to-one and all-zeros maps to itself, so starting from
    -- a non-zero state we can never walk into the all-zero lock-up.
    constant lfsr8_seed : std_logic_vector(7 downto 0) := X"FF";

    -- One Galois step, ie multiply the register by x modulo the polynomial.
    -- Shift left and fold lfsr8_poly back in when the bit falling off the top
    -- was set.
    function lfsr8_step (
        state : std_logic_vector(7 downto 0)
    ) return std_logic_vector;

    -- Advance the state for one scrambled character, one Galois step per data
    -- bit. The loop unrolls at elaboration so this is a flat XOR network once
    -- synthesized.
    function lfsr8_next_char (
        state : std_logic_vector(7 downto 0)
    ) return std_logic_vector;

end package;

package body lfsr8_pkg is

    function lfsr8_step (
        state : std_logic_vector(7 downto 0)
    ) return std_logic_vector is
        variable shifted : std_logic_vector(7 downto 0);
    begin
        shifted := state(6 downto 0) & '0';

        if state(7) = '1' then
            shifted := shifted xor lfsr8_poly;
        end if;

        return shifted;
    end function;

    function lfsr8_next_char (
        state : std_logic_vector(7 downto 0)
    ) return std_logic_vector is
        variable next_state : std_logic_vector(7 downto 0) := state;
    begin
        for i in 1 to 8 loop
            next_state := lfsr8_step(next_state);
        end loop;

        return next_state;
    end function;

end package body;
