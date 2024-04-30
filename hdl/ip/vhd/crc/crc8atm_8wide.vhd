-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

-- An 8-wide parallel CRC LFSR implementation for the
-- CRC8ATM CRC algorithm.
-- The polynomial represented here is x^8+x^2+x+1 with
-- a 0's seed value.

entity crc8atm_8wide is
    port (
        clk     : in    std_logic;
        reset   : in    std_logic;
        data_in : in    std_logic_vector(7 downto 0);
        enable  : in    std_logic;
        clear   : in    std_logic;
        crc_out : out   std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of crc8atm_8wide is

begin

    crc_reg: process(clk, reset)
    begin
        if reset then
            crc_out <= (others => '0');
        elsif rising_edge(clk) then
            -- This logic may run on a faster clock cycle than our shifter
            -- so we allow the external logic to clock faster and use the
            -- enable and clear to control when we do the shifts.
            if clear then
                crc_out <= (others => '0');
            elsif enable then
                -- This equation is created by unrolling 8 shifts of the
                -- LFSR.
                crc_out(0) <= crc_out(0) xor crc_out(6) xor crc_out(7) xor data_in(0) xor data_in(6) xor data_in(7);
                crc_out(1) <= crc_out(0) xor crc_out(1) xor crc_out(6) xor data_in(0) xor data_in(1) xor data_in(6);
                crc_out(2) <= crc_out(0) xor crc_out(1) xor crc_out(2) xor crc_out(6) xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(6);
                crc_out(3) <= crc_out(1) xor crc_out(2) xor crc_out(3) xor crc_out(7) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(7);
                crc_out(4) <= crc_out(2) xor crc_out(3) xor crc_out(4) xor data_in(2) xor data_in(3) xor data_in(4);
                crc_out(5) <= crc_out(3) xor crc_out(4) xor crc_out(5) xor data_in(3) xor data_in(4) xor data_in(5);
                crc_out(6) <= crc_out(4) xor crc_out(5) xor crc_out(6) xor data_in(4) xor data_in(5) xor data_in(6);
                crc_out(7) <= crc_out(5) xor crc_out(6) xor crc_out(7) xor data_in(5) xor data_in(6) xor data_in(7);
            end if;
        end if;
    end process;

end rtl;
