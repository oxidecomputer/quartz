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
use work.dimm_regs_pkg.all;

entity dimms_subsystem_top is
    generic (
        CLK_PER_NS  : positive;
        I2C_MODE    : mode_t
    );
    port (
        clk         : in std_logic;
        reset       : in std_logic;

        -- AXI-Lite interface
        axi_if : view axil8x32_pkg.axil_target;

        in_a0 : in std_logic;

        -- DIMM PCAMP pins
        dimm_a_pcamp : in std_logic;
        dimm_b_pcamp : in std_logic;
        dimm_c_pcamp : in std_logic;
        dimm_d_pcamp : in std_logic;
        dimm_e_pcamp : in std_logic;
        dimm_f_pcamp : in std_logic;
        dimm_g_pcamp : in std_logic;
        dimm_h_pcamp : in std_logic;
        dimm_i_pcamp : in std_logic;
        dimm_j_pcamp : in std_logic;
        dimm_k_pcamp : in std_logic;
        dimm_l_pcamp : in std_logic;

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

architecture rtl of dimms_subsystem_top is
    signal bus0 : proxy_chan_reg_t;
    signal bus1 : proxy_chan_reg_t;
    signal dimm_pcamp_raw : std_logic_vector(11 downto 0);
    signal dimm_pcap_syncd : std_logic_vector(11 downto 0);
    signal dimm_pcamp : dimm_pcamp_type;
    
begin

    dimm_pcamp_raw <= dimm_a_pcamp & dimm_b_pcamp & dimm_c_pcamp &
                     dimm_d_pcamp & dimm_e_pcamp & dimm_f_pcamp &
                     dimm_g_pcamp & dimm_h_pcamp & dimm_i_pcamp &
                     dimm_j_pcamp & dimm_k_pcamp & dimm_l_pcamp;

    pcam_sync: for i in dimm_pcamp_raw'range generate
        meta_sync_inst: entity work.meta_sync
         port map(
            async_input => dimm_pcamp_raw(i),
            clk => clk,
            sycnd_output => dimm_pcap_syncd(i)
        );
    end generate;

    dimm_pcamp <=
        (pcamp_a => dimm_pcap_syncd(11),
         pcamp_b => dimm_pcap_syncd(10),
         pcamp_c => dimm_pcap_syncd(9),
         pcamp_d => dimm_pcap_syncd(8),
         pcamp_e => dimm_pcap_syncd(7),
         pcamp_f => dimm_pcap_syncd(6),
         pcamp_g => dimm_pcap_syncd(5),
         pcamp_h => dimm_pcap_syncd(4),
         pcamp_i => dimm_pcap_syncd(3),
         pcamp_j => dimm_pcap_syncd(2),
         pcamp_k => dimm_pcap_syncd(1),
         pcamp_l => dimm_pcap_syncd(0));

    spd_regs_inst: entity work.spd_regs
     port map(
        clk => clk,
        reset => reset,
        axi_if => axi_if,
        dimm_pcamp => dimm_pcamp,
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
        in_a0 => in_a0,
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
        in_a0 => in_a0,
        cpu_scl_if => cpu_scl_if1,
        cpu_sda_if => cpu_sda_if1,
        dimm_scl_if => dimm_scl_if1,
        dimm_sda_if => dimm_sda_if1
    );
    
end rtl;