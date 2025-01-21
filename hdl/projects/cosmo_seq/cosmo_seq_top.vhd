-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Cosmo Sequencer FPGA targeting the Spartan-7

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity cosmo_seq_top is
    port (
        -- Board clocks and resets
        clk_50mhz_fpga1_1 : in std_logic;
        clk_50mhz_fpga1_2 : in std_logic;
        clk_buff_m2_nic_rsw_to_fpga1_los_l : in std_logic;
        -- FMC interface
        fmc_sp_to_fpga1_clk : in std_logic;
        fmc_sp_to_fpga1_oe_l : in std_logic;
        fmc_sp_to_fpga1_we_l : in std_logic;
        fmc_sp_to_fpga1_wait_l : out std_logic;
        fmc_sp_to_fpga1_cs1_l: in std_logic;
        fmc_sp_to_fpga1_adv_l : in std_logic;
        fmc_sp_to_fpga1_bl_l : in std_logic_vector(1 downto 0);
        fmc_sp_to_fpga1_da : inout std_logic_vector(15 downto 0);
        fmc_sp_to_fpga1_a : in std_logic_vector(23 downto 16);
        -- eSPI interfaces
        -- eSPI0
        fpga1_espi0_cs_l_buff_oe_en_l : out std_logic;  -- Don't want to be chip-selected while SP5 is off
        espi_sp5_to_fpga1_reset_l : in std_logic; -- Un-used currently
        espi0_sp5_to_fpga1_clk : in std_logic;
        espi0_sp5_to_fpga1_cs_l : in std_logic;
        espi0_sp5_to_fpga1_dat : inout std_logic_vector(3 downto 0);
        -- eSPI1 (currently un-used)
        espi1_sp5_to_fpga1_clk : in std_logic;
        espi1_sp5_to_fpga1_clk_2 : in std_logic;
        espi1_sp5_to_fpga1_cs_l : in std_logic;
        espi1_sp5_to_fpga1_dat : inout std_logic_vector(3 downto 0);

        -- Group A Power Rail control and PGs
        v12_ddr5_abcdef_a0_pg : in std_logic;
        v12_ddr5_ghijkl_a0_pg : in std_logic;
        dimm_a_pg : in std_logic;
        dimm_b_pg : in std_logic;
        dimm_c_pg : in std_logic;
        dimm_d_pg : in std_logic;
        dimm_e_pg : in std_logic;
        dimm_f_pg : in std_logic;
        dimm_g_pg : in std_logic;
        dimm_h_pg : in std_logic;
        dimm_i_pg : in std_logic;
        dimm_j_pg : in std_logic;
        dimm_k_pg : in std_logic;
        dimm_l_pg : in std_logic;
        -- Thermal control, alerts and feedback
        fan_central_hsc_to_fpga1_pg : in std_logic;
        fan_east_hsc_to_fpga1_pg : in std_logic;
        fan_to_fpga1_fan_fail : in std_logic;
        fan_west_hsc_to_fpga1_pg : in std_logic;
        fpga1_to_fan_central_hsc_disable : out std_logic;
        fpga1_to_fan_east_hsc_disable : out std_logic;
        fpga1_to_fan_west_hsc_disable : out std_logic;
        smbus_fan_central_hsc_to_fpga1_alert_l : in std_logic;
        smbus_fan_east_hsc_to_fpga1_alert_l : in std_logic;
        smbus_fan_west_hsc_to_fpga1_alert_l : in std_logic;
        smbus_fpga1_to_nic_therm_alert_l : in std_logic;
        smbus_ibc_to_fpga1_alert_l : in std_logic;
        smbus_m2_hsc_to_fpga1_alert_l : in std_logic;
        smbus_nic_hsc_to_fpga1_alert_l : in std_logic;
        smbus_therm_nc_to_fpga1_alert_l : in std_logic;
        smbus_therm_ne_to_fpga1_alert_l : in std_logic;
        smbus_therm_nw_to_fpga1_alert_l : in std_logic;
        smbus_therm_sc_to_fpga1_alert_l : in std_logic;
        smbus_therm_se_to_fpga1_alert_l : in std_logic;
        smbus_therm_sw_to_fpga1_alert_l : in std_logic;
        smbus_v12_ddr5_abcdef_hsc_to_fpga1_alert : in std_logic;
        smbus_v12_ddr5_ghijkl_hsc_to_fpga1_alert : in std_logic;
        smbus_v12_mcio_a0hp_hsc_to_fpga1_alert_l : in std_logic;
        main_hsc_to_fpga1_alert_l : in std_logic;
        vr_v1p8_sys_to_fpga1_alert_l : in std_logic;
        vr_v3p3_sys_to_fpga1_alert_l : in std_logic;
        vr_v5p0_sys_to_fpga1_alert_l : in std_logic;
        m2a_hsc_to_fpga1_fault_l : in std_logic;
        m2b_hsc_to_fpga1_fault_l : in std_logic;
        pwr_cont1_to_fpga1_alert_l : in std_logic;
        v0p96_nic_to_fpga1_alert_l : in std_logic;
        v12p0_nic_a0hp_to_fpga1_fault_l : in std_logic;
        pwr_cont2_to_fpga1_alert_l : in std_logic;
        pwr_cont3_to_fpga1_alert_l : in std_logic;
        pwr_cont3_to_fpga1_cfp : in std_logic;
        pwr_cont3_to_fpga1_vrhot_n : in std_logic;

        -- SP5 BootRom SPI interface
        spi_fpga1_to_flash_clk : out std_logic;
        spi_fpga1_to_flash_cs_l : out std_logic;
        spi_fpga1_to_flash_dat : inout std_logic_vector(3 downto 0);

        -- Spare and board-level status stuff
        fpga1_to_sp_mux_ign_mux_sel : in std_logic;
        fpga1_to_ign_trgt_fpga_creset : out std_logic;
        seq_rev_id : in std_logic_vector(2 downto 0);
        fpga1_spare_v1p8 : in std_logic_vector(7 downto 0);
        fpga1_spare_v3p3 : in std_logic_vector(7 downto 0);
        fpga1_status_led : out std_logic;
        fpga1_to_fpga2_io : in std_logic_vector(5 downto 0);

        -- T6 NIC sequencing
        fpga1_to_nic_cld_rst_l : out std_logic;
        fpga1_to_nic_eeprom_wp_l : out std_logic;
        fpga1_to_nic_flash_eeprom_wp_buffer_oe_l : out std_logic;
        fpga1_to_nic_flash_wp_l : out std_logic;
        fpga1_to_nic_hsc_en : out std_logic;
        fpga1_to_nic_mfg_mode_l : out std_logic;
        nic_to_fpga1_ext_rst_l : in std_logic;
        v0p96_nic_vdd_a0hp_pg : in std_logic;
        pcie_fpga1_to_nic_perst_l : in std_logic;
        v5p0_nic_a0hp_pg : in std_logic;
        v5p0_nic_a0hp_to_fpga1_fault_l : in std_logic;
        fpga1_to_pcie_clk_buff_nic_oe_l : in std_logic;
        v1p1_nic_enet_a0hp_pg : in std_logic;
        v12p0_nic_a0hp_pg : in std_logic;
        v1p2_nic_enet_a0hp_pg : in std_logic;
        v1p2_nic_pcie_a0hp_pg : in std_logic;
        v1p5_nic_a0hp_pg : in std_logic;
        sp5_to_nic_mfg_mode_l : in std_logic;

        -- SP5 sequencing
        sp5_to_fpga1_thermtrip_l : in std_logic;
        pwr_cont1_to_fpga1_vddcr_cpu0_pg : in std_logic;
        pwr_cont1_to_fpga1_vddcr_cpu1_pg : in std_logic;
        pwr_cont1_to_fpga1_vddcr_soc_pg : in std_logic;
        pwr_cont1_to_fpga1_vddio_sp5_pg : in std_logic;
        pwr_fpga1_to_v1p5_sp5_rtc_a2_en : in std_logic;
        pwr_v1p5_sp5_rtc_a2_to_fpga1_pg : in std_logic;
        sp5_to_fpga1_pwrgd_out : in std_logic;
        sp5_to_fpga1_pwrok_unbuf : in std_logic;
        sp5_to_fpga1_slp_s3_l : in std_logic;
        sp5_to_fpga1_slp_s5_l : in std_logic;
        v3p3_sp5_en : in std_logic;
        v3p3_sp5_pg : in std_logic;
        sp_to_fpga1_system_reset_l : in std_logic;
        fpga1_to_sp5_rsmrst_l : out std_logic;
        fpga1_to_sp5_sys_reset_l : out std_logic;
        vddcr_cpu0_en : out std_logic;
        vddcr_cpu1_en : out std_logic;
        vddcr_soc_en : out std_logic;
        vddio_sp5_en : out std_logic;
        v1p1_sp5_en : in std_logic;
        v1p1_sp5_pg : in std_logic;
        fpga1_to_sp5_pwr_btn_l : in std_logic;
        fpga1_to_sp5_pwrgd : in std_logic;
        fpga1_to_sp5_reset_l : in std_logic;
        fpga1_to_sp5_romtype0 : in std_logic;
        v1p8_sp5_en : in std_logic;
        v1p8_sp5_pg : in std_logic;

        -- backplane interface
        fpga1_to_bp_buff_output_en_l : in std_logic;
        pcie_aux_fpga1_to_rsw_perst_l : in std_logic;
        pcie_aux_rsw_to_fpga1_prsnt_buff_l : in std_logic;
        pcie_aux_rsw_to_fpga1_pwrflt_buff_l : in std_logic;
        fpga1_to_pcie_clk_buff_rsw_oe_l : in std_logic;
        rsw_to_sp5_pcie_attached_buff_l : in std_logic;

        -- non-FMC SP interface things
        fpga1_to_sp_int_l : in std_logic;
        fpga1_to_sp_irq_l : out std_logic_vector(6 downto 1);
        fpga1_to_sp_misc_a : in std_logic;
        fpga1_to_sp_misc_b : in std_logic;
        fpga1_to_sp_misc_c : in std_logic;
        fpga1_to_sp_misc_d : in std_logic;

        -- Un-USED SP5 things
        hdt_conn_to_mux_testen : in std_logic;
        hdt_fpga1_to_mux_dat : in std_logic;
        hdt_fpga1_to_mux_dbreq_l : in std_logic;
        hdt_fpga1_to_mux_en_l : in std_logic;
        hdt_fpga1_to_mux_sel : in std_logic;
        hdt_fpga1_to_mux_tck : in std_logic;
        hdt_fpga1_to_mux_tms : in std_logic;
        hdt_fpga1_to_mux_trst_l : in std_logic;
        hdt_fpga1_to_mux_xtrig5_l : in std_logic;
        hdt_fpga1_to_mux_xtrig6_l : in std_logic;
        hdt_fpga1_to_mux_xtrig7_l : in std_logic;
        hdt_mux_to_fpga1_dat : in std_logic;
        fpga1_to_sp5_apml_xltr_en : in std_logic;
        fpga1_to_sp5_espi_kbrst_l : in std_logic;
        spi0_sp5_to_fpga1_cs_l : in std_logic;
        spi1_sp5_to_fpga1_cs_l : in std_logic;
        spi2_sp5_to_fpga1_cs_l : in std_logic;
        sp5_to_fpga1_alert_l : in std_logic;
        sp5_to_fpga1_debug : in std_logic_vector(2 downto 1);
        sp5_to_fpga1_genint_l : in std_logic; 
        sp5_to_fpga1_smerr_l : in std_logic;

        -- I3C DDR stuff
        i3c_fpga1_to_dimm_abcdef_scl : inout std_logic;
        i3c_fpga1_to_dimm_abcdef_sda : inout std_logic;
        i3c_fpga1_to_dimm_ghijkl_scl : inout std_logic;
        i3c_fpga1_to_dimm_ghijkl_sda : inout std_logic;
        i3c_fpga1_to_dimm_oe_l : out std_logic;
        i3c_sp5_to_fpga1_abcdef_scl : inout std_logic;
        i3c_sp5_to_fpga1_abcdef_sda : inout std_logic;
        i3c_sp5_to_fpga1_ghijkl_scl : inout std_logic;
        i3c_sp5_to_fpga1_ghijkl_sda : inout std_logic;
        i3c_sp5_to_fpga1_oe_l : out std_logic;
        sp5_to_fpga1_spd_host_ctrl_l : in std_logic;

        -- I2C Hotplug stuff
        i2c_sp5_to_fpgax_hp_scl : inout std_logic;
        i2c_sp5_to_fpgax_hp_sda : inout std_logic;
        i2c_sp_to_fpga1_scl : inout std_logic;
        i2c_sp_to_fpga1_sda : inout std_logic;

        fpga1_to_i2c_mux1_sel : out std_logic_vector(1 downto 0);
        fpga1_to_i2c_mux2_sel : out std_logic_vector(1 downto 0);
        fpga1_to_i2c_mux3_sel : in std_logic_vector(1 downto 0);
        fpga1_to_m2a_hsc_en : in std_logic;
        fpga1_to_m2a_perst_l : in std_logic;
        fpga1_to_m2b_hsc_en : in std_logic;
        fpga1_to_m2b_perst_l : in std_logic;
        fpga1_to_pcie_clk_buff_m2a_oe_l : in std_logic;
        fpga1_to_pcie_clk_buff_m2b_oe_l : in std_logic;
        m2a_to_fpga1_pedet : in std_logic;
        m2a_to_fpga1_prsnt_l : in std_logic;
        v3p3_m2a_a0hp_pg_l : in std_logic;
        v3p3_m2b_a0hp_pg_l : in std_logic;
        v3p3_nic_a0hp_pg : in std_logic;
        
        fpga1_to_v12_ddr5_abcdef_hsc_en : in std_logic;
        fpga1_to_v12_ddr5_ghijkl_hsc_en : in std_logic;
        fpga1_to_v1p2_fpga2_a2_ldo_en : in std_logic;

        m2b_to_fpga1_pedet : in std_logic;
        m2b_to_fpga1_prsnt_l : in std_logic;

        -- SP5 to SP UARTs
        -- SP5 UART0 proxies through the FPGA for fun and profit
        fpga1_uart0_buff_oe_en_l : out std_logic;
        fpga1_uart1_buff_oe_en_l : out std_logic;
        -- UART0 SP5 side, with hw handshake
        uart0_sp5_to_fpga1_dat : in std_logic;
        uart0_fpga1_to_sp5_dat_buff : out std_logic;
        uart0_fpga1_to_sp5_rts_l_buff : out std_logic;
        uart0_sp5_to_fpga1_rts_l : in std_logic;
        -- UART0 SP side
        uart0_fpga1_to_sp_dat : out std_logic;
        uart0_fpga1_to_sp_rts_l : out std_logic;
        uart0_sp_to_fpga1_dat : in std_logic;
        uart0_sp_to_fpga1_rts_l : in std_logic;
        -- UART1 SP side (SP5-side of UART1 is over eSPI interface)
        uart1_fpga1_to_sp_dat : out std_logic;
        uart1_fpga1_to_sp_rts_l : out std_logic;
        uart1_sp_to_fpga1_dat : in std_logic;
        uart1_sp_to_fpga1_rts_l : in std_logic;
        uart0_sp5_to_fpga1_int : in std_logic;  -- Potentially mis-named?
        -- Un-used SP5 UART1 without hw handshake
        uart1_fpga1_to_sp5_dat_buff : out std_logic;
        uart1_sp5_to_fpga1_dat : in std_logic;
        -- SPARE UART for hw usage
        uart_local_fpga1_to_sp_dat_r : in std_logic;
        uart_local_fpga1_to_sp_rts_l_r : in std_logic;
        uart_local_sp_to_fpga1_dat : in std_logic;
        uart_local_sp_to_fpga1_rts_l : in std_logic;
        
        -- What to do with this stuff?, some maybe removed?
        v1p2_fpga2_a2_pg : in std_logic;
        v2p5_fpga2_a2_pg : in std_logic;
        v2p5_mgmt_a2_pg : in std_logic;
        v3p3_fpga2_a2_pg : in std_logic;
        
    );
end entity;

architecture rtl of cosmo_seq_top is

    signal clk_125m : std_logic;
    signal reset_125m : std_logic;
    signal clk_200m : std_logic;
    signal reset_200m : std_logic;
    signal pll_locked_async : std_logic;
    signal reset_fmc : std_logic;

    signal counter : unsigned(31 downto 0);

begin

    -- Xilinx PLL instantiation
    pll: entity work.cosmo_pll
    port map ( 
        clk_50m => clk_50mhz_fpga1_1,
        clk_125m => clk_125m,
        clk_200m => clk_200m,
        reset => not sp_to_fpga1_system_reset_l,
        locked => pll_locked_async
      
    );

    -- Reset synchronizer into the clock domains
    reset_sync_inst: entity work.reset_sync
    port map(
        pll_locked_async => pll_locked_async,
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        sp_fmc_clk => fmc_sp_to_fpga1_clk,
        reset_fmc_clk => reset_fmc
    );


    -- Blink an LED at some rate
    led: process(clk_125m, reset_125m)
    begin
        if reset_125m then
            counter <= (others => '0');
        elsif rising_edge(clk_125m) then
            counter <= counter + 1;
        end if;
    end process;
    fpga1_status_led <= counter(20);


end rtl;