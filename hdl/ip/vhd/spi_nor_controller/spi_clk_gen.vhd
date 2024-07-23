-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity spi_clk_gen is
    port (
        clk : in std_logic;
        reset : in std_logic;
        divisor: in unsigned(15 downto 0);
        enable : in boolean;
        sclk : out std_logic
    );
end entity;

architecture rtl of spi_clk_gen is
    signal div_cnts : unsigned(15 downto 0) := (others => '0');
    signal strobe : boolean := false;
    signal internal_enable : boolean := false;
    signal enable_last : boolean := false;
begin

    -- Pretty simple spi generator.
    -- start with a rising edge
    -- generate requested clock

    div_strobe: process(clk, reset) 
    begin
        if reset then
            div_cnts <= (others => '0');
            strobe <= false;
        elsif rising_edge(clk) then
            strobe <= false;
            if internal_enable then
                div_cnts <= div_cnts - 1;
                if div_cnts = 0 then
                    strobe <= true;
                    div_cnts <= divisor;
                end if;
            else
                div_cnts <= divisor;
            end if;
        end if;
    end process;

    sclk_gen: process(clk, reset)
        variable nxt_sclk: std_logic;
    begin
        if reset then
            sclk <= '0';
            internal_enable <= false;
            enable_last <= false;

        elsif rising_edge(clk) then
            enable_last <= enable;
            if enable  and not enable_last  then
                internal_enable <= true;
            elsif not enable then
                internal_enable <= false;
            end if;

            if internal_enable then
                nxt_sclk := sclk;
                if strobe then
                    nxt_sclk := not sclk;
                end if;
                sclk <= nxt_sclk;  -- assign value to output

            else
                sclk <= '0';
            end if;
        end if;
    end process;


end rtl;