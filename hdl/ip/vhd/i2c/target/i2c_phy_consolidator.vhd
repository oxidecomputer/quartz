-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_phy_consolidator is
    generic(
        -- number of i2c targets to consolidate
        TARGET_NUM : integer
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        -- single, "pins" interface, consolidation of
        -- multiple target interfaces
        scl : in std_logic;
        scl_o : out std_logic;
        scl_oe : out std_logic;
        sda : in std_logic;
        sda_o : out std_logic;
        sda_oe : out std_logic;

        -- multiple "target" interfaces
        -- each sitting "on" the bus with
        -- different i2c addresses
        tgt_scl : out std_logic_vector(TARGET_NUM-1 downto 0);
        tgt_scl_o : in std_logic_vector(TARGET_NUM-1 downto 0);
        tgt_scl_oe : in std_logic_vector(TARGET_NUM-1 downto 0);
        tgt_sda : out std_logic_vector(TARGET_NUM-1 downto 0);
        tgt_sda_o : in std_logic_vector(TARGET_NUM-1 downto 0);
        tgt_sda_oe : in std_logic_vector(TARGET_NUM-1 downto 0)

    );
end entity;

architecture rtl of i2c_phy_consolidator is

begin

    -- input from pins and output to targets are easy everyone sees the bus
    process(all)
    begin
        for i in 0 to TARGET_NUM-1 loop
            tgt_scl(i) <= scl;
            tgt_sda(i) <= sda;
        end loop;
    end process;

    -- output enable to bus will be active when any target is driving
    -- using reduction OR operator here, oe is active high
    scl_oe <= or tgt_scl_oe;
    sda_oe <= or tgt_sda_oe;

    -- output is always low, we use OE to gate this on tristate bus
    sda_o <= '0';
    scl_o <= '0';



end rtl;