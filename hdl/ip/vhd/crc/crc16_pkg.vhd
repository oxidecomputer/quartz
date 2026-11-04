-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- CRC-16/CCITT-FALSE, polynomial x^16 + x^12 + x^5 + 1 (0x1021), seed 0xFFFF,
-- MSB first, no reflection and no final xor. This is the payload CRC in
-- RFD 693, transmitted high byte first.
--
-- The next-state function is kept here as a pure function rather than only
-- inside an entity so that a framer can hold the CRC as a plain register field
-- and swap it in and out when a packet is preempted, and so the same code is
-- the golden model in simulation.
package crc16_pkg is

    subtype crc16_t is std_logic_vector(15 downto 0);

    constant crc16_poly : crc16_t := X"1021";
    -- The seed is non-zero on purpose: payload length is not in the header, so
    -- with a zero seed leading zero bytes would be invisible to the check.
    constant crc16_init : crc16_t := X"FFFF";

    -- Running the CRC over the payload followed by its own CRC, high byte
    -- first, leaves the register at zero regardless of the seed, so a receiver
    -- can check a packet without knowing where the payload ends.
    constant crc16_residue_good : crc16_t := X"0000";
    -- A transmitter that has to abandon a packet sends the inverted CRC. The
    -- residue of that is also a constant, so the receiver can tell "sender
    -- gave up" apart from "corrupted on the wire".
    constant crc16_residue_abort : crc16_t := X"1D0F";

    -- One shift, MSB first, with the next data bit folded in.
    function crc16_step (
        crc : crc16_t;
        bit : std_logic
    ) return crc16_t;

    -- Advance over one byte, MSB first. The loop unrolls at elaboration so this
    -- is a flat xor network once synthesized.
    function crc16_next (
        crc : crc16_t;
        data : std_logic_vector(7 downto 0)
    ) return crc16_t;

end package;

package body crc16_pkg is

    function crc16_step (
        crc : crc16_t;
        bit : std_logic
    ) return crc16_t is
        variable shifted : crc16_t;
    begin
        shifted := crc(14 downto 0) & '0';
        if (crc(15) xor bit) = '1' then
            shifted := shifted xor crc16_poly;
        end if;
        return shifted;
    end function;

    function crc16_next (
        crc : crc16_t;
        data : std_logic_vector(7 downto 0)
    ) return crc16_t is
        variable next_crc : crc16_t := crc;
    begin
        for i in 7 downto 0 loop
            next_crc := crc16_step(next_crc, data(i));
        end loop;
        return next_crc;
    end function;

end package body;
