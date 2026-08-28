-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Metro Sequencer FPGA targeting the Spartan-7 (U27, XC7S100-1FGGA484I).
--
-- Structurally this is cosmo_seq's top with the T6 NIC replaced by an AMD
-- Versal Premium VP1202: the SP-facing FMC bus, eSPI/SPI-NOR service, DIMM SPD
-- proxy, hotplug emulation, UART routing and I2C muxing are all the shared
-- blocks, and the Versal sequencing and boot-flash mux are Metro's own.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil_common_pkg.all;
use work.axil26x32_pkg;
use work.axil8x32_pkg;
use work.axil32x32_pkg;
use work.axil15x32_pkg;
use work.axi_st8_pkg;
use work.axilite_if_2k19_helper_pkg.all;
use work.i2c_common_pkg.all;
use work.time_pkg.all;
use work.tristate_if_pkg.all;

use work.sp5_power_pkg.all;
use work.sequencer_io_pkg.all;
use work.sp5_uart_subsystem_pkg.all;

entity metro_seq_top is
    port (
        -- Board clocks and resets
        clk_50mhz_fpga1_2 : in std_logic;
        clk_50mhz_fpga1_1 : in std_logic;
        clk_buff_m2_rsw_to_fpga1_los_l : in std_logic;
        clk_buff_nic_to_fpga1_los_l : in std_logic;
        sp_to_fpga1_system_reset_l : in std_logic;
        -- FMC interface to the SP
        fmc_sp_to_fpga1_a : in std_logic_vector(23 downto 16);
        fmc_sp_to_fpga1_adv_l : in std_logic;
        fmc_sp_to_fpga1_bl_l : in std_logic_vector(1 downto 0);
        fmc_sp_to_fpga1_clk : in std_logic;
        fmc_sp_to_fpga1_cs_l : in std_logic;
        fmc_sp_to_fpga1_da : inout std_logic_vector(15 downto 0);
        fmc_sp_to_fpga1_oe_l : in std_logic;
        fmc_sp_to_fpga1_wait_l : out std_logic;
        fmc_sp_to_fpga1_we_l : in std_logic;
        -- eSPI interfaces to the SP5
        espi0_fpga1_to_sp5_alert_l : in std_logic;
        espi0_sp5_to_fpga1_clk : in std_logic;
        espi0_sp5_to_fpga1_cs_l : in std_logic;
        espi0_sp5_to_fpga1_dat : inout std_logic_vector(3 downto 0);
        espi1_fpga1_to_sp5_alert_l : in std_logic;
        espi1_sp5_to_fpga1_clk : in std_logic;
        espi1_sp5_to_fpga1_clk_2 : in std_logic;
        espi1_sp5_to_fpga1_cs_l : in std_logic;
        espi1_sp5_to_fpga1_dat : inout std_logic_vector(3 downto 0);
        espi_sp5_to_fpga1_reset_l : in std_logic;
        -- SP5 boot flash (SPI-NOR)
        spi0_sp5_to_fpga1_cs_l : in std_logic;
        spi1_sp5_to_fpga1_cs_l : in std_logic;
        spi2_sp5_to_fpga1_cs_l : in std_logic;
        spi_fpga1_to_flash_clk : out std_logic;
        spi_fpga1_to_flash_cs_l : out std_logic;
        spi_fpga1_to_flash_dat : inout std_logic_vector(3 downto 0);
        -- Versal (VP1202) boot straps, status and boot-flash mux
        fpga1_to_vercel_flash_qspi_mux_en_l : out std_logic;
        fpga1_to_vercel_flash_qspi_mux_sel : out std_logic;
        fpga1_to_versal_erro_done_buff_en : out std_logic;
        fpga1_to_versal_mode : out std_logic_vector(3 downto 0);
        fpga1_to_versal_mode_buffer_en_l : out std_logic;
        fpga1_to_versal_por_b : out std_logic;
        qspi_fpga1_to_vercel_flash_mux_cs_l : out std_logic;
        qspi_fpga1_to_vercel_flash_mux_d : inout std_logic_vector(3 downto 0);
        qspi_fpga1_to_vercel_flash_mux_sck : out std_logic;
        versal_to_fpga1_done : in std_logic;
        versal_to_fpga1_error_out : in std_logic;
        -- Versal power rails
        fpga1_to_nic_hsc_en : out std_logic;
        sp5_to_nic_mfg_mode_l : in std_logic;
        v0p88_nic_a0hp_en : out std_logic;
        v0p88_nic_a0hp_pg : in std_logic;
        v0p8_nic_vccint_a0hp_en : out std_logic;
        v0p8_nic_vccint_a0hp_pg : in std_logic;
        v0p92_nic_avcc_a0hp_pg : in std_logic;
        v12p0_nic_a0hp_pg : in std_logic;
        v12p0_nic_a0hp_to_fpga1_fault_l : in std_logic;
        v1p1_nic_a0hp_en : out std_logic;
        v1p2_nic_avtt_a0hp_pg : in std_logic;
        v1p4_nic_a0hp_en : out std_logic;
        v1p5_nic_a0hp_en : out std_logic;
        v1p5_nic_a0hp_pg : in std_logic;
        v1p5_nic_avccaux_a0hp_en : out std_logic;
        v1p5_nic_avccaux_a0hp_pg : in std_logic;
        v1p8_nic_a0hp_en : out std_logic;
        v1p8_nic_a0hp_pg : in std_logic;
        v3p3_nic_a0hp_en : out std_logic;
        v3p3_nic_a0hp_pg : in std_logic;
        v5p0_nic_a0hp_pg : in std_logic;
        v5p0_nic_a0hp_to_fpga1_fault_l : in std_logic;
        -- Versal PCIe channels
        fpga1_to_pcie_clk_buff_nic_cha_oe_l : out std_logic;
        fpga1_to_pcie_clk_buff_nic_chb_oe_l : out std_logic;
        pcie_fpga1_to_nic_cha_perst_l : out std_logic;
        pcie_fpga1_to_nic_chb_perst_l : out std_logic;
        pcie_nic_to_fpga1_cha_prsnt_l : in std_logic;
        pcie_nic_to_fpga1_cha_pwren_l : in std_logic;
        pcie_nic_to_fpga1_chb_prsnt_l : in std_logic;
        pcie_nic_to_fpga1_chb_pwren_l : in std_logic;
        -- SP5 power rails and sequencing
        fpga1_to_sp5_apml_xltr_en : out std_logic;
        fpga1_to_sp5_espi_kbrst_l : in std_logic;
        fpga1_to_sp5_pwr_btn_l : out std_logic;
        fpga1_to_sp5_pwrgd : out std_logic;
        fpga1_to_sp5_romtype0 : in std_logic;
        fpga1_to_sp5_rsmrst_l : out std_logic;
        fpga1_to_sp5_sys_reset_l : out std_logic;
        pwr_cont1_to_fpga1_alert_l : in std_logic;
        pwr_cont1_to_fpga1_vddcr_cpu0_pg : in std_logic;
        pwr_cont1_to_fpga1_vddcr_cpu1_pg : in std_logic;
        pwr_cont1_to_fpga1_vddcr_soc_pg : in std_logic;
        pwr_cont1_to_fpga1_vddio_sp5_pg : in std_logic;
        pwr_cont2_to_fpga1_alert_l : in std_logic;
        pwr_cont3_to_fpga1_alert_l : in std_logic;
        pwr_cont3_to_fpga1_cfp : in std_logic;
        pwr_cont3_to_fpga1_vrhot_n : in std_logic;
        pwr_cont4_to_fpga1_alert_l : in std_logic;
        pwr_cont4_to_fpga1_cfp : in std_logic;
        pwr_cont4_to_fpga1_vrhot_n : in std_logic;
        pwr_fpga1_to_v1p5_sp5_rtc_a2_en : out std_logic;
        pwr_v1p5_sp5_rtc_a2_to_fpga1_pg : in std_logic;
        sp5_to_fpga1_alert_l : in std_logic;
        sp5_to_fpga1_debug1 : out std_logic;
        sp5_to_fpga1_debug2 : in std_logic;
        sp5_to_fpga1_pwrgd_out : in std_logic;
        sp5_to_fpga1_pwrok_unbuf : in std_logic;
        fpga1_to_sp5_reset_l : in std_logic;
        sp5_to_fpga1_slp_s3_l : in std_logic;
        sp5_to_fpga1_slp_s5_l : in std_logic;
        sp5_to_fpga1_smerr_l : in std_logic;
        sp5_to_fpga1_spd_host_ctrl_l : in std_logic;
        sp5_to_fpga1_thermtrip_l : in std_logic;
        v1p1_i3c_a2_pg : in std_logic;
        v1p1_sp5_en : out std_logic;
        v1p1_sp5_pg : in std_logic;
        v1p2_fpga2_a2_pg : in std_logic;
        v1p8_sp5_en : out std_logic;
        v1p8_sp5_pg : in std_logic;
        v2p5_fpga2_a2_pg : in std_logic;
        v2p5_mgmt_a2_pg : in std_logic;
        v3p3_fpga2_a2_pg : in std_logic;
        v3p3_sp5_en : out std_logic;
        v3p3_sp5_pg : in std_logic;
        vddcr_cpu0_en : out std_logic;
        vddcr_cpu1_en : out std_logic;
        vddcr_soc_en : out std_logic;
        vddio_sp5_en : out std_logic;
        -- DDR bulk power and DIMM power good
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
        fpga1_to_v12_ddr5_abcdef_hsc_en : out std_logic;
        fpga1_to_v12_ddr5_ghijkl_hsc_en : out std_logic;
        v12_ddr5_abcdef_a0_pg : in std_logic;
        v12_ddr5_ghijkl_a0_pg : in std_logic;
        -- DIMM SPD I3C
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
        -- M.2 hotplug
        fpga1_to_m2_apml_xltr_en : out std_logic;
        fpga1_to_m2a_hsc_en : out std_logic;
        fpga1_to_m2a_perst_l : out std_logic;
        fpga1_to_m2b_hsc_en : out std_logic;
        fpga1_to_m2b_perst_l : out std_logic;
        fpga1_to_pcie_clk_buff_m2a_oe_l : out std_logic;
        fpga1_to_pcie_clk_buff_m2b_oe_l : out std_logic;
        m2a_hsc_to_fpga1_fault_l : in std_logic;
        m2a_to_fpga1_pedet : in std_logic;
        m2a_to_fpga1_prsnt_l : in std_logic;
        m2b_hsc_to_fpga1_fault_l : in std_logic;
        m2b_to_fpga1_pedet : in std_logic;
        m2b_to_fpga1_prsnt_l : in std_logic;
        v3p3_m2a_a0hp_pg_l : in std_logic;
        v3p3_m2b_a0hp_pg_l : in std_logic;
        -- Backplane / rear switch
        fpga1_to_bp_buff_output_en_l : out std_logic;
        fpga1_to_pcie_clk_buff_rsw_oe_l : out std_logic;
        pcie_aux_fpga1_to_rsw_perst_l : out std_logic;
        pcie_aux_rsw_to_fpga1_prsnt_buff_l : in std_logic;
        pcie_aux_rsw_to_fpga1_pwrflt_buff_l : in std_logic;
        rsw_to_sp5_pcie_attached_buff_l : in std_logic;
        -- Fans and thermal
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
        smbus_therm_ne_to_fpga1_alert_l : in std_logic;
        smbus_therm_nw_to_fpga1_alert_l : in std_logic;
        smbus_therm_sc_to_fpga1_alert_l : in std_logic;
        smbus_therm_se_to_fpga1_alert_l : in std_logic;
        smbus_therm_sw_to_fpga1_alert_l : in std_logic;
        -- Regulator and hotswap alerts
        i2c_sp_to_nic_sysmon_alert_l : in std_logic;
        main_hsc_to_fpga1_alert_l : in std_logic;
        smbus_ibc_to_fpga1_alert_l : in std_logic;
        smbus_m2_hsc_to_fpga1_alert_l : in std_logic;
        smbus_nic_hsc_to_fpga1_alert_l : in std_logic;
        smbus_v12_ddr5_abcdef_hsc_to_fpga1_alert : in std_logic;
        smbus_v12_ddr5_ghijkl_hsc_to_fpga1_alert : in std_logic;
        vr_v1p8_sys_to_fpga1_alert_l : in std_logic;
        vr_v3p3_sys_to_fpga1_alert_l : in std_logic;
        vr_v5p0_sys_to_fpga1_alert_l : in std_logic;
        -- I2C to the SP and SP5
        fpga1_to_i2c_mux1_sel : out std_logic_vector(1 downto 0);
        fpga1_to_i2c_mux2_sel : out std_logic_vector(1 downto 0);
        fpga1_to_i2c_mux3_sel : out std_logic_vector(1 downto 0);
        i2c_sp5_sec_v3p3_scl : inout std_logic;
        i2c_sp5_sec_v3p3_sda : inout std_logic;
        i2c_sp5_to_fpgax_hp_scl : inout std_logic;
        i2c_sp5_to_fpgax_hp_sda : inout std_logic;
        i2c_sp_to_fpga1_scl : inout std_logic;
        i2c_sp_to_fpga1_sda : inout std_logic;
        sp_to_fpga1_mux_reset_l : in std_logic;
        -- UARTs
        uart0_fpga1_to_sp5_dat_buff : out std_logic;
        uart0_fpga1_to_sp5_rts_l_buff : out std_logic;
        uart0_fpga1_to_sp_dat : out std_logic;
        uart0_fpga1_to_sp_rts_l : out std_logic;
        uart0_sp5_to_fpga1_dat : in std_logic;
        uart0_sp5_to_fpga1_int : in std_logic;
        uart0_sp5_to_fpga1_rts_l : in std_logic;
        uart0_sp_to_fpga1_dat : in std_logic;
        uart0_sp_to_fpga1_rts_l : in std_logic;
        uart1_fpga1_to_sp5_dat_buff : out std_logic;
        uart1_fpga1_to_sp_dat : out std_logic;
        uart1_fpga1_to_sp_rts_l : out std_logic;
        uart1_sp5_to_fpga1_dat : in std_logic;
        uart1_sp_to_fpga1_dat : in std_logic;
        uart1_sp_to_fpga1_rts_l : in std_logic;
        uart8_fpga1_to_sp_dat : out std_logic;
        uart8_sp_to_fpga1_dat : in std_logic;
        uart_debug_to_fpga1_dat : in std_logic;
        uart_debug_to_fpga1_rts_l : in std_logic;
        uart_fpga1_to_debug_dat : out std_logic;
        uart_fpga1_to_debug_rts_l : out std_logic;
        uart_local_fpga1_to_sp_dat : in std_logic;
        uart_local_fpga1_to_sp_rts_l : in std_logic;
        uart_local_sp_to_fpga1_dat : in std_logic;
        uart_local_sp_to_fpga1_rts_l : in std_logic;
        -- HDT debug mux
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
        -- Ignition, straps, spares and misc
        fpga1_debug_uart_buf_oe_en_l : out std_logic;
        fpga1_espi0_cs_l_buff_oe_en_l : out std_logic;
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
        fpga1_to_fpga2_io : out std_logic_vector(5 downto 0);
        fpga1_to_ign_trgt_fpga_creset : out std_logic;
        fpga1_to_jtag_mux_sel : out std_logic;
        fpga1_to_sp_int_l : in std_logic;
        fpga1_to_sp_irq_l : out std_logic_vector(6 downto 1);
        fpga1_to_sp_misc_a : in std_logic;
        fpga1_to_sp_misc_b : in std_logic;
        fpga1_to_sp_misc_c : in std_logic;
        fpga1_to_sp_misc_d : in std_logic;
        fpga1_to_sp_mux_ign_mux_sel : out std_logic;
        fpga1_uart0_buff_oe_en_l : out std_logic;
        fpga1_uart1_buff_oe_en_l : out std_logic;
        fpga1_version_id : in std_logic_vector(1 downto 0);
        sp5_to_fpga1_genint_l : out std_logic;
        seq_rev_id : in std_logic_vector(2 downto 0);
    );
end entity;

architecture rtl of metro_seq_top is

    signal clk_125m : std_logic;
    signal reset_125m : std_logic;
    signal clk_200m : std_logic;
    signal reset_200m : std_logic;
    signal reset_fmc : std_logic;
    alias fmc_clk : std_logic is fmc_sp_to_fpga1_clk;
    -- deskewed/phase-shifted FMC clock from the MMCM in board_support; the
    -- FMC domain runs on this, never on the raw pin
    signal fmc_clk_buf : std_logic;
    signal fmc_capture_clk_buf : std_logic;
    constant INFO_RESP_IDX : integer := 0;
    constant SPINOR_RESP_IDX: integer := 1;
    constant SEQ_RESP_IDX: integer := 2;
    constant SP_I2C_RESP_IDX: integer := 3;
    constant SP5_HP_RESP_IDX : integer := 4;
    constant SPD_PROXY_RESP_IDX : integer := 5;
    constant DBG_CTRL_RESP_IDX : integer := 6;
    constant ESPI_RESP_IDX: integer := 7;
    constant HASH_RESP_IDX : integer := 8;
    constant VERSAL_FLASH_RESP_IDX : integer := 9;
    constant VERSAL_FLASH_CTRL_RESP_IDX : integer := 10;
    constant ESPI1_RESP_IDX : integer := 11;

    constant config_array : axil_responder_cfg_array_t := 
        (INFO_RESP_IDX => resp_cfg(base_addr => x"00000000", addr_span_bits => 8), 
         SPINOR_RESP_IDX => resp_cfg(base_addr => x"00000100", addr_span_bits => 8),
         SEQ_RESP_IDX => resp_cfg(base_addr => x"00000200", addr_span_bits => 8),
         SP_I2C_RESP_IDX => resp_cfg(base_addr => x"00000300", addr_span_bits => 8),
         SP5_HP_RESP_IDX => resp_cfg(base_addr => x"00000400", addr_span_bits => 8),
         SPD_PROXY_RESP_IDX => resp_cfg(base_addr => x"00000500", addr_span_bits => 8),
         DBG_CTRL_RESP_IDX => resp_cfg(base_addr => x"00000600", addr_span_bits => 8),
         -- eSPI is the largest register file and the most distant block, and it
         -- owns the worst 125MHz path in the design, so give the fabric a cycle
         -- in each direction to get there and back.
         ESPI_RESP_IDX => resp_cfg(base_addr => x"00008000", addr_span_bits => 15, pipe_stages => 1),
         HASH_RESP_IDX => resp_cfg(base_addr => x"00000700", addr_span_bits => 8),
         VERSAL_FLASH_RESP_IDX => resp_cfg(base_addr => x"00000800", addr_span_bits => 8),
         VERSAL_FLASH_CTRL_RESP_IDX => resp_cfg(base_addr => x"00000900", addr_span_bits => 8),
         -- Second eSPI target, same size and same reasoning as the first.
         ESPI1_RESP_IDX => resp_cfg(base_addr => x"00010000", addr_span_bits => 15, pipe_stages => 1)
         );
    signal fmc_axi_if : axil26x32_pkg.axil_t;
    signal fabric_responders : axil32x32_pkg.axil_array_t(config_array'range);
    signal responders_8b : axil8x32_pkg.axil_array_t(config_array'range);
    signal responders_15b : axil15x32_pkg.axil_array_t(config_array'range);
    signal fmc_internal_data_out : std_logic_vector(15 downto 0);
    signal fmc_data_out_hiz: std_logic_vector(15 downto 0);

    signal spinor_io_o : std_logic_vector(3 downto 0);
    signal spinor_io_oe : std_logic_vector(3 downto 0);
    signal espi_io_o : std_logic_vector(3 downto 0);
    signal espi_io_oe : std_logic_vector(3 downto 0);
    signal espi1_io_o : std_logic_vector(3 downto 0);
    signal espi1_io_oe : std_logic_vector(3 downto 0);
    -- The eSPI1 wrapper's spi_nor drives the Versal flash pins directly and
    -- parks them unless the mux control block has the flash.
    signal versal_flash_bus_enable : std_logic;
    -- eSPI1 has no IPCC UART behind it; its peripheral channel is tied off.
    signal espi1_uart_from_axi_st : axi_st8_pkg.axi_st_t;
    signal espi1_uart_to_axi_st : axi_st8_pkg.axi_st_t;
    -- hash engine <-> spi_nor flash client port(s)
    -- One hash engine serves both flashes: the SP5 boot flash behind eSPI0
    -- and the Versal boot flash behind eSPI1.
    constant HASH_NUM_FLASHES : natural := 2;
    signal hash_flash_cmd_rdata : std_logic_vector(31 downto 0);
    signal hash_flash_cmd_rdack : std_logic_vector(HASH_NUM_FLASHES - 1 downto 0);
    signal hash_flash_cmd_rempty : std_logic_vector(HASH_NUM_FLASHES - 1 downto 0);
    signal hash_flash_rsp_wdata : std_logic_vector(HASH_NUM_FLASHES * 8 - 1 downto 0);
    signal hash_flash_rsp_write : std_logic_vector(HASH_NUM_FLASHES - 1 downto 0);

    signal ipcc_uart_from_espi_axi_st : axi_st8_pkg.axi_st_t;
    signal ipcc_uart_to_espi_axi_st : axi_st8_pkg.axi_st_t;
    signal a0_ok : std_logic;
    signal a0_idle : std_logic;
    signal ddr_bulk : ddr_bulk_power_t;
    signal sp5_group_a : group_a_power_t;
    signal sp5_group_b : group_b_power_t;
    signal sp5_group_c : group_c_power_t;
    signal versal_rails : versal_power_t;
    signal versal_boot : versal_boot_t;
    signal versal_pcie : versal_pcie_t;
    signal versal_held_in_reset : std_logic;
    signal flash_owned_by_seq : std_logic;
    signal versal_hash_req : std_logic;
    signal versal_hash_ack : std_logic;
    signal versal_hash_err : std_logic;
    signal sp5_seq_pins : sp5_seq_pins_t;
    signal early_power : early_power_t;
    signal sp_scl_o : std_logic;
    signal sp_scl_oe : std_logic;
    signal sp_sda_o : std_logic;
    signal sp_sda_oe : std_logic;
    signal sp5_scl_o : std_logic;
    signal sp5_scl_oe : std_logic;
    signal sp5_sda_o : std_logic;
    signal sp5_sda_oe : std_logic;

    signal sp5_versal_power_en : std_logic;
    signal sp5_versal_cha_perst_l : std_logic;
    signal sp5_versal_chb_perst_l : std_logic;
    signal sp5_versal_faulted : std_logic;
    signal vercel_flash_io_o : std_logic_vector(3 downto 0);
    signal vercel_flash_io_oe : std_logic_vector(3 downto 0);
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
    -- Metro's FPGA2 sends its hotplug interrupts straight to the SP
    -- (FPGA2_TO_SP_INT[1..3]), so unlike cosmo there is no FPGA2 IRQ arriving
    -- here to fold in.
    alias a0_ok_to_fpga2 : std_logic is fpga1_to_fpga2_io(2);
    signal uart_dbg_if : uart_dbg_t;
    signal allow_backplane_pcie_clk : std_logic;
    signal versal_dbg_pins : nic_debug_if;
    signal reg_alert_l_pins : seq_power_alert_pins_t;
    -- No T6 on this board; the shared sequencer's T6 ports are tied off to
    -- these and its T6 outputs left open.
    signal nic_rails_unused : nic_power_t := nic_power_absent;
    signal nic_seq_pins_unused : nic_seq_pins_t := nic_seq_pins_absent;
    signal dbg_pins_uart_out : std_logic;
    signal dbg_pins_uart_out_rts_l : std_logic;
    signal dbg_pins_uart_in : std_logic;
    signal dbg_pins_uart_in_rts_l : std_logic;
    signal uart_headder_fall_back_to_debug_pins : std_logic;
    signal sp_mux_reset_l_syncd : std_logic;

begin

    meta_sync_inst_mux_reset_l: entity work.meta_sync
     port map(
        async_input => sp_to_fpga1_mux_reset_l,
        clk => clk_125m,
        sycnd_output => sp_mux_reset_l_syncd
    );

    -- SP5 SEC I2C: pins are wired but nothing drives this bus yet.
    i2c_sp5_sec_v3p3_scl <= 'Z';
    i2c_sp5_sec_v3p3_sda <= 'Z';
    -- misc things tied:
    fpga1_to_fpga2_io(5 downto 3) <= (others => 'Z');
    fpga1_to_fpga2_io(1 downto 0) <= (others => 'Z');
    fpga1_to_sp5_sys_reset_l <= 'Z';  -- We don't use this in product, external PU.
    fpga1_to_sp_irq_l(6 downto 2) <= (others => '1');
    -- The JTAG mux stays pointed at the external header; the FPGA only takes it
    -- when someone deliberately drives this from a debug session.
    fpga1_to_jtag_mux_sel <= '0';
    -- Metro adds a buffer enable for the dedicated debug UART header alongside
    -- the two SP-facing ones.
    fpga1_debug_uart_buf_oe_en_l <= '0';
    -- The low half of the 3V3 spare header. Nothing drives these, and they go
    -- to a header someone may well jumper, so hold them off rather than leaving
    -- output ports undriven for the tools to resolve however they like.
    fpga1_spare_v3p3_0 <= 'Z';
    fpga1_spare_v3p3_1 <= 'Z';
    fpga1_spare_v3p3_2 <= 'Z';
    fpga1_spare_v3p3_3 <= 'Z';
    fpga1_to_bp_buff_output_en_l <= '0'; -- This buffer has to be enabled to see any BP PCIe signals
    -- Enable various buffers when we're in A0:
    fpga1_espi0_cs_l_buff_oe_en_l <= '0' when sp5_seq_pins.pwr_good else 'Z';
    fpga1_to_sp5_apml_xltr_en <= sp5_seq_pins.pwr_good;
    fpga1_to_m2_apml_xltr_en <= sp5_seq_pins.pwr_good;
    fpga1_uart0_buff_oe_en_l <= '0' when a0_ok else '1';
    fpga1_uart1_buff_oe_en_l <= '0' when a0_ok else '1'; -- not used but why not enable anyway?
    uart1_fpga1_to_sp5_dat_buff <= '1';  -- Make this idle generally, buffer protects from cross-drive
    
    i3c_sp5_to_fpga1_oe_l <= '0' when  sp5_seq_pins.pwr_good else '1';
    -- Metro does not carry the rev1 cosmo buffer bug, so the DIMM side can be
    -- enabled regardless of SP5 power state, which is what we actually want.
    i3c_fpga1_to_dimm_oe_l <= '0';

    ---------------------------------------------
    -- FMC to AXI Interface from the SP
    ---------------------------------------------
    stm32h7_fmc_target_inst: entity work.stm32h7_fmc_target
    port map(
       chip_reset => reset_fmc,
       fmc_clk => fmc_clk_buf,
       fmc_capture_clk => fmc_capture_clk_buf,
       a(24 downto 20) => "00000",
       a(19 downto 16) => fmc_sp_to_fpga1_a(19 downto 16),
       --a(23 downto 16) => fmc_sp_to_fpga1_a,
       addr_data_in => fmc_sp_to_fpga1_da,
       data_out => fmc_internal_data_out,
       data_out_hiz => fmc_data_out_hiz,
       ne(3 downto 1) => "111",
       ne(0) => fmc_sp_to_fpga1_cs_l,
       noe => fmc_sp_to_fpga1_oe_l,
       nwe => fmc_sp_to_fpga1_we_l,
       nl => fmc_sp_to_fpga1_adv_l,
       nwait => fmc_sp_to_fpga1_wait_l,
       timeout_count => open,
       contention_count => open,
       aclk => clk_125m,
       aresetn => not reset_125m,
       axi_if => fmc_axi_if
   );
    -- tristate control for the FMC data bus
    -- per-bit tristate, hiz already in OBUFT T polarity so each pin's T
    -- flop packs into its IOB with no inverter in between
    fmc_da_tris: for i in fmc_sp_to_fpga1_da'range generate
        fmc_sp_to_fpga1_da(i) <= 'Z' when fmc_data_out_hiz(i) = '1' else fmc_internal_data_out(i);
    end generate;

   -- Axi decode/interconnect
   axil_interconnect_inst: entity work.axil_interconnect
    generic map(
       config_array => config_array
   )
    port map(
       clk => clk_125m,
       reset => reset_125m,
       initiator => fmc_axi_if,
       responders => fabric_responders
   );

    -- Block that generates our clocks, resets and
    -- deals with core board-level functionality
    -- includes the common "info" block on the axi bus
    resize_axil(fabric_responders(INFO_RESP_IDX), responders_8b(INFO_RESP_IDX));
    board_support_inst: entity work.board_support
     port map(
        board_50mhz_clk => clk_50mhz_fpga1_1,
        sp_fmc_clk => fmc_clk,
        fmc_clk_buf => fmc_clk_buf,
        fmc_capture_clk_buf => fmc_capture_clk_buf,
        sp_system_reset_l => sp_to_fpga1_system_reset_l,
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        reset_fmc => reset_fmc,
        fpga1_status_led => fpga1_status_led,
        hubris_compat_ver => seq_rev_id,
        info_axi_if => responders_8b(INFO_RESP_IDX)
    );

    -- espi and flash interface block
    -- espi and spi-nor blocks manage their own synchronization.
    -- only a tiny portion of the espi design runs at 200MHz
    -- all the system interfaces run at 125MHz for common clocking
    resize_axil(fabric_responders(ESPI_RESP_IDX), responders_15b(ESPI_RESP_IDX));
    resize_axil(fabric_responders(SPINOR_RESP_IDX), responders_8b(SPINOR_RESP_IDX));
    resize_axil(fabric_responders(HASH_RESP_IDX), responders_8b(HASH_RESP_IDX));
    espi_spinor_ss: entity work.sp5_espi_flash_subsystem
     port map(
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        espi_axi_if => responders_15b(ESPI_RESP_IDX),
        espi_csn => espi0_sp5_to_fpga1_cs_l,
        espi_clk => espi0_sp5_to_fpga1_clk,
        espi_dat => espi0_sp5_to_fpga1_dat,
        espi_dat_o => espi_io_o,
        espi_dat_oe => espi_io_oe,
        response_csn => espi_resp_csn,  -- debugging with saleae if you have access
        ipcc_uart_from_espi => ipcc_uart_from_espi_axi_st,
        ipcc_uart_to_espi => ipcc_uart_to_espi_axi_st,
        spinor_axi_if => responders_8b(SPINOR_RESP_IDX),
        spi_nor_csn => spi_fpga1_to_flash_cs_l,
        spi_nor_clk => spi_fpga1_to_flash_clk,
        spi_nor_dat => spi_fpga1_to_flash_dat,
        spi_nor_dat_o => spinor_io_o,
        spi_nor_dat_oe => spinor_io_oe,
        hash_cmd_fifo_rdata => hash_flash_cmd_rdata,
        hash_cmd_fifo_rdack => hash_flash_cmd_rdack(0),
        hash_cmd_fifo_rempty => hash_flash_cmd_rempty(0),
        hash_data_fifo_wdata => hash_flash_rsp_wdata(7 downto 0),
        hash_data_fifo_write => hash_flash_rsp_write(0)
    );

    -- SHA3 hashing engine. It reads flash through spi_nor_top's second client
    -- port and owns the FIFOs on that path; it sits here rather than inside the
    -- eSPI wrapper so one engine can serve more than one flash.
    hash_engine_inst: entity work.hash_engine_top
     generic map(
        NUM_FLASHES => HASH_NUM_FLASHES,
        -- The sequencer's pre-boot measurement is of the Versal image, on
        -- the flash behind eSPI1.
        HW_FLASH_SEL => 1
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders_8b(HASH_RESP_IDX),
        hw_req => versal_hash_req,
        hw_ack => versal_hash_ack,
        hw_err => versal_hash_err,
        flash_cmd_rdata => hash_flash_cmd_rdata,
        flash_cmd_rdack => hash_flash_cmd_rdack,
        flash_cmd_rempty => hash_flash_cmd_rempty,
        flash_rsp_wdata => hash_flash_rsp_wdata,
        flash_rsp_write => hash_flash_rsp_write
    );
    -- Second eSPI target on the SP5's other eSPI port, fronting the Versal's
    -- boot flash. This is the one place the host may write flash over SAFS,
    -- which is how a Versal image gets loaded; the enable bit in its control
    -- register still has to be set by the SP. There is no IPCC UART behind
    -- this port, and no post codes either: the SP5 only writes those to
    -- eSPI0, so the buffer for them is left out.
    -- Its spi_nor runs at half the SP5 boot flash's rate, 125MHz
    -- / (2 * 2) = 31.25MHz: nothing here is on a boot path, the SP only
    -- reaches this flash while the Versal is held in reset, so there is no
    -- reason to run at the ceiling. The slower rate widens the read sample
    -- window from roughly 3.6..11.7ns to -4.4..19.7ns, which leaves
    -- rx_sample_taps = 2 (8ns) far from either edge instead of about 4ns
    -- clear of both. metro_timing.xdc carries the arithmetic.
    resize_axil(fabric_responders(ESPI1_RESP_IDX), responders_15b(ESPI1_RESP_IDX));
    resize_axil(fabric_responders(VERSAL_FLASH_RESP_IDX), responders_8b(VERSAL_FLASH_RESP_IDX));
    espi1_uart_from_axi_st.ready <= '1';
    espi1_uart_to_axi_st.valid <= '0';
    espi1_uart_to_axi_st.data <= (others => '0');
    espi1_versal_flash_ss: entity work.sp5_espi_flash_subsystem
     generic map(
        FLASH_WRITES_ALLOWED => true,
        POST_CODE_BUFFER_ENABLED => false,
        SPI_NOR_SCLK_DIVISOR => 1,
        SPI_NOR_RX_SAMPLE_TAPS => 2
     )
     port map(
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        espi_axi_if => responders_15b(ESPI1_RESP_IDX),
        espi_csn => espi1_sp5_to_fpga1_cs_l,
        espi_clk => espi1_sp5_to_fpga1_clk,
        espi_dat => espi1_sp5_to_fpga1_dat,
        espi_dat_o => espi1_io_o,
        espi_dat_oe => espi1_io_oe,
        response_csn => open,
        ipcc_uart_from_espi => espi1_uart_from_axi_st,
        ipcc_uart_to_espi => espi1_uart_to_axi_st,
        spinor_axi_if => responders_8b(VERSAL_FLASH_RESP_IDX),
        spi_nor_csn => qspi_fpga1_to_vercel_flash_mux_cs_l,
        spi_nor_clk => qspi_fpga1_to_vercel_flash_mux_sck,
        spi_nor_dat => qspi_fpga1_to_vercel_flash_mux_d,
        spi_nor_dat_o => vercel_flash_io_o,
        spi_nor_dat_oe => vercel_flash_io_oe,
        spi_nor_bus_enable => versal_flash_bus_enable,
        hash_cmd_fifo_rdata => hash_flash_cmd_rdata,
        hash_cmd_fifo_rdack => hash_flash_cmd_rdack(1),
        hash_cmd_fifo_rempty => hash_flash_cmd_rempty(1),
        hash_data_fifo_wdata => hash_flash_rsp_wdata(15 downto 8),
        hash_data_fifo_write => hash_flash_rsp_write(1)
    );

    --Tristates for spi-nor flash pins and espi
    spi_nor_espi_tris:process(all)
    begin
        for i in spi_fpga1_to_flash_dat'range loop
            spi_fpga1_to_flash_dat(i) <= spinor_io_o(i) when spinor_io_oe(i) = '1' else 'Z';
            espi0_sp5_to_fpga1_dat(i) <= espi_io_o(i) when espi_io_oe(i) = '1' else 'Z';
            espi1_sp5_to_fpga1_dat(i) <= espi1_io_o(i) when espi1_io_oe(i) = '1' else 'Z';
        end loop;
    end process;

    -- UART subsystem
    -- stuff externally synchronized inside the UART block(s)
    sp5_uart_ss: entity work.sp5_uart_subsystem
     port map(
        clk => clk_125m,
        reset => reset_125m,
        dbg_if => uart_dbg_if,
        in_a0 => a0_ok,
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
        dbg_pins_uart_out => dbg_pins_uart_out,
        dbg_pins_uart_out_rts_l => dbg_pins_uart_out_rts_l,
        dbg_pins_uart_in => dbg_pins_uart_in,
        dbg_pins_uart_in_rts_l => dbg_pins_uart_in_rts_l
    );

    -- Metro has a dedicated debug UART header, so there is no fallback onto the
    -- spare pins and no rev-conditional NIC power-good remap the way cosmo has.
    uart_fpga1_to_debug_dat <= dbg_pins_uart_out;
    dbg_pins_uart_in <= uart_debug_to_fpga1_dat;
    uart_fpga1_to_debug_rts_l <= dbg_pins_uart_in_rts_l;
    dbg_pins_uart_out_rts_l <= uart_debug_to_fpga1_rts_l;
    fpga1_spare_v3p3_6 <= 'Z';
    fpga1_spare_v3p3_7 <= 'Z';

    -- UART8 is a Metro addition: a fifth SP-facing UART, data only, with no
    -- flow control and no peer defined on the schematic. Park it until we know
    -- what it is meant to carry, rather than guessing at a mapping.
    uart8_fpga1_to_sp_dat <= '1';

    -- SP I2C muxes
    -- i2c is the only input, sycn'd inside the mux block(s)
    resize_axil(fabric_responders(SP_I2C_RESP_IDX), responders_8b(SP_I2C_RESP_IDX));
    sp_i2c_subsystem_inst: entity work.sp_i2c_subsystem
     port map(
        clk => clk_125m,
        reset => reset_125m,
        in_a0 => a0_ok,
        sp_mux_reset_l => sp_mux_reset_l_syncd,
        axi_if => responders_8b(SP_I2C_RESP_IDX),
        sp_scl => i2c_sp_to_fpga1_scl,
        sp_scl_o => sp_scl_o,
        sp_scl_oe => sp_scl_oe,
        sp_sda => i2c_sp_to_fpga1_sda,
        sp_sda_o => sp_sda_o,
        sp_sda_oe => sp_sda_oe,
        i2c_mux1_sel => fpga1_to_i2c_mux1_sel,
        i2c_mux2_sel => fpga1_to_i2c_mux2_sel,
        i2c_mux3_sel => fpga1_to_i2c_mux3_sel,
        -- cosmo drives an M.2 translator enable off mux1; metro's translator
        -- enable is tied to SP5 power good above, so leave this open.
        i2c_mux1_en => open
    );
    --Tristates for spi-nor flash pins and espi
    i2c_sp_to_fpga1_scl <= sp_scl_o when sp_scl_oe = '1' else 'Z';
    i2c_sp_to_fpga1_sda <= sp_sda_o when sp_sda_oe = '1' else 'Z';

    -- SP5 I2c hotplug expanders
    -- Inputs synchronized inside the block
    resize_axil(fabric_responders(SP5_HP_RESP_IDX), responders_8b(SP5_HP_RESP_IDX));
    sp5_hotplug_subsystem_inst: entity work.sp5_hotplug_subsystem
     generic map(
        NIC2_SLOT_ENABLED => true
     )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders_8b(SP5_HP_RESP_IDX),
        allow_backplane_pcie_clk => allow_backplane_pcie_clk,
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
        -- The Versal takes the slot the T6 has on cosmo for its channel A,
        -- and the otherwise unused fifth expander bank for channel B. Both
        -- are the one device, so both slots report the same fault; each has
        -- its own presence and its own PERST.
        t6_power_en => sp5_versal_power_en,
        t6_perst_l => sp5_versal_cha_perst_l,
        t6_faulted => sp5_versal_faulted,
        t6_prsnt_l => pcie_nic_to_fpga1_cha_prsnt_l,
        nic2_power_en => open,
        nic2_perst_l => sp5_versal_chb_perst_l,
        nic2_faulted => sp5_versal_faulted,
        nic2_prsnt_l => pcie_nic_to_fpga1_chb_prsnt_l,
        pcie_aux_rsw_perst_l => pcie_aux_fpga1_to_rsw_perst_l,
        pcie_aux_rsw_prsnt_buff_l => pcie_aux_rsw_to_fpga1_prsnt_buff_l,
        pcie_aux_rsw_pwrflt_buff_l=> pcie_aux_rsw_to_fpga1_pwrflt_buff_l,
        pcie_clk_buff_rsw_oe_l => fpga1_to_pcie_clk_buff_rsw_oe_l_int,
        rsw_sp5_pcie_attached_buff_l =>rsw_to_sp5_pcie_attached_buff_l
    );

    a0_ok_to_fpga2 <= a0_ok;  -- A0 OK signal to fpga2, used for power sequencing

    amd_hp_irq_n_final <= hp_int_n;
    sp5_to_fpga1_genint_l <= '0' when amd_hp_irq_n_final = '0' else 'Z';

    fpga1_to_pcie_clk_buff_rsw_oe_l <= '0' when fpga1_to_pcie_clk_buff_rsw_oe_l_int = '0' else 'Z';

    --Tristates for spi-nor flash pins and espi
    i2c_sp5_to_fpgax_hp_scl <= sp5_scl_o when sp5_scl_oe = '1' else 'Z';
    i2c_sp5_to_fpgax_hp_sda <= sp5_sda_o when sp5_sda_oe = '1' else 'Z';

    --Block that deals with sequencing the SP5 and nic etc
    -- inputs synchronized inside the block
    resize_axil(fabric_responders(SEQ_RESP_IDX), responders_8b(SEQ_RESP_IDX));
    seq: entity work.sp5_sequencer
     generic map(
        CNTS_P_MS => calc_ms(desired_ms => 1, clk_period_ns => 8),
        NIC_KIND => NIC_VERSAL
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders_8b(SEQ_RESP_IDX),
        a0_ok => a0_ok,
        a0_idle => a0_idle,
        irq_l_out => fpga1_to_sp_irq_l(1),
        allow_backplane_pcie_clk => allow_backplane_pcie_clk,
        early_power_pins => early_power,
        ddr_bulk_pins => ddr_bulk,
        group_a_pins => sp5_group_a,
        group_b_pins => sp5_group_b,
        group_c_pins => sp5_group_c,
        sp5_seq_pins => sp5_seq_pins,
        versal_rails_pins => versal_rails,
        versal_boot_pins => versal_boot,
        versal_pcie_pins => versal_pcie,
        nic_dbg_pins => versal_dbg_pins,
        nic_rails_pins => nic_rails_unused,
        nic_seq_pins => nic_seq_pins_unused,
        versal_held_in_reset => versal_held_in_reset,
        flash_owned_by_seq => flash_owned_by_seq,
        hash_req => versal_hash_req,
        hash_ack => versal_hash_ack,
        hash_err => versal_hash_err,
        version_id => fpga1_version_id,
        sp5_nic_perst_l => sp5_versal_cha_perst_l,
        sp5_nic_chb_perst_l => sp5_versal_chb_perst_l,
        sp5_nic_faulted => sp5_versal_faulted,
        ignition_mux_sel => fpga1_to_sp_mux_ign_mux_sel,
        ignition_creset => fpga1_to_ign_trgt_fpga_creset,
        reg_alert_l_pins => reg_alert_l_pins
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
    -- Versal rails. Every rail here has its own enable, unlike cosmo's T6
    -- where a single hotswap enable cascaded the lot.
    --
    -- The two hotswap power goods are active low at the pin, despite the port
    -- names, which follow cosmo_seq's. Pass them through raw: versal_sync is
    -- the single place that inverts them, exactly as seq_sync does on cosmo.
    -- Inverting here as well would double up and hand the sequencer the
    -- opposite of the truth.
    fpga1_to_nic_hsc_en <= versal_rails.hsc_12v.enable;
    versal_rails.hsc_12v.pg <= v12p0_nic_a0hp_pg;
    versal_rails.hsc_5v.pg <= v5p0_nic_a0hp_pg;
    v3p3_nic_a0hp_en <= versal_rails.v3p3.enable;
    versal_rails.v3p3.pg <= v3p3_nic_a0hp_pg;
    v1p8_nic_a0hp_en <= versal_rails.v1p8.enable;
    versal_rails.v1p8.pg <= v1p8_nic_a0hp_pg;
    v1p5_nic_a0hp_en <= versal_rails.v1p5.enable;
    versal_rails.v1p5.pg <= v1p5_nic_a0hp_pg;
    v1p5_nic_avccaux_a0hp_en <= versal_rails.v1p5_avccaux.enable;
    versal_rails.v1p5_avccaux.pg <= v1p5_nic_avccaux_a0hp_pg;
    v1p4_nic_a0hp_en <= versal_rails.v1p4.enable;
    -- There is no power-good pin for the 1V4 rail on this board, so mirror its
    -- enable the way cosmo does for its rev1 1V4.
    versal_rails.v1p4.pg <= versal_rails.v1p4.enable;
    v1p1_nic_a0hp_en <= versal_rails.v1p1.enable;
    -- Likewise no discrete 1V1 power good; it comes up with the aux group.
    versal_rails.v1p1.pg <= versal_rails.v1p1.enable;
    v0p88_nic_a0hp_en <= versal_rails.v0p88.enable;
    versal_rails.v0p88.pg <= v0p88_nic_a0hp_pg;
    v0p8_nic_vccint_a0hp_en <= versal_rails.v0p8_vccint.enable;
    versal_rails.v0p8_vccint.pg <= v0p8_nic_vccint_a0hp_pg;
    -- Transceiver rails: readback only, they cascade off the groups above.
    versal_rails.v0p92_avcc.pg <= v0p92_nic_avcc_a0hp_pg;
    versal_rails.v1p2_avtt.pg <= v1p2_nic_avtt_a0hp_pg;

    -- SP5 sequence-related pins
    sp5_seq_pins.thermtrip_l <= sp5_to_fpga1_thermtrip_l;
    sp5_seq_pins.smerr_l <= sp5_to_fpga1_smerr_l;
    sp5_seq_pins.reset_l <= fpga1_to_sp5_reset_l;
    sp5_seq_pins.pwr_ok <= sp5_to_fpga1_pwrok_unbuf;
    fpga1_to_sp5_pwr_btn_l <= '0' when sp5_seq_pins.pwr_btn_l = '0' else 'Z';
    sp5_seq_pins.slp_s3_l <= sp5_to_fpga1_slp_s3_l;
    sp5_seq_pins.slp_s5_l <= sp5_to_fpga1_slp_s5_l;
    fpga1_to_sp5_rsmrst_l <= sp5_seq_pins.rsmrst_l;
    -- Board-type strap the SP5 samples at power up. a1_a0_seq drives its
    -- is_cosmo output high here because it is cosmo's block; Metro is not
    -- cosmo, so hold the pin low and leave that output unread until Metro's own
    -- board-identity convention is settled with the SP5 firmware.
    sp5_to_fpga1_debug1 <= '0';
    fpga1_to_sp5_pwrgd <= sp5_seq_pins.pwr_good;

    -- Versal boot straps and status
    fpga1_to_versal_por_b <= versal_boot.por_b;
    fpga1_to_versal_mode <= versal_boot.mode;
    fpga1_to_versal_mode_buffer_en_l <= versal_boot.mode_buffer_en_l;
    fpga1_to_versal_erro_done_buff_en <= versal_boot.err_done_buff_en;
    versal_boot.done <= versal_to_fpga1_done;
    versal_boot.error_out <= versal_to_fpga1_error_out;

    -- Versal PCIe, two channels. The clock buffer output enables are open
    -- drain on this board, same as the M.2 and backplane ones.
    pcie_fpga1_to_nic_cha_perst_l <= versal_pcie.cha.perst_l;
    versal_pcie.cha.prsnt_l <= pcie_nic_to_fpga1_cha_prsnt_l;
    versal_pcie.cha.pwren_l <= pcie_nic_to_fpga1_cha_pwren_l;
    fpga1_to_pcie_clk_buff_nic_cha_oe_l <= '0' when versal_pcie.cha.clk_buff_oe_l = '0' else 'Z';
    pcie_fpga1_to_nic_chb_perst_l <= versal_pcie.chb.perst_l;
    versal_pcie.chb.prsnt_l <= pcie_nic_to_fpga1_chb_prsnt_l;
    versal_pcie.chb.pwren_l <= pcie_nic_to_fpga1_chb_pwren_l;
    fpga1_to_pcie_clk_buff_nic_chb_oe_l <= '0' when versal_pcie.chb.clk_buff_oe_l = '0' else 'Z';

    -- Versal boot flash mux on sheet 137. The controller behind it is the
    -- eSPI1 wrapper's spi_nor above; this block only gates its pins on the
    -- mux being granted, which needs the Versal held in reset.
    resize_axil(fabric_responders(VERSAL_FLASH_CTRL_RESP_IDX), responders_8b(VERSAL_FLASH_CTRL_RESP_IDX));
    versal_flash_ss: entity work.versal_flash_subsystem
     port map(
        clk => clk_125m,
        reset => reset_125m,
        ctrl_axi_if => responders_8b(VERSAL_FLASH_CTRL_RESP_IDX),
        versal_held_in_reset => versal_held_in_reset,
        flash_owned_by_seq => flash_owned_by_seq,
        flash_qspi_mux_sel => fpga1_to_vercel_flash_qspi_mux_sel,
        flash_qspi_mux_en_l => fpga1_to_vercel_flash_qspi_mux_en_l,
        flash_bus_enable => versal_flash_bus_enable
    );
    vercel_flash_tris: process(all)
    begin
        for i in qspi_fpga1_to_vercel_flash_mux_d'range loop
            qspi_fpga1_to_vercel_flash_mux_d(i) <=
                vercel_flash_io_o(i) when vercel_flash_io_oe(i) = '1' else 'Z';
        end loop;
    end process;

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

    
    reg_alert_l_pins.smbus_fan_central_hsc_to_fpga1_alert_l <= smbus_fan_central_hsc_to_fpga1_alert_l;
    reg_alert_l_pins.smbus_fan_east_hsc_to_fpga1_alert_l <= smbus_fan_east_hsc_to_fpga1_alert_l;
    reg_alert_l_pins.smbus_fan_west_hsc_to_fpga1_alert_l <= smbus_fan_west_hsc_to_fpga1_alert_l;
    reg_alert_l_pins.smbus_ibc_to_fpga1_alert_l <= smbus_ibc_to_fpga1_alert_l;
    reg_alert_l_pins.smbus_m2_hsc_to_fpga1_alert_l <= smbus_m2_hsc_to_fpga1_alert_l;
    reg_alert_l_pins.smbus_nic_hsc_to_fpga1_alert_l <= smbus_nic_hsc_to_fpga1_alert_l;
    reg_alert_l_pins.smbus_v12_ddr5_abcdef_hsc_to_fpga1_alert <= smbus_v12_ddr5_abcdef_hsc_to_fpga1_alert;
    reg_alert_l_pins.smbus_v12_ddr5_ghijkl_hsc_to_fpga1_alert <= smbus_v12_ddr5_ghijkl_hsc_to_fpga1_alert;
    -- cosmo-only alert pins, absent here
    reg_alert_l_pins.smbus_v12_mcio_a0hp_hsc_to_fpga1_alert_l <= '1';
    reg_alert_l_pins.v0p96_nic_to_fpga1_alert_l <= '1';
    reg_alert_l_pins.main_hsc_to_fpga1_alert_l <= main_hsc_to_fpga1_alert_l;
    reg_alert_l_pins.vr_v1p8_sys_to_fpga1_alert_l <= vr_v1p8_sys_to_fpga1_alert_l;
    reg_alert_l_pins.vr_v3p3_sys_to_fpga1_alert_l <= vr_v3p3_sys_to_fpga1_alert_l;
    reg_alert_l_pins.vr_v5p0_sys_to_fpga1_alert_l <= vr_v5p0_sys_to_fpga1_alert_l;
    reg_alert_l_pins.pwr_cont1_to_fpga1_alert_l <= pwr_cont1_to_fpga1_alert_l;
    reg_alert_l_pins.pwr_cont2_to_fpga1_alert_l <= pwr_cont2_to_fpga1_alert_l;
    reg_alert_l_pins.pwr_cont3_to_fpga1_alert_l <= pwr_cont3_to_fpga1_alert_l;
    reg_alert_l_pins.pwr_cont4_to_fpga1_alert_l <= pwr_cont4_to_fpga1_alert_l;

    resize_axil(fabric_responders(SPD_PROXY_RESP_IDX), responders_8b(SPD_PROXY_RESP_IDX));
    dimm_spd_proxy_top_inst: entity work.dimms_subsystem_top
     generic map(
        CLK_PER_NS => 8,
        I2C_MODE => FAST_PLUS
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders_8b(SPD_PROXY_RESP_IDX),
        in_a0 => a0_ok,
        dimm_a_pcamp => dimm_a_pg,
        dimm_b_pcamp => dimm_b_pg,
        dimm_c_pcamp => dimm_c_pg,
        dimm_d_pcamp => dimm_d_pg,
        dimm_e_pcamp => dimm_e_pg,
        dimm_f_pcamp => dimm_f_pg,
        dimm_g_pcamp => dimm_g_pg,
        dimm_h_pcamp => dimm_h_pg,
        dimm_i_pcamp => dimm_i_pg,
        dimm_j_pcamp => dimm_j_pg,
        dimm_k_pcamp => dimm_k_pg,
        dimm_l_pcamp => dimm_l_pg,
        cpu_scl_if0 => sp5_abcdef_scl_if,
        cpu_sda_if0 => sp5_abcdef_sda_if,
        cpu_scl_if1 => sp5_ghijkl_scl_if,
        cpu_sda_if1 => sp5_ghijkl_sda_if,
        dimm_scl_if0 => dimm_abcdef_scl_if,
        dimm_sda_if0 => dimm_abcdef_sda_if,
        dimm_scl_if1 => dimm_ghijkl_scl_if,
        dimm_sda_if1 => dimm_ghijkl_sda_if
    );

    resize_axil(fabric_responders(DBG_CTRL_RESP_IDX), responders_8b(DBG_CTRL_RESP_IDX));
    debug_module_top_inst: entity work.debug_module_top
     port map(
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders_8b(DBG_CTRL_RESP_IDX),
        in_a0 => a0_ok,
        -- Metro has no FPGA2 hotplug IRQ arriving here, so tie the tap idle.
        fpga2_hp_irq_n => '1',
        hp_int_n => hp_int_n,
        sp5_debug2_pin => sp5_to_fpga1_debug2,
        uart_headder_fall_back_to_debug_pins => uart_headder_fall_back_to_debug_pins,
        uart_dbg_if => uart_dbg_if,
         -- hotplug
        i2c_sp5_to_fpgax_hp_sda => i2c_sp5_to_fpgax_hp_sda,
        i2c_sp5_to_fpgax_hp_scl => i2c_sp5_to_fpgax_hp_scl,
        -- sp
        i2c_sp_to_fpga1_scl => i2c_sp_to_fpga1_scl,
        i2c_sp_to_fpga1_sda => i2c_sp_to_fpga1_sda,
        -- sp5 i2c
        i2c_sp5_sec_to_fpga1_scl => i2c_sp5_sec_v3p3_scl,
        i2c_sp5_sec_to_fpga1_sda => i2c_sp5_sec_v3p3_sda,
        -- dimms
        i3c_sp5_to_fpga1_abcdef_scl => i3c_sp5_to_fpga1_abcdef_scl,
        i3c_sp5_to_fpga1_abcdef_sda => i3c_sp5_to_fpga1_abcdef_sda,
        i3c_sp5_to_fpga1_ghijkl_scl => i3c_sp5_to_fpga1_ghijkl_scl,
        i3c_sp5_to_fpga1_ghijkl_sda => i3c_sp5_to_fpga1_ghijkl_sda,
        i3c_fpga1_to_dimm_abcdef_scl => i3c_fpga1_to_dimm_abcdef_scl,
        i3c_fpga1_to_dimm_abcdef_sda => i3c_fpga1_to_dimm_abcdef_sda,
        i3c_fpga1_to_dimm_ghijkl_scl => i3c_fpga1_to_dimm_ghijkl_scl,
        i3c_fpga1_to_dimm_ghijkl_sda => i3c_fpga1_to_dimm_ghijkl_sda,
        -- UARTs
        uart1_sp_to_fpga1_dat =>  uart1_sp_to_fpga1_dat,
        uart1_fpga1_to_sp_dat  =>  uart1_fpga1_to_sp_dat,
        uart0_sp_to_fpga1_dat =>  uart0_sp_to_fpga1_dat,
        uart0_fpga1_to_sp_dat  =>  uart0_fpga1_to_sp_dat,
        uart0_fpga1_to_sp5_dat  =>  uart0_fpga1_to_sp5_dat_buff,
        uart0_sp5_to_fpga1_dat  =>  uart0_sp5_to_fpga1_dat,
        -- ESPI signals
        espi0_sp5_to_fpga_clk => espi0_sp5_to_fpga1_clk,
        espi0_sp5_to_fpga_cs_l => espi0_sp5_to_fpga1_cs_l,
        espi0_sp5_to_fpga1_dat => espi0_sp5_to_fpga1_dat,
        espi_resp_csn => espi_resp_csn,
        nic_dbg_pins => versal_dbg_pins,
        -- MUX
        mux1_sel => fpga1_to_i2c_mux1_sel,
        mux2_sel => fpga1_to_i2c_mux2_sel,
        mux3_sel => fpga1_to_i2c_mux3_sel,

        fpga1_spare_v1p8 => fpga1_spare_v1p8
    );


end rtl;
