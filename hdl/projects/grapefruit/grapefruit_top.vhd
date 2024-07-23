-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil_common_pkg.all;
use work.axil26x32_pkg;
use work.axil8x32_pkg;

entity grapefruit_top is
    port (
        clk     : in    std_logic;
        reset_l : in    std_logic;

        ledn : out   std_logic
        clk   : in    std_logic;
        reset_l : in    std_logic; -- SP_TO_FPGA_LOGIC_RESET_L
        seq_reg_to_sp_V3P3_pg: out std_logic;
        seq_reg_to_sp_v1p2_pg: out std_logic;
        sp5_to_sp_present_l : out std_logic;
        sp_to_sp5_prochot_l : in std_logic;
        sp5_to_sp_sp5R : out std_logic_vector(4 downto 1);
        sp5_to_sp_coretype : out std_logic_vector(2 downto 0);
        sp_to_ignit_fault_l: in std_logic;
        sp5_to_sp_int_l : out std_logic;
        sp_to_sp5_int_l : in std_logic;
        sp_to_sp5_nmi_sync_flood_l: in std_logic;
        nic_to_sp_gpio0_present1: out std_logic;
        nic_to_sp_gpio0_present2: out std_logic;
        rot_to_ignit_fault_l: in std_logic;

        fmc_sp_to_fpga_clk : in std_logic;
        fmc_sp_to_fpga_oe_l : in std_logic;
        fmc_sp_to_fpga_we_l : in std_logic;
        fmc_sp_to_fpga_wait_l : out std_logic;
        fmc_sp_to_fpga_cs1_l: in std_logic;
        fmc_sp_to_fpga_adv_l : in std_logic;
        fmc_sp_to_fpga_bl0_l : in std_logic;
        fmc_sp_to_fpga_bl1_l : in std_logic;
        fmc_sp_to_fpga_da : inout std_logic_vector(15 downto 0);
        fmc_sp_to_fpga_a : in std_logic_vector(19 downto 16);

        seq_to_sp_misc_a : in std_logic;
        seq_to_sp_misc_b : in std_logic;
        seq_to_sp_misc_c : in std_logic;
        seq_to_sp_misc_d : in std_logic;

        seq_to_sp_int_l : in std_logic;
        fpga_to_sp_irq1_l : out std_logic;
        fpga_to_sp_irq2_l : out std_logic;
        fpga_to_sp_irq3_l : out std_logic;
        fpga_to_sp_irq4_l : out std_logic;

        uart0_sp_to_fpga_dat : in std_logic;
        uart0_fpga_to_sp_dat: out std_logic;
        uart0_sp_to_fpga_rts_l : in std_logic;
        uart0_fpga_to_sp_rts_l: out std_logic;

        uart1_sp_to_fpga_dat : in std_logic;
        uart1_fpga_to_sp_dat: out std_logic;
        uart1_sp_to_fpga_rts_l : in std_logic;
        uart1_fpga_to_sp_rts_l: out std_logic;

        uart_local_sp_to_fpga_dat : in std_logic;
        uart_local_fpga_to_sp_dat: out std_logic;
        uart_local_sp_to_fpga_rts_l : in std_logic;
        uart_local_fpga_to_sp_rts_l: out std_logic;

        sp_to_seq_system_reset_l : in std_logic;
        seq_rev_id : in std_logic_vector(2 downto 0);

        spi_fpga_to_flash_cs_l : out std_logic;
        spi_fpga_to_flash_clk : out std_logic;
        spi_fpga_to_flash_dat0 : out std_logic;
        spi_fpga_to_flash_dat1 : in std_logic;
        spi_fpga_to_flash_dat2 : in std_logic;
        spi_fpga_to_flash_dat3 : in std_logic;

        spi_fpga_to_flash2_cs_l : out std_logic;
        spi_fpga_to_flash2_clk : out std_logic;
        spi_fpga_to_flash2_dat : inout std_logic_vector(3 downto 0);
        
        i3c_sp5_to_fpga_oe_n_3v3: out std_logic;
        i3c_fpga_to_dimm_oe_n_3v3: out std_logic;

        uart0_sp5_to_fpga_data: in std_logic;
        uart0_fpga_to_sp5_data: out std_logic;
        uart0_sp5_to_fpga_rts_l : in std_logic;
        uart0_fpga_to_sp5_rts_l: out std_logic;

        uart1_scm_to_hpm_dat: out std_logic;
        uart1_hpm_to_scm_dat: in std_logic;

        fpga_spare_1v8: out std_logic_vector(7 downto 0);
        fpga_spare_3v3: out std_logic_vector(7 downto 0);

        espi_hpm_to_scm_reset_l : in std_logic;
        espi_scm_to_hpm_alert_l : out std_logic;
        espi_hpm_to_scm_cs_l: in std_logic;
        espi_hpm_to_scm_clk: in std_logic;
        espi_hpm_to_scm_dat: inout std_logic_vector(3 downto 0);

        i3c_hpm_to_scm_dimm0_abcdef_scl: inout std_logic;
        i3c_hpm_to_scm_dimm0_abcdef_sda: inout std_logic;
        i3c_hpm_to_scm_dimm0_ghijkl_scl: inout std_logic;
        i3c_hpm_to_scm_dimm0_ghijkl_sda: inout std_logic;

        i3c_hpm_to_scm_dimm1_abcdef_scl: inout std_logic;
        i3c_hpm_to_scm_dimm1_abcdef_sda: inout std_logic;
        i3c_hpm_to_scm_dimm1_ghijkl_scl: inout std_logic;
        i3c_hpm_to_scm_dimm1_ghijkl_sda: inout std_logic;

        i3c_scm_to_dimm0_abcdef_scl: inout std_logic;
        i3c_scm_to_dimm0_abcdef_sda: inout std_logic;
        i3c_scm_to_dimm0_ghijkl_scl: inout std_logic;
        i3c_scm_to_dimm0_ghijkl_sda: inout std_logic;
        i3c_scm_to_dimm1_abcdef_scl: inout std_logic;
        i3c_scm_to_dimm1_abcdef_sda: inout std_logic;
        i3c_scm_to_dimm1_ghijkl_scl: inout std_logic;
        i3c_scm_to_dimm1_ghijkl_sda: inout std_logic;

        hdt_scm_to_hpm_tck: out std_logic;
        hdt_scm_to_spm_tms: out std_logic;
        hdt_scm_to_spm_dat: out std_logic;
        hdt_hpm_to_scm_dat: in std_logic;
        scm_to_hpm_fw_recovery: out std_logic;
        hpm_to_scm_stby_rdy: in std_logic;
        scm_to_hpm_stby_en: out std_logic;
        scm_to_hpm_stby_rst_l: out std_logic;
        scm_to_hpm_pwrbtn_l: out std_logic;
        hpm_to_scm_pwrok: in std_logic;
        scm_to_hpm_dbreq_l: out std_logic;
        hpm_to_scm_pcie_rst_buf_l: out std_logic;
        hpm_to_scm_spare: in std_logic_vector(1 downto 0);
        scm_to_hpm_rot_cpu_rst_l: out std_logic;
        hpm_to_scm_chassis_intr_l: in std_logic;
        hpm_to_scm_irq_l: in std_logic;
        scm_to_hpm_virtual_reseat: out std_logic;
        uart_spare_scm_to_hpm_dat: out std_logic;
        uart_spare_hpm_to_scm_dat: in std_logic;

        qspi0_hpm_to_scm_clk : in std_logic;
        qspi0_hpm_to_scm_cs0_l: in std_logic;
        qspi0_hpm_to_scm_cs1_l: in std_logic;
        qspi0_hpm_to_scm_dat0: in std_logic;
        qspi0_hpm_to_scm_dat1: out std_logic;
        qspi0_hpm_to_scm_dat2: in std_logic;
        qspi0_hpm_to_scm_dat3: in std_logic;
        sgpip_scm_to_hpm_clk : out std_logic;

        sgpio_scm_to_hpm_dat: out std_logic_vector(1 downto 0);
        sgpio_hpm_to_scm_dat: in std_logic_vector(1 downto 0);
        sgpio_scm_to_hpm_ld: out std_logic_vector(1 downto 0);
        sgpio_scm_to_hpm_reset_l: in std_logic;
        sgpio_hpm_to_scm_intr_l: out std_logic;

        qspi1_scm_to_hpm_clk : out std_logic;
        qspi1_scm_to_hpm_cs_l: in std_logic;
        qspi1_scm_to_hpm_dat: inout std_logic_vector(3 downto 0);
        spi_hpm_to_scm_tpm_cs_l : in std_logic;

        i2c_sp_to_fpga_scl: inout std_logic;
        i2c_sp_to_fpga_sda: inout std_logic;

        i2c_scm_to_hpm_scl0: inout std_logic;
        i2c_scm_to_hpm_sda0: inout std_logic;
        i2c_scm_to_hpm_scl1: inout std_logic;
        i2c_scm_to_hpm_sda1: inout std_logic;
        i2c_scm_to_hpm_sda3: inout std_logic;
        i2c_scm_to_hpm_scl3: inout std_logic;
        i2c_scm_to_hpm_sda4: inout std_logic;
        i2c_scm_to_hpm_scl4: inout std_logic;
        i2c_scm_to_hpm_sda5: inout std_logic;
        i2c_scm_to_hpm_scl5: inout std_logic;
        i2c_scm_to_hpm_sda8: inout std_logic;
        i2c_scm_to_hpm_scl8: inout std_logic;
        i2c_scm_to_hpm_sda9: inout std_logic;
        i2c_scm_to_hpm_scl9: inout std_logic;
        i2c_scm_to_hpm_sda11: inout std_logic;
        i2c_scm_to_hpm_scl11: inout std_logic;
        i2c_scm_to_hpm_sda12: inout std_logic;
        i2c_scm_to_hpm_scl12: inout std_logic;

        fpga_to_fruid_scl: inout std_logic;
        fpga_to_fruid_sda: inout std_logic
    );
end entity;

architecture rtl of grapefruit_top is

    signal counter : unsigned(31 downto 0);
    signal pll_locked_async: std_logic;
    signal clk_125m : std_logic;
    signal reset_125m : std_logic;
    signal clk_200m : std_logic;
    signal reset_200m : std_logic;
    signal reset_fmc: std_logic;

    signal sp_awvalid : std_logic;
    signal sp_awready : std_logic;
    signal sp_awaddr : std_logic_vector(25 downto 0);
    signal sp_wvalid : std_logic;
    signal sp_wready : std_logic;
    signal sp_wstrb : std_logic_vector(3 downto 0);
    signal sp_wdata : std_logic_vector(31 downto 0);
    signal sp_bvalid : std_logic;
    signal sp_bready : std_logic;
    signal sp_arvalid : std_logic;
    signal sp_arready : std_logic;
    signal sp_araddr : std_logic_vector(25 downto 0);
    signal sp_rvalid : std_logic;
    signal sp_rready : std_logic;
    signal sp_rdata : std_logic_vector(31 downto 0);

    signal fmc_internal_data_out : std_logic_vector(15 downto 0);
    signal fmc_data_out_enable: std_logic;

    signal fmc_axi_if : axil26x32_pkg.axil_t;

    constant responder_count : integer := 1;
    constant config_array : axil_responder_cfg_array_t(0 downto 0) := (0 => (base_addr => x"00000000", addr_span_bits => 8));
    signal responders : axil8x32_pkg.axil_array_t(0 downto 0);

begin

    tst: process(clk, reset_l)
    -- Generate the clock signals for the necessary domains
    -- 200MHz is targetted for the eSPI interface so we can run fabric
    -- at ~3x the 66MHz SPI clock rate
    pll: entity work.gfruit_pll
        port map ( 
          clk_50m => clk,
          clk_125m => clk_125m,
          clk_200m => clk_200m,
          reset => not reset_l,
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
        sp_fmc_clk => fmc_sp_to_fpga_clk,
        reset_fmc_clk => reset_fmc
    );

    tst : process (clk_125m, reset_125m)
    begin
        if reset_125m then
            counter <= (others => '0');
        elsif rising_edge(clk_125m) then
            counter <= counter + 1;
        end if;
    end process;

    fpga_spare_1v8(0) <= not counter(26);
    fpga_spare_1v8(1) <= pll_locked_async;
    fpga_spare_1v8(2) <= reset_l;

    stm32h7_fmc_target_inst: entity work.stm32h7_fmc_target
     port map(
        chip_reset => reset_fmc,
        fmc_clk => fmc_sp_to_fpga_clk,
        a(24 downto 20) => "00000",
        a(19 downto 16) => fmc_sp_to_fpga_a,
        addr_data_in => fmc_sp_to_fpga_da,
        data_out => fmc_internal_data_out,
        data_out_en => fmc_data_out_enable,
        ne(3 downto 1) => "111",
        ne(0) => fmc_sp_to_fpga_cs1_l,
        noe => fmc_sp_to_fpga_oe_l,
        nwe => fmc_sp_to_fpga_we_l,
        nl => fmc_sp_to_fpga_adv_l,
        nwait => fmc_sp_to_fpga_wait_l,
        aclk => clk_125m,
        aresetn => not reset_125m,
        axi_if => fmc_axi_if

    );

    -- Axi interconnect
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

    -- tristate control for the FMC data bus
    fmc_sp_to_fpga_da <= fmc_internal_data_out when fmc_data_out_enable = '1' else (others => 'Z');

    registers_inst: entity work.registers
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders(0)
    );


    -- Basic flash spi passthru fomr qspi0 to spi flash
    spi_fpga_to_flash_cs_l <= qspi0_hpm_to_scm_cs0_l;
    spi_fpga_to_flash_clk <= qspi0_hpm_to_scm_clk;
    spi_fpga_to_flash_dat0 <= qspi0_hpm_to_scm_dat0;
    qspi0_hpm_to_scm_dat1 <= spi_fpga_to_flash_dat1;

    -- Debug stuff for i3c
    -- pin the enables low to enable the devices
    i3c_sp5_to_fpga_oe_n_3v3 <= '0';
    i3c_fpga_to_dimm_oe_n_3v3 <= '0';

    i3c_hpm_to_scm_dimm0_abcdef_scl <= not counter(26);
    i3c_hpm_to_scm_dimm0_abcdef_sda <= not counter(26);
    i3c_hpm_to_scm_dimm0_ghijkl_scl <= not counter(26);
    i3c_hpm_to_scm_dimm0_ghijkl_sda <= not counter(26);

    i3c_hpm_to_scm_dimm1_abcdef_scl <= not counter(26);
    i3c_hpm_to_scm_dimm1_abcdef_sda <= not counter(26);
    i3c_hpm_to_scm_dimm1_ghijkl_scl <= not counter(26);
    i3c_hpm_to_scm_dimm1_ghijkl_sda <= not counter(26);

    i3c_scm_to_dimm0_abcdef_scl <= not counter(26);
    i3c_scm_to_dimm0_abcdef_sda <= not counter(26);
    i3c_scm_to_dimm0_ghijkl_scl <= not counter(26);
    i3c_scm_to_dimm0_ghijkl_sda <= not counter(26);
    
    i3c_scm_to_dimm1_abcdef_scl <= not counter(26);
    i3c_scm_to_dimm1_abcdef_sda <= not counter(26);
    i3c_scm_to_dimm1_ghijkl_scl <= not counter(26);
    i3c_scm_to_dimm1_ghijkl_sda <= not counter(26);

    
end rtl;
