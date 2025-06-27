-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.debug_regs_pkg.all;
use work.sequencer_io_pkg.all;

entity debug_header is
    port (
        clk_200m : in std_logic;
        reset_200m : in std_logic;

        dbg_1v8_ctrl: in dbg_1v8_ctrl_type;

        -- hotplug
        i2c_sp5_to_fpgax_hp_sda: in std_logic;
        i2c_sp5_to_fpgax_hp_scl: in std_logic;
        -- sp
        i2c_sp_to_fpga1_scl: in std_logic;
        i2c_sp_to_fpga1_sda: in std_logic;
        -- dimms
        i3c_sp5_to_fpga1_abcdef_scl: in std_logic;
        i3c_sp5_to_fpga1_abcdef_sda: in std_logic;
        i3c_sp5_to_fpga1_ghijkl_scl: in std_logic;
        i3c_sp5_to_fpga1_ghijkl_sda: in std_logic;
        i3c_fpga1_to_dimm_abcdef_scl: in std_logic;
        i3c_fpga1_to_dimm_abcdef_sda: in std_logic;
        i3c_fpga1_to_dimm_ghijkl_scl: in std_logic;
        i3c_fpga1_to_dimm_ghijkl_sda: in std_logic;
        -- UARTs
        uart1_sp_to_fpga1_dat: in std_logic; -- sp ipcc
        uart1_fpga1_to_sp_dat : in std_logic; -- sp ipcc
        uart0_sp_to_fpga1_dat: in std_logic; -- sp console
        uart0_fpga1_to_sp_dat : in std_logic; -- sp console
        uart0_fpga1_to_sp5_dat : in std_logic; -- sp5 console
        uart0_sp5_to_fpga1_dat : in std_logic; -- sp5 console
        -- ESPI signals
        espi0_sp5_to_fpga_clk: in std_logic;
        espi0_sp5_to_fpga_cs_l: in std_logic;
        espi0_sp5_to_fpga1_dat: in std_logic_vector(3 downto 0);
        espi_resp_csn: in std_logic;
        -- T6 signals
        nic_dbg_pins : view t6_debug_dbg;
        -- sp5 toggle pins
        sp5_debug2_pin : in std_logic;

        fpga1_spare_v1p8 : out std_logic_vector(7 downto 0); -- 8 spare pins on the debug header

       
    );
end entity;

architecture rtl of debug_header is
    signal i2c_sp_to_fpga1_sda_int : std_logic;
    signal i2c_sp_to_fpga1_scl_int : std_logic;
    signal i2c_sp5_to_fpgax_hp_sda_int: std_logic;
    signal i2c_sp5_to_fpgax_hp_scl_int: std_logic;
    signal i3c_sp5_to_fpga1_abcdef_scl_int: std_logic;
    signal i3c_sp5_to_fpga1_abcdef_sda_int: std_logic;
    signal i3c_sp5_to_fpga1_ghijkl_scl_int: std_logic;
    signal i3c_sp5_to_fpga1_ghijkl_sda_int: std_logic;
    signal i3c_fpga1_to_dimm_abcdef_scl_int: std_logic;
    signal i3c_fpga1_to_dimm_abcdef_sda_int: std_logic;
    signal i3c_fpga1_to_dimm_ghijkl_scl_int: std_logic;
    signal i3c_fpga1_to_dimm_ghijkl_sda_int: std_logic;
    signal uart1_sp_to_fpga1_dat_int : std_logic;
    signal uart1_fpga1_to_sp_dat_int : std_logic;
    signal uart0_sp_to_fpga1_dat_int : std_logic;
    signal uart0_fpga1_to_sp_dat_int : std_logic;
    signal uart0_fpga1_to_sp5_dat_int : std_logic;
    signal uart0_sp5_to_fpga1_dat_int : std_logic;
    signal espi0_sp5_to_fpga_clk_int : std_logic;
    signal espi0_sp5_to_fpga_cs_l_int : std_logic;
    signal espi0_sp5_to_fpga1_dat_int : std_logic_vector(3 downto 0);
    signal espi_resp_csn_int : std_logic;
    signal dbg_1v8_ctrl_200 : dbg_1v8_ctrl_type;
    signal fpga1_spare_reg : std_logic_vector(7 downto 0);
    signal nic_dbg_pins_int : t6_debug_if;
    signal sp5_debug2_pin_int : std_logic;


begin
sample_reg: process(clk_200m, reset_200m)
    begin
        if rising_edge(clk_200m) then
            dbg_1v8_ctrl_200 <= dbg_1v8_ctrl;
            i2c_sp_to_fpga1_sda_int <= i2c_sp_to_fpga1_sda;
            i2c_sp_to_fpga1_scl_int <= i2c_sp_to_fpga1_scl;
            i2c_sp5_to_fpgax_hp_sda_int <= i2c_sp5_to_fpgax_hp_sda;
            i2c_sp5_to_fpgax_hp_scl_int <= i2c_sp5_to_fpgax_hp_scl;
            i3c_sp5_to_fpga1_abcdef_scl_int <= i3c_sp5_to_fpga1_abcdef_scl; 
            i3c_sp5_to_fpga1_abcdef_sda_int <= i3c_sp5_to_fpga1_abcdef_sda; 
            i3c_sp5_to_fpga1_ghijkl_scl_int <= i3c_sp5_to_fpga1_ghijkl_scl; 
            i3c_sp5_to_fpga1_ghijkl_sda_int <= i3c_sp5_to_fpga1_ghijkl_sda; 
            i3c_fpga1_to_dimm_abcdef_scl_int <= i3c_fpga1_to_dimm_abcdef_scl;
            i3c_fpga1_to_dimm_abcdef_sda_int <= i3c_fpga1_to_dimm_abcdef_sda;
            i3c_fpga1_to_dimm_ghijkl_scl_int <= i3c_fpga1_to_dimm_ghijkl_scl;
            i3c_fpga1_to_dimm_ghijkl_sda_int <= i3c_fpga1_to_dimm_ghijkl_sda;
            uart1_sp_to_fpga1_dat_int <= uart1_sp_to_fpga1_dat;
            uart1_fpga1_to_sp_dat_int <= uart1_fpga1_to_sp_dat;
            uart0_sp_to_fpga1_dat_int <= uart0_sp_to_fpga1_dat;
            uart0_fpga1_to_sp_dat_int <= uart0_fpga1_to_sp_dat;
            uart0_fpga1_to_sp5_dat_int <= uart0_fpga1_to_sp5_dat;
            uart0_sp5_to_fpga1_dat_int <= uart0_sp5_to_fpga1_dat;
            espi0_sp5_to_fpga_clk_int <= espi0_sp5_to_fpga_clk;
            espi0_sp5_to_fpga_cs_l_int <= espi0_sp5_to_fpga_cs_l;
            espi0_sp5_to_fpga1_dat_int <= espi0_sp5_to_fpga1_dat;
            espi_resp_csn_int <= espi_resp_csn;
            nic_dbg_pins_int <= nic_dbg_pins;
            sp5_debug2_pin_int <= sp5_debug2_pin;
        end if;
    end process;

hdr_dbg_reg_1v8: process(clk_200m, reset_200m)
    begin
        if reset_200m = '1' then
            fpga1_spare_reg <= (others => '0');
        
        elsif rising_edge(clk_200m) then
            if dbg_1v8_ctrl_200.pins7_6 /= NONE then
                fpga1_spare_v1p8(7 downto 6) <= fpga1_spare_reg(7 downto 6);
            else
                fpga1_spare_v1p8(7 downto 6) <= (others => 'Z');
            end if;
            if dbg_1v8_ctrl_200.pins5_4 /= NONE then
                fpga1_spare_v1p8(5 downto 4) <= fpga1_spare_reg(5 downto 4);
            else
                fpga1_spare_v1p8(4 downto 4) <= (others => 'Z');
            end if;
            if dbg_1v8_ctrl_200.pins3_2 /= NONE then
                fpga1_spare_v1p8(3 downto 2) <= fpga1_spare_reg(3 downto 2);
            else
                fpga1_spare_v1p8(3 downto 2) <= (others => 'Z');
            end if;
            if dbg_1v8_ctrl_200.pins1_0 /= NONE then
                fpga1_spare_v1p8(1 downto 0) <= fpga1_spare_reg(1 downto 0);
            else
                fpga1_spare_v1p8(1 downto 0) <= (others => 'Z');
            end if;

            -- Deal with pins7..6
            case dbg_1v8_ctrl_200.pins7_6 is
                when I2C_DIMM0_BUS =>
                    fpga1_spare_reg(7) <= i3c_fpga1_to_dimm_abcdef_scl_int;
                    fpga1_spare_reg(6) <= i3c_fpga1_to_dimm_abcdef_sda_int;
                when I2C_DIMM1_BUS =>
                    fpga1_spare_reg(7) <= i3c_fpga1_to_dimm_ghijkl_scl_int;
                    fpga1_spare_reg(6) <= i3c_fpga1_to_dimm_ghijkl_sda_int;
                when I2C_SP5_DIMM0_BUS =>
                    fpga1_spare_reg(7) <= i3c_sp5_to_fpga1_abcdef_scl_int;
                    fpga1_spare_reg(6) <= i3c_sp5_to_fpga1_abcdef_sda_int;
                when I2C_SP5_DIMM1_BUS =>
                    fpga1_spare_reg(7) <= i3c_sp5_to_fpga1_ghijkl_scl_int;
                    fpga1_spare_reg(6) <= i3c_sp5_to_fpga1_ghijkl_sda_int;
                when I2C_SP5_HP_BUS =>
                    fpga1_spare_reg(7) <= i2c_sp5_to_fpgax_hp_scl_int;
                    fpga1_spare_reg(6) <= i2c_sp5_to_fpgax_hp_sda_int;
                when I2C_SP_MUX_BUS =>
                    fpga1_spare_reg(7) <= i2c_sp_to_fpga1_scl_int;
                    fpga1_spare_reg(6) <= i2c_sp_to_fpga1_sda_int;
                when ESPI_BUS =>
                    fpga1_spare_reg(7) <= espi0_sp5_to_fpga_clk_int;
                    fpga1_spare_reg(6) <= espi0_sp5_to_fpga_cs_l_int;
                when SP_CONSOLE_BUS =>
                    fpga1_spare_reg(7) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_reg(6) <= uart0_sp_to_fpga1_dat_int;
                when SP5_CONSOLE_BUS =>
                    fpga1_spare_reg(7) <= uart0_fpga1_to_sp5_dat_int;
                    fpga1_spare_reg(6) <= uart0_sp5_to_fpga1_dat_int;
                when SP_IPCC_BUS =>
                    fpga1_spare_reg(7) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_reg(6) <= uart1_sp_to_fpga1_dat_int;
                when T6_SEQUENCER =>
                    -- T6 debug pins
                    fpga1_spare_reg(7) <= nic_dbg_pins_int.rails_en;
                    fpga1_spare_reg(6) <= nic_dbg_pins_int.rails_pg;
                when others =>
                    -- Default case, do nothing
                    fpga1_spare_reg(7 downto 6) <= (others => '0');
            end case;
            -- Deal with pins5..4
            case dbg_1v8_ctrl_200.pins5_4 is
                when I2C_DIMM0_BUS =>
                    fpga1_spare_reg(5) <= i3c_fpga1_to_dimm_abcdef_scl_int;
                    fpga1_spare_reg(4) <= i3c_fpga1_to_dimm_abcdef_sda_int;
                when I2C_DIMM1_BUS =>
                    fpga1_spare_reg(5) <= i3c_fpga1_to_dimm_ghijkl_scl_int;
                    fpga1_spare_reg(4) <= i3c_fpga1_to_dimm_ghijkl_sda_int;
                when I2C_SP5_DIMM0_BUS =>
                    fpga1_spare_reg(5) <= i3c_sp5_to_fpga1_abcdef_scl_int;
                    fpga1_spare_reg(4) <= i3c_sp5_to_fpga1_abcdef_sda_int;
                when I2C_SP5_DIMM1_BUS =>
                    fpga1_spare_reg(5) <= i3c_sp5_to_fpga1_ghijkl_scl_int;
                    fpga1_spare_reg(4) <= i3c_sp5_to_fpga1_ghijkl_sda_int;
                when I2C_SP5_HP_BUS =>
                    fpga1_spare_reg(5) <= i2c_sp5_to_fpgax_hp_scl_int;
                    fpga1_spare_reg(4) <= i2c_sp5_to_fpgax_hp_sda_int;
                when I2C_SP_MUX_BUS =>
                    fpga1_spare_reg(5) <= i2c_sp_to_fpga1_scl_int;
                    fpga1_spare_reg(4) <= i2c_sp_to_fpga1_sda_int;
                when ESPI_BUS =>
                    fpga1_spare_reg(5) <= espi0_sp5_to_fpga1_dat_int(1);
                    fpga1_spare_reg(4) <= espi0_sp5_to_fpga1_dat_int(0);
                when SP_CONSOLE_BUS =>
                    fpga1_spare_reg(5) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_reg(4) <= uart0_sp_to_fpga1_dat_int;
                when SP5_CONSOLE_BUS =>
                    fpga1_spare_reg(5) <= uart0_fpga1_to_sp5_dat_int;
                    fpga1_spare_reg(4) <= uart0_sp5_to_fpga1_dat_int;
                when SP_IPCC_BUS =>
                    fpga1_spare_reg(5) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_reg(4) <= uart1_sp_to_fpga1_dat_int;
                 when T6_SEQUENCER =>
                    -- T6 debug pins
                    fpga1_spare_reg(5) <= nic_dbg_pins.cld_rst_l;
                    fpga1_spare_reg(4) <=  nic_dbg_pins.perst_l;
                when others =>
                    -- Default case, do nothing
                    fpga1_spare_reg(5 downto 4) <= (others => '0');
            end case;
            -- Deal with pins3..2
            case dbg_1v8_ctrl_200.pins3_2 is
                when I2C_DIMM0_BUS =>
                    fpga1_spare_reg(3) <= i3c_fpga1_to_dimm_abcdef_scl_int;
                    fpga1_spare_reg(2) <= i3c_fpga1_to_dimm_abcdef_sda_int;
                when I2C_DIMM1_BUS =>
                    fpga1_spare_reg(3) <= i3c_fpga1_to_dimm_ghijkl_scl_int;
                    fpga1_spare_reg(2) <= i3c_fpga1_to_dimm_ghijkl_sda_int;
                when I2C_SP5_DIMM0_BUS =>
                    fpga1_spare_reg(3) <= i3c_sp5_to_fpga1_abcdef_scl_int;
                    fpga1_spare_reg(2) <= i3c_sp5_to_fpga1_abcdef_sda_int;
                when I2C_SP5_DIMM1_BUS =>
                    fpga1_spare_reg(3) <= i3c_sp5_to_fpga1_ghijkl_scl_int;
                    fpga1_spare_reg(2) <= i3c_sp5_to_fpga1_ghijkl_sda_int;
                when I2C_SP5_HP_BUS =>
                    fpga1_spare_reg(3) <= i2c_sp5_to_fpgax_hp_scl_int;
                    fpga1_spare_reg(2) <= i2c_sp5_to_fpgax_hp_sda_int;
                when I2C_SP_MUX_BUS =>
                    fpga1_spare_reg(3) <= i2c_sp_to_fpga1_scl_int;
                    fpga1_spare_reg(2) <= i2c_sp_to_fpga1_sda_int;
                when ESPI_BUS =>
                    fpga1_spare_reg(3) <= espi_resp_csn;
                    fpga1_spare_reg(2) <= '0'; -- Unused in this case
                when SP_CONSOLE_BUS =>
                    fpga1_spare_reg(3) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_reg(2) <= uart0_sp_to_fpga1_dat_int;
                when SP5_CONSOLE_BUS =>
                    fpga1_spare_reg(3) <= uart0_fpga1_to_sp5_dat_int;
                    fpga1_spare_reg(2) <= uart0_sp5_to_fpga1_dat_int;
                when SP_IPCC_BUS =>
                    fpga1_spare_reg(3) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_reg(2) <= uart1_sp_to_fpga1_dat_int;
                when T6_SEQUENCER =>
                    fpga1_spare_reg(3) <= nic_dbg_pins.sp5_mfg_mode_l;
                    fpga1_spare_reg(2) <= nic_dbg_pins.nic_mfg_mode_l;
                when others =>
                    -- Default case, do nothing
                    fpga1_spare_reg(3 downto 2) <= (others => '0');
            end case;

            -- Deal with pins1..0
            case dbg_1v8_ctrl_200.pins1_0 is
                when I2C_DIMM0_BUS =>
                    fpga1_spare_reg(1) <= i3c_fpga1_to_dimm_abcdef_scl_int;
                    fpga1_spare_reg(0) <= i3c_fpga1_to_dimm_abcdef_sda_int;
                when I2C_DIMM1_BUS =>
                    fpga1_spare_reg(1) <= i3c_fpga1_to_dimm_ghijkl_scl_int;
                    fpga1_spare_reg(0) <= i3c_fpga1_to_dimm_ghijkl_sda_int;
                when I2C_SP5_DIMM0_BUS =>
                    fpga1_spare_reg(1) <= i3c_sp5_to_fpga1_abcdef_scl_int;
                    fpga1_spare_reg(0) <= i3c_sp5_to_fpga1_abcdef_sda_int;
                when I2C_SP5_DIMM1_BUS =>
                    fpga1_spare_reg(1) <= i3c_sp5_to_fpga1_ghijkl_scl_int;
                    fpga1_spare_reg(0) <= i3c_sp5_to_fpga1_ghijkl_sda_int;
                when I2C_SP5_HP_BUS =>
                    fpga1_spare_reg(1) <= i2c_sp5_to_fpgax_hp_scl_int;
                    fpga1_spare_reg(0) <= i2c_sp5_to_fpgax_hp_sda_int;
                when I2C_SP_MUX_BUS =>
                    fpga1_spare_reg(1) <= i2c_sp_to_fpga1_scl_int;
                    fpga1_spare_reg(0) <= i2c_sp_to_fpga1_sda_int;
                when ESPI_BUS =>
                    fpga1_spare_reg(1) <= espi0_sp5_to_fpga1_dat_int(3);
                    fpga1_spare_reg(0) <= espi0_sp5_to_fpga1_dat_int(2);
                when SP_CONSOLE_BUS =>
                    fpga1_spare_reg(1) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_reg(0) <= uart0_sp_to_fpga1_dat_int;
                when SP5_CONSOLE_BUS =>
                    fpga1_spare_reg(1) <= uart0_fpga1_to_sp5_dat_int;
                    fpga1_spare_reg(0) <= uart0_sp5_to_fpga1_dat_int;
                when SP_IPCC_BUS =>
                    fpga1_spare_reg(1) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_reg(0) <= uart1_sp_to_fpga1_dat_int;
                when T6_SEQUENCER =>
                    fpga1_spare_reg(1) <= nic_dbg_pins.ext_rst_l;
                    fpga1_spare_reg(0) <= sp5_debug2_pin_int; -- Unused in this case.
                when others =>
                    -- Default case, do nothing
                    fpga1_spare_reg(1 downto 0) <= (others => '0');
            end case;
        end if;
    end process;



end rtl;