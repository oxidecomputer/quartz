-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Cosmo Front Hot-plug FPGA targeting an ice40 HX8k
-- Pin names snapshot from 20Nov2024


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

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
        -- CLK Buffer I/F
        clk_buff_cemabcd_to_fpga2_los_l: in std_logic;
        clk_buff_cemefg_to_fpga2_los_l : in std_logic;
        clk_buff_cemhij_to_fpga2_los_l : in std_logic;
        fpga2_to_clk_buff_cema_oe_l: out std_logic;
        fpga2_to_clk_buff_cemb_oe_l: out std_logic;
        fpga2_to_clk_buff_cemc_oe_l: out std_logic;
        fpga2_to_clk_buff_cemd_oe_l: out std_logic;
        fpga2_to_clk_buff_ceme_oe_l : out std_logic;
        fpga2_to_clk_buff_cemf_oe_l : out std_logic;
        fpga2_to_clk_buff_cemg_oe_l : out std_logic;
        fpga2_to_clk_buff_cemh_oe_l : out std_logic;
        fpga2_to_clk_buff_cemi_oe_l : out std_logic;
        fpga2_to_clk_buff_cemj_oe_l : out std_logic;
        fpga2_to_clk_buff_mcio_oe_l : out std_logic;
        fpga2_to_clk_buff_ufl_oe_l : out std_logic;
        -- MCIO I/F
        v12_mcio_a0hp_pg: in std_logic;
        fpga2_to_mcio_perst_l: out std_logic;
        fpga2_to_mcio_prpe: out std_logic;
        fpga2_to_v12_mcio_a0hp_hsc_en: out std_logic;
        -- FPGA1 I/F
        fpga1_to_fpga2_io: in std_logic_vector(5 downto 0); 
        -- FPGA misc I/O
        fpga2_spare_v3p3: in std_logic_vector(7 downto 0);
        fpga2_status_led: out std_logic;
        -- SP I/F
        fpga2_to_sp_int_l: in std_logic_vector(2 downto 0); -- 3..1 in sch
        smbus_sp_to_fpga2_smclk: inout std_logic;
        smbus_sp_to_fpga2_smdat: inout std_logic;
        spi_fpga2_to_sp_mux_dat: in std_logic;
        spi_sp_mux_to_fpga2_cs_l : in std_logic;
        spi_sp_mux_to_fpga2_dat : in std_logic;
        spi_sp_mux_to_fpga2_sck : in std_logic;
        uart_fpga2_to_sp_dat: in std_logic;
        uart_sp_to_fpga2_dat: in std_logic;
        -- I2C Muxes
        fpga2_to_i2c_mux4_sel: in std_logic_vector(1 downto 0);
        fpga2_to_i2c_mux5_sel: in std_logic_vector(1 downto 0);
        fpga2_to_i2c_mux6_sel: in std_logic_vector(1 downto 0);
        fpga2_to_i2c_mux7_sel: in std_logic_vector(1 downto 0);
        fpga2_to_i2c_mux8_sel: in std_logic_vector(1 downto 0);
        -- SP5 I/F
        i2c_sp5_to_fpga2_scl: inout std_logic;
        i2c_sp5_to_fpga2_sda: inout std_logic;
        i2c_sp5_to_fpga2_xltr_en: in std_logic;
        sp5_to_fpga_genint_3v3_l: in std_logic

    );
end entity;

architecture rtl of cosmo_hp_top is

begin

end rtl;