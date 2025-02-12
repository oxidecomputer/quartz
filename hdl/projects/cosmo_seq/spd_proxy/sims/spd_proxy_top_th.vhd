-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.i2c_common_pkg.all;
use work.tristate_if_pkg.all;
use work.stream8_pkg;

use work.i2c_cmd_vc_pkg.all;
use work.i2c_target_vc_pkg.all;

entity spd_proxy_top_th is
    generic (
        CLK_PER_NS  : positive;
    );
end entity;

architecture th of spd_proxy_top_th is
    constant CLK_PER_TIME : time := CLK_PER_NS * 1 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
begin

    -- simulated CPU I2C controller
    i2c_controller_vc_inst: entity work.i2c_controller_vc
     generic map(
        i2c_ctrl_vc => i2c_ctrl_vc
    )
     port map(
        scl => scl,
        sda => sda
    );

    -- DUT: the SPD proxy
    spd_proxy_top_inst: entity work.spd_proxy_top
     generic map(
        CLK_PER_NS => CLK_PER_NS,
        I2C_MODE => I2C_MODE
    )
     port map(
        clk => clk,
        reset => reset,
        cpu_scl_if => cpu_scl_if,
        cpu_sda_if => cpu_sda_if,
        dimm_scl_if => dimm_scl_if,
        dimm_sda_if => dimm_sda_if
    );

    -- simulated DIMM I2C target
    i2c_target_vc_inst: entity work.i2c_target_vc
     generic map(
        i2c_target_vc => i2c_target_vc
    )
     port map(
        scl_if => scl_if,
        sda_if => sda_if
    );

end architecture;