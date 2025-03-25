-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Cosmo Front Hot-plug FPGA targeting an ice40 HX8k


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity cosmo_ignition_top is
    port (
        clk_50mhz_ign_trgt_fpga : in std_logic;
        ign_trgt_fpga_design_reset_l : in std_logic;
        ign_trgt_fpga_debug_led : out std_logic_vector(3 downto 0);
        ign_trgt_fpga_spare_v3p3 : out std_logic_vector(7 downto 0);
        ign_trgt_id : in std_logic_vector(7 downto 0);
        ign_trgt_fpga_lvds_status_led_en_l : out std_logic;
        ign_trgt_fpga_pushbutton_reset_l : in std_logic;
        lvds_rsw0_to_ign_trgt_fpga_p : in std_logic;
        lvds_rsw0_to_ign_trgt_fpga_n : in std_logic;
        lvds_ign_trgt_fpga_to_rsw0_p : out std_logic;
        lvds_ign_trgt_fpga_to_rsw0_n : out std_logic;
        lvds_rsw1_to_ign_trgt_fpga_p : in std_logic;
        lvds_rsw1_to_ign_trgt_fpga_n : in std_logic;
        lvds_ign_trgt_fpga_to_rsw1_p : out std_logic;
        lvds_ign_trgt_fpga_to_rsw1_n : out std_logic;
        v3p3_fpga2_a2_pg : in std_logic;
        v1p2_fpga2_a2_pg : in std_logic;
        v2p5_fpga2_a2_pg : in std_logic;
        main_hsc_restart : out std_logic;
        ibc_en : out std_logic;
        v5p0_sys_a2_pg : in std_logic;
        v3p3_sys_a2_pg : in std_logic;
        v1p8_sys_a2_pg : in std_logic;
        v1p0_mgmt_a2_pg : in std_logic;
        v2p5_mgmt_a2_pg : in std_logic;
        v12_sys_a2_pg_l : in std_logic;
        main_hsc_pg : in std_logic;
        sp_fault_l : in std_logic;
        rot_fault_l : in std_logic

    );
end entity;

architecture rtl of cosmo_ignition_top is
   
begin

    main_hsc_restart <= '0';
    ibc_en <= '1';

end rtl;