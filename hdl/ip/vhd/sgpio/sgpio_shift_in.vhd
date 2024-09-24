-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity sgpio_shift_in is
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
        load : in std_logic;
        di : in   std_logic;
        in_reg : out std_logic_vector(BIT_COUNT - 1 downto 0);
        in_reg_valid : out  std_logic;
    );
end entity;


architecture rtl of sgpio_shift_in is
    signal load_sr   : std_logic_vector(BIT_COUNT - 1 downto 0);
    signal shift_reg : std_logic_vector(BIT_COUNT - 1 downto 0);
    signal sclk_last : std_logic;

begin

    in_reg <= shift_reg;
    -- data is valid when the sampled load signal shows 5 consecutive 0s
    -- followed by a 1 indicating the last bit of the data.
    in_reg_valid <= '1' when load_sr(5 downto 0) = 1 else '0';

    process(clk, reset)
    variable sclk_fedge : boolean := false;
    begin
        if reset then
            shift_reg <= (others => '0');
            load_sr <= (others => '0');
            sclk_last <= '0';
        elsif rising_edge(clk) then
            sclk_fedge := sclk = '0' and sclk_last = '1';
            sclk_last <= sclk;
            if sclk_fedge then
                -- Sample DI
                shift_reg <= shift_left(shift_reg, 1);
                shift_reg(0) <=di;
                -- Sample LOAD
                load_sr <= shift_left(load_sr, 1);
                load_sr(0) <= load;
            end if;
        end if;
    end process;


end rtl;