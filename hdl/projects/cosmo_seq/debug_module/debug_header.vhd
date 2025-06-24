-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.debug_regs_pkg.all;

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


begin
sample_reg: process(clk_200m, reset_200m)
    begin
        if rising_edge(clk_200m) then
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
        end if;
    end process;

hdr_dbg_reg_1v8: process(clk_200m, reset_200m)
    begin
        if rising_edge(clk_200m) then

            -- Deal with pins7..6
            case dbg_1v8_ctrl.pins7_6 is
                when I2C_DIMM0_BUS =>
                    fpga1_spare_v1p8(7) <= i3c_fpga1_to_dimm_abcdef_scl_int;
                    fpga1_spare_v1p8(6) <= i3c_fpga1_to_dimm_abcdef_sda_int;
                when I2C_DIMM1_BUS =>
                    fpga1_spare_v1p8(7) <= i3c_fpga1_to_dimm_ghijkl_scl_int;
                    fpga1_spare_v1p8(6) <= i3c_fpga1_to_dimm_ghijkl_sda_int;
                when I2C_SP5_DIMM0_BUS =>
                    fpga1_spare_v1p8(7) <= i3c_sp5_to_fpga1_abcdef_scl_int;
                    fpga1_spare_v1p8(6) <= i3c_sp5_to_fpga1_abcdef_sda_int;
                when I2C_SP5_DIMM1_BUS =>
                    fpga1_spare_v1p8(7) <= i3c_sp5_to_fpga1_ghijkl_scl_int;
                    fpga1_spare_v1p8(6) <= i3c_sp5_to_fpga1_ghijkl_sda_int;
                when I2C_SP5_HP_BUS =>
                    fpga1_spare_v1p8(7) <= i2c_sp5_to_fpgax_hp_scl_int;
                    fpga1_spare_v1p8(6) <= i2c_sp5_to_fpgax_hp_sda_int;
                when I2C_SP_MUX_BUS =>
                    fpga1_spare_v1p8(7) <= i2c_sp_to_fpga1_scl_int;
                    fpga1_spare_v1p8(6) <= i2c_sp_to_fpga1_sda_int;
                when ESPI_BUS =>
                    fpga1_spare_v1p8(7) <= espi0_sp5_to_fpga_clk;
                    fpga1_spare_v1p8(6) <= espi0_sp5_to_fpga_cs_l;
                when SP_CONSOLE_BUS =>
                    fpga1_spare_v1p8(7) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_v1p8(6) <= uart0_sp_to_fpga1_dat_int;
                when SP5_CONSOLE_BUS =>
                    fpga1_spare_v1p8(7) <= uart0_fpga1_to_sp5_dat_int;
                    fpga1_spare_v1p8(6) <= uart0_sp5_to_fpga1_dat_int;
                when SP_IPCC_BUS =>
                    fpga1_spare_v1p8(7) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_v1p8(6) <= uart1_sp_to_fpga1_dat;
                when others =>
                    -- Default case, do nothing
                    fpga1_spare_v1p8(7 downto 6) <= (others => 'Z');
            end case;
            -- Deal with pins5..4
            case dbg_1v8_ctrl.pins5_4 is
                when I2C_DIMM0_BUS =>
                    fpga1_spare_v1p8(5) <= i3c_fpga1_to_dimm_abcdef_scl_int;
                    fpga1_spare_v1p8(4) <= i3c_fpga1_to_dimm_abcdef_sda_int;
                when I2C_DIMM1_BUS =>
                    fpga1_spare_v1p8(5) <= i3c_fpga1_to_dimm_ghijkl_scl_int;
                    fpga1_spare_v1p8(4) <= i3c_fpga1_to_dimm_ghijkl_sda_int;
                when I2C_SP5_DIMM0_BUS =>
                    fpga1_spare_v1p8(5) <= i3c_sp5_to_fpga1_abcdef_scl_int;
                    fpga1_spare_v1p8(4) <= i3c_sp5_to_fpga1_abcdef_sda_int;
                when I2C_SP5_DIMM1_BUS =>
                    fpga1_spare_v1p8(5) <= i3c_sp5_to_fpga1_ghijkl_scl_int;
                    fpga1_spare_v1p8(4) <= i3c_sp5_to_fpga1_ghijkl_sda_int;
                when I2C_SP5_HP_BUS =>
                    fpga1_spare_v1p8(5) <= i2c_sp5_to_fpgax_hp_scl_int;
                    fpga1_spare_v1p8(4) <= i2c_sp5_to_fpgax_hp_sda_int;
                when I2C_SP_MUX_BUS =>
                    fpga1_spare_v1p8(5) <= i2c_sp_to_fpga1_scl_int;
                    fpga1_spare_v1p8(4) <= i2c_sp_to_fpga1_sda_int;
                when ESPI_BUS =>
                    fpga1_spare_v1p8(5) <= espi0_sp5_to_fpga1_dat(1);
                    fpga1_spare_v1p8(4) <= espi0_sp5_to_fpga1_dat(0);
                when SP_CONSOLE_BUS =>
                    fpga1_spare_v1p8(5) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_v1p8(4) <= uart0_sp_to_fpga1_dat_int;
                when SP5_CONSOLE_BUS =>
                    fpga1_spare_v1p8(5) <= uart0_fpga1_to_sp5_dat_int;
                    fpga1_spare_v1p8(4) <= uart0_sp5_to_fpga1_dat_int;
                when SP_IPCC_BUS =>
                    fpga1_spare_v1p8(5) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_v1p8(4) <= uart1_sp_to_fpga1_dat;
                when others =>
                    -- Default case, do nothing
                    fpga1_spare_v1p8(5 downto 4) <= (others => 'Z');
            end case;
            -- Deal with pins3..2
            case dbg_1v8_ctrl.pins3_2 is
                when I2C_DIMM0_BUS =>
                    fpga1_spare_v1p8(3) <= i3c_fpga1_to_dimm_abcdef_scl_int;
                    fpga1_spare_v1p8(2) <= i3c_fpga1_to_dimm_abcdef_sda_int;
                when I2C_DIMM1_BUS =>
                    fpga1_spare_v1p8(3) <= i3c_fpga1_to_dimm_ghijkl_scl_int;
                    fpga1_spare_v1p8(2) <= i3c_fpga1_to_dimm_ghijkl_sda_int;
                when I2C_SP5_DIMM0_BUS =>
                    fpga1_spare_v1p8(3) <= i3c_sp5_to_fpga1_abcdef_scl_int;
                    fpga1_spare_v1p8(2) <= i3c_sp5_to_fpga1_abcdef_sda_int;
                when I2C_SP5_DIMM1_BUS =>
                    fpga1_spare_v1p8(3) <= i3c_sp5_to_fpga1_ghijkl_scl_int;
                    fpga1_spare_v1p8(2) <= i3c_sp5_to_fpga1_ghijkl_sda_int;
                when I2C_SP5_HP_BUS =>
                    fpga1_spare_v1p8(3) <= i2c_sp5_to_fpgax_hp_scl_int;
                    fpga1_spare_v1p8(2) <= i2c_sp5_to_fpgax_hp_sda_int;
                when I2C_SP_MUX_BUS =>
                    fpga1_spare_v1p8(3) <= i2c_sp_to_fpga1_scl_int;
                    fpga1_spare_v1p8(2) <= i2c_sp_to_fpga1_sda_int;
                when ESPI_BUS =>
                    fpga1_spare_v1p8(3) <= espi_resp_csn;
                    fpga1_spare_v1p8(2) <= 'Z'; -- Unused in this case
                when SP_CONSOLE_BUS =>
                    fpga1_spare_v1p8(3) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_v1p8(2) <= uart0_sp_to_fpga1_dat_int;
                when SP5_CONSOLE_BUS =>
                    fpga1_spare_v1p8(3) <= uart0_fpga1_to_sp5_dat_int;
                    fpga1_spare_v1p8(2) <= uart0_sp5_to_fpga1_dat_int;
                when SP_IPCC_BUS =>
                    fpga1_spare_v1p8(3) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_v1p8(2) <= uart1_sp_to_fpga1_dat;
                when others =>
                    -- Default case, do nothing
                    fpga1_spare_v1p8(3 downto 2) <= (others => 'Z');
            end case;

            -- Deal with pins1..0
            case dbg_1v8_ctrl.pins1_0 is
                when I2C_DIMM0_BUS =>
                    fpga1_spare_v1p8(1) <= i3c_fpga1_to_dimm_abcdef_scl_int;
                    fpga1_spare_v1p8(0) <= i3c_fpga1_to_dimm_abcdef_sda_int;
                when I2C_DIMM1_BUS =>
                    fpga1_spare_v1p8(1) <= i3c_fpga1_to_dimm_ghijkl_scl_int;
                    fpga1_spare_v1p8(0) <= i3c_fpga1_to_dimm_ghijkl_sda_int;
                when I2C_SP5_DIMM0_BUS =>
                    fpga1_spare_v1p8(1) <= i3c_sp5_to_fpga1_abcdef_scl_int;
                    fpga1_spare_v1p8(0) <= i3c_sp5_to_fpga1_abcdef_sda_int;
                when I2C_SP5_DIMM1_BUS =>
                    fpga1_spare_v1p8(1) <= i3c_sp5_to_fpga1_ghijkl_scl_int;
                    fpga1_spare_v1p8(0) <= i3c_sp5_to_fpga1_ghijkl_sda_int;
                when I2C_SP5_HP_BUS =>
                    fpga1_spare_v1p8(1) <= i2c_sp5_to_fpgax_hp_scl_int;
                    fpga1_spare_v1p8(0) <= i2c_sp5_to_fpgax_hp_sda_int;
                when I2C_SP_MUX_BUS =>
                    fpga1_spare_v1p8(1) <= i2c_sp_to_fpga1_scl_int;
                    fpga1_spare_v1p8(0) <= i2c_sp_to_fpga1_sda_int;
                when ESPI_BUS =>
                    fpga1_spare_v1p8(1) <= espi0_sp5_to_fpga1_dat(3);
                    fpga1_spare_v1p8(0) <= espi0_sp5_to_fpga1_dat(2);
                when SP_CONSOLE_BUS =>
                    fpga1_spare_v1p8(1) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_v1p8(0) <= uart0_sp_to_fpga1_dat_int;
                when SP5_CONSOLE_BUS =>
                    fpga1_spare_v1p8(1) <= uart0_fpga1_to_sp5_dat_int;
                    fpga1_spare_v1p8(0) <= uart0_sp5_to_fpga1_dat_int;
                when SP_IPCC_BUS =>
                    fpga1_spare_v1p8(1) <= uart1_fpga1_to_sp_dat_int;
                    fpga1_spare_v1p8(0) <= uart1_sp_to_fpga1_dat;
                when others =>
                    -- Default case, do nothing
                    fpga1_spare_v1p8(1 downto 0) <= (others => 'Z');
            end case;
        end if;
    end process;

end rtl;