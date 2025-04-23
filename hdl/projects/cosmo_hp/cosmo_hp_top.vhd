-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Cosmo Ignition FPGA top targeting an ice40 HX8k


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.pca9506_pkg.all;
use work.axil_common_pkg.all;
use work.axilite_if_2k8_pkg.all;

entity cosmo_hp_top is
    port (
        clk_50mhz_fpga2: in std_logic;
        sp_to_fpga2_system_reset_l: in std_logic;
        -- CEM A
        cema_to_fpga2_alert_l : in std_logic;
        cema_to_fpga2_ifdet_l : in std_logic;
        cema_to_fpga2_pg_l : in std_logic;
        cema_to_fpga2_prsnt_l : in std_logic;
        cema_to_fpga2_pwrflt_l : in std_logic;
        cema_to_fpga2_sharkfin_present : in std_logic;
        fpga2_to_cema_attnled: out std_logic;
        fpga2_to_cema_perst_l : out std_logic;
        fpga2_to_cema_pwren : out std_logic;
        fpga2_to_clk_buff_cema_oe_l: out std_logic;
        -- CEM B
        cemb_to_fpga2_alert_l : in std_logic;
        cemb_to_fpga2_ifdet_l : in std_logic;
        cemb_to_fpga2_pg_l : in std_logic;
        cemb_to_fpga2_prsnt_l : in std_logic;
        cemb_to_fpga2_pwrflt_l : in std_logic;
        cemb_to_fpga2_sharkfin_present : in std_logic;
        fpga2_to_cemb_attnled: out std_logic;
        fpga2_to_cemb_perst_l : out std_logic;
        fpga2_to_cemb_pwren : out std_logic;
        fpga2_to_clk_buff_cemb_oe_l: out std_logic;
        -- CEM C
        cemc_to_fpga2_alert_l : in std_logic;
        cemc_to_fpga2_ifdet_l : in std_logic;
        cemc_to_fpga2_pg_l : in std_logic;
        cemc_to_fpga2_prsnt_l : in std_logic;
        cemc_to_fpga2_pwrflt_l : in std_logic;
        cemc_to_fpga2_sharkfin_present : in std_logic;
        fpga2_to_cemc_attnled: out std_logic;
        fpga2_to_cemc_perst_l : out std_logic;
        fpga2_to_cemc_pwren : out std_logic;
        fpga2_to_clk_buff_cemc_oe_l: out std_logic;
        -- CEM D
        cemd_to_fpga2_alert_l: in std_logic;
        cemd_to_fpga2_ifdet_l: in std_logic;
        cemd_to_fpga2_pg_l: in std_logic;
        cemd_to_fpga2_prsnt_l: in std_logic;
        cemd_to_fpga2_pwrflt_l: in std_logic;
        cemd_to_fpga2_sharkfin_present: in std_logic;
        fpga2_to_cemd_attnled: out std_logic;
        fpga2_to_cemd_perst_l: out std_logic;
        fpga2_to_cemd_pwren: out std_logic;
        fpga2_to_clk_buff_cemd_oe_l: out std_logic;
        -- CEM E
        ceme_to_fpga2_alert_l : in std_logic;
        ceme_to_fpga2_ifdet_l : in std_logic;
        ceme_to_fpga2_pg_l : in std_logic;
        ceme_to_fpga2_prsnt_l : in std_logic;
        ceme_to_fpga2_pwrflt_l : in std_logic;
        ceme_to_fpga2_sharkfin_present : in std_logic;
        fpga2_to_ceme_attnled: out std_logic;
        fpga2_to_ceme_perst_l : out std_logic;
        fpga2_to_ceme_pwren : out std_logic;
        fpga2_to_clk_buff_ceme_oe_l : out std_logic;
        -- CEM F
        cemf_to_fpga2_alert_l : in std_logic;
        cemf_to_fpga2_ifdet_l : in std_logic;
        cemf_to_fpga2_pg_l : in std_logic;
        cemf_to_fpga2_prsnt_l : in std_logic;
        cemf_to_fpga2_pwrflt_l : in std_logic;
        cemf_to_fpga2_sharkfin_present : in std_logic;
        fpga2_to_cemf_attnled: out std_logic;
        fpga2_to_cemf_perst_l : out std_logic;
        fpga2_to_cemf_pwren : out std_logic;
        fpga2_to_clk_buff_cemf_oe_l : out std_logic;
        -- CEM G
        cemg_to_fpga2_alert_l : in std_logic;
        cemg_to_fpga2_ifdet_l : in std_logic;
        cemg_to_fpga2_pg_l : in std_logic;
        cemg_to_fpga2_prsnt_l : in std_logic;
        cemg_to_fpga2_pwrflt_l : in std_logic;
        cemg_to_fpga2_sharkfin_present : in std_logic;
        fpga2_to_cemg_attnled: out std_logic;
        fpga2_to_cemg_perst_l : out std_logic;
        fpga2_to_cemg_pwren : out std_logic;
        fpga2_to_clk_buff_cemg_oe_l : out std_logic;
        -- CEM H
        cemh_to_fpga2_alert_l: in std_logic;
        cemh_to_fpga2_ifdet_l: in std_logic;
        cemh_to_fpga2_pg_l: in std_logic;
        cemh_to_fpga2_prsnt_l: in std_logic;
        cemh_to_fpga2_pwrflt_l: in std_logic;
        cemh_to_fpga2_sharkfin_present: in std_logic;
        fpga2_to_cemh_attnled: out std_logic;
        fpga2_to_cemh_perst_l: out std_logic;
        fpga2_to_cemh_pwren: out std_logic;
        fpga2_to_clk_buff_cemh_oe_l : out std_logic;
        -- CEM I
        cemi_to_fpga2_alert_l: in std_logic;
        cemi_to_fpga2_ifdet_l: in std_logic;
        cemi_to_fpga2_pg_l: in std_logic;
        cemi_to_fpga2_prsnt_l: in std_logic;
        cemi_to_fpga2_pwrflt_l: in std_logic;
        cemi_to_fpga2_sharkfin_present: in std_logic;
        fpga2_to_cemi_attnled: out std_logic;
        fpga2_to_cemi_perst_l: out std_logic;
        fpga2_to_cemi_pwren: out std_logic;
        fpga2_to_clk_buff_cemi_oe_l : out std_logic;
        -- CEM J
        cemj_to_fpga2_alert_l : in std_logic;
        cemj_to_fpga2_ifdet_l : in std_logic;
        cemj_to_fpga2_pg_l : in std_logic;
        cemj_to_fpga2_prsnt_l : in std_logic;
        cemj_to_fpga2_pwrflt_l : in std_logic;
        cemj_to_fpga2_sharkfin_present : in std_logic;
        fpga2_to_cemj_attnled: out std_logic;
        fpga2_to_cemj_perst_l : out std_logic;
        fpga2_to_cemj_pwren : out std_logic;
        fpga2_to_clk_buff_cemj_oe_l : out std_logic;
        -- CLK Buffer I/F
        clk_buff_cemabcd_to_fpga2_los_l: in std_logic;
        clk_buff_cemefg_to_fpga2_los_l : in std_logic;
        clk_buff_cemhij_to_fpga2_los_l : in std_logic;
        fpga2_to_clk_buff_mcio_oe_l : out std_logic;
        fpga2_to_clk_buff_ufl_oe_l : out std_logic;
        -- MCIO I/F
        v12_mcio_a0hp_pg: in std_logic;
        fpga2_to_mcio_perst_l: out std_logic;
        fpga2_to_mcio_prpe: in std_logic; -- TODO, confirm Hi-Z works with yosys + ghdl
        fpga2_to_v12_mcio_a0hp_hsc_en: out std_logic;
        -- FPGA1 I/F
        -- MSBs of bus are from fpga1
        fpga1_to_fpga2_io: in std_logic_vector(2 downto 0);
        fpga2_to_fpga1_io: out std_logic_vector(2 downto 0);
        -- FPGA misc I/O
        fpga2_spare_v3p3: out std_logic_vector(7 downto 0);
        fpga2_status_led: out std_logic;
        -- SP I/F
        fpga2_to_sp_int_l: in std_logic_vector(2 downto 0); -- 3..1 in sch
        smbus_sp_to_fpga2_smclk: inout std_logic;
        smbus_sp_to_fpga2_smdat: inout std_logic;
        spi_fpga2_to_sp_mux_dat: out std_logic;
        spi_sp_mux_to_fpga2_cs_l : in std_logic;
        spi_sp_mux_to_fpga2_dat : in std_logic;
        spi_sp_mux_to_fpga2_sck : in std_logic;
        uart_fpga2_to_sp_dat: in std_logic;
        uart_sp_to_fpga2_dat: in std_logic;
        -- I2C Muxes
        fpga2_to_i2c_mux4_sel: out std_logic_vector(1 downto 0);
        fpga2_to_i2c_mux5_sel: out std_logic_vector(1 downto 0);
        fpga2_to_i2c_mux6_sel: out std_logic_vector(1 downto 0);
        fpga2_to_i2c_mux7_sel: out std_logic_vector(1 downto 0);
        fpga2_to_i2c_mux8_sel: out std_logic_vector(1 downto 0);
        -- SP5 I/F
        i2c_sp5_to_fpga2_scl: inout std_logic;
        i2c_sp5_to_fpga2_sda: inout std_logic;
        i2c_sp5_to_fpga2_xltr_en: out std_logic;
        sp5_to_fpga_genint_3v3_l: out std_logic

    );
end entity;

architecture rtl of cosmo_hp_top is
    type io_i2c_addr_t is array (natural range <>) of std_logic_vector(6 downto 0);
    type mux_sel_t is array (natural range <>) of std_logic_vector(1 downto 0);
    constant io_i2c_addr:  io_i2c_addr_t(0 to 1) := (
        b"0100_000",  -- CEM A, B, C, D, E  I/O
        b"0100_001"   -- CEM F, G, H, I, J  I/O
    );
    constant mux_i2c_addr:  io_i2c_addr_t(0 to 4) := (
        b"1110_000",  -- Mux 4: CEMs A, B, C
        b"1110_001",  -- Mux 5: CEMS D, E, F
        b"1110_010",  -- Mux 6: MCIO1, MCIO2, CEM G
        b"1110_011",  -- Mux 7: CEM H, I, J
        b"1110_100"   -- Mux 8: Front Bus
    );

    signal mux_sel : mux_sel_t(mux_i2c_addr'range);
    -- hotplug breakout
    signal sp5_tgt_scl : std_logic_vector(1 downto 0);
    signal sp5_tgt_scl_o : std_logic_vector(1 downto 0);
    signal sp5_tgt_scl_oe : std_logic_vector(1 downto 0);
    signal sp5_tgt_sda : std_logic_vector(1 downto 0);
    signal sp5_tgt_sda_o : std_logic_vector(1 downto 0);
    signal sp5_tgt_sda_oe : std_logic_vector(1 downto 0);
    signal sp5_scl_o : std_logic;
    signal sp5_scl_oe: std_logic;
    signal sp5_sda_o : std_logic;
    signal sp5_sda_oe: std_logic;
    -- i2c mux breakout
    signal sp_tgt_scl : std_logic_vector(4 downto 0);
    signal sp_tgt_scl_o : std_logic_vector(4 downto 0);
    signal sp_tgt_scl_oe : std_logic_vector(4 downto 0);
    signal sp_tgt_sda : std_logic_vector(4 downto 0);
    signal sp_tgt_sda_o : std_logic_vector(4 downto 0);
    signal sp_tgt_sda_oe : std_logic_vector(4 downto 0);
    signal sp_scl_o : std_logic;
    signal sp_scl_oe: std_logic;
    signal sp_sda_o : std_logic;
    signal sp_sda_oe: std_logic;

    signal led_blink_cntr: unsigned(24 downto 0) := (others => '0');
    signal reset_50m: std_logic;
    alias clk_50m is clk_50mhz_fpga2;
    signal pca_io_o : multiple_pca9506_pin_t(io_i2c_addr'range);
    signal pca_io_oe : multiple_pca9506_pin_t(io_i2c_addr'range);
    signal pca_io : multiple_pca9506_pin_t(io_i2c_addr'range);
    signal pca_int_n : std_logic_vector(io_i2c_addr'length - 1 downto 0);

    constant config_array : axil_responder_cfg_array_t := 
    (0 => (base_addr => x"00000000", addr_span_bits => 8),
     1 => (base_addr => x"00000100", addr_span_bits => 8),
     2 => (base_addr => x"00000200", addr_span_bits => 8)
     );

    signal sp_write_address_addr : std_logic_vector(15 downto 0);
    signal sp_write_address_valid : std_logic;
    signal sp_write_address_ready : std_logic;
    signal sp_write_data_data : std_logic_vector(31 downto 0);
    signal sp_write_data_strb : std_logic_vector(3 downto 0);
    signal sp_write_data_ready : std_logic;
    signal sp_write_data_valid : std_logic;
    signal sp_write_response_valid : std_logic;
    signal sp_write_response_resp : std_logic_vector(1 downto 0);
    signal sp_write_response_ready : std_logic;
    signal sp_read_address_addr : std_logic_vector(15 downto 0);
    signal sp_read_address_ready : std_logic;
    signal sp_read_address_valid : std_logic;
    signal sp_read_data_valid : std_logic;
    signal sp_read_data_ready : std_logic;
    signal sp_read_data_resp : std_logic_vector(1 downto 0);
    signal sp_read_data_data : std_logic_vector(31 downto 0);

    signal responders_write_address_valid : std_logic_vector(config_array'range);
    signal responders_write_address_ready : std_logic_vector(config_array'range);
    signal responders_write_address_addr : tgt_addr8_t(config_array'range);
    signal responders_write_data_valid : std_logic_vector(config_array'range);
    signal responders_write_data_ready : std_logic_vector(config_array'range);
    signal responders_write_data_data : tgt_dat32_t(config_array'range);
    signal responders_write_data_strb : tgt_strb_t(config_array'range);
    signal responders_write_response_ready : std_logic_vector(config_array'range);
    signal responders_write_response_resp : tgt_resp_t(config_array'range);
    signal responders_write_response_valid : std_logic_vector(config_array'range);
    signal responders_read_address_valid : std_logic_vector(config_array'range);
    signal responders_read_address_addr : tgt_addr8_t(config_array'range);
    signal responders_read_address_ready : std_logic_vector(config_array'range);
    signal responders_read_data_ready : std_logic_vector(config_array'range);
    signal responders_read_data_resp : tgt_resp_t(config_array'range);
    signal responders_read_data_valid : std_logic_vector(config_array'range);
    signal responders_read_data_data :  tgt_dat32_t(config_array'range);
    signal fpga2_to_clk_buff_cema_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_cemb_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_cemc_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_cemd_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_ceme_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_cemf_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_cemg_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_cemh_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_cemi_oe_l_int : std_logic;
    signal fpga2_to_clk_buff_cemj_oe_l_int : std_logic;
    signal fpga2_to_cema_perst_l_int : std_logic;
    signal fpga2_to_cemb_perst_l_int : std_logic;
    signal fpga2_to_cemc_perst_l_int : std_logic;
    signal fpga2_to_cemd_perst_l_int : std_logic;
    signal fpga2_to_ceme_perst_l_int : std_logic;
    signal fpga2_to_cemf_perst_l_int : std_logic;
    signal fpga2_to_cemg_perst_l_int : std_logic;
    signal fpga2_to_cemh_perst_l_int : std_logic;
    signal fpga2_to_cemi_perst_l_int : std_logic;
    signal fpga2_to_cemj_perst_l_int : std_logic;
    alias in_a0_unsyncd is fpga1_to_fpga2_io(2);
    signal in_a0 : std_logic;
    alias amd_gen_int_l is fpga2_to_fpga1_io(2); -- goes to fpga1 which can do the alert generation
    signal amd_gen_int : std_logic;
    
begin

    fpga2_to_fpga1_io(1 downto 0) <= (others => 'Z');
    amd_gen_int_l <= amd_gen_int;  -- connect the alert generation to fpga1

    fpga2_spare_v3p3(7) <= amd_gen_int_l;
    fpga2_spare_v3p3(6) <= cema_to_fpga2_pg_l;
    fpga2_spare_v3p3(5) <= cema_to_fpga2_prsnt_l;
    fpga2_spare_v3p3(4) <= cema_to_fpga2_pwrflt_l;
    fpga2_spare_v3p3(2) <= cema_to_fpga2_sharkfin_present;

    sp5_to_fpga_genint_3v3_l <= 'Z';  -- Broken on rev1 due to U33's direction

    meta_sync_inst: entity work.meta_sync
     port map(
        async_input => in_a0_unsyncd,
        clk => clk_50m,
        sycnd_output => in_a0
    );

    -------------------------------------
    -- Basic Board support stuff
    -------------------------------------
    -- Reset synchronizer
    clk125m_sync: entity work.async_reset_bridge
     generic map(
        async_reset_active_level => '0'
    )
     port map(
        clk => clk_50m,
        reset_async => sp_to_fpga2_system_reset_l,
        reset_sync => reset_50m -- this is our synchronized reset now
    );

    -- Simple blinking LED based on a counter
    led_blink: process(clk_50m, reset_50m)
    begin
        if reset_50m then
            led_blink_cntr <= (others => '0');
        elsif rising_edge(clk_50m) then
            led_blink_cntr <= led_blink_cntr + 1;
        end if;
    end process;
    fpga2_status_led <= led_blink_cntr(led_blink_cntr'high);

    --------------------------------------
    -- Static pins for future use
    --------------------------------------
    -- placeholder mcio stuff
    fpga2_to_mcio_perst_l <= '0';
    fpga2_to_v12_mcio_a0hp_hsc_en <= '0';
    fpga2_to_clk_buff_mcio_oe_l <= 'Z';
    -- pin the ufl clock buffer off
    fpga2_to_clk_buff_ufl_oe_l <= 'Z';

    ---------------------------------------
    -- Hubris SPI interface
    ---------------------------------------
    spi_axi_controller_inst: entity work.spi_axi_controller
     port map(
        clk => clk_50m,
        reset => reset_50m,
        csn => spi_sp_mux_to_fpga2_cs_l,
        sclk => spi_sp_mux_to_fpga2_sck,
        copi => spi_sp_mux_to_fpga2_dat,
        cipo => spi_fpga2_to_sp_mux_dat,
        awvalid => sp_write_address_valid,
        awready => sp_write_address_ready,
        awaddr => sp_write_address_addr,
        wvalid => sp_write_data_valid,
        wready => sp_write_data_ready,
        wdata => sp_write_data_data,
        wstrb => sp_write_data_strb,
        bvalid => sp_write_response_valid,
        bready => sp_write_response_ready,
        bresp => sp_write_response_resp,
        arvalid => sp_read_address_valid,
        arready => sp_read_address_ready,
        araddr => sp_read_address_addr,
        rvalid => sp_read_data_valid,
        rready => sp_read_data_ready,
        rdata => sp_read_data_data,
        rresp => sp_read_data_resp
    );

    -- AXI fabric block
axil_interconnect_2k8_inst: entity work.axil_interconnect_2k8
 generic map(
    initiator_addr_width => 16,
    config_array => config_array
)
 port map(
    clk => clk_50m,
    reset => reset_50m,
    initiator_write_address_addr => sp_write_address_addr,
    initiator_write_address_valid => sp_write_address_valid,
    initiator_write_address_ready => sp_write_address_ready,
    initiator_write_data_data => sp_write_data_data,
    initiator_write_data_strb => sp_write_data_strb,
    initiator_write_data_ready => sp_write_data_ready,
    initiator_write_data_valid => sp_write_data_valid,
    initiator_write_response_valid => sp_write_response_valid,
    initiator_write_response_resp => sp_write_response_resp,
    initiator_write_response_ready => sp_write_response_ready,
    initiator_read_address_addr => sp_read_address_addr,
    initiator_read_address_ready => sp_read_address_ready,
    initiator_read_address_valid => sp_read_address_valid,
    initiator_read_data_valid => sp_read_data_valid,
    initiator_read_data_ready => sp_read_data_ready,
    initiator_read_data_resp => sp_read_data_resp,
    initiator_read_data_data => sp_read_data_data,
    responders_write_address_valid => responders_write_address_valid,
    responders_write_address_ready => responders_write_address_ready,
    responders_write_address_addr => responders_write_address_addr,
    responders_write_data_valid => responders_write_data_valid,
    responders_write_data_ready => responders_write_data_ready,
    responders_write_data_data => responders_write_data_data,
    responders_write_data_strb => responders_write_data_strb,
    responders_write_response_ready => responders_write_response_ready,
    responders_write_response_resp => responders_write_response_resp,
    responders_write_response_valid => responders_write_response_valid,
    responders_read_address_valid => responders_read_address_valid,
    responders_read_address_addr => responders_read_address_addr,
    responders_read_address_ready => responders_read_address_ready,
    responders_read_data_ready => responders_read_data_ready,
    responders_read_data_resp => responders_read_data_resp,
    responders_read_data_valid => responders_read_data_valid,
    responders_read_data_data => responders_read_data_data
);
    --Info block
    info_2k8_inst: entity work.info_2k8
     generic map(
        hubris_compat_num_bits => 3
    )
     port map(
        clk => clk_50m,
        reset => reset_50m,
        hubris_compat_pins => "000",
        awvalid => responders_write_address_valid(0),
        awready => responders_write_address_ready(0),
        awaddr => responders_write_address_addr(0),
        wvalid => responders_write_data_valid(0),
        wready => responders_write_data_ready(0),
        wdata => responders_write_data_data(0),
        wstrb => responders_write_data_strb(0),
        bvalid => responders_write_response_valid(0),
        bready => responders_write_response_ready(0),
        bresp => responders_write_response_resp(0),
        arvalid => responders_read_address_valid(0),
        arready => responders_read_address_ready(0),
        araddr => responders_read_address_addr(0),
        rvalid => responders_read_data_valid(0),
        rready => responders_read_data_ready(0),
        rdata => responders_read_data_data(0),
        rresp => responders_read_data_resp(0)
    );
    -------------------------------------
    -- SP5 I2C STUFF
    -------------------------------------
    -- i2c breakout phy consolidator for sp5 hotplug
    sp5_i2c_phy_consolidator_inst: entity work.i2c_phy_consolidator
     generic map(
        TARGET_NUM => 2
    )
     port map(
        clk => clk_50m,
        reset => reset_50m,
        scl => i2c_sp5_to_fpga2_scl,
        scl_o => sp5_scl_o,
        scl_oe => sp5_scl_oe,
        sda => i2c_sp5_to_fpga2_sda,
        sda_o => sp5_sda_o,
        sda_oe => sp5_sda_oe,
        tgt_scl => sp5_tgt_scl,
        tgt_scl_o => sp5_tgt_scl_o,
        tgt_scl_oe => sp5_tgt_scl_oe,
        tgt_sda => sp5_tgt_sda,
        tgt_sda_o => sp5_tgt_sda_o,
        tgt_sda_oe => sp5_tgt_sda_oe
    );
    -- tri-state muxes, top level
    i2c_sp5_to_fpga2_scl <= sp5_scl_o when sp5_scl_oe = '1' else 'Z';
    i2c_sp5_to_fpga2_sda <= sp5_sda_o when sp5_sda_oe = '1' else 'Z';
    i2c_sp5_to_fpga2_xltr_en <= '1'; -- Pin the level translator on, it should manage hotplug itself
    
    -- Need qty 2 I/O expanders
    io_gen: for i in io_i2c_addr'range generate
        pca9506_top_inst: entity work.pca9506_top
         generic map(
            i2c_addr => io_i2c_addr(i)
        )
         port map(
            clk => clk_50m,
            reset => reset_50m,
            inband_reset => not in_a0,
            scl => sp5_tgt_scl(i),
            scl_o => sp5_tgt_scl_o(i),
            scl_oe => sp5_tgt_scl_oe(i),
            sda => sp5_tgt_sda(i),
            sda_o => sp5_tgt_sda_o(i),
            sda_oe => sp5_tgt_sda_oe(i),
            io => pca_io(i),
            io_oe => pca_io_oe(i),
            io_o => pca_io_o(i),
            int_n => pca_int_n(i),
            awvalid => responders_write_address_valid(i+1),
            awready => responders_write_address_ready(i+1),
            awaddr => responders_write_address_addr(i+1),
            wvalid => responders_write_data_valid(i+1),
            wready => responders_write_data_ready(i+1),
            wdata => responders_write_data_data(i+1),
            wstrb => responders_write_data_strb(i+1),
            bvalid => responders_write_response_valid(i+1),
            bready => responders_write_response_ready(i+1),
            bresp => responders_write_response_resp(i+1),
            arvalid => responders_read_address_valid(i+1),
            arready => responders_read_address_ready(i+1),
            araddr => responders_read_address_addr(i+1),
            rvalid => responders_read_data_valid(i+1),
            rready => responders_read_data_ready(i+1),
            rdata => responders_read_data_data(i+1),
            rresp => responders_read_data_resp(i+1)

        );
    end generate;

    amd_gen_int <= and pca_int_n;  -- bitwise, assert any time any of the irqs is low
    -------------------------------------
    -- SP I2C STUFF
    -------------------------------------
    -- i2c breakout phy consolidator for sp i2c muxes
    sp_i2c_phy_consolidator_inst: entity work.i2c_phy_consolidator
     generic map(
        TARGET_NUM => 5
    )
     port map(
        clk => clk_50m,
        reset => reset_50m,
        scl => smbus_sp_to_fpga2_smclk,
        scl_o => sp_scl_o,
        scl_oe => sp_scl_oe,
        sda => smbus_sp_to_fpga2_smdat,
        sda_o => sp_sda_o,
        sda_oe => sp_sda_oe,
        tgt_scl => sp_tgt_scl,
        tgt_scl_o => sp_tgt_scl_o,
        tgt_scl_oe => sp_tgt_scl_oe,
        tgt_sda => sp_tgt_sda,
        tgt_sda_o => sp_tgt_sda_o,
        tgt_sda_oe => sp_tgt_sda_oe
    );

    -- tri-state muxes, top level
    smbus_sp_to_fpga2_smclk <= sp_scl_o when sp_scl_oe = '1' else 'Z';
    smbus_sp_to_fpga2_smdat <= sp_sda_o when sp_sda_oe = '1' else 'Z';

    -- 5 muxes here
    mux_gen: for i in mux_i2c_addr'range generate
        pca9545ish_top_inst: entity work.pca9545ish_top
         generic map(
            i2c_addr => mux_i2c_addr(i)
        )
         port map(
            clk => clk_50m,
            reset => reset_50m,
            mux_reset => '0',
            allowed_to_enable => '1', -- TODO: fix this up later with exclusive logic
            scl => sp_tgt_scl(i),
            scl_o => sp_tgt_scl_o(i),
            scl_oe => sp_tgt_scl_oe(i),
            sda => sp_tgt_sda(i),
            sda_o => sp_tgt_sda_o(i),
            sda_oe => sp_tgt_sda_oe(i),
            mux_sel => mux_sel(i)
        );
    end generate;

    -- assign out the mux selects from the vector to the pins
    fpga2_to_i2c_mux4_sel <= mux_sel(0);
    fpga2_to_i2c_mux5_sel <= mux_sel(1);
    fpga2_to_i2c_mux6_sel <= mux_sel(2);
    fpga2_to_i2c_mux7_sel <= mux_sel(3);
    fpga2_to_i2c_mux8_sel <= mux_sel(4);

    -------------------------------------
    -- Hotplug CEM stuff
    -------------------------------------
    fpga2_to_clk_buff_cema_oe_l <= '0' when fpga2_to_clk_buff_cema_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_cemb_oe_l <= '0' when fpga2_to_clk_buff_cemb_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_cemc_oe_l <= '0' when fpga2_to_clk_buff_cemc_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_cemd_oe_l <= '0' when fpga2_to_clk_buff_cemd_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_ceme_oe_l <= '0' when fpga2_to_clk_buff_ceme_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_cemf_oe_l <= '0' when fpga2_to_clk_buff_cemf_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_cemg_oe_l <= '0' when fpga2_to_clk_buff_cemg_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_cemh_oe_l <= '0' when fpga2_to_clk_buff_cemh_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_cemi_oe_l <= '0' when fpga2_to_clk_buff_cemi_oe_l_int = '0' else 'Z';
    fpga2_to_clk_buff_cemj_oe_l <= '0' when fpga2_to_clk_buff_cemj_oe_l_int = '0' else 'Z';

    fpga2_to_cema_perst_l <= '0' when fpga2_to_cema_perst_l_int = '0' else 'Z';
    fpga2_to_cemb_perst_l <= '0' when fpga2_to_cemb_perst_l_int = '0' else 'Z';
    fpga2_to_cemc_perst_l <= '0' when fpga2_to_cemc_perst_l_int = '0' else 'Z';
    fpga2_to_cemd_perst_l <= '0' when fpga2_to_cemd_perst_l_int = '0' else 'Z';
    fpga2_to_ceme_perst_l <= '0' when fpga2_to_ceme_perst_l_int = '0' else 'Z';
    fpga2_to_cemf_perst_l <= '0' when fpga2_to_cemf_perst_l_int = '0' else 'Z';
    fpga2_to_cemg_perst_l <= '0' when fpga2_to_cemg_perst_l_int = '0' else 'Z';
    fpga2_to_cemh_perst_l <= '0' when fpga2_to_cemh_perst_l_int = '0' else 'Z';
    fpga2_to_cemi_perst_l <= '0' when fpga2_to_cemi_perst_l_int = '0' else 'Z';
    fpga2_to_cemj_perst_l <= '0' when fpga2_to_cemj_perst_l_int = '0' else 'Z';
        -- CEM sync logic etc
    hp_subsystem_top_inst: entity work.hp_subsystem_top
     port map(
        clk => clk_50m,
        reset => reset_50m,
        cema_to_fpga2_alert_l => cema_to_fpga2_alert_l,
        cema_to_fpga2_ifdet_l => cema_to_fpga2_ifdet_l,
        cema_to_fpga2_pg_l => cema_to_fpga2_pg_l,
        cema_to_fpga2_prsnt_l => cema_to_fpga2_prsnt_l,
        cema_to_fpga2_pwrflt_l => cema_to_fpga2_pwrflt_l,
        cema_to_fpga2_sharkfin_present => cema_to_fpga2_sharkfin_present,
        fpga2_to_cema_attnled => fpga2_to_cema_attnled,
        fpga2_to_cema_perst_l => fpga2_to_cema_perst_l_int,
        fpga2_to_cema_pwren => fpga2_to_cema_pwren,
        fpga2_to_clk_buff_cema_oe_l => fpga2_to_clk_buff_cema_oe_l_int,
        cemb_to_fpga2_alert_l => cemb_to_fpga2_alert_l,
        cemb_to_fpga2_ifdet_l => cemb_to_fpga2_ifdet_l,
        cemb_to_fpga2_pg_l => cemb_to_fpga2_pg_l,
        cemb_to_fpga2_prsnt_l => cemb_to_fpga2_prsnt_l,
        cemb_to_fpga2_pwrflt_l => cemb_to_fpga2_pwrflt_l,
        cemb_to_fpga2_sharkfin_present => cemb_to_fpga2_sharkfin_present,
        fpga2_to_cemb_attnled => fpga2_to_cemb_attnled,
        fpga2_to_cemb_perst_l => fpga2_to_cemb_perst_l_int,
        fpga2_to_cemb_pwren => fpga2_to_cemb_pwren,
        fpga2_to_clk_buff_cemb_oe_l => fpga2_to_clk_buff_cemb_oe_l_int,
        cemc_to_fpga2_alert_l => cemc_to_fpga2_alert_l,
        cemc_to_fpga2_ifdet_l => cemc_to_fpga2_ifdet_l,
        cemc_to_fpga2_pg_l => cemc_to_fpga2_pg_l,
        cemc_to_fpga2_prsnt_l => cemc_to_fpga2_prsnt_l,
        cemc_to_fpga2_pwrflt_l => cemc_to_fpga2_pwrflt_l,
        cemc_to_fpga2_sharkfin_present => cemc_to_fpga2_sharkfin_present,
        fpga2_to_cemc_attnled => fpga2_to_cemc_attnled,
        fpga2_to_cemc_perst_l => fpga2_to_cemc_perst_l_int,
        fpga2_to_cemc_pwren => fpga2_to_cemc_pwren,
        fpga2_to_clk_buff_cemc_oe_l => fpga2_to_clk_buff_cemc_oe_l_int,
        cemd_to_fpga2_alert_l => cemd_to_fpga2_alert_l,
        cemd_to_fpga2_ifdet_l => cemd_to_fpga2_ifdet_l,
        cemd_to_fpga2_pg_l => cemd_to_fpga2_pg_l,
        cemd_to_fpga2_prsnt_l => cemd_to_fpga2_prsnt_l,
        cemd_to_fpga2_pwrflt_l => cemd_to_fpga2_pwrflt_l,
        cemd_to_fpga2_sharkfin_present => cemd_to_fpga2_sharkfin_present,
        fpga2_to_cemd_attnled => fpga2_to_cemd_attnled,
        fpga2_to_cemd_perst_l => fpga2_to_cemd_perst_l_int,
        fpga2_to_cemd_pwren => fpga2_to_cemd_pwren,
        fpga2_to_clk_buff_cemd_oe_l => fpga2_to_clk_buff_cemd_oe_l_int,
        ceme_to_fpga2_alert_l => ceme_to_fpga2_alert_l,
        ceme_to_fpga2_ifdet_l => ceme_to_fpga2_ifdet_l,
        ceme_to_fpga2_pg_l => ceme_to_fpga2_pg_l,
        ceme_to_fpga2_prsnt_l => ceme_to_fpga2_prsnt_l,
        ceme_to_fpga2_pwrflt_l => ceme_to_fpga2_pwrflt_l,
        ceme_to_fpga2_sharkfin_present => ceme_to_fpga2_sharkfin_present,
        fpga2_to_ceme_attnled => fpga2_to_ceme_attnled,
        fpga2_to_ceme_perst_l => fpga2_to_ceme_perst_l_int,
        fpga2_to_ceme_pwren => fpga2_to_ceme_pwren,
        fpga2_to_clk_buff_ceme_oe_l => fpga2_to_clk_buff_ceme_oe_l_int,
        cemf_to_fpga2_alert_l => cemf_to_fpga2_alert_l,
        cemf_to_fpga2_ifdet_l => cemf_to_fpga2_ifdet_l,
        cemf_to_fpga2_pg_l => cemf_to_fpga2_pg_l,
        cemf_to_fpga2_prsnt_l => cemf_to_fpga2_prsnt_l,
        cemf_to_fpga2_pwrflt_l => cemf_to_fpga2_pwrflt_l,
        cemf_to_fpga2_sharkfin_present => cemf_to_fpga2_sharkfin_present,
        fpga2_to_cemf_attnled => fpga2_to_cemf_attnled,
        fpga2_to_cemf_perst_l => fpga2_to_cemf_perst_l_int,
        fpga2_to_cemf_pwren => fpga2_to_cemf_pwren,
        fpga2_to_clk_buff_cemf_oe_l => fpga2_to_clk_buff_cemf_oe_l_int,
        cemg_to_fpga2_alert_l => cemg_to_fpga2_alert_l,
        cemg_to_fpga2_ifdet_l => cemg_to_fpga2_ifdet_l,
        cemg_to_fpga2_pg_l => cemg_to_fpga2_pg_l,
        cemg_to_fpga2_prsnt_l => cemg_to_fpga2_prsnt_l,
        cemg_to_fpga2_pwrflt_l => cemg_to_fpga2_pwrflt_l,
        cemg_to_fpga2_sharkfin_present => cemg_to_fpga2_sharkfin_present,
        fpga2_to_cemg_attnled => fpga2_to_cemg_attnled,
        fpga2_to_cemg_perst_l => fpga2_to_cemg_perst_l_int,
        fpga2_to_cemg_pwren => fpga2_to_cemg_pwren,
        fpga2_to_clk_buff_cemg_oe_l => fpga2_to_clk_buff_cemg_oe_l_int,
        cemh_to_fpga2_alert_l => cemh_to_fpga2_alert_l,
        cemh_to_fpga2_ifdet_l => cemh_to_fpga2_ifdet_l,
        cemh_to_fpga2_pg_l => cemh_to_fpga2_pg_l,
        cemh_to_fpga2_prsnt_l => cemh_to_fpga2_prsnt_l,
        cemh_to_fpga2_pwrflt_l => cemh_to_fpga2_pwrflt_l,
        cemh_to_fpga2_sharkfin_present => cemh_to_fpga2_sharkfin_present,
        fpga2_to_cemh_attnled => fpga2_to_cemh_attnled,
        fpga2_to_cemh_perst_l => fpga2_to_cemh_perst_l_int,
        fpga2_to_cemh_pwren => fpga2_to_cemh_pwren,
        fpga2_to_clk_buff_cemh_oe_l => fpga2_to_clk_buff_cemh_oe_l_int,
        cemi_to_fpga2_alert_l => cemi_to_fpga2_alert_l,
        cemi_to_fpga2_ifdet_l => cemi_to_fpga2_ifdet_l,
        cemi_to_fpga2_pg_l => cemi_to_fpga2_pg_l,
        cemi_to_fpga2_prsnt_l => cemi_to_fpga2_prsnt_l,
        cemi_to_fpga2_pwrflt_l => cemi_to_fpga2_pwrflt_l,
        cemi_to_fpga2_sharkfin_present => cemi_to_fpga2_sharkfin_present,
        fpga2_to_cemi_attnled => fpga2_to_cemi_attnled,
        fpga2_to_cemi_perst_l => fpga2_to_cemi_perst_l_int,
        fpga2_to_cemi_pwren => fpga2_to_cemi_pwren,
        fpga2_to_clk_buff_cemi_oe_l => fpga2_to_clk_buff_cemi_oe_l_int,
        cemj_to_fpga2_alert_l => cemj_to_fpga2_alert_l,
        cemj_to_fpga2_ifdet_l => cemj_to_fpga2_ifdet_l,
        cemj_to_fpga2_pg_l => cemj_to_fpga2_pg_l,
        cemj_to_fpga2_prsnt_l => cemj_to_fpga2_prsnt_l,
        cemj_to_fpga2_pwrflt_l => cemj_to_fpga2_pwrflt_l,
        cemj_to_fpga2_sharkfin_present => cemj_to_fpga2_sharkfin_present,
        fpga2_to_cemj_attnled => fpga2_to_cemj_attnled,
        fpga2_to_cemj_perst_l => fpga2_to_cemj_perst_l_int,
        fpga2_to_cemj_pwren => fpga2_to_cemj_pwren,
        fpga2_to_clk_buff_cemj_oe_l => fpga2_to_clk_buff_cemj_oe_l_int,
        io => pca_io,
        io_o => pca_io_o,
        io_oe => pca_io_oe
    );

end rtl;