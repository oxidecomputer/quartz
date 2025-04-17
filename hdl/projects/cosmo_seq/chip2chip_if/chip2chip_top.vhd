-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip2chip_top is
    port(
        clk : in std_logic;
        reset : in std_logic;

        -- pins interface
        from_fpga2: in std_logic_vector(2 downto 0);
        to_fpga2: out std_logic_vector(2 downto 0);

        --system interface
        in_a0: in std_logic;
        front_hp_irq_l : out std_logic
    );
end entity;

architecture rtl of chip2chip_top is

begin

    -- TODO: wire this up 
    front_hp_irq_l <= '1';

end rtl;