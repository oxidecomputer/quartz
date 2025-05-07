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

use work.axil_common_pkg.all;
use work.axil26x32_pkg;
use work.axil8x32_pkg;
use work.axi_st8_pkg;
use work.i2c_common_pkg.all;
use work.axi_st8_pkg;
use work.time_pkg.all;
use work.tristate_if_pkg.all;

use work.sequencer_io_pkg.all;

entity cosmo_seq_top is
    port (
        -- Board clocks and resets
        clk_50mhz_fpga1_1 : in std_logic;
        clk_50mhz_fpga1_2 : in std_logic;
        clk_buff_m2_nic_rsw_to_fpga1_los_l : in std_logic;
        sp_to_fpga1_system_reset_l : in std_logic;
        -- FMC interface
        fmc_sp_to_fpga1_clk : in std_logic;
        fmc_sp_to_fpga1_oe_l : in std_logic;
        fmc_sp_to_fpga1_we_l : in std_logic;
        fmc_sp_to_fpga1_wait_l : out std_logic;
        fmc_sp_to_fpga1_cs_l: in std_logic;
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
        espi0_fpga1_to_sp5_alert_l : in std_logic;  -- Un-used currently in-band alert
        -- eSPI1 (currently un-used)
        espi1_sp5_to_fpga1_clk : in std_logic;
        espi1_sp5_to_fpga1_clk_2 : in std_logic;
        espi1_sp5_to_fpga1_cs_l : in std_logic;
        espi1_sp5_to_fpga1_dat : in std_logic_vector(3 downto 0);  --really inout but unused
        espi1_fpga1_to_sp5_alert_l : in std_logic;  -- really an out but unused

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
        -- misc alerts
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
        pwr_cont2_to_fpga1_alert_l : in std_logic;
        pwr_cont3_to_fpga1_alert_l : in std_logic;

        -- SP5 BootRom SPI interface
        spi_fpga1_to_flash_clk : out std_logic;
        spi_fpga1_to_flash_cs_l : out std_logic;
        spi_fpga1_to_flash_dat : inout std_logic_vector(3 downto 0);

        -- Spare and board-level status stuff
        fpga1_to_sp_mux_ign_mux_sel : out std_logic;
        fpga1_to_ign_trgt_fpga_creset : out std_logic; -- swap to output when we want to use this
        seq_rev_id : in std_logic_vector(2 downto 0);

        fpga1_spare_v1p8 : out std_logic_vector(7 downto 0);
        fpga1_spare_v3p3_0 : out std_logic;
        fpga1_spare_v3p3_1 : out std_logic;
        fpga1_spare_v3p3_2 : out std_logic;
        fpga1_spare_v3p3_3 : out std_logic;
        fpga1_spare_v3p3_4 : in std_logic;
        fpga1_spare_v3p3_5 : in std_logic;
        fpga1_spare_v3p3_6 : out std_logic;
        fpga1_spare_v3p3_7 : out std_logic;
        fpga1_status_led : out std_logic;
        fpga2_to_fpga1_io : in std_logic_vector(2 downto 0);
        fpga1_to_fpga2_io : out std_logic_vector(2 downto 0);

        -- T6 NIC sequencing
        fpga1_to_nic_cld_rst_l : out std_logic;
        fpga1_to_nic_eeprom_wp_l : out std_logic;
        fpga1_to_nic_flash_eeprom_wp_buffer_oe_l : out std_logic;
        fpga1_to_nic_flash_wp_l : out std_logic;
        fpga1_to_nic_hsc_en : out std_logic;
        fpga1_to_nic_mfg_mode_l : out std_logic;
        nic_to_fpga1_ext_rst_l : in std_logic;
        v0p96_nic_vdd_a0hp_pg : in std_logic;
        pcie_fpga1_to_nic_perst_l : out std_logic;
        v5p0_nic_a0hp_pg : in std_logic;
        v12p0_nic_a0hp_to_fpga1_fault_l : in std_logic;
        v5p0_nic_a0hp_to_fpga1_fault_l : in std_logic;
        fpga1_to_pcie_clk_buff_nic_oe_l : out std_logic;
        v1p1_nic_enet_a0hp_pg : in std_logic;
        v12p0_nic_a0hp_pg : in std_logic;
        v1p2_nic_enet_a0hp_pg : in std_logic;
        v1p2_nic_pcie_a0hp_pg : in std_logic;
        v1p5_nic_a0hp_pg : in std_logic;
        sp5_to_nic_mfg_mode_l : in std_logic;

        -- SP5/DDR sequencing
        pwr_cont3_to_fpga1_cfp : in std_logic;
        pwr_cont3_to_fpga1_vrhot_n : in std_logic;
        fpga1_to_v12_ddr5_abcdef_hsc_en : out std_logic;
        fpga1_to_v12_ddr5_ghijkl_hsc_en : out std_logic;
        sp5_to_fpga1_thermtrip_l : in std_logic;
        pwr_cont1_to_fpga1_vddcr_cpu0_pg : in std_logic;
        pwr_cont1_to_fpga1_vddcr_cpu1_pg : in std_logic;
        pwr_cont1_to_fpga1_vddcr_soc_pg : in std_logic;
        pwr_cont1_to_fpga1_vddio_sp5_pg : in std_logic;
        pwr_fpga1_to_v1p5_sp5_rtc_a2_en : out std_logic;
        pwr_v1p5_sp5_rtc_a2_to_fpga1_pg : in std_logic;
        sp5_to_fpga1_pwrgd_out : in std_logic; -- spare readback from SP5
        sp5_to_fpga1_pwrok_unbuf : in std_logic;
        sp5_to_fpga1_slp_s3_l : in std_logic;
        sp5_to_fpga1_slp_s5_l : in std_logic;
        v3p3_sp5_en : out std_logic;
        v3p3_sp5_pg : in std_logic;
        fpga1_to_sp5_rsmrst_l : out std_logic;
        fpga1_to_sp5_sys_reset_l : out std_logic;  -- really an out but we don't use, external PU
        vddcr_cpu0_en : out std_logic;
        vddcr_cpu1_en : out std_logic;
        vddcr_soc_en : out std_logic;
        vddio_sp5_en : out std_logic;
        v1p1_sp5_en : out std_logic;
        v1p1_sp5_pg : in std_logic;
        fpga1_to_sp5_pwr_btn_l : out std_logic;
        fpga1_to_sp5_pwrgd : out std_logic;
        fpga1_to_sp5_reset_l : in std_logic;
        fpga1_to_sp5_romtype0 : in std_logic;
        v1p8_sp5_en : out std_logic;
        v1p8_sp5_pg : in std_logic;
        
        -- backplane interface
        fpga1_to_bp_buff_output_en_l : out std_logic;
        pcie_aux_fpga1_to_rsw_perst_l : out std_logic;
        pcie_aux_rsw_to_fpga1_prsnt_buff_l : in std_logic;
        pcie_aux_rsw_to_fpga1_pwrflt_buff_l : in std_logic;
        fpga1_to_pcie_clk_buff_rsw_oe_l : out std_logic;
        rsw_to_sp5_pcie_attached_buff_l : in std_logic;

        -- non-FMC SP interface things
        fpga1_to_sp_int_l : in std_logic;
        fpga1_to_sp_irq_l : out std_logic_vector(6 downto 1);
        fpga1_to_sp_misc_a : in std_logic;
        fpga1_to_sp_misc_b : in std_logic;
        fpga1_to_sp_misc_c : in std_logic;
        fpga1_to_sp_misc_d : in std_logic;

        -- Un-USED SP5 things
        -- hdt_conn_to_mux_testen : out std_logic;
        -- hdt_fpga1_to_mux_dat : out std_logic;
        -- hdt_fpga1_to_mux_dbreq_l : out std_logic;
        -- hdt_fpga1_to_mux_en_l : out std_logic;
        -- hdt_fpga1_to_mux_sel : out std_logic;
        -- hdt_fpga1_to_mux_tck : out std_logic;
        -- hdt_fpga1_to_mux_tms : out std_logic;
        -- hdt_fpga1_to_mux_trst_l : out std_logic;
        -- hdt_fpga1_to_mux_xtrig5_l : out std_logic;
        -- hdt_fpga1_to_mux_xtrig6_l : out std_logic;
        -- hdt_fpga1_to_mux_xtrig7_l : out std_logic;
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
        fpga1_to_sp5_apml_xltr_en : out std_logic;
        fpga1_to_sp5_espi_kbrst_l : in std_logic;
        spi0_sp5_to_fpga1_cs_l : in std_logic;
        spi1_sp5_to_fpga1_cs_l : in std_logic;
        spi2_sp5_to_fpga1_cs_l : in std_logic;
        sp5_to_fpga1_alert_l : in std_logic;
        sp5_to_fpga1_debug : out std_logic_vector(2 downto 1);
        sp5_to_fpga1_genint_l : out std_logic; 
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
        -- I2C SP mux stuff
        i2c_sp_to_fpga1_scl : inout std_logic;
        i2c_sp_to_fpga1_sda : inout std_logic;

        fpga1_to_i2c_mux1_sel : out std_logic_vector(1 downto 0);
        fpga1_to_i2c_mux2_sel : out std_logic_vector(1 downto 0);
        fpga1_to_i2c_mux3_sel : out std_logic_vector(1 downto 0);
        fpga1_to_m2a_hsc_en : out std_logic;
        fpga1_to_m2a_perst_l : out std_logic;
        fpga1_to_m2b_hsc_en : out std_logic;
        fpga1_to_m2b_perst_l : out std_logic;
        fpga1_to_pcie_clk_buff_m2a_oe_l : out std_logic;
        fpga1_to_pcie_clk_buff_m2b_oe_l : out std_logic;
        m2a_to_fpga1_pedet : in std_logic;
        m2a_to_fpga1_prsnt_l : in std_logic;
        v3p3_m2a_a0hp_pg_l : in std_logic;
        v3p3_m2b_a0hp_pg_l : in std_logic;
        v3p3_nic_a0hp_pg : in std_logic;

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
        uart_local_fpga1_to_sp_dat : in std_logic;
        uart_local_fpga1_to_sp_rts_l : in std_logic;
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
    signal reset_fmc : std_logic;
    alias fmc_clk : std_logic is fmc_sp_to_fpga1_clk;
    constant INFO_RESP_IDX : integer := 0;
    constant SPINOR_RESP_IDX: integer := 1;
    constant ESPI_RESP_IDX: integer := 2;
    constant SEQ_RESP_IDX: integer := 3;
    constant SP_I2C_RESP_IDX: integer := 4;
    constant SP5_HP_RESP_IDX : integer := 5;
    constant SPD_PROXY_RESP_IDX : integer := 6;

    constant config_array : axil_responder_cfg_array_t := 
        (INFO_RESP_IDX => (base_addr => x"00000000", addr_span_bits => 8), 
         SPINOR_RESP_IDX => (base_addr => x"00000100", addr_span_bits => 8),
         ESPI_RESP_IDX => (base_addr => x"00000200", addr_span_bits => 8),
         SEQ_RESP_IDX => (base_addr => x"00000300", addr_span_bits => 8),
         SP_I2C_RESP_IDX => (base_addr => x"00000400", addr_span_bits => 8),
         SP5_HP_RESP_IDX => (base_addr => x"00000500", addr_span_bits => 8),
         SPD_PROXY_RESP_IDX => (base_addr => x"00000600", addr_span_bits => 8)
         );
    signal fmc_axi_if : axil26x32_pkg.axil_t;
    signal responders : axil8x32_pkg.axil_array_t(config_array'range);
    signal fmc_internal_data_out : std_logic_vector(15 downto 0);
    signal fmc_data_out_enable: std_logic;

    signal spinor_io_o : std_logic_vector(3 downto 0);
    signal spinor_io_oe : std_logic_vector(3 downto 0);
    signal espi_io_o : std_logic_vector(3 downto 0);
    signal espi_io_oe : std_logic_vector(3 downto 0);

    signal ipcc_uart_from_espi_axi_st : axi_st8_pkg.axi_st_t;
    signal ipcc_uart_to_espi_axi_st : axi_st8_pkg.axi_st_t;
    signal a0_ok : std_logic;
    signal a0_idle : std_logic;
    signal ddr_bulk : ddr_bulk_power_t;
    signal sp5_group_a : group_a_power_t;
    signal sp5_group_b : group_b_power_t;
    signal sp5_group_c : group_c_power_t;
    signal nic_rails : nic_power_t;
    signal sp5_seq_pins : sp5_seq_pins_t;
    signal nic_seq_pins : nic_seq_pins_t;
    signal early_power : early_power_t;
    signal sp_scl_o : std_logic;
    signal sp_scl_oe : std_logic;
    signal sp_sda_o : std_logic;
    signal sp_sda_oe : std_logic;
    signal sp5_scl_o : std_logic;
    signal sp5_scl_oe : std_logic;
    signal sp5_sda_o : std_logic;
    signal sp5_sda_oe : std_logic;

    signal sp5_t6_power_en : std_logic;
    signal sp5_t6_perst_l : std_logic;
    signal espi_resp_csn : std_logic;
    signal hp_int_n : std_logic;

    signal fpga1_to_pcie_clk_buff_rsw_oe_l_int : std_logic;

    signal sp5_abcdef_scl_if : tristate;
    signal sp5_abcdef_sda_if : tristate;
    signal sp5_ghijkl_scl_if : tristate;
    signal sp5_ghijkl_sda_if : tristate;
    signal dimm_abcdef_scl_if : tristate;
    signal dimm_abcdef_sda_if : tristate;
    signal dimm_ghijkl_scl_if : tristate;
    signal dimm_ghijkl_sda_if : tristate;

    signal amd_hp_irq_n_final : std_logic;
    alias fpga2_hp_irq_n_unsyncd : std_logic is fpga2_to_fpga1_io(2);
    signal fpga2_hp_irq_n : std_logic;
    alias a0_ok_to_fpga2 : std_logic is fpga1_to_fpga2_io(2);

begin

    meta_sync_inst: entity work.meta_sync
     port map(
        async_input => fpga2_hp_irq_n_unsyncd,
        clk => clk_125m,
        sycnd_output => fpga2_hp_irq_n
    );

    espi_dbg: process(clk_200m, reset_200m)
    begin
        if rising_edge(clk_200m) then
            fpga1_spare_v1p8(0) <= i3c_fpga1_to_dimm_abcdef_scl;
            fpga1_spare_v1p8(7) <= i3c_fpga1_to_dimm_abcdef_sda;
            fpga1_spare_v1p8(6) <= amd_hp_irq_n_final;
            fpga1_spare_v1p8(1) <= espi0_sp5_to_fpga1_clk;
            fpga1_spare_v1p8(2) <= espi0_sp5_to_fpga1_cs_l;
            fpga1_spare_v1p8(3) <= espi0_sp5_to_fpga1_dat(0);
            fpga1_spare_v1p8(4) <= espi0_sp5_to_fpga1_dat(1);
            fpga1_spare_v1p8(5) <= espi_resp_csn;
        end if;
    end process;
    -- misc things tied:
    fpga1_to_fpga2_io <= (others => 'Z');
    fpga1_to_sp5_sys_reset_l <= 'Z';  -- We don't use this in product, external PU.
    fpga1_to_ign_trgt_fpga_creset <= '0';  -- Disabled until we decide what to do with it
    fpga1_to_sp_mux_ign_mux_sel <= '0';  -- Default until we decide what to do with it
    fpga1_to_sp_irq_l <= (others => '1');
    -- Enable various buffers when we're in A0:
    fpga1_espi0_cs_l_buff_oe_en_l <= '0' when sp5_seq_pins.pwr_good else 'Z';
    fpga1_to_sp5_apml_xltr_en <= sp5_seq_pins.pwr_good;
    fpga1_uart0_buff_oe_en_l <= '0' when a0_ok else '1';
    fpga1_uart1_buff_oe_en_l <= '0' when a0_ok else '1'; -- not used but why not enable anyway?
    uart1_fpga1_to_sp5_dat_buff <= '1';  -- Make this idle generally, buffer protects from cross-drive
    i3c_sp5_to_fpga1_oe_l <= '0' when  sp5_seq_pins.pwr_good else '1';
    i3c_fpga1_to_dimm_oe_l <= '0' when  sp5_seq_pins.pwr_good else '1';

    -- hdt_fpga1_to_mux_en_l <= 'Z';
    -- hdt_fpga1_to_mux_sel <= '0';

    -- hdt_conn_to_mux_testen <= '0';
    -- hdt_fpga1_to_mux_dat <= '1' when sp5_group_a.v1p8_sp5_a1.enable = '1' else '0';
    -- hdt_fpga1_to_mux_dbreq_l <= '1' when sp5_group_a.v1p8_sp5_a1.enable = '1' else '0';
    -- hdt_fpga1_to_mux_tck <= sp5_group_a.v1p8_sp5_a1.enable;
    -- hdt_fpga1_to_mux_tms <= '1' when sp5_group_a.v1p8_sp5_a1.enable = '1' else '0';
    -- hdt_fpga1_to_mux_trst_l <= '1' when sp5_group_a.v1p8_sp5_a1.enable = '1' else '0';
    -- hdt_fpga1_to_mux_xtrig5_l  <= 'Z';
    -- hdt_fpga1_to_mux_xtrig6_l <= 'Z';
    -- hdt_fpga1_to_mux_xtrig7_l  <= 'Z';

    ---------------------------------------------
    -- FMC to AXI Interface from the SP
    ---------------------------------------------
    stm32h7_fmc_target_inst: entity work.stm32h7_fmc_target
    port map(
       chip_reset => reset_fmc,
       fmc_clk => fmc_clk,
       a(24 downto 20) => "00000",
       a(19 downto 16) => fmc_sp_to_fpga1_a(19 downto 16),
       --a(23 downto 16) => fmc_sp_to_fpga1_a,
       addr_data_in => fmc_sp_to_fpga1_da,
       data_out => fmc_internal_data_out,
       data_out_en => fmc_data_out_enable,
       ne(3 downto 1) => "111",
       ne(0) => fmc_sp_to_fpga1_cs_l,
       noe => fmc_sp_to_fpga1_oe_l,
       nwe => fmc_sp_to_fpga1_we_l,
       nl => fmc_sp_to_fpga1_adv_l,
       nwait => fmc_sp_to_fpga1_wait_l,
       aclk => clk_125m,
       aresetn => not reset_125m,
       axi_if => fmc_axi_if
   );
    -- tristate control for the FMC data bus
    fmc_sp_to_fpga1_da <= fmc_internal_data_out when fmc_data_out_enable = '1' else (others => 'Z');

   -- Axi decode/interconnect
   axil_interconnect_inst: entity work.axil_interconnect
    generic map(
       config_array => config_array
   )
    port map(
       clk => clk_125m,
       reset => reset_125m,
       initiator => fmc_axi_if,
       responders => responders
   );

    -- Block that generates our clocks, resets and
    -- deals with core board-level functionality
    -- includes the common "info" block on the axi bus
    board_support_inst: entity work.board_support
     port map(
        board_50mhz_clk => clk_50mhz_fpga1_1,
        sp_fmc_clk => fmc_clk,
        sp_system_reset_l => sp_to_fpga1_system_reset_l,
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        reset_fmc => reset_fmc,
        fpga1_status_led => fpga1_status_led,
        hubris_compat_ver => seq_rev_id,
        info_axi_if => responders(INFO_RESP_IDX)
    );

    -- espi and flash interface block
    -- espi and spi-nor blocks manage their own synchronization.
    -- only a tiny portion of the espi design runs at 200MHz
    -- all the system interfaces run at 125MHz for common clocking
    espi_spinor_ss: entity work.sp5_espi_flash_subsystem
     port map(
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        espi_axi_if => responders(ESPI_RESP_IDX),
        espi_csn => espi0_sp5_to_fpga1_cs_l,
        espi_clk => espi0_sp5_to_fpga1_clk,
        espi_dat => espi0_sp5_to_fpga1_dat,
        espi_dat_o => espi_io_o,
        espi_dat_oe => espi_io_oe,
        response_csn => espi_resp_csn,  -- debugging with saleae if you have access
        ipcc_uart_from_espi => ipcc_uart_from_espi_axi_st,
        ipcc_uart_to_espi => ipcc_uart_to_espi_axi_st,
        spinor_axi_if => responders(SPINOR_RESP_IDX),
        spi_nor_csn => spi_fpga1_to_flash_cs_l,
        spi_nor_clk => spi_fpga1_to_flash_clk,
        spi_nor_dat => spi_fpga1_to_flash_dat,
        spi_nor_dat_o => spinor_io_o,
        spi_nor_dat_oe => spinor_io_oe
    );
    --Tristates for spi-nor flash pins and espi
    spi_nor_espi_tris:process(all)
    begin
        for i in spi_fpga1_to_flash_dat'range loop
            spi_fpga1_to_flash_dat(i) <= spinor_io_o(i) when spinor_io_oe(i) = '1' else 'Z';
            espi0_sp5_to_fpga1_dat(i) <= espi_io_o(i) when espi_io_oe(i) = '1' else 'Z';
        end loop;
    end process;

    -- UART subsystem
    -- stuff externally synchronized inside the UART block(s)
    sp5_uart_ss: entity work.sp5_uart_subsystem
     port map(
        clk => clk_125m,
        reset => reset_125m,
        -- UART pins
        -- IPCC SP side
        ipcc_from_sp => uart1_sp_to_fpga1_dat,
        ipcc_to_sp => uart1_fpga1_to_sp_dat,
        ipcc_from_sp_rts_l => uart1_sp_to_fpga1_rts_l,
        ipcc_to_sp_rts_l => uart1_fpga1_to_sp_rts_l,
        -- UART0 SP-side
        console_from_sp => uart0_sp_to_fpga1_dat,
        console_to_sp_dat => uart0_fpga1_to_sp_dat,
        console_to_sp_rts_l => uart0_fpga1_to_sp_rts_l,
        console_from_sp_rts_l => uart0_sp_to_fpga1_rts_l,
        -- UART0 SP5-side
        host_from_fpga => uart0_fpga1_to_sp5_dat_buff,
        host_to_fpga => uart0_sp5_to_fpga1_dat,
        host_from_fpga_rts_l => uart0_fpga1_to_sp5_rts_l_buff,
        host_to_fpga_rts_l => uart0_sp5_to_fpga1_rts_l,
        uart_from_fpga => open,
        uart_to_fpga => '1',
        uart_from_fpga_rts_l => open,
        uart_to_fpga_rts_l => '0',
        -- IPCC "UART" from espi
        ipcc_from_espi => ipcc_uart_from_espi_axi_st,
        ipcc_to_espi => ipcc_uart_to_espi_axi_st,
        -- 
        dbg_mux_en => '1',
        dbg_pins_uart_out => fpga1_spare_v3p3_7,
        dbg_pins_uart_out_rts_l => fpga1_spare_v3p3_4,
        dbg_pins_uart_in => fpga1_spare_v3p3_5,
        dbg_pins_uart_in_rts_l => fpga1_spare_v3p3_6
    );

    -- SP I2C muxes
    -- i2c is the only input, sycn'd inside the mux block(s)
    sp_i2c_subsystem_inst: entity work.sp_i2c_subsystem
     port map(
        clk => clk_125m,
        reset => reset_125m,
        in_a0 => a0_ok,
        axi_if => responders(SP_I2C_RESP_IDX),
        sp_scl => i2c_sp_to_fpga1_scl,
        sp_scl_o => sp_scl_o,
        sp_scl_oe => sp_scl_oe,
        sp_sda => i2c_sp_to_fpga1_sda,
        sp_sda_o => sp_sda_o,
        sp_sda_oe => sp_sda_oe,
        i2c_mux1_sel => fpga1_to_i2c_mux1_sel,
        i2c_mux2_sel => fpga1_to_i2c_mux2_sel,
        i2c_mux3_sel => fpga1_to_i2c_mux3_sel
    );
    --Tristates for spi-nor flash pins and espi
    i2c_sp_to_fpga1_scl <= sp_scl_o when sp_scl_oe = '1' else 'Z';
    i2c_sp_to_fpga1_sda <= sp_sda_o when sp_sda_oe = '1' else 'Z';

    -- SP5 I2c hotplug expanders
    -- Inputs synchronized inside the block
    sp5_hotplug_subsystem_inst: entity work.sp5_hotplug_subsystem
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders(SP5_HP_RESP_IDX),
        sp5_i2c_sda => i2c_sp5_to_fpgax_hp_sda,
        sp5_i2c_sda_o => sp5_sda_o,
        sp5_i2c_sda_oe => sp5_sda_oe,
        sp5_i2c_scl => i2c_sp5_to_fpgax_hp_scl,
        sp5_i2c_scl_o => sp5_scl_o,
        sp5_i2c_scl_oe => sp5_scl_oe,
        int_n => hp_int_n,
        a0_ok => a0_ok,
        m2a_pedet => m2a_to_fpga1_pedet,
        m2a_prsnt_l => m2a_to_fpga1_prsnt_l,
        m2a_hsc_en => fpga1_to_m2a_hsc_en,
        m2a_perst_l => fpga1_to_m2a_perst_l,
        m2a_pwr_fault_l => m2a_hsc_to_fpga1_fault_l,
        pcie_clk_buff_m2a_oe_l => fpga1_to_pcie_clk_buff_m2a_oe_l,
        m2b_pedet => m2b_to_fpga1_pedet,
        m2b_prsnt_l => m2b_to_fpga1_prsnt_l,
        m2b_hsc_en => fpga1_to_m2b_hsc_en,
        m2b_perst_l => fpga1_to_m2b_perst_l,
        m2b_pwr_fault_l => m2b_hsc_to_fpga1_fault_l,
        pcie_clk_buff_m2b_oe_l => fpga1_to_pcie_clk_buff_m2b_oe_l,
        t6_power_en => sp5_t6_power_en,
        t6_perst_l => sp5_t6_perst_l,
        pcie_aux_rsw_perst_l => pcie_aux_fpga1_to_rsw_perst_l,
        pcie_aux_rsw_prsnt_buff_l => pcie_aux_rsw_to_fpga1_prsnt_buff_l,
        pcie_aux_rsw_pwrflt_buff_l=> pcie_aux_rsw_to_fpga1_pwrflt_buff_l,
        pcie_clk_buff_rsw_oe_l => fpga1_to_pcie_clk_buff_rsw_oe_l_int,
        rsw_sp5_pcie_attached_buff_l =>rsw_to_sp5_pcie_attached_buff_l
    );

    a0_ok_to_fpga2 <= a0_ok;  -- A0 OK signal to fpga2, used for power sequencing

    -- combine fpga signals cosmo revA
    amd_hp_irq_n_final <= '0' when fpga2_hp_irq_n = '0' or hp_int_n = '0' else '1';
    sp5_to_fpga1_genint_l <= '0' when amd_hp_irq_n_final = '0' else 'Z';

    fpga1_to_pcie_clk_buff_rsw_oe_l <= '0' when fpga1_to_pcie_clk_buff_rsw_oe_l_int = '0' else 'Z';

    --Tristates for spi-nor flash pins and espi
    i2c_sp5_to_fpgax_hp_scl <= sp5_scl_o when sp5_scl_oe = '1' else 'Z';
    i2c_sp5_to_fpgax_hp_sda <= sp5_sda_o when sp5_sda_oe = '1' else 'Z';

    --Block that deals with sequencing the SP5 and nic etc
    -- inputs synchronized inside the block
    seq: entity work.sp5_sequencer
     generic map(
        CNTS_P_MS => calc_ms(desired_ms => 1, clk_period_ns => 8)
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders(SEQ_RESP_IDX),
        a0_ok => a0_ok,
        a0_idle => a0_idle,
        early_power_pins => early_power,
        ddr_bulk_pins => ddr_bulk,
        group_a_pins => sp5_group_a,
        group_b_pins => sp5_group_b,
        group_c_pins => sp5_group_c,
        sp5_seq_pins => sp5_seq_pins,
        nic_rails_pins => nic_rails,
        nic_seq_pins => nic_seq_pins,
        sp5_t6_power_en => sp5_t6_power_en,
        sp5_t6_perst_l => sp5_t6_perst_l
    );

    -- early power related pins
    early_power.fan_central_hsc_pg <= fan_central_hsc_to_fpga1_pg;
    early_power.fan_east_hsc_pg <= fan_east_hsc_to_fpga1_pg;
    early_power.fan_west_hsc_pg <= fan_west_hsc_to_fpga1_pg;
    early_power.fan_fail <= fan_to_fpga1_fan_fail;
    fpga1_to_fan_central_hsc_disable <= early_power.fan_central_hsc_disable;
    fpga1_to_fan_east_hsc_disable <= early_power.fan_east_hsc_disable;
    fpga1_to_fan_west_hsc_disable <= early_power.fan_west_hsc_disable;

    -- Bulk DDR power control and HSC readback
    ddr_bulk.abcdef_hsc.pg <= v12_ddr5_abcdef_a0_pg;
    fpga1_to_v12_ddr5_abcdef_hsc_en <= ddr_bulk.abcdef_hsc.enable;
    ddr_bulk.ghijkl_hsc.pg <= v12_ddr5_ghijkl_a0_pg;
    fpga1_to_v12_ddr5_ghijkl_hsc_en <= ddr_bulk.ghijkl_hsc.enable;
    -- SP5 rails
    -- group A enables and PGs
    pwr_fpga1_to_v1p5_sp5_rtc_a2_en <= sp5_group_a.pwr_v1p5_rtc.enable;
    sp5_group_a.pwr_v1p5_rtc.pg <= pwr_v1p5_sp5_rtc_a2_to_fpga1_pg;
    v3p3_sp5_en <= sp5_group_a.v3p3_sp5_a1.enable;
    sp5_group_a.v3p3_sp5_a1.pg <= v3p3_sp5_pg;
    v1p8_sp5_en <= sp5_group_a.v1p8_sp5_a1.enable;
    sp5_group_a.v1p8_sp5_a1.pg <= v1p8_sp5_pg;
    -- group B enable and pg
    v1p1_sp5_en <= sp5_group_b.v1p1_sp5.enable;
    sp5_group_b.v1p1_sp5.pg <= v1p1_sp5_pg;
    -- group C enables and pgs
    vddio_sp5_en <= sp5_group_c.vddio_sp5_a0.enable;
    sp5_group_c.vddio_sp5_a0.pg <= pwr_cont1_to_fpga1_vddio_sp5_pg;
    vddcr_cpu1_en <= sp5_group_c.vddcr_cpu1.enable;
    sp5_group_c.vddcr_cpu1.pg <= pwr_cont1_to_fpga1_vddcr_cpu1_pg;
    vddcr_cpu0_en <= sp5_group_c.vddcr_cpu0.enable;
    sp5_group_c.vddcr_cpu0.pg <= pwr_cont1_to_fpga1_vddcr_cpu0_pg;
    vddcr_soc_en <= sp5_group_c.vddcr_soc.enable;
    sp5_group_c.vddcr_soc.pg <= pwr_cont1_to_fpga1_vddcr_soc_pg;
    -- nic rails
    fpga1_to_nic_hsc_en <= nic_rails.nic_hsc_12v.enable;
    nic_rails.v1p5_nic_a0hp.pg <= v1p5_nic_a0hp_pg;
    nic_rails.v1p2_nic_pcie_a0hp.pg <= v1p2_nic_pcie_a0hp_pg;
    nic_rails.v1p2_nic_enet_a0hp.pg <= v1p2_nic_enet_a0hp_pg;
    nic_rails.v3p3_nic_a0hp.pg <= v3p3_nic_a0hp_pg;
    nic_rails.v1p1_nic_a0hp.pg <= v1p1_nic_enet_a0hp_pg;
    -- TODO rev-1 cosmo missing readback on v1p4_nic_a0hp -- cascade enabled in hw from V5P0_NIC_A0HP
    nic_rails.v0p96_nic_vdd_a0hp.pg <= v0p96_nic_vdd_a0hp_pg;
    nic_rails.nic_hsc_12v.pg <= v12p0_nic_a0hp_pg;
    nic_rails.nic_hsc_5v.pg <= v5p0_nic_a0hp_pg;

    -- SP5 sequence-related pins
    sp5_seq_pins.thermtrip_l <= sp5_to_fpga1_thermtrip_l;
    sp5_seq_pins.smerr_l <= sp5_to_fpga1_smerr_l;
    sp5_seq_pins.reset_l <= fpga1_to_sp5_reset_l;
    sp5_seq_pins.pwr_ok <= sp5_to_fpga1_pwrok_unbuf;
    fpga1_to_sp5_pwr_btn_l <= '0' when sp5_seq_pins.pwr_btn_l = '0' else 'Z';
    sp5_seq_pins.slp_s3_l <= sp5_to_fpga1_slp_s3_l;
    sp5_seq_pins.slp_s5_l <= sp5_to_fpga1_slp_s5_l;
    fpga1_to_sp5_rsmrst_l <= sp5_seq_pins.rsmrst_l;
    sp5_to_fpga1_debug(1) <= sp5_seq_pins.is_cosmo;
    sp5_to_fpga1_debug(2) <= 'Z';
    fpga1_to_sp5_pwrgd <= sp5_seq_pins.pwr_good;

    -- Nic sequence-related pins
    fpga1_to_nic_cld_rst_l <= nic_seq_pins.cld_rst_l;
    fpga1_to_nic_eeprom_wp_l <= nic_seq_pins.eeprom_wp_l;
    fpga1_to_pcie_clk_buff_nic_oe_l <= '0' when nic_seq_pins.nic_pcie_clk_buff_oe_l = '0' else 'Z';
    fpga1_to_nic_flash_wp_l <= nic_seq_pins.flash_wp_l;
    fpga1_to_nic_mfg_mode_l <= nic_seq_pins.nic_mfg_mode_l;
    nic_seq_pins.ext_rst_l <= nic_to_fpga1_ext_rst_l;
    fpga1_to_nic_flash_eeprom_wp_buffer_oe_l <= nic_seq_pins.eeprom_wp_buffer_oe_l;
    nic_seq_pins.sp5_mfg_mode_l <= sp5_to_nic_mfg_mode_l;
    pcie_fpga1_to_nic_perst_l <= nic_seq_pins.perst_l;

    -- SP5 <-> FPGA busses (filtered in proxy block)
    i3c_sp5_to_fpga1_abcdef_scl <= sp5_abcdef_scl_if.o when sp5_abcdef_scl_if.oe else 'Z';
    sp5_abcdef_scl_if.i <= i3c_sp5_to_fpga1_abcdef_scl;
    i3c_sp5_to_fpga1_abcdef_sda <= sp5_abcdef_sda_if.o when sp5_abcdef_sda_if.oe else 'Z';
    sp5_abcdef_sda_if.i <= i3c_sp5_to_fpga1_abcdef_sda;
    i3c_sp5_to_fpga1_ghijkl_scl <= sp5_ghijkl_scl_if.o when sp5_ghijkl_scl_if.oe else 'Z';
    sp5_ghijkl_scl_if.i <= i3c_sp5_to_fpga1_ghijkl_scl;
    i3c_sp5_to_fpga1_ghijkl_sda <= sp5_ghijkl_sda_if.o when sp5_ghijkl_sda_if.oe else 'Z';
    sp5_ghijkl_sda_if.i <= i3c_sp5_to_fpga1_ghijkl_sda;
        -- FPGA <-> DIMMs busses (filtered in proxy block)
    i3c_fpga1_to_dimm_abcdef_scl <= dimm_abcdef_scl_if.o when dimm_abcdef_scl_if.oe else 'Z';
    dimm_abcdef_scl_if.i <= i3c_fpga1_to_dimm_abcdef_scl;
    i3c_fpga1_to_dimm_abcdef_sda <= dimm_abcdef_sda_if.o when dimm_abcdef_sda_if.oe else 'Z';
    dimm_abcdef_sda_if.i <= i3c_fpga1_to_dimm_abcdef_sda;
        i3c_fpga1_to_dimm_ghijkl_scl <= dimm_ghijkl_scl_if.o when dimm_ghijkl_scl_if.oe else 'Z';
    dimm_ghijkl_scl_if.i <= i3c_fpga1_to_dimm_ghijkl_scl;
    i3c_fpga1_to_dimm_ghijkl_sda <= dimm_ghijkl_sda_if.o when dimm_ghijkl_sda_if.oe else 'Z';
    dimm_ghijkl_sda_if.i <= i3c_fpga1_to_dimm_ghijkl_sda;
    
    spd_proxy_top_abcdef_inst: entity work.spd_proxy_top
     generic map(
        CLK_PER_NS => 8,
        I2C_MODE => FAST_PLUS
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders(SPD_PROXY_RESP_IDX),
        cpu_scl_if0 => sp5_abcdef_scl_if,
        cpu_sda_if0 => sp5_abcdef_sda_if,
        cpu_scl_if1 => sp5_ghijkl_scl_if,
        cpu_sda_if1 => sp5_ghijkl_sda_if,
        dimm_scl_if0 => dimm_abcdef_scl_if,
        dimm_sda_if0 => dimm_abcdef_sda_if,
        dimm_scl_if1 => dimm_ghijkl_scl_if,
        dimm_sda_if1 => dimm_ghijkl_sda_if
    );


end rtl;