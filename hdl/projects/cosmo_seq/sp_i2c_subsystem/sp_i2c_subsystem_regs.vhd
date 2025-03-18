-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity sp_i2c_subsystem_regs is
    port(
        clk : in std_logic;
        reset : in std_logic;

        axi_if : view axil8x32_pkg.axil_target
    );
end entity;
architecture rtl of sp_i2c_subsystem_regs is

begin

end rtl;