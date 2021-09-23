// Copyright 2021 Oxide Computer Company

package GimletSeqTop;

import MetaSync::*;

//SPI interface

(* always_enabled *)
interface Top;
    // SPI interface
    (* prefix = "" *)
    interface SpiPeriphPins pins;
    
endinterface

TBD: seq_to_sp3_sys_rst_l

interface SeqInputPins;
    // Fans interface
    fanhp_to_seq_fault_l
    fan_to_seq_fan_fail
    fanhp_to_seq_pwrgd

    // Clock gen interface.
    seq_to_clk_gpio1        // TODO: input or output?
    seq_to_clk_gpio2        // TODO: input or output?
    seq_to_clk_gpio3        // TODO: input or output?
    seq_to_clk_gpio4        // TODO: input or output?
    seq_to_clk_gpio5        // TODO: input or output?
    seq_to_clk_gpio8        // TODO: input or output?
    seq_to_clk_gpio9        // TODO: input or output?
    

    // A1 Power-related
    sp3_to_seq_v3p3_s5_pg
    sp3_to_seq_v1p8_s5_pg
    sp3_to_seq_v0p9_vdd_soc_s5_pg
    sp3_to_sp_slp_s3_l
    sp3_to_sp_slp_s5_l

    // A0 Power-related
    pwr_cont_dimm_abcd_pg0
    pwr_cont_dimm_abcd_pg1
    pwr_cont_dimm_abcd_pg2
    pwr_cont_dimm_abcd_cfp
    pwr_cont_dimm_abcd_nvrhot

    pwr_cont_dimm_efgh_pg0
    pwr_cont_dimm_efgh_pg1
    pwr_cont_dimm_efgh_pg2
    pwr_cont_dimm_efgh_cfp
    pwr_cont_dimm_efgh_nvrhot

    //AMD interface
    sp3_to_seq_thermtrip_l
    seq_to_sp3_sys_rst_l    // TODO: input or output?
    sp3_to_seq_fsr_req_l    // TODO: input or output?
    sp3_to_seq_pwrgd_out    // TODO: input or output?
    sp3_to_seq_pwrok_v3p3   // TODO: input or output?
    sp3_to_seq_reset_v3p3_l // TODO: input or output?

    
    pwr_cont2_sp3_pg1
    pwr_cont1_sp3_nvrhot
    pwr_cont_nic_pg0
    pwr_cont_nic_nvrhot
    
    pwr_cont2_sp3_pwrok
    
    pwr_cont1_sp3_pwrok
    seq_to_clk_ntest
    
    dimm_to_seq_abcd_v2p5_pg
    dimm_to_seq_efgh_v2p5_pg
    
    pwr_cont2_sp3_pg0
    vtt_efgh_a0_to_seq_pg_l
    pwr_cont1_sp3_pg1
    pwr_cont2_sp3_nvrhot
    
    pwr_cont1_sp3_pg0

    pwr_cont_nic_cfp
    
    pwr_cont2_sp3_cfp
    seq_v1p8_sp3_vdd_pg_l
    vtt_abcd_a0_to_seq_pg_l
    
    

    // NIC interface
    pwr_cont_nic_pg1
    nic_to_seq_v1p5a_pg_l
    nic_to_seq_v1p5d_pg_l
    nic_to_seq_v1p2_pg_l
    nic_to_seq_v1p1_pg_l
    nic_to_sp3_pwrflt_l
    
endinterface

interface SeqOutputPins;
    method Bit#(1) seq_to_dimm_efgh_v2p5_en;
    method Bit#(1) pwr_cont_dimm_abcd_en1;
    method Bit#(1) seq_to_nic_v1p2_enet_en;
    method Bit#(1) seq_to_nic_comb_pg;
    method Bit#(1) pwr_cont_dimm_efgh_en0;
    method Bit#(1) pwr_cont_dimm_efgh_en2;
    method Bit#(1) sp3_to_seq_rtc_v1p5_en;
    method Bit#(1) pwr_cont1_sp3_cfp;
    method Bit#(1) seq_to_sp3_v1p8_en;
    method Bit#(1) pwr_cont2_sp3_en;
    method Bit#(1) seq_to_dimm_abcd_v2p5_en;
    method Bit#(1) seq_to_sp3_v1p5_rtc_en;
    method Bit#(1) pwr_cont_nic_en1;
    method Bit#(1) seq_to_sp3_v1p8_s5_en;
    method Bit#(1) pwr_cont_dimm_abcd_en2;
    method Bit#(1) pwr_cont_nic_en0;
    method Bit#(1) pwr_cont_dimm_abcd_en0;
    method Bit#(1) seq_to_nic_cld_rst_l;
    method Bit#(1) seq_to_sp3_v0p9_s5_en;
    method Bit#(1) pwr_cont_dimm_efgh_en1;
    method Bit#(1) clk_to_seq_nmr_l;
    method Bit#(1) sp_to_sp3_pwr_btn_l;
    method Bit#(1) seq_to_nic_v1p5a_en;
    method Bit#(1) seq_to_nic_v1p5d_en;
    method Bit#(1) seq_to_nic_v1p2_en;
    method Bit#(1) seq_to_nic_ldo_v3p3_en;
    method Bit#(1) seq_to_vtt_efgh_en;
    method Bit#(1) seq_to_sp3_pwr_good;
    method Bit#(1) seq_to_fanhp_restart_l;
    method Bit#(1) seq_to_sp3_rsmrst_v3p3_l;
    method Bit#(1) seq_to_fan_hp_en;
    method Bit#(1) seq_to_vtt_abcd_a0_en;
endinterface

(* synthesize, default_clock_osc="clk50m" *)
module mkGimletSeq (Top);
    Fans fan_block <- mkFans();

    // Meta-harden inputs.
endmodule

endpackage: GimletSeqTop