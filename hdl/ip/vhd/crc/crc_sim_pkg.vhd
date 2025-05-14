-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- As a reminder when making these:
--  Highest term is xor'd with next input bit and result is fed back into the 
--  XOR gates inserted at before corresponding bit in shift register.
--  ie x^8+x^2+x+1 has bit7 xor'd with input, then fed back into an XOR gate
--  between bit0 and  bit1 and another XOR gate between  bit1 and bit2.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

package crc_sim_pkg is
    -- Non-parallel, non-synth CRC8 ATM function for testbench use
    impure function crc8_atm (
          data: queue_t;
          gen_invalid_crc: boolean := false
    ) return std_logic_vector;

    -- Non-parallel, non-synth CRC8 autostar function for testbench use
    impure function crc8_autostar (
          data: queue_t;
          final_xor_value: std_logic_vector(7 downto 0) := (others => '0');
          gen_invalid_crc: boolean := false
    ) return std_logic_vector;

end package;

package body crc_sim_pkg is

     -- Non-parallel, non-synth CRC8 ATM function for testbench use
     -- The polynomial represented here is x^8+x^2+x+1 with a 0 seed value.
    impure function crc8_atm (
        data: queue_t;
        gen_invalid_crc: boolean := false
    ) return std_logic_vector is
        -- create a copy so we don't destroy the input queue here
        constant  crc_queue : queue_t                  := copy(data);
        variable d : std_logic_vector(7 downto 0)      := (others => '0');
        variable next_q : std_logic_vector(7 downto 0) := (others => '0');
        variable last_q : std_logic_vector(7 downto 0) := (others => '0');

    begin
        while not is_empty(crc_queue) loop
            d := To_StdLogicVector(pop_byte(crc_queue), 8);
            for i in 0 to 7 loop
                next_q(0) := last_q(7) xor d(7);
                next_q(1) := last_q(7) xor d(7) xor last_q(0);
                next_q(2) := last_q(7) xor d(7) xor last_q(1);
                next_q(7 downto 3) := last_q(6 downto 2);
                last_q := next_q;
                d := shift_left(d, 1);
            end loop;
        end loop;
        if gen_invalid_crc then
            last_q := not last_q;
        end if;
        return last_q;
    end;

    -- The polynomial represented here is x^8+x^5+x^3+x^2+x+1 with
    -- a 1's seed value.
    impure function crc8_autostar (
        data: queue_t;
        final_xor_value: std_logic_vector(7 downto 0) := (others => '0');
        gen_invalid_crc: boolean := false
    ) return std_logic_vector is
        -- create a copy so we don't destroy the input queue here
        constant  crc_queue : queue_t                  := copy(data);
        variable d : std_logic_vector(7 downto 0)      := (others => '0');
        variable next_q : std_logic_vector(7 downto 0) := (others => '0');
        variable last_q : std_logic_vector(7 downto 0) := (others => '1');

    begin
        while not is_empty(crc_queue) loop
            d := To_StdLogicVector(pop_byte(crc_queue), 8);
            for i in 0 to 7 loop
                next_q(0) := last_q(7) xor d(7);
                next_q(1) := last_q(7) xor d(7) xor last_q(0);
                next_q(2) := last_q(7) xor d(7) xor last_q(1);
                next_q(3) := last_q(7) xor d(7) xor last_q(2);
                next_q(4) := last_q(3);
                next_q(5) := last_q(7) xor d(7) xor last_q(4);
                next_q(7 downto 6) := last_q(6 downto 5);
                last_q := next_q;
                d := shift_left(d, 1);
            end loop;
        end loop;
        if gen_invalid_crc then
            last_q := not last_q;
        end if;
        return last_q xor final_xor_value;
    end function;

end package body;