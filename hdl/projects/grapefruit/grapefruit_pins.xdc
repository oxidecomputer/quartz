# Configure I/O Bank 0 for 3.3V/2.5V operation set_property CFGBVS VCCO [current_design]
set_property CFGBVS VCCO [current_design]

# Configure I/O Bank 0 for 3.3V operation 
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property -dict { PACKAGE_PIN L8  IOSTANDARD LVCMOS33 } [get_ports { clk }]; # FPGA_50MHz_CLK2
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { reset_l }]; # SP_TO_FPGA_LOGIC_RESET_L
set_property -dict { PACKAGE_PIN N21 IOSTANDARD LVCMOS33 } [get_ports { seq_reg_to_sp_V3P3_pg }];
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS33 } [get_ports { seq_reg_to_sp_v1p2_pg }];
set_property -dict { PACKAGE_PIN P22 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_present_l }];
set_property -dict { PACKAGE_PIN N20 IOSTANDARD LVCMOS33 } [get_ports { sp_to_sp5_prochot_l }];
set_property -dict { PACKAGE_PIN T21 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_sp5R[4] }];
set_property -dict { PACKAGE_PIN N18 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_sp5R[3] }];
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_sp5R[2] }];
set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_sp5R[1] }];
set_property -dict { PACKAGE_PIN W22 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_coretype[2] }];
set_property -dict { PACKAGE_PIN V21 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_coretype[1] }];
set_property -dict { PACKAGE_PIN T22 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_coretype[0] }];
set_property -dict { PACKAGE_PIN N22 IOSTANDARD LVCMOS33 } [get_ports { sp_to_ignit_fault_l }];
set_property -dict { PACKAGE_PIN U22 IOSTANDARD LVCMOS33 } [get_ports { sp5_to_sp_int_l }];
set_property -dict { PACKAGE_PIN V22 IOSTANDARD LVCMOS33 } [get_ports { sp_to_sp5_int_l }];
set_property -dict { PACKAGE_PIN W21 IOSTANDARD LVCMOS33 } [get_ports { sp_to_sp5_nmi_sync_flood_l }];
set_property -dict { PACKAGE_PIN Y21 IOSTANDARD LVCMOS33 } [get_ports { nic_to_sp_gpio0_present1 }];
set_property -dict { PACKAGE_PIN U20 IOSTANDARD LVCMOS33 } [get_ports { nic_to_sp_gpio0_present2 }];
set_property -dict { PACKAGE_PIN V20 IOSTANDARD LVCMOS33 } [get_ports { rot_to_ignit_fault_l }];
set_property -dict { PACKAGE_PIN F17 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_clk }];
# ERROR: [Place 30-574] Poor placement for routing between an IO pin and BUFG. If this sub optimal condition is acceptable for this design
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets fmc_sp_to_fpga_clk_IBUF];
set_property -dict { PACKAGE_PIN F18 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_oe_l }];
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_we_l }];
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_wait_l }];
set_property IOB TRUE [get_ports fmc_sp_to_fpga_wait_l]
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_cs1_l }];
set_property -dict { PACKAGE_PIN H18 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_adv_l }];
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_bl0_l }];
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_bl1_l }];
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS33 } [get_ports { fpga_spare_3v3[7] }];
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { fpga_spare_3v3[6] }];
set_property -dict { PACKAGE_PIN B21 IOSTANDARD LVCMOS33 } [get_ports { fpga_spare_3v3[5] }];
set_property -dict { PACKAGE_PIN C20 IOSTANDARD LVCMOS33 } [get_ports { fpga_spare_3v3[4] }];
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { fpga_spare_3v3[3] }];
set_property -dict { PACKAGE_PIN D21 IOSTANDARD LVCMOS33 } [get_ports { fpga_spare_3v3[2] }];
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { fpga_spare_3v3[1] }];
set_property -dict { PACKAGE_PIN C22 IOSTANDARD LVCMOS33 } [get_ports { fpga_spare_3v3[0] }];
set_property -dict { PACKAGE_PIN G22 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[15] }];
set_property -dict { PACKAGE_PIN G21 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[14] }];
set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[13] }];
set_property -dict { PACKAGE_PIN H19 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[12] }];
set_property -dict { PACKAGE_PIN L19 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[11] }];
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[10] }];
set_property -dict { PACKAGE_PIN J20 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[9] }];
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[8] }];
set_property -dict { PACKAGE_PIN K19 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[7] }];
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[6] }];
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[5] }];
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[4] }];
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[3] }];
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[2] }];
set_property -dict { PACKAGE_PIN L15 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[1] }];
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_da[0] }];
set_property -dict { PACKAGE_PIN K22 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_a[19] }];
set_property -dict { PACKAGE_PIN L22 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_a[18] }];
set_property -dict { PACKAGE_PIN H21 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_a[17] }];
set_property -dict { PACKAGE_PIN H20 IOSTANDARD LVCMOS33 } [get_ports { fmc_sp_to_fpga_a[16] }];
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 } [get_ports { seq_to_sp_misc_a }];
set_property -dict { PACKAGE_PIN G11 IOSTANDARD LVCMOS33 } [get_ports { seq_to_sp_misc_b  }];
set_property -dict { PACKAGE_PIN F11 IOSTANDARD LVCMOS33 } [get_ports { seq_to_sp_misc_c }];
set_property -dict { PACKAGE_PIN G10 IOSTANDARD LVCMOS33 } [get_ports { seq_to_sp_misc_d }];
set_property -dict { PACKAGE_PIN E11 IOSTANDARD LVCMOS33 } [get_ports { seq_to_sp_int_l }];
set_property -dict { PACKAGE_PIN D11 IOSTANDARD LVCMOS33 } [get_ports { fpga_to_sp_irq1_l }];
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports { fpga_to_sp_irq2_l }];
set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports { fpga_to_sp_irq3_l }];
set_property -dict { PACKAGE_PIN F12 IOSTANDARD LVCMOS33 } [get_ports { fpga_to_sp_irq4_l }];
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { uart0_sp_to_fpga_dat }];
set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS33 } [get_ports { uart0_fpga_to_sp_dat }];
set_property -dict { PACKAGE_PIN D13 IOSTANDARD LVCMOS33 } [get_ports { uart0_sp_to_fpga_rts_l }];
set_property -dict { PACKAGE_PIN C13 IOSTANDARD LVCMOS33 } [get_ports { uart0_fpga_to_sp_rts_l }];
set_property -dict { PACKAGE_PIN B13 IOSTANDARD LVCMOS33 } [get_ports { uart1_sp_to_fpga_dat }];
set_property -dict { PACKAGE_PIN A12 IOSTANDARD LVCMOS33 } [get_ports { uart1_fpga_to_sp_dat }];
set_property -dict { PACKAGE_PIN A13 IOSTANDARD LVCMOS33 } [get_ports { uart1_sp_to_fpga_rts_l }];
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports { uart1_fpga_to_sp_rts_l }];
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports { uart_local_sp_to_fpga_dat }];
set_property -dict { PACKAGE_PIN D15 IOSTANDARD LVCMOS33 } [get_ports { uart_local_fpga_to_sp_dat }];
set_property -dict { PACKAGE_PIN D12 IOSTANDARD LVCMOS33 } [get_ports { uart_local_sp_to_fpga_rts_l }];
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { uart_local_fpga_to_sp_rts_l }];
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports { sp_to_seq_system_reset_l }];
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports { seq_rev_id[2] }];
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports { seq_rev_id[1] }];
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports { seq_rev_id[0] }];
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash_cs_l }];
set_property -dict { PACKAGE_PIN E15 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash_clk }];
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash_dat[3] }];
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash_dat[2] }];
set_property -dict { PACKAGE_PIN B14 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash_dat[1] }];
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash_dat[0] }];
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash2_cs_l }];
set_property -dict { PACKAGE_PIN A19 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash2_clk }];
set_property -dict { PACKAGE_PIN A20 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash2_dat[3] }];
set_property -dict { PACKAGE_PIN B20 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash2_dat[2] }];
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash2_dat[1] }];
set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 } [get_ports { spi_fpga_to_flash2_dat[0] }];
set_property -dict { PACKAGE_PIN C18 IOSTANDARD LVCMOS33 } [get_ports { i3c_sp5_to_fpga_oe_n_3v3 }];
set_property -dict { PACKAGE_PIN C19 IOSTANDARD LVCMOS33 } [get_ports { i3c_fpga_to_dimm_oe_n_3v3 }];
set_property -dict { PACKAGE_PIN R2 IOSTANDARD LVCMOS18 } [get_ports { uart0_sp5_to_fpga_data }];
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS18 } [get_ports { uart0_fpga_to_sp5_data }];
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS18 } [get_ports { uart0_sp5_to_fpga_rts_l }];
set_property -dict { PACKAGE_PIN T7 IOSTANDARD LVCMOS18 } [get_ports { uart0_fpga_to_sp5_rts_l }];
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS18 } [get_ports { uart1_scm_to_hpm_dat }];
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS18 } [get_ports { uart1_hpm_to_scm_dat }];
set_property -dict { PACKAGE_PIN T8 IOSTANDARD LVCMOS18 } [get_ports { fpga_spare_1v8[7] }];
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS18 } [get_ports { fpga_spare_1v8[6] }];
set_property -dict { PACKAGE_PIN V6 IOSTANDARD LVCMOS18 } [get_ports { fpga_spare_1v8[5] }];
set_property -dict { PACKAGE_PIN V1 IOSTANDARD LVCMOS18 } [get_ports { fpga_spare_1v8[4] }];
set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS18 } [get_ports { fpga_spare_1v8[3] }];
set_property -dict { PACKAGE_PIN W1 IOSTANDARD LVCMOS18 } [get_ports { fpga_spare_1v8[2] }];
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS18 } [get_ports { fpga_spare_1v8[1] }];
set_property -dict { PACKAGE_PIN W2 IOSTANDARD LVCMOS18 } [get_ports { fpga_spare_1v8[0] }];
set_property -dict { PACKAGE_PIN Y1 IOSTANDARD LVCMOS18 } [get_ports { espi_hpm_to_scm_reset_l }];
# espi boot wants alert to be data[1], but it's annoying to carry that rename through the desig
# so we swapped them here
#set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS18 } [get_ports { espi_scm_to_hpm_alert_l }];
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS18 } [get_ports { espi_scm_to_hpm_alert_l }];
set_property -dict { PACKAGE_PIN U1 IOSTANDARD LVCMOS18 } [get_ports { espi_hpm_to_scm_cs_l }];
set_property -dict { PACKAGE_PIN W3 IOSTANDARD LVCMOS18 } [get_ports { espi_hpm_to_scm_clk }];
set_property -dict { PACKAGE_PIN T3 IOSTANDARD LVCMOS18 } [get_ports { espi_hpm_to_scm_dat[3] }];
set_property -dict { PACKAGE_PIN U3 IOSTANDARD LVCMOS18 } [get_ports { espi_hpm_to_scm_dat[2] }];
set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS18 } [get_ports { espi_hpm_to_scm_dat[1] }];
set_property -dict { PACKAGE_PIN Y3 IOSTANDARD LVCMOS18 } [get_ports { espi_hpm_to_scm_dat[0] }];
set_property SLEW FAST [get_ports espi_hpm_to_scm_dat[*]]
set_property -dict { PACKAGE_PIN AA6 IOSTANDARD LVCMOS18 } [get_ports { i3c_hpm_to_scm_dimm0_abcdef_scl }];
set_property -dict { PACKAGE_PIN AB6 IOSTANDARD LVCMOS18 } [get_ports { i3c_hpm_to_scm_dimm0_abcdef_sda }];
set_property -dict { PACKAGE_PIN Y6 IOSTANDARD LVCMOS18 } [get_ports { i3c_hpm_to_scm_dimm0_ghijkl_scl }];
set_property -dict { PACKAGE_PIN Y5 IOSTANDARD LVCMOS18 } [get_ports { i3c_hpm_to_scm_dimm0_ghijkl_sda }];
set_property -dict { PACKAGE_PIN Y4 IOSTANDARD LVCMOS18 } [get_ports { i3c_hpm_to_scm_dimm1_abcdef_scl }];
set_property -dict { PACKAGE_PIN AA3 IOSTANDARD LVCMOS18 } [get_ports { i3c_hpm_to_scm_dimm1_abcdef_sda }];
set_property -dict { PACKAGE_PIN AB3 IOSTANDARD LVCMOS18 } [get_ports { i3c_hpm_to_scm_dimm1_ghijkl_scl }];
set_property -dict { PACKAGE_PIN AB2 IOSTANDARD LVCMOS18 } [get_ports { i3c_hpm_to_scm_dimm1_ghijkl_sda }];
set_property -dict { PACKAGE_PIN AA1 IOSTANDARD LVCMOS18 PULLUP true } [get_ports { i3c_scm_to_dimm0_abcdef_scl }];
set_property -dict { PACKAGE_PIN AB5 IOSTANDARD LVCMOS18 PULLUP true } [get_ports { i3c_scm_to_dimm0_abcdef_sda }];
set_property -dict { PACKAGE_PIN AB4 IOSTANDARD LVCMOS18 } [get_ports { i3c_scm_to_dimm0_ghijkl_scl }];
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS18 } [get_ports { i3c_scm_to_dimm0_ghijkl_sda }];
set_property -dict { PACKAGE_PIN W8 IOSTANDARD LVCMOS18 } [get_ports { i3c_scm_to_dimm1_abcdef_scl }];
set_property -dict { PACKAGE_PIN Y8 IOSTANDARD LVCMOS18 } [get_ports { i3c_scm_to_dimm1_abcdef_sda }];
set_property -dict { PACKAGE_PIN AA8 IOSTANDARD LVCMOS18 } [get_ports { i3c_scm_to_dimm1_ghijkl_scl }];
set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS18 } [get_ports { i3c_scm_to_dimm1_ghijkl_sda }];
set_property -dict { PACKAGE_PIN H7 IOSTANDARD LVCMOS33 } [get_ports { hdt_scm_to_hpm_tck }];
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 } [get_ports { hdt_scm_to_spm_tms }];
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 } [get_ports { hdt_scm_to_spm_dat }];
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports { hdt_hpm_to_scm_dat }];
set_property -dict { PACKAGE_PIN H3 IOSTANDARD LVCMOS33 } [get_ports { scm_to_hpm_fw_recovery }];
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports { hpm_to_scm_stby_rdy }];
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports { scm_to_hpm_stby_en }];
set_property -dict { PACKAGE_PIN K3 IOSTANDARD LVCMOS33 } [get_ports { scm_to_hpm_stby_rst_l }];
set_property -dict { PACKAGE_PIN K2 IOSTANDARD LVCMOS33 } [get_ports { scm_to_hpm_pwrbtn_l }];
set_property -dict { PACKAGE_PIN H6 IOSTANDARD LVCMOS33 } [get_ports { hpm_to_scm_pwrok }];
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } [get_ports { scm_to_hpm_dbreq_l }];
set_property -dict { PACKAGE_PIN K6 IOSTANDARD LVCMOS33 } [get_ports { hpm_to_scm_pcie_rst_buf_l }];
set_property -dict { PACKAGE_PIN J6 IOSTANDARD LVCMOS33 } [get_ports { hpm_to_scm_spare[1] }];
set_property -dict { PACKAGE_PIN L7 IOSTANDARD LVCMOS33 } [get_ports { hpm_to_scm_spare[0] }];
set_property -dict { PACKAGE_PIN J8 IOSTANDARD LVCMOS33 } [get_ports { scm_to_hpm_rot_cpu_rst_l }];
set_property -dict { PACKAGE_PIN J7 IOSTANDARD LVCMOS33 } [get_ports { hpm_to_scm_chassis_intr_l }];
set_property -dict { PACKAGE_PIN L6 IOSTANDARD LVCMOS33 } [get_ports { hpm_to_scm_irq_l }];
set_property -dict { PACKAGE_PIN L5 IOSTANDARD LVCMOS33 } [get_ports { scm_to_hpm_virtual_reseat }];
set_property -dict { PACKAGE_PIN K5 IOSTANDARD LVCMOS33 } [get_ports { uart_spare_scm_to_hpm_dat }];
set_property -dict { PACKAGE_PIN L4 IOSTANDARD LVCMOS33 } [get_ports { uart_spare_hpm_to_scm_dat }];
set_property -dict { PACKAGE_PIN M4 IOSTANDARD LVCMOS33 } [get_ports { qspi0_hpm_to_scm_clk }];
set_property -dict { PACKAGE_PIN M3 IOSTANDARD LVCMOS33 } [get_ports { qspi0_hpm_to_scm_cs0_l }];
set_property -dict { PACKAGE_PIN N6 IOSTANDARD LVCMOS33 } [get_ports { qspi0_hpm_to_scm_cs1_l }];
set_property -dict { PACKAGE_PIN M1 IOSTANDARD LVCMOS33 } [get_ports { qspi0_hpm_to_scm_dat3 }];
set_property -dict { PACKAGE_PIN M2 IOSTANDARD LVCMOS33 } [get_ports { qspi0_hpm_to_scm_dat2 }];
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 } [get_ports { qspi0_hpm_to_scm_dat1 }];
set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS33 } [get_ports { qspi0_hpm_to_scm_dat0 }];
set_property -dict { PACKAGE_PIN N4 IOSTANDARD LVCMOS33 } [get_ports { sgpio_scm_to_hpm_clk }];
set_property -dict { PACKAGE_PIN P2 IOSTANDARD LVCMOS33 } [get_ports { sgpio_scm_to_hpm_dat[1] }];
set_property -dict { PACKAGE_PIN P1 IOSTANDARD LVCMOS33 } [get_ports { sgpio_scm_to_hpm_dat[0] }];
set_property -dict { PACKAGE_PIN P8 IOSTANDARD LVCMOS33 } [get_ports { sgpio_hpm_to_scm_dat[1] }];
set_property -dict { PACKAGE_PIN N1 IOSTANDARD LVCMOS33 } [get_ports { sgpio_hpm_to_scm_dat[0] }];
set_property -dict { PACKAGE_PIN N8 IOSTANDARD LVCMOS33 } [get_ports { sgpio_scm_to_hpm_ld[1] }];
set_property -dict { PACKAGE_PIN P3 IOSTANDARD LVCMOS33 } [get_ports { sgpio_scm_to_hpm_ld[0] }];
set_property -dict { PACKAGE_PIN N5 IOSTANDARD LVCMOS33 } [get_ports { sgpio_scm_to_hpm_reset_l }];
set_property -dict { PACKAGE_PIN M5 IOSTANDARD LVCMOS33 } [get_ports { sgpio_hpm_to_scm_intr_l }];
set_property -dict { PACKAGE_PIN P7 IOSTANDARD LVCMOS33 } [get_ports { qspi1_scm_to_hpm_clk  }];
set_property -dict { PACKAGE_PIN N7 IOSTANDARD LVCMOS33 } [get_ports { qspi1_scm_to_hpm_cs_l }];
set_property -dict { PACKAGE_PIN R4 IOSTANDARD LVCMOS33 } [get_ports { qspi1_scm_to_hpm_dat[3] }];
set_property -dict { PACKAGE_PIN R5 IOSTANDARD LVCMOS33 } [get_ports { qspi1_scm_to_hpm_dat[2] }];
set_property -dict { PACKAGE_PIN R6 IOSTANDARD LVCMOS33 } [get_ports { qspi1_scm_to_hpm_dat[1] }];
set_property -dict { PACKAGE_PIN R7 IOSTANDARD LVCMOS33 } [get_ports { qspi1_scm_to_hpm_dat[0] }];
set_property -dict { PACKAGE_PIN R3 IOSTANDARD LVCMOS33 } [get_ports { spi_hpm_to_scm_tpm_cs_l }];
set_property -dict { PACKAGE_PIN F8 IOSTANDARD LVCMOS33 } [get_ports { i2c_sp_to_fpga_scl }];
set_property -dict { PACKAGE_PIN F5 IOSTANDARD LVCMOS33 } [get_ports { i2c_sp_to_fpga_sda }];
set_property -dict { PACKAGE_PIN E8 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl0 }];
set_property -dict { PACKAGE_PIN B9 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda0 }];
set_property -dict { PACKAGE_PIN A9 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl1 }];
set_property -dict { PACKAGE_PIN B10 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda1 }];
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl3 }];
set_property -dict { PACKAGE_PIN C9 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda3 }];
set_property -dict { PACKAGE_PIN C8 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl4 }];
set_property -dict { PACKAGE_PIN A7 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda4 }];
set_property -dict { PACKAGE_PIN A6 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl5 }];
set_property -dict { PACKAGE_PIN B8 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda5 }];
set_property -dict { PACKAGE_PIN B7 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl8 }];
set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda8 }];
set_property -dict { PACKAGE_PIN D7 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl9 }];
set_property -dict { PACKAGE_PIN C6 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda9 }];
set_property -dict { PACKAGE_PIN C5 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl11 }];
set_property -dict { PACKAGE_PIN D6 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda11 }];
set_property -dict { PACKAGE_PIN D5 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_scl12 }];
set_property -dict { PACKAGE_PIN G8 IOSTANDARD LVCMOS33 } [get_ports { i2c_scm_to_hpm_sda12 }];
set_property -dict { PACKAGE_PIN B1 IOSTANDARD LVCMOS33 } [get_ports { fpga_to_fruid_scl }];
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports { fpga_to_fruid_sda }];