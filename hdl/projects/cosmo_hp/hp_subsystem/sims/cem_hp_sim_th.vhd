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

    use work.cem_hp_io_pkg.all;
    use work.cem_sim_pkg.all;
    use work.cem_hp_io_pkg.all;
    use work.pca9506_pkg.all;

entity cem_hp_sim_th is
end entity;

architecture th of cem_hp_sim_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal fpga_to_cem : fpga_to_cem_io_t;
    signal cem_to_fpga : cem_to_fpga_io_t;
    signal fpga_to_hp : fpga_to_hp_io_t;
    signal hp_to_fpga : hp_to_fpga_io_t;
    signal cem_perst_l : std_logic;
    signal cem_clk_en_l : std_logic;    
    signal pca_io_o : multiple_pca9506_pin_t(0 to 1);
    signal pca_io_oe : multiple_pca9506_pin_t(0 to 1);
    signal pca_io : multiple_pca9506_pin_t(0 to 1);
    signal cema_to_fpga2_alert_l : std_logic := '1';
    signal cema_to_fpga2_ifdet_l : std_logic := '0';
    signal cema_to_fpga2_pg_l : std_logic;
    signal cema_to_fpga2_prsnt_l : std_logic := '0';
    signal cema_to_fpga2_pwrflt_l : std_logic := '1';
    signal cema_to_fpga2_sharkfin_present : std_logic := '1';
    signal fpga2_to_cema_attnled : std_logic;
    signal fpga2_to_cema_perst_l : std_logic;
    signal fpga2_to_cema_pwren : std_logic;
    signal fpga2_to_clk_buff_cema_oe_l : std_logic;


begin

    -- set up a fastish clock for the sim env
    -- and release reset after a bit of time
    clk   <= not clk after 10 ns;
    reset <= '0' after 200 ns;

  mdl : entity work.cem_model
    port map (
        clk => clk,
        reset => reset,
        cem_to_fpga => cem_to_fpga,  -- not used in this test
        fpga_to_cem => fpga_to_cem,  -- not used in this test
        fpga_to_hp => fpga_to_hp,
        hp_to_fpga => hp_to_fpga  
    );
    

  dut: entity work.hp_logic
    port map (
        clk => clk,
        reset => reset,
        cem_led_pwm => '0',
        cem_led_force => '0',  
        from_cem => cem_to_fpga,
        to_cem => fpga_to_cem,
        cem_perst_l => cem_perst_l, 
        cem_clk_en_l => cem_clk_en_l, 
        from_sp5 => hp_to_fpga,  
        to_sp5 => fpga_to_hp 
    );

    cema_to_fpga2_pg_l <= not fpga2_to_cema_pwren;  -- power good is driven by the FPGA
    hp_subsystem_top_inst: entity work.hp_subsystem_top
     port map(
        clk => clk,
        reset => reset,
        awvalid => '0',
        awready => open,
        awaddr => (others => '0'),
        -- write data channel
        wvalid => '0',
        wready => open,
        wdata => (others => '0'),
        wstrb => (others => '0'),
        -- write response channel
        bvalid => open,
        bready => '0',
        bresp => open,
        -- read address channel
        arvalid => '0',
        arready => open,
        araddr => (others => '0'),
        -- read data channel
        rvalid => open,
        rready => '0',
        rdata => open,
        rresp => open,
        cema_to_fpga2_alert_l => cema_to_fpga2_alert_l,
        cema_to_fpga2_ifdet_l => cema_to_fpga2_ifdet_l,
        cema_to_fpga2_pg_l => cema_to_fpga2_pg_l,
        cema_to_fpga2_prsnt_l => cema_to_fpga2_prsnt_l,
        cema_to_fpga2_pwrflt_l => cema_to_fpga2_pwrflt_l,
        cema_to_fpga2_sharkfin_present => cema_to_fpga2_sharkfin_present,
        fpga2_to_cema_attnled => fpga2_to_cema_attnled,
        fpga2_to_cema_perst_l => fpga2_to_cema_perst_l,
        fpga2_to_cema_pwren => fpga2_to_cema_pwren,
        fpga2_to_clk_buff_cema_oe_l => fpga2_to_clk_buff_cema_oe_l,
        cemb_to_fpga2_alert_l => '1',
        cemb_to_fpga2_ifdet_l => '1',
        cemb_to_fpga2_pg_l => '1',
        cemb_to_fpga2_prsnt_l => '1',
        cemb_to_fpga2_pwrflt_l => '1',
        cemb_to_fpga2_sharkfin_present => '0',
        fpga2_to_cemb_attnled => open,
        fpga2_to_cemb_perst_l => open,
        fpga2_to_cemb_pwren => open,
        fpga2_to_clk_buff_cemb_oe_l => open,
        cemc_to_fpga2_alert_l => '1',
        cemc_to_fpga2_ifdet_l => '1',
        cemc_to_fpga2_pg_l => '1',
        cemc_to_fpga2_prsnt_l => '1',
        cemc_to_fpga2_pwrflt_l => '1',
        cemc_to_fpga2_sharkfin_present => '0',
        fpga2_to_cemc_attnled => open,
        fpga2_to_cemc_perst_l => open,
        fpga2_to_cemc_pwren => open,
        fpga2_to_clk_buff_cemc_oe_l => open,
        cemd_to_fpga2_alert_l => '1',
        cemd_to_fpga2_ifdet_l => '1',
        cemd_to_fpga2_pg_l => '1',
        cemd_to_fpga2_prsnt_l => '1',
        cemd_to_fpga2_pwrflt_l => '1',
        cemd_to_fpga2_sharkfin_present => '0',
        fpga2_to_cemd_attnled => open,
        fpga2_to_cemd_perst_l => open,
        fpga2_to_cemd_pwren => open,
        fpga2_to_clk_buff_cemd_oe_l => open,
        ceme_to_fpga2_alert_l => '1',
        ceme_to_fpga2_ifdet_l => '1',
        ceme_to_fpga2_pg_l => '1',
        ceme_to_fpga2_prsnt_l => '1',
        ceme_to_fpga2_pwrflt_l => '1',
        ceme_to_fpga2_sharkfin_present => '0',
        fpga2_to_ceme_attnled => open,
        fpga2_to_ceme_perst_l => open,
        fpga2_to_ceme_pwren => open,
        fpga2_to_clk_buff_ceme_oe_l => open,
        cemf_to_fpga2_alert_l => '1',
        cemf_to_fpga2_ifdet_l => '1',
        cemf_to_fpga2_pg_l => '1',
        cemf_to_fpga2_prsnt_l => '1',
        cemf_to_fpga2_pwrflt_l => '1',
        cemf_to_fpga2_sharkfin_present => '0',
        fpga2_to_cemf_attnled => open,
        fpga2_to_cemf_perst_l => open,
        fpga2_to_cemf_pwren => open,
        fpga2_to_clk_buff_cemf_oe_l => open,
        cemg_to_fpga2_alert_l => '1',
        cemg_to_fpga2_ifdet_l => '1',
        cemg_to_fpga2_pg_l => '1',
        cemg_to_fpga2_prsnt_l => '1',
        cemg_to_fpga2_pwrflt_l => '1',
        cemg_to_fpga2_sharkfin_present => '0',
        fpga2_to_cemg_attnled => open,
        fpga2_to_cemg_perst_l => open,
        fpga2_to_cemg_pwren => open,
        fpga2_to_clk_buff_cemg_oe_l => open,
        cemh_to_fpga2_alert_l => '1',
        cemh_to_fpga2_ifdet_l => '1',
        cemh_to_fpga2_pg_l => '1',
        cemh_to_fpga2_prsnt_l => '1',
        cemh_to_fpga2_pwrflt_l => '1',
        cemh_to_fpga2_sharkfin_present => '0',
        fpga2_to_cemh_attnled => open,
        fpga2_to_cemh_perst_l => open,
        fpga2_to_cemh_pwren => open,
        fpga2_to_clk_buff_cemh_oe_l => open,
        cemi_to_fpga2_alert_l => '1',
        cemi_to_fpga2_ifdet_l => '1',
        cemi_to_fpga2_pg_l => '1',
        cemi_to_fpga2_prsnt_l => '1',
        cemi_to_fpga2_pwrflt_l => '1',
        cemi_to_fpga2_sharkfin_present => '0',
        fpga2_to_cemi_attnled => open,
        fpga2_to_cemi_perst_l => open,
        fpga2_to_cemi_pwren => open,
        fpga2_to_clk_buff_cemi_oe_l => open,
        cemj_to_fpga2_alert_l => '1',
        cemj_to_fpga2_ifdet_l => '1',
        cemj_to_fpga2_pg_l => '1',
        cemj_to_fpga2_prsnt_l => '1',
        cemj_to_fpga2_pwrflt_l => '1',
        cemj_to_fpga2_sharkfin_present => '0',
        fpga2_to_cemj_attnled => open,
        fpga2_to_cemj_perst_l => open,
        fpga2_to_cemj_pwren => open,
        fpga2_to_clk_buff_cemj_oe_l => open,
        io => pca_io,
        io_o => pca_io_o,
        io_oe => pca_io_oe
    );

  
end th;