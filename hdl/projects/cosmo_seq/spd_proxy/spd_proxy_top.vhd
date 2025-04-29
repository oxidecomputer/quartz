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

entity spd_proxy_top is
    generic (
        CLK_PER_NS  : positive;
        I2C_MODE    : mode_t;
        NUM_BUSSES  : natural;
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

    signal i2c_command : cmd_t_array(NUM_BUSSES - 1 downto 0);
    signal i2c_ctrlr_idle : std_logic_vector(NUM_BUSSES - 1 downto 0);
    signal i2c_command_valid : std_logic_vector(NUM_BUSSES - 1 downto 0);
    signal i2c_tx_st_if : axi_st8_pkg.axi_st_array_t(NUM_BUSSES - 1 downto 0);
    signal i2c_rx_st_if : axi_st8_pkg.axi_st_array_t(NUM_BUSSES - 1 downto 0);

begin

    i2c_command(1) <= CMD_RESET;
    i2c_command_valid(1) <= '0';

    i2c_tx_st_if(1).data <= (others => '0');
    i2c_tx_st_if(1).valid <= '0';
    i2c_rx_st_if(1).ready <= '1';
    fpga_spd_ctrl_inst: entity work.fpga_spd_ctrl
     port map(
        clk => clk,
        reset => reset,
        axi_if => axi_if,
        i2c_command => i2c_command(0),
        i2c_command_valid => i2c_command_valid(0),
        i2c_ctrlr_idle => i2c_ctrlr_idle(0),
        i2c_tx_st_if => i2c_tx_st_if(0),
        i2c_rx_st_if => i2c_rx_st_if(0)
    );


    -- There's probably a way to make this a generate loop but view
    -- arrays were something I did a quick try at and vivado didn't like it
    -- so I'll come back here later
    spd_i2c_proxy0_inst: entity work.spd_i2c_proxy
     generic map(
        CLK_PER_NS => CLK_PER_NS,
        I2C_MODE => I2C_MODE
    )
     port map(
        clk => clk,
        reset => reset,
        cpu_scl_if => cpu_scl_if0,
        cpu_sda_if => cpu_sda_if0,
        dimm_scl_if => dimm_scl_if0,
        dimm_sda_if => dimm_sda_if0,
        i2c_command => i2c_command(0),
        i2c_command_valid => i2c_command_valid(0),
        i2c_ctrlr_idle => i2c_ctrlr_idle(0),
        i2c_tx_st_if => i2c_tx_st_if(0),
        i2c_rx_st_if => i2c_rx_st_if(0)
    );
    spd_i2c_proxy1_inst: entity work.spd_i2c_proxy
    generic map(
       CLK_PER_NS => CLK_PER_NS,
       I2C_MODE => I2C_MODE
   )
    port map(
       clk => clk,
       reset => reset,
       cpu_scl_if => cpu_scl_if1,
       cpu_sda_if => cpu_sda_if1,
       dimm_scl_if => dimm_scl_if1,
       dimm_sda_if => dimm_sda_if1,
       i2c_command => i2c_command(1),
       i2c_command_valid => i2c_command_valid(1),
       i2c_ctrlr_idle => i2c_ctrlr_idle(1),
       i2c_tx_st_if => i2c_tx_st_if(1),
       i2c_rx_st_if => i2c_rx_st_if(1)
   );
end rtl;