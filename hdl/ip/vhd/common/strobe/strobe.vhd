-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- A small block that will generate a single `clk` pulse on `strobe` every `TICKS` cycles of `clk`.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity strobe is
    generic (
        TICKS   : positive
    );
    port (
        clk     : in std_logic;
        reset   : in std_logic;

        enable  : in std_logic;
        strobe  : out std_logic
    );
end entity strobe;

architecture rtl of strobe is
    signal strobe_counter   : natural range 0 to TICKS := 0;
begin
    strobe_gen: process (clk, reset) is
    begin
        if reset then
            strobe_counter  <= 0;
            strobe          <= '0';
        elsif rising_edge(clk) then
            if strobe_counter = TICKS - 1 then
                strobe          <= '1';
                strobe_counter  <= 0;
            elsif enable then
                strobe          <= '0';
                strobe_counter  <= strobe_counter + 1;
            end if;
        end if;
    end process;
end rtl;