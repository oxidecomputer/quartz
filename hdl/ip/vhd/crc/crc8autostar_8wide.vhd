-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

-- An 8-wide parallel CRC LFSR implementation for the
-- CRC8 AUTOSTAR 0x2F CRC algorithm.
-- The polynomial represented here is x^8+x^5+x^3+x^2+x+1 with
-- a 1's seed value.

entity crc8autostar_8wide is
    generic(
        -- Default here doesn't change the register value (something xor'd with 0 is itself)
        FINAL_XOR_VALUE : std_logic_vector(7 downto 0) := (others => '0')
    );
    port (
        clk     : in    std_logic;
        reset   : in    std_logic;
        data_in : in    std_logic_vector(7 downto 0);
        enable  : in    std_logic;
        clear   : in    std_logic;
        crc_out : out   std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of crc8autostar_8wide is
    signal crc_reg : std_logic_vector(7 downto 0);
begin

    crc_lfsr: process(clk, reset)
    begin
        if reset then
            crc_reg <= (others => '1');
        elsif rising_edge(clk) then
            -- This logic may run on a faster clock cycle than our shifter
            -- so we allow the external logic to clock faster and use the
            -- enable and clear to control when we do the shifts.
            if clear then
                crc_reg <= (others => '1');
            elsif enable then
                -- This equation is created by unrolling 8 shifts of the
                -- LFSR.
                crc_reg(0) <= crc_reg(0) xor crc_reg(3) xor crc_reg(5) xor crc_reg(7) xor 
                              data_in(0) xor data_in(3) xor data_in(5) xor data_in(7);
                crc_reg(1) <= crc_reg(0) xor crc_reg(1) xor crc_reg(3) xor crc_reg(4) xor crc_reg(5) xor crc_reg(6) xor crc_reg(7) xor
                              data_in(0) xor data_in(1) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(7);
                crc_reg(2) <= crc_reg(0) xor crc_reg(1) xor crc_reg(2) xor crc_reg(3) xor crc_reg(4) xor crc_reg(6) xor
                              data_in(0) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(4) xor data_in(6);
                crc_reg(3) <= crc_reg(0) xor crc_reg(1) xor crc_reg(2) xor crc_reg(4) xor 
                              data_in(0) xor data_in(1) xor data_in(2) xor data_in(4) xor data_in(5);
                crc_reg(4) <= crc_reg(1) xor crc_reg(2) xor crc_reg(3) xor crc_reg(5) xor 
                              data_in(1) xor data_in(2) xor data_in(3) xor data_in(5); 
                crc_reg(5) <= crc_reg(0) xor crc_reg(2) xor crc_reg(4) xor crc_reg(5) xor crc_reg(6) xor crc_reg(7) xor 
                              data_in(0) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(7);
                crc_reg(6) <= crc_reg(1) xor crc_reg(3) xor crc_reg(5) xor crc_reg(6) xor crc_reg(7) xor 
                              data_in(1) xor data_in(3) xor data_in(5) xor data_in(6) xor data_in(7);
                crc_reg(7) <= crc_reg(2) xor crc_reg(4) xor crc_reg(6) xor crc_reg(7) xor 
                              data_in(2) xor data_in(4) xor data_in(6) xor data_in(7);
            end if;
        end if;
    end process;
    crc_out <= crc_reg xor FINAL_XOR_VALUE;

end rtl;