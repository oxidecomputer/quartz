-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity sgpio_shift_out is
    generic (
        BIT_COUNT : integer := 8;
        INIT_VALUE : std_logic_vector(BIT_COUNT - 1 downto 0) := (others => '1');
    );
    port (
        --! Latching clock input
        clk : in    std_logic;
        reset : in std_logic;
        --! Output, sync'd to clk
        sclk : in std_logic;
        do : out   std_logic;
        out_reg : in std_logic_vector(BIT_COUNT - 1 downto 0);
        out_reg_load_en :in std_logic;
    );
end entity;

architecture rtl of sgpio_shift_out is
    signal shift_reg : std_logic_vector(BIT_COUNT - 1 downto 0);
    signal sclk_last : std_logic;

begin 

    do <= shift_reg(shift_reg'high);

    process(clk, reset)
    variable sclk_redge : boolean := false;
    begin
        if reset then 
            shift_reg <= INIT_VALUE;
            sclk_last <= '0';
        elsif rising_edge(clk) then
            sclk_redge := sclk = '1' and sclk_last = '0';
            sclk_last <= sclk;
            if out_reg_load_en = '1' and sclk_redge then
                shift_reg <= out_reg;
            elsif sclk_redge then
                shift_reg <= shift_left(shift_reg, 1);
            end if;

        end if;
    end process;


end rtl;