-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Cosmo Front Hot-plug FPGA targeting an ice40 HX8k


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.cem_hp_io_pkg.all;
use work.pca9506_pkg.all;

entity hp_subsystem_top is
    port (
        clk : in std_logic;
        reset : in std_logic;

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
        -- I/O expander
        io : out multiple_pca9506_pin_t(0 to 1);
        io_o : in multiple_pca9506_pin_t(0 to 1);
        io_oe : in multiple_pca9506_pin_t(0 to 1)
    );
end entity;

architecture rtl of hp_subsystem_top is
    signal from_cem_pre_sync : from_cem_t;
    signal from_cem_syncd : from_cem_t;

    signal to_cem : to_cem_t;
    signal cem_perst_l : std_logic_vector(9 downto 0);
    signal cem_clk_en_l: std_logic_vector(9 downto 0);

    signal from_sp5 : from_sp5_io_t;
    signal to_sp5 : to_sp5_io_t;
    constant FIVE_MS : integer := 250000; -- 5ms for the duty cycle timer
    signal duty_cycle : integer := 0; -- Duty cycle for the PWM, 0-100%
    signal pwm_cntr : unsigned(7 downto 0); -- Counter for the PWM
    signal cem_led_pwm : std_logic := '0'; -- PWM output for the CEM LED
    signal dc_timer: unsigned(31 downto 0) := (others => '0'); -- Timer for the duty cycle

    

begin
    -- CEMA inputs
    from_cem_pre_sync(0).alert_l <= cema_to_fpga2_alert_l;
    from_cem_pre_sync(0).ifdet_l <= cema_to_fpga2_ifdet_l;
    from_cem_pre_sync(0).pg_l <= cema_to_fpga2_pg_l;
    from_cem_pre_sync(0).prsnt_l <= cema_to_fpga2_prsnt_l;
    from_cem_pre_sync(0).pwrflt_l <= cema_to_fpga2_pwrflt_l;
    from_cem_pre_sync(0).sharkfin_present <= cema_to_fpga2_sharkfin_present;
    -- CEMB inputs
    from_cem_pre_sync(1).alert_l <= cemb_to_fpga2_alert_l;
    from_cem_pre_sync(1).ifdet_l <= cemb_to_fpga2_ifdet_l;
    from_cem_pre_sync(1).pg_l <= cemb_to_fpga2_pg_l;
    from_cem_pre_sync(1).prsnt_l <= cemb_to_fpga2_prsnt_l;
    from_cem_pre_sync(1).pwrflt_l <= cemb_to_fpga2_pwrflt_l;
    from_cem_pre_sync(1).sharkfin_present <= cemb_to_fpga2_sharkfin_present;
    -- CEMC inputs
    from_cem_pre_sync(2).alert_l <= cemc_to_fpga2_alert_l;
    from_cem_pre_sync(2).ifdet_l <= cemc_to_fpga2_ifdet_l;
    from_cem_pre_sync(2).pg_l <= cemc_to_fpga2_pg_l;
    from_cem_pre_sync(2).prsnt_l <= cemc_to_fpga2_prsnt_l;
    from_cem_pre_sync(2).pwrflt_l <= cemc_to_fpga2_pwrflt_l;
    from_cem_pre_sync(2).sharkfin_present <= cemc_to_fpga2_sharkfin_present;
    -- CEMD inputs
    from_cem_pre_sync(3).alert_l <= cemd_to_fpga2_alert_l;
    from_cem_pre_sync(3).ifdet_l <= cemd_to_fpga2_ifdet_l;
    from_cem_pre_sync(3).pg_l <= cemd_to_fpga2_pg_l;
    from_cem_pre_sync(3).prsnt_l <= cemd_to_fpga2_prsnt_l;
    from_cem_pre_sync(3).pwrflt_l <= cemd_to_fpga2_pwrflt_l;
    from_cem_pre_sync(3).sharkfin_present <= cemd_to_fpga2_sharkfin_present;
    -- CEME inputs
    from_cem_pre_sync(4).alert_l <= ceme_to_fpga2_alert_l;
    from_cem_pre_sync(4).ifdet_l <= ceme_to_fpga2_ifdet_l;
    from_cem_pre_sync(4).pg_l <= ceme_to_fpga2_pg_l;
    from_cem_pre_sync(4).prsnt_l <= ceme_to_fpga2_prsnt_l;
    from_cem_pre_sync(4).pwrflt_l <= ceme_to_fpga2_pwrflt_l;
    from_cem_pre_sync(4).sharkfin_present <= ceme_to_fpga2_sharkfin_present;
    -- CEMF inputs
    from_cem_pre_sync(5).alert_l <= cemf_to_fpga2_alert_l;
    from_cem_pre_sync(5).ifdet_l <= cemf_to_fpga2_ifdet_l;
    from_cem_pre_sync(5).pg_l <= cemf_to_fpga2_pg_l;
    from_cem_pre_sync(5).prsnt_l <= cemf_to_fpga2_prsnt_l;
    from_cem_pre_sync(5).pwrflt_l <= cemf_to_fpga2_pwrflt_l;
    from_cem_pre_sync(5).sharkfin_present <= cemf_to_fpga2_sharkfin_present;
    -- CEMG inputs
    from_cem_pre_sync(6).alert_l <= cemg_to_fpga2_alert_l;
    from_cem_pre_sync(6).ifdet_l <= cemg_to_fpga2_ifdet_l;
    from_cem_pre_sync(6).pg_l <= cemg_to_fpga2_pg_l;
    from_cem_pre_sync(6).prsnt_l <= cemg_to_fpga2_prsnt_l;
    from_cem_pre_sync(6).pwrflt_l <= cemg_to_fpga2_pwrflt_l;
    from_cem_pre_sync(6).sharkfin_present <= cemg_to_fpga2_sharkfin_present;
    -- CEMH inputs
    from_cem_pre_sync(7).alert_l <= cemh_to_fpga2_alert_l;
    from_cem_pre_sync(7).ifdet_l <= cemh_to_fpga2_ifdet_l;
    from_cem_pre_sync(7).pg_l <= cemh_to_fpga2_pg_l;
    from_cem_pre_sync(7).prsnt_l <= cemh_to_fpga2_prsnt_l;
    from_cem_pre_sync(7).pwrflt_l <= cemh_to_fpga2_pwrflt_l;
    from_cem_pre_sync(7).sharkfin_present <= cemh_to_fpga2_sharkfin_present; 
    -- CEMI inputs
    from_cem_pre_sync(8).alert_l <= cemi_to_fpga2_alert_l;
    from_cem_pre_sync(8).ifdet_l <= cemi_to_fpga2_ifdet_l;
    from_cem_pre_sync(8).pg_l <= cemi_to_fpga2_pg_l;
    from_cem_pre_sync(8).prsnt_l <= cemi_to_fpga2_prsnt_l;
    from_cem_pre_sync(8).pwrflt_l <= cemi_to_fpga2_pwrflt_l;
    from_cem_pre_sync(8).sharkfin_present <= cemi_to_fpga2_sharkfin_present;
    -- CEMJ inputs
    from_cem_pre_sync(9).alert_l <= cemj_to_fpga2_alert_l;
    from_cem_pre_sync(9).ifdet_l <= cemj_to_fpga2_ifdet_l;
    from_cem_pre_sync(9).pg_l <= cemj_to_fpga2_pg_l;
    from_cem_pre_sync(9).prsnt_l <= cemj_to_fpga2_prsnt_l;
    from_cem_pre_sync(9).pwrflt_l <= cemj_to_fpga2_pwrflt_l;
    from_cem_pre_sync(9).sharkfin_present <= cemj_to_fpga2_sharkfin_present;

    -- Deal with I/O expander here
    pca_gen: for i in io'range generate -- outer 0 to 1 loop for each pca
        port_gen: for j in pca9506_pin_t'range generate -- inner 0 to 4 loop for each port
            -- A (0) = 0,0
            -- B (1) = 0,1
            -- C (2) = 0,2
            -- D (3) = 0,3
            -- E (4) = 0,4
            -- F (5) = 1,0
            -- G (6) = 1,1
            -- H (7) = 1,2
            -- I (8) = 1,3
            -- J (9) = 1,4


            io(i)(j) <= to_sp5_io(to_sp5(5*i + j));
            from_sp5(5*i + j) <= from_sp5_io(io_o(i)(j), io_oe(i)(j));
        end generate;
    end generate;

    -- Now build the sync blocks
    cem_sync_inst: entity work.cem_sync
     port map(
        clk => clk,
        from_cem => from_cem_pre_sync,
        from_cem_syncd => from_cem_syncd
    );

    pwm: process(clk, reset)
    begin
        if reset = '1' then
            -- Reset the sync'd signals
            duty_cycle <= 0; -- reset the duty cycle
            pwm_cntr <= (others => '0'); -- reset the counter
            cem_led_pwm <= '0'; -- default to 0 when reset
            dc_timer <= (others => '0');
        elsif rising_edge(clk) then
            if pwm_cntr < 99 then
                -- Increment the counter until we reach 100, this is our sync period
                pwm_cntr <= pwm_cntr + 1;
            else
                -- Reset the counter after 100 cycles, this allows us to sync every 100 cycles
                pwm_cntr <= (others => '0');
            end if;
            if pwm_cntr < duty_cycle then
                -- If the counter is less than the duty cycle, assert the pwm signal
                cem_led_pwm <= '1';
            else
                -- Otherwise, deassert the pwm signal
                cem_led_pwm <= '0';
            end if;

            -- Want 100 steps of duty cycle over 0.5s so 5 ms/tick
            if dc_timer < FIVE_MS and to_cem(0).pwren ='1'  then
                -- Increment the timer until we reach 5ms
                dc_timer <= dc_timer + 1;
            else
               if duty_cycle < 100 then
                    -- Increase the duty cycle by 1 until we reach 100%
                    duty_cycle <= duty_cycle + 1;
                end if;
                -- Reset the timer after reaching 5ms
                dc_timer <= (others => '0');
            end if;

            if to_cem(0).pwren = '0' then
                -- If the first CEM's power is off, reset the duty cycle to 0
                -- to avoid PWM when not powered
                duty_cycle <= 0;
            end if;


 
        end if;
    end process pwm;

    -- Put the per-cem logic here and loop it
    cem_logic_gen: for i in from_cem_syncd'range generate
        cem_logic_inst: entity work.hp_logic
         port map(
            clk => clk,
            reset => reset,
            cem_led_pwm => '1',
            cem_led_force => '0',
            from_cem => from_cem_syncd(i),
            to_cem => to_cem(i),
            cem_perst_l => cem_perst_l(i),
            cem_clk_en_l => cem_clk_en_l(i),
            from_sp5 => from_sp5(i),  -- bring I/O in from i/o expander
            to_sp5 => to_sp5(i)-- send I/O out to i/o expander
        );
    end generate;

    -- CEMA outputs
    fpga2_to_cema_attnled <= to_cem(0).attnled;
    fpga2_to_cema_perst_l <= cem_perst_l(0);
    fpga2_to_cema_pwren <= to_cem(0).pwren;
    fpga2_to_clk_buff_cema_oe_l <=cem_clk_en_l(0);
    -- CEMB outputs
    fpga2_to_cemb_attnled <= to_cem(1).attnled;
    fpga2_to_cemb_perst_l <= cem_perst_l(1);
    fpga2_to_cemb_pwren <= to_cem(1).pwren;
    fpga2_to_clk_buff_cemb_oe_l <=cem_clk_en_l(1);
    -- CEMC outputs
    fpga2_to_cemc_attnled <= to_cem(2).attnled;
    fpga2_to_cemc_perst_l <= cem_perst_l(2);
    fpga2_to_cemc_pwren <= to_cem(2).pwren;
    fpga2_to_clk_buff_cemc_oe_l <=cem_clk_en_l(2);
    -- CEMD outputs
    fpga2_to_cemd_attnled <= to_cem(3).attnled;
    fpga2_to_cemd_perst_l <= cem_perst_l(3);
    fpga2_to_cemd_pwren <= to_cem(3).pwren;
    fpga2_to_clk_buff_cemd_oe_l <=cem_clk_en_l(3);
    -- CEME outputs
    fpga2_to_ceme_attnled <= to_cem(4).attnled;
    fpga2_to_ceme_perst_l <= cem_perst_l(4);
    fpga2_to_ceme_pwren <= to_cem(4).pwren;
    fpga2_to_clk_buff_ceme_oe_l <=cem_clk_en_l(4);
    -- CEMF outputs
    fpga2_to_cemf_attnled <= to_cem(5).attnled;
    fpga2_to_cemf_perst_l <= cem_perst_l(5);
    fpga2_to_cemf_pwren <= to_cem(5).pwren;
    fpga2_to_clk_buff_cemf_oe_l <=cem_clk_en_l(5);
    -- CEMG outputs
    fpga2_to_cemg_attnled <= to_cem(6).attnled;
    fpga2_to_cemg_perst_l <= cem_perst_l(6);
    fpga2_to_cemg_pwren <= to_cem(6).pwren;
    fpga2_to_clk_buff_cemg_oe_l <=cem_clk_en_l(6);
    -- CEMH outputs
    fpga2_to_cemh_attnled <= to_cem(7).attnled;
    fpga2_to_cemh_perst_l <= cem_perst_l(7);
    fpga2_to_cemh_pwren <= to_cem(7).pwren;
    fpga2_to_clk_buff_cemh_oe_l <=cem_clk_en_l(7);
    -- CEMI outputs
    fpga2_to_cemi_attnled <= to_cem(8).attnled;
    fpga2_to_cemi_perst_l <= cem_perst_l(8);
    fpga2_to_cemi_pwren <= to_cem(8).pwren;
    fpga2_to_clk_buff_cemi_oe_l <=cem_clk_en_l(8);
    -- CEMJ outputs
    fpga2_to_cemj_attnled <= to_cem(9).attnled;
    fpga2_to_cemj_perst_l <= cem_perst_l(9);
    fpga2_to_cemj_pwren <= to_cem(9).pwren;
    fpga2_to_clk_buff_cemj_oe_l <=cem_clk_en_l(9);

end rtl;