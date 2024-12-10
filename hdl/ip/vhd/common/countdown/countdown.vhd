-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- A general purpose counter block which counts down from a supplied `count` to zero. `done is not
-- registered and will be asserted immediately when the internal count is at zero. Control priority
-- for the counter is:
--      1. `clear` will set the counter to zero
--      2. `load` will set the counter to `count`
--      3. `decr` will decrement the counter by 1

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity countdown is
    generic (
        SIZE    : positive
    );
    port (
        clk     : in std_logic;
        reset   : in std_logic;

        -- target value to count down from
        count   : in std_logic_vector(SIZE - 1 downto 0);
        -- loads `count` into internal registers
        load    : in std_logic;
        -- decrement internal counter
        decr    : in std_logic;
        -- set internal counter to zero
        clear   : in std_logic;

        -- high if internal counter is equal to zero
        done    : out std_logic
    );
end entity countdown;

architecture rtl of countdown is
    signal counter  : std_logic_vector(SIZE - 1 downto 0);
begin
    counter_gen: process (clk, reset) is
    begin
        if reset = '1' then
            counter <= (others => '0');
        elsif rising_edge(clk) then
            if clear then
                counter <= (others => '0');
            elsif load then
                counter <= count;
            elsif decr then
                counter <= counter - 1;
            end if;
        end if;
    end process;

    done    <= '1' when counter = 0 else '0';
end rtl;