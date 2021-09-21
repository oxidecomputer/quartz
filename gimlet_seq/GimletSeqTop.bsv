// Copyright 2021 Oxide Computer Company

package GimletSeqTop;

import MetaSync::*;

//SPI interface

(* always_enabled *)
interface Top;
    
endinterface

TBD: seq_to_sp3_sys_rst_l

interface SeqInputPins;
    sp3_to_seq_thermtrip_l
    pwr_cont1_sp3_nvrhot
    sp3_to_seq_v1p8_s5_pg
    seq_to_clk_gpio1        // TODO: input or output?
    seq_to_clk_gpio2        // TODO: input or output?
    seq_to_clk_gpio3        // TODO: input or output?
    seq_to_clk_gpio4        // TODO: input or output?
    seq_to_clk_gpio5        // TODO: input or output?
    seq_to_clk_gpio8        // TODO: input or output?
    seq_to_clk_gpio9        // TODO: input or output?
    seq_to_sp3_sys_rst_l    // TODO: input or output?
    sp3_to_seq_fsr_req_l    // TODO: input or output?
    pwr_cont_dimm_efgh_pg0
    pwr_cont_dimm_abcd_pg2
    pwr_cont2_sp3_pg1
    pwr_cont_dimm_abcd_cfp
    pwr_cont_nic_pg0
    pwr_cont_nic_nvrhot
    pwr_cont_dimm_efgh_pg1
    pwr_cont2_sp3_pwrok
    sp3_to_seq_v3p3_s5_pg
    pwr_cont1_sp3_pwrok
    seq_to_clk_ntest
    pwr_cont_dimm_abcd_pg0
    dimm_to_seq_abcd_v2p5_pg
    dimm_to_seq_efgh_v2p5_pg
    sp3_to_sp_slp_s3_l
    pwr_cont2_sp3_pg0
    sp3_to_sp_slp_s5_l
    vtt_efgh_a0_to_seq_pg_l
    pwr_cont1_sp3_pg1
    pwr_cont2_sp3_nvrhot
    pwr_cont_dimm_efgh_pg2
    pwr_cont1_sp3_pg0
    sp3_to_seq_v0p9_vdd_soc_s5_pg
    pwr_cont_nic_cfp
    pwr_cont_dimm_abcd_pg1
    
endinterface

interface SeqOutputPins;
    seq_to_dimm_efgh_v2p5_en
    pwr_cont_dimm_efgh_cfp
    pwr_cont_dimm_abcd_en1
    seq_to_nic_v1p2_enet_en
    seq_to_nic_comb_pg
    pwr_cont_dimm_efgh_en0
    pwr_cont_dimm_efgh_en2
    sp3_to_seq_rtc_v1p5_en
    pwr_cont1_sp3_cfp
    seq_to_sp3_v1p8_en
    pwr_cont2_sp3_en
    seq_to_dimm_abcd_v2p5_en
    seq_to_sp3_v1p5_rtc_en
    pwr_cont_nic_en1
    seq_to_sp3_v1p8_s5_en
    pwr_cont_dimm_abcd_en2
    pwr_cont_nic_en0
    pwr_cont_dimm_abcd_en0
    seq_to_nic_cld_rst_l
    seq_to_sp3_v0p9_s5_en
    pwr_cont_dimm_efgh_en1
    clk_to_seq_nmr_l
    sp_to_sp3_pwr_btn_l

endinterface

(* synthesize, default_clock_osc="clk50m" *)
module mkGimletSeq (Top);
    Fans fan_block <- mkFans();

    // Meta-harden inputs.
endmodule

endpackage: GimletSeqTop