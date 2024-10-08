
// Generated by Bluespec Compiler, version 2021.07 (build 4cac6eb)
//
// On Thu Oct 14 19:09:29 CDT 2021
//
//
// Ports:
// Name                         I/O  size props
// cipo                           O     1 reg
// seq_to_nic_v1p2_enet_en        O     1 reg
// seq_to_nic_comb_pg             O     1 reg
// pwr_cont_nic_en1               O     1 reg
// pwr_cont_nic_en0               O     1 reg
// seq_to_nic_cld_rst_l           O     1 reg
// seq_to_nic_v1p5a_en            O     1 reg
// seq_to_nic_v1p5d_en            O     1 reg
// seq_to_nic_v1p2_en             O     1 reg
// seq_to_nic_v1p1_en             O     1 reg
// seq_to_nic_ldo_v3p3_en         O     1 reg
// nic_to_sp3_pwrflt_l            O     1 reg
// seq_to_fanhp_restart_l         O     1 reg
// seq_to_fan_hp_en               O     1 reg
// seq_to_dimm_efgh_v2p5_en       O     1 reg
// seq_to_dimm_abcd_v2p5_en       O     1 reg
// seq_to_sp3_v3p3_s5_en          O     1 reg
// seq_to_sp3_v1p5_rtc_en         O     1 reg
// seq_to_sp3_v1p8_s5_en          O     1 reg
// seq_to_sp3_v0p9_s5_en          O     1 reg
// seq_to_sp3_rsmrst_v3p3_l       O     1 reg
// seq_to_sp3_sys_rst_l           O     1 reg
// pwr_cont_dimm_abcd_en1         O     1 reg
// pwr_cont_dimm_efgh_en0         O     1 reg
// pwr_cont_dimm_efgh_en2         O     1 reg
// pwr_cont2_sp3_pwrok            O     1 reg
// seq_to_sp3_v1p8_en             O     1 reg
// pwr_cont1_sp3_pwrok            O     1 reg
// pwr_cont2_sp3_en               O     1 reg
// pwr_cont1_sp3_en               O     1 reg
// pwr_cont_dimm_abcd_en2         O     1 reg
// pwr_cont_dimm_abcd_en0         O     1 reg
// pwr_cont_dimm_efgh_en1         O     1 reg
// sp_to_sp3_pwr_btn_l            O     1 reg
// seq_to_vtt_efgh_en             O     1 reg
// seq_to_sp3_pwr_good            O     1 reg
// seq_to_vtt_abcd_a0_en          O     1 reg
// clk_to_seq_nmr_l               O     1 reg
// testpoint                      O     1 reg
// clk50m                         I     1 clock
// RST_N                          I     1 reset
// csn                            I     1
// sclk                           I     1
// copi                           I     1
// pwr_cont_nic_pg0               I     1
// pwr_cont_nic_nvrhot            I     1
// pwr_cont_nic_cfp               I     1
// nic_to_seq_v1p5a_pg_l          I     1
// nic_to_seq_v1p5d_pg_l          I     1
// nic_to_seq_v1p2_pg_l           I     1
// nic_to_seq_v1p1_pg_l           I     1
// pwr_cont_nic_pg1               I     1
// fanhp_to_seq_fault_l           I     1
// fan_to_seq_fan_fail            I     1
// fanhp_to_seq_pwrgd             I     1
// dimm_to_seq_abcd_v2p5_pg       I     1
// dimm_to_seq_efgh_v2p5_pg       I     1
// sp3_to_seq_v1p8_s5_pg          I     1
// sp3_to_seq_rtc_v1p5_en         I     1
// sp3_to_seq_v3p3_s5_pg          I     1
// sp3_to_seq_v0p9_vdd_soc_s5_pg  I     1
// sp3_to_seq_pwrgd_out           I     1
// pwr_cont_dimm_efgh_cfp         I     1
// pwr_cont1_sp3_nvrhot           I     1
// pwr_cont_dimm_efgh_pg0         I     1
// pwr_cont1_sp3_cfp              I     1
// pwr_cont2_sp3_pg1              I     1
// pwr_cont_dimm_abcd_pg2         I     1
// pwr_cont_dimm_abcd_cfp         I     1
// pwr_cont_dimm_efgh_pg1         I     1
// pwr_cont_dimm_abcd_pg0         I     1
// sp3_to_sp_slp_s3_l             I     1
// pwr_cont2_sp3_pg0              I     1
// sp3_to_sp_slp_s5_l             I     1
// vtt_efgh_a0_to_seq_pg_l        I     1
// pwr_cont1_sp3_pg1              I     1
// pwr_cont2_sp3_nvrhot           I     1
// pwr_cont_dimm_efgh_pg2         I     1
// pwr_cont1_sp3_pg0              I     1
// pwr_cont_dimm_abcd_pg1         I     1
// pwr_cont2_sp3_cfp              I     1
// seq_v1p8_sp3_vdd_pg_l          I     1
// sp3_to_seq_pwrok_v3p3          I     1
// pwr_cont_dimm_efgh_nvrhot      I     1
// sp3_to_seq_reset_v3p3_l        I     1
// pwr_cont_dimm_abcd_nvrhot      I     1
// vtt_abcd_a0_to_seq_pg_l        I     1
// sp3_to_seq_thermtrip_l         I     1
// sp3_to_seq_fsr_req_l           I     1
// seq_to_clk_gpio3               I     1
// seq_to_clk_gpio9               I     1
// seq_to_clk_gpio8               I     1
// seq_to_clk_gpio2               I     1
// seq_to_clk_gpio1               I     1
// seq_to_clk_gpio5               I     1
// seq_to_clk_gpio4               I     1
//
// No combinational paths from inputs to outputs
//
//

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif

module mkGimletSeqTop(clk50m,
		      RST_N,

		      csn,

		      sclk,

		      copi,

		      cipo,

		      pwr_cont_nic_pg0,

		      pwr_cont_nic_nvrhot,

		      pwr_cont_nic_cfp,

		      nic_to_seq_v1p5a_pg_l,

		      nic_to_seq_v1p5d_pg_l,

		      nic_to_seq_v1p2_pg_l,

		      nic_to_seq_v1p1_pg_l,

		      pwr_cont_nic_pg1,

		      fanhp_to_seq_fault_l,

		      fan_to_seq_fan_fail,

		      fanhp_to_seq_pwrgd,

		      dimm_to_seq_abcd_v2p5_pg,

		      dimm_to_seq_efgh_v2p5_pg,

		      sp3_to_seq_v1p8_s5_pg,

		      sp3_to_seq_rtc_v1p5_en,

		      sp3_to_seq_v3p3_s5_pg,

		      sp3_to_seq_v0p9_vdd_soc_s5_pg,

		      sp3_to_seq_pwrgd_out,

		      pwr_cont_dimm_efgh_cfp,

		      pwr_cont1_sp3_nvrhot,

		      pwr_cont_dimm_efgh_pg0,

		      pwr_cont1_sp3_cfp,

		      pwr_cont2_sp3_pg1,

		      pwr_cont_dimm_abcd_pg2,

		      pwr_cont_dimm_abcd_cfp,

		      pwr_cont_dimm_efgh_pg1,

		      pwr_cont_dimm_abcd_pg0,

		      sp3_to_sp_slp_s3_l,

		      pwr_cont2_sp3_pg0,

		      sp3_to_sp_slp_s5_l,

		      vtt_efgh_a0_to_seq_pg_l,

		      pwr_cont1_sp3_pg1,

		      pwr_cont2_sp3_nvrhot,

		      pwr_cont_dimm_efgh_pg2,

		      pwr_cont1_sp3_pg0,

		      pwr_cont_dimm_abcd_pg1,

		      pwr_cont2_sp3_cfp,

		      seq_v1p8_sp3_vdd_pg_l,

		      sp3_to_seq_pwrok_v3p3,

		      pwr_cont_dimm_efgh_nvrhot,

		      sp3_to_seq_reset_v3p3_l,

		      pwr_cont_dimm_abcd_nvrhot,

		      vtt_abcd_a0_to_seq_pg_l,

		      sp3_to_seq_thermtrip_l,

		      sp3_to_seq_fsr_req_l,

		      seq_to_clk_gpio3,

		      seq_to_clk_gpio9,

		      seq_to_clk_gpio8,

		      seq_to_clk_gpio2,

		      seq_to_clk_gpio1,

		      seq_to_clk_gpio5,

		      seq_to_clk_gpio4,

		      seq_to_nic_v1p2_enet_en,

		      seq_to_nic_comb_pg,

		      pwr_cont_nic_en1,

		      pwr_cont_nic_en0,

		      seq_to_nic_cld_rst_l,

		      seq_to_nic_v1p5a_en,

		      seq_to_nic_v1p5d_en,

		      seq_to_nic_v1p2_en,

		      seq_to_nic_v1p1_en,

		      seq_to_nic_ldo_v3p3_en,

		      nic_to_sp3_pwrflt_l,

		      seq_to_fanhp_restart_l,

		      seq_to_fan_hp_en,

		      seq_to_dimm_efgh_v2p5_en,

		      seq_to_dimm_abcd_v2p5_en,

		      seq_to_sp3_v3p3_s5_en,

		      seq_to_sp3_v1p5_rtc_en,

		      seq_to_sp3_v1p8_s5_en,

		      seq_to_sp3_v0p9_s5_en,

		      seq_to_sp3_rsmrst_v3p3_l,

		      seq_to_sp3_sys_rst_l,

		      pwr_cont_dimm_abcd_en1,

		      pwr_cont_dimm_efgh_en0,

		      pwr_cont_dimm_efgh_en2,

		      pwr_cont2_sp3_pwrok,

		      seq_to_sp3_v1p8_en,

		      pwr_cont1_sp3_pwrok,

		      pwr_cont2_sp3_en,

		      pwr_cont1_sp3_en,

		      pwr_cont_dimm_abcd_en2,

		      pwr_cont_dimm_abcd_en0,

		      pwr_cont_dimm_efgh_en1,

		      sp_to_sp3_pwr_btn_l,

		      seq_to_vtt_efgh_en,

		      seq_to_sp3_pwr_good,

		      seq_to_vtt_abcd_a0_en,

		      clk_to_seq_nmr_l,

		      testpoint);
  input  clk50m;
  input  RST_N;

  // action method spi_pins_csn
  input  csn;

  // action method spi_pins_sclk
  input  sclk;

  // action method spi_pins_copi
  input  copi;

  // value method spi_pins_cipo
  output cipo;

  // action method in_pins_nic_pins_pwr_cont_nic_pg0
  input  pwr_cont_nic_pg0;

  // action method in_pins_nic_pins_pwr_cont_nic_nvrhot
  input  pwr_cont_nic_nvrhot;

  // action method in_pins_nic_pins_pwr_cont_nic_cfp
  input  pwr_cont_nic_cfp;

  // action method in_pins_nic_pins_nic_to_seq_v1p5a_pg_l
  input  nic_to_seq_v1p5a_pg_l;

  // action method in_pins_nic_pins_nic_to_seq_v1p5d_pg_l
  input  nic_to_seq_v1p5d_pg_l;

  // action method in_pins_nic_pins_nic_to_seq_v1p2_pg_l
  input  nic_to_seq_v1p2_pg_l;

  // action method in_pins_nic_pins_nic_to_seq_v1p1_pg_l
  input  nic_to_seq_v1p1_pg_l;

  // action method in_pins_nic_pins_pwr_cont_nic_pg1
  input  pwr_cont_nic_pg1;

  // action method in_pins_early_in_pins_fanhp_to_seq_fault_l
  input  fanhp_to_seq_fault_l;

  // action method in_pins_early_in_pins_fan_to_seq_fan_fail
  input  fan_to_seq_fan_fail;

  // action method in_pins_early_in_pins_fanhp_to_seq_pwrgd
  input  fanhp_to_seq_pwrgd;

  // action method in_pins_early_in_pins_dimm_to_seq_abcd_v2p5_pg
  input  dimm_to_seq_abcd_v2p5_pg;

  // action method in_pins_early_in_pins_dimm_to_seq_efgh_v2p5_pg
  input  dimm_to_seq_efgh_v2p5_pg;

  // action method in_pins_a1_pins_sp3_to_seq_v1p8_s5_pg
  input  sp3_to_seq_v1p8_s5_pg;

  // action method in_pins_a1_pins_sp3_to_seq_rtc_v1p5_en
  input  sp3_to_seq_rtc_v1p5_en;

  // action method in_pins_a1_pins_sp3_to_seq_v3p3_s5_pg
  input  sp3_to_seq_v3p3_s5_pg;

  // action method in_pins_a1_pins_sp3_to_seq_v0p9_vdd_soc_s5_pg
  input  sp3_to_seq_v0p9_vdd_soc_s5_pg;

  // action method in_pins_a0_pins_sp3_to_seq_pwrgd_out
  input  sp3_to_seq_pwrgd_out;

  // action method in_pins_a0_pins_pwr_cont_dimm_efgh_cfp
  input  pwr_cont_dimm_efgh_cfp;

  // action method in_pins_a0_pins_pwr_cont1_sp3_nvrhot
  input  pwr_cont1_sp3_nvrhot;

  // action method in_pins_a0_pins_pwr_cont_dimm_efgh_pg0
  input  pwr_cont_dimm_efgh_pg0;

  // action method in_pins_a0_pins_pwr_cont1_sp3_cfp
  input  pwr_cont1_sp3_cfp;

  // action method in_pins_a0_pins_pwr_cont2_sp3_pg1
  input  pwr_cont2_sp3_pg1;

  // action method in_pins_a0_pins_pwr_cont_dimm_abcd_pg2
  input  pwr_cont_dimm_abcd_pg2;

  // action method in_pins_a0_pins_pwr_cont_dimm_abcd_cfp
  input  pwr_cont_dimm_abcd_cfp;

  // action method in_pins_a0_pins_pwr_cont_dimm_efgh_pg1
  input  pwr_cont_dimm_efgh_pg1;

  // action method in_pins_a0_pins_pwr_cont_dimm_abcd_pg0
  input  pwr_cont_dimm_abcd_pg0;

  // action method in_pins_a0_pins_sp3_to_sp_slp_s3_l
  input  sp3_to_sp_slp_s3_l;

  // action method in_pins_a0_pins_pwr_cont2_sp3_pg0
  input  pwr_cont2_sp3_pg0;

  // action method in_pins_a0_pins_sp3_to_sp_slp_s5_l
  input  sp3_to_sp_slp_s5_l;

  // action method in_pins_a0_pins_vtt_efgh_a0_to_seq_pg_l
  input  vtt_efgh_a0_to_seq_pg_l;

  // action method in_pins_a0_pins_pwr_cont1_sp3_pg1
  input  pwr_cont1_sp3_pg1;

  // action method in_pins_a0_pins_pwr_cont2_sp3_nvrhot
  input  pwr_cont2_sp3_nvrhot;

  // action method in_pins_a0_pins_pwr_cont_dimm_efgh_pg2
  input  pwr_cont_dimm_efgh_pg2;

  // action method in_pins_a0_pins_pwr_cont1_sp3_pg0
  input  pwr_cont1_sp3_pg0;

  // action method in_pins_a0_pins_pwr_cont_dimm_abcd_pg1
  input  pwr_cont_dimm_abcd_pg1;

  // action method in_pins_a0_pins_pwr_cont2_sp3_cfp
  input  pwr_cont2_sp3_cfp;

  // action method in_pins_a0_pins_seq_v1p8_sp3_vdd_pg_l
  input  seq_v1p8_sp3_vdd_pg_l;

  // action method in_pins_a0_pins_sp3_to_seq_pwrok_v3p3
  input  sp3_to_seq_pwrok_v3p3;

  // action method in_pins_a0_pins_pwr_cont_dimm_efgh_nvrhot
  input  pwr_cont_dimm_efgh_nvrhot;

  // action method in_pins_a0_pins_sp3_to_seq_reset_v3p3_l
  input  sp3_to_seq_reset_v3p3_l;

  // action method in_pins_a0_pins_pwr_cont_dimm_abcd_nvrhot
  input  pwr_cont_dimm_abcd_nvrhot;

  // action method in_pins_a0_pins_vtt_abcd_a0_to_seq_pg_l
  input  vtt_abcd_a0_to_seq_pg_l;

  // action method in_pins_misc_pins_sp3_to_seq_thermtrip_l
  input  sp3_to_seq_thermtrip_l;

  // action method in_pins_misc_pins_sp3_to_seq_fsr_req_l
  input  sp3_to_seq_fsr_req_l;

  // action method in_pins_misc_pins_seq_to_clk_gpio3
  input  seq_to_clk_gpio3;

  // action method in_pins_misc_pins_seq_to_clk_gpio9
  input  seq_to_clk_gpio9;

  // action method in_pins_misc_pins_seq_to_clk_gpio8
  input  seq_to_clk_gpio8;

  // action method in_pins_misc_pins_seq_to_clk_gpio2
  input  seq_to_clk_gpio2;

  // action method in_pins_misc_pins_seq_to_clk_gpio1
  input  seq_to_clk_gpio1;

  // action method in_pins_misc_pins_seq_to_clk_gpio5
  input  seq_to_clk_gpio5;

  // action method in_pins_misc_pins_seq_to_clk_gpio4
  input  seq_to_clk_gpio4;

  // value method out_pins_nic_pins_seq_to_nic_v1p2_enet_en
  output seq_to_nic_v1p2_enet_en = 1;

  // value method out_pins_nic_pins_seq_to_nic_comb_pg
  output seq_to_nic_comb_pg = 1;

  // value method out_pins_nic_pins_pwr_cont_nic_en1
  output pwr_cont_nic_en1 = 1;

  // value method out_pins_nic_pins_pwr_cont_nic_en0
  output pwr_cont_nic_en0 = 1;

  // value method out_pins_nic_pins_seq_to_nic_cld_rst_l
  output seq_to_nic_cld_rst_l = 1;

  // value method out_pins_nic_pins_seq_to_nic_v1p5a_en
  output seq_to_nic_v1p5a_en = 1;

  // value method out_pins_nic_pins_seq_to_nic_v1p5d_en
  output seq_to_nic_v1p5d_en = 1;

  // value method out_pins_nic_pins_seq_to_nic_v1p2_en
  output seq_to_nic_v1p2_en = 1;

  // value method out_pins_nic_pins_seq_to_nic_v1p1_en
  output seq_to_nic_v1p1_en = 1;

  // value method out_pins_nic_pins_seq_to_nic_ldo_v3p3_en
  output seq_to_nic_ldo_v3p3_en = 1;

  // value method out_pins_nic_pins_nic_to_sp3_pwrflt_l
  output nic_to_sp3_pwrflt_l  = 1;

  // value method out_pins_early_pins_seq_to_fanhp_restart_l
  output seq_to_fanhp_restart_l  = 1;

  // value method out_pins_early_pins_seq_to_fan_hp_en
  output seq_to_fan_hp_en = 1;

  // value method out_pins_early_pins_seq_to_dimm_efgh_v2p5_en
  output seq_to_dimm_efgh_v2p5_en = 1;
  // WORKING HERE

  // value method out_pins_early_pins_seq_to_dimm_abcd_v2p5_en
  output seq_to_dimm_abcd_v2p5_en= 1; // broken?

  // value method out_pins_a1_pins_seq_to_sp3_v3p3_s5_en
  output seq_to_sp3_v3p3_s5_en= 1;

  // value method out_pins_a1_pins_seq_to_sp3_v1p5_rtc_en
  output seq_to_sp3_v1p5_rtc_en= 1;

  // value method out_pins_a1_pins_seq_to_sp3_v1p8_s5_en
  output seq_to_sp3_v1p8_s5_en= 1;

  // value method out_pins_a1_pins_seq_to_sp3_v0p9_s5_en
  output seq_to_sp3_v0p9_s5_en= 1;

  // value method out_pins_a1_pins_seq_to_sp3_rsmrst_v3p3_l
  output seq_to_sp3_rsmrst_v3p3_l= 1;

  // value method out_pins_a0_pins_seq_to_sp3_sys_rst_l
  output seq_to_sp3_sys_rst_l= 1;

  // value method out_pins_a0_pins_pwr_cont_dimm_abcd_en1
  output pwr_cont_dimm_abcd_en1= 1;
  // BROKEN HERE
  // value method out_pins_a0_pins_pwr_cont_dimm_efgh_en0
  output pwr_cont_dimm_efgh_en0= 1;

  // value method out_pins_a0_pins_pwr_cont_dimm_efgh_en2
  output pwr_cont_dimm_efgh_en2= 1;

  // value method out_pins_a0_pins_pwr_cont2_sp3_pwrok
  output pwr_cont2_sp3_pwrok= 1;

  // value method out_pins_a0_pins_seq_to_sp3_v1p8_en
  output seq_to_sp3_v1p8_en= 1;

  // value method out_pins_a0_pins_pwr_cont1_sp3_pwrok
  output pwr_cont1_sp3_pwrok= 1;

  // value method out_pins_a0_pins_pwr_cont2_sp3_en
  output pwr_cont2_sp3_en= 1;

  // value method out_pins_a0_pins_pwr_cont1_sp3_en
  output pwr_cont1_sp3_en= 1;

  // value method out_pins_a0_pins_pwr_cont_dimm_abcd_en2
  output pwr_cont_dimm_abcd_en2= 1;

  // value method out_pins_a0_pins_pwr_cont_dimm_abcd_en0
  output pwr_cont_dimm_abcd_en0= 1;

  // value method out_pins_a0_pins_pwr_cont_dimm_efgh_en1
  output pwr_cont_dimm_efgh_en1= 1;

  // value method out_pins_a0_pins_sp_to_sp3_pwr_btn_l
  output sp_to_sp3_pwr_btn_l = 1;

  // value method out_pins_a0_pins_seq_to_vtt_efgh_en
  output seq_to_vtt_efgh_en= 1;

  // value method out_pins_a0_pins_seq_to_sp3_pwr_good
  output seq_to_sp3_pwr_good= 1;

  // value method out_pins_a0_pins_seq_to_vtt_abcd_a0_en
  output seq_to_vtt_abcd_a0_en= 1;

  // value method out_pins_misc_pins_clk_to_seq_nmr_l
  output clk_to_seq_nmr_l = 1;

  // value method out_pins_misc_pins_testpoint
  output testpoint= 1;

endmodule