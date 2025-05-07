-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.i2c_common_pkg.all;
use work.axi_st8_pkg;
use work.axil8x32_pkg;
use work.time_pkg.all;
use work.tristate_if_pkg.all;
use work.spd_proxy_pkg.all;

entity spd_proxy_top is
    generic (
        CLK_PER_NS  : positive;
        I2C_MODE    : mode_t
    );
    port (
        clk         : in std_logic;
        reset       : in std_logic;

        -- AXI-Lite interface
        axi_if : view axil8x32_pkg.axil_target;

        -- CPU <-> FPGA
        cpu_scl_if0  : view tristate_if;
        cpu_sda_if0  : view tristate_if;
        cpu_scl_if1  : view tristate_if;
        cpu_sda_if1  : view tristate_if;

        -- FPGA <-> DIMMs
        dimm_scl_if0 : view tristate_if;
        dimm_sda_if0 : view tristate_if;
        dimm_scl_if1 : view tristate_if;
        dimm_sda_if1 : view tristate_if;
    );
end entity;

architecture rtl of spd_proxy_top is
    signal bus0 : proxy_chan_reg_t;
    signal bus1 : proxy_chan_reg_t;
    

begin

    spd_regs_inst: entity work.spd_regs
     port map(
        clk => clk,
        reset => reset,
        axi_if => axi_if,
        bus0 => bus0,
        bus1 => bus1
    );

    proxy_channel_top_bus0: entity work.proxy_channel_top
     generic map(
        NUM_DIMMS_ON_BUS => 6,
        CLK_PER_NS => CLK_PER_NS,
        I2C_MODE => I2C_MODE
    )
     port map(
        clk => clk,
        reset => reset,
        regs_if => bus0,
        cpu_scl_if => cpu_scl_if0,
        cpu_sda_if => cpu_sda_if0,
        dimm_scl_if => dimm_scl_if0,
        dimm_sda_if => dimm_sda_if0
    );

    proxy_channel_top_bus1: entity work.proxy_channel_top
     generic map(
        NUM_DIMMS_ON_BUS => 6,
        CLK_PER_NS => CLK_PER_NS,
        I2C_MODE => I2C_MODE
    )
     port map(
        clk => clk,
        reset => reset,
        regs_if => bus1,
        cpu_scl_if => cpu_scl_if1,
        cpu_sda_if => cpu_sda_if1,
        dimm_scl_if => dimm_scl_if1,
        dimm_sda_if => dimm_sda_if1
    );
    
end rtl;