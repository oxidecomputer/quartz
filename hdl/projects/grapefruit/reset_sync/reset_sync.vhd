-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_sync is
    port (
        pll_locked_async : in std_logic;

        clk_125m : in std_logic;
        reset_125m : out std_logic;
        clk_200m : in std_logic;
        reset_200m : out std_logic
    );
end entity;

architecture rtl of reset_sync is

begin

    clk125m_sync: entity work.async_reset_bridge
     generic map(
        async_reset_active_level => '0'  -- locked = 1 means out of reset
    )
     port map(
        clk => clk_125m,
        reset_async => pll_locked_async,
        reset_sync => reset_125m
    );

    clk200m_sync: entity work.async_reset_bridge
     generic map(
        async_reset_active_level => '0'  -- locked = 1 means out of reset
    )
     port map(
        clk => clk_200m,
        reset_async => pll_locked_async,
        reset_sync => reset_200m
    );

end architecture;