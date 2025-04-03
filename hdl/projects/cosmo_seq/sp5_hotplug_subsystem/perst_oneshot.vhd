-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.calc_pkg.all; 

entity perst_oneshot is
    generic(
        PERST_CNTS : integer
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        power_en : in std_logic; -- active high input from the pin
        perst_l : out std_logic
    ); 
end entity;

architecture rtl of perst_oneshot is
    signal cntr : unsigned(log2ceil(PERST_CNTS)-1 downto 0) := (others => '0');
    
    
begin

    sm:process(clk, reset)
    begin
        if reset then
            cntr <= (others => '0'); -- reset the counter
            perst_l <= '0'; 

        elsif rising_edge(clk) then
            if power_en = '1' and cntr <= (PERST_CNTS-1) then
                -- increment the counter if power_en is high and we haven't reached the max count
                cntr <= cntr + 1;
                perst_l <= '0'; 
            elsif  power_en then
                perst_l <= '1'; -- once we reach the max count, assert perst_l
            else
                -- if power_en is low, reset the counter and deassert perst_l
                cntr <= (others => '0'); 
                perst_l <= '0'; 
            end if;

        end if;
    end process;



end rtl;