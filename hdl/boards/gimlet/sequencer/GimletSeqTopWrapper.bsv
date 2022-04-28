package GimletSeqTopWrapper;

import Clocks::*;

// Cobalt-provided stuff
import ICE40::*;
import SPI::*;

// Local stuff
import GimletSeqTop::*;

(* always_enabled *)
interface RawInputPins;
    (* prefix = "" *)
    method Action nic_to_seq_v1p1_pg((* port = "nic_to_seq_v1p1_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_rev_id0((* port = "seq_rev_id0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_rev_id1((* port = "seq_rev_id1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p5a_pg((* port = "nic_to_seq_v1p5a_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p2_pg((* port = "nic_to_seq_v1p2_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action testpoint2((* port = "testpoint2" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p2_enet_pg((* port = "nic_to_seq_v1p2_enet_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_ext_rst_l((* port = "nic_to_seq_ext_rst_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p1_pg((* port = "nic_to_seq_v1p1_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action fanhp_to_seq_fault_l((* port = "fanhp_to_seq_fault_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action fanhp_to_seq_pwrgd((* port = "fanhp_to_seq_pwrgd" *) Bit#(1) value);
    (* prefix = "" *)
    method Action vtt_ef_a0_to_seq_pg((* port = "vtt_ef_a0_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action vtt_gh_a0_to_seq_pg((* port = "vtt_gh_a0_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio3((* port = "seq_to_clk_gpio3" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio9((* port = "seq_to_clk_gpio9" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio8((* port = "seq_to_clk_gpio8" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio2((* port = "seq_to_clk_gpio2" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_header_misc_i((* port = "seq_to_header_misc_i" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_rsw_pwren_l_via_seq((* port = "sp3_to_rsw_pwren_l_via_seq" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_efgh_pg0((* port = "pwr_cont_dimm_efgh_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio1((* port = "seq_to_clk_gpio1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio4((* port = "seq_to_clk_gpio4" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_header_misc_e((* port = "seq_to_header_misc_e" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_header_misc_f((* port = "seq_to_header_misc_f" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_header_misc_g((* port = "seq_to_header_misc_g" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_header_misc_h((* port = "seq_to_header_misc_h" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio5((* port = "seq_to_clk_gpio5" *) Bit#(1) value);
    (* prefix = "" *)
    method Action vtt_ab_a0_to_seq_pg((* port = "vtt_ab_a0_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action vtt_cd_a0_to_seq_pg((* port = "vtt_cd_a0_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_v1p8_sp3_vdd_pg((* port = "seq_v1p8_sp3_vdd_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_nic_perst_l((* port = "sp3_to_seq_nic_perst_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_sp_misc_a((* port = "seq_to_sp_misc_a" *) Bit#(1) value);
    (* prefix = "" *)
    method Action dimm_to_seq_efgh_v2p5_pg((* port = "dimm_to_seq_efgh_v2p5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action dimm_to_seq_abcd_v2p5_pg((* port = "dimm_to_seq_abcd_v2p5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_sp_misc_d((* port = "seq_to_sp_misc_d" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_v0p9_a0hp_pg((* port = "nic_v0p9_a0hp_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_pg0((* port = "pwr_cont_dimm_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action v3p3_sys_to_seq_pg((* port = "v3p3_sys_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action fan_to_seq_fan_fail((* port = "fan_to_seq_fan_fail" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_v3p3_s5_pg((* port = "sp3_to_seq_v3p3_s5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_v1p8_s5_pg((* port = "sp3_to_seq_v1p8_s5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_pg1((* port = "pwr_cont_dimm_pg1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont1_sp3_cfp((* port = "pwr_cont1_sp3_cfp" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont1_sp3_nvrhot((* port = "pwr_cont1_sp3_nvrhot" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_fsr_req_l((* port = "sp3_to_seq_fsr_req_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_pwrgd_out((* port = "sp3_to_seq_pwrgd_out" *) Bit#(1) value);
    (* prefix = "" *)
    method Action rstn((* port = "rstn" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_sp_misc_b((* port = "seq_to_sp_misc_b" *) Bit#(1) value);
    (* prefix = "" *)
    method Action copi((* port = "copi" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont2_sp3_pg1((* port = "pwr_cont2_sp3_pg1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont2_sp3_cfp((* port = "pwr_cont2_sp3_cfp" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_nvrhot((* port = "pwr_cont_dimm_nvrhot" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont1_sp3_pg0((* port = "pwr_cont1_sp3_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_reset_v3p3_l((* port = "sp3_to_seq_reset_v3p3_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_thermtrip_l((* port = "sp3_to_seq_thermtrip_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_slp_s3_l((* port = "sp3_to_seq_slp_s3_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sclk((* port = "sclk" *) Bit#(1) value);
    (* prefix = "" *)
    method Action csn((* port = "csn" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont1_sp3_pg1((* port = "pwr_cont1_sp3_pg1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_rtc_v1p5_pg((* port = "sp3_to_seq_rtc_v1p5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_pwrok_v3p3((* port = "sp3_to_seq_pwrok_v3p3" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_v0p9_vdd_soc_s5_pg((* port = "sp3_to_seq_v0p9_vdd_soc_s5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_slp_s5_l((* port = "sp3_to_seq_slp_s5_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_sp_misc_c((* port = "seq_to_sp_misc_c" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont2_sp3_pg0((* port = "pwr_cont2_sp3_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont2_sp3_nvrhot((* port = "pwr_cont2_sp3_nvrhot" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_cfp((* port = "pwr_cont_dimm_cfp" *) Bit#(1) value);
endinterface

interface RawOutputPins;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p1_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p2_enet_en;
    (* prefix = "" *)
    method Bit#(1) pwr_cont_nic_pg1;
    (* prefix = "" *)
    method Bit#(1) pwr_cont_nic_pg0;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p5a_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_ldo_v3p3_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p2_en;
    (* prefix = "" *)
    method Bit#(1) testpoint1;
    (* prefix = "" *)
    method Bit#(1) seq_rev_id2;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_cld_rst_l;
    (* prefix = "" *)
    method Bit#(1) pwr_cont_nic_en0;
    (* prefix = "" *)
    method Bit#(1) nic_to_seq_v1p5d_pg;
    (* prefix = "" *)
    method Bit#(1) pwr_cont_nic_en1;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p5d_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_clk_nmr_l;
    (* prefix = "" *)
    method Bit#(1) seq_to_clk_ntest;
    (* prefix = "" *)
    method Bit#(1) v2p5_seq_pll_a2;
    (* prefix = "" *)
    method Bit#(1) seq_to_fan_hp_en;
    (* prefix = "" *)
    method Bit#(1) clk50m_to_seq_gbin0;
    (* prefix = "" *)
    method Bit#(1) seq_to_vtt_efgh_en;
    (* prefix = "" *)
    method Bit#(1) seq_proxy_sp3_to_rsw_pwren_l;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp_interrupt;
    (* prefix = "" *)
    method Bit#(1) seq_to_led_en_l;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v0p9_a0hp_en;
    (* prefix = "" *)
    method Bit#(1) pwr_cont_dimm_efgh_en0;
    (* prefix = "" *)
    method Bit#(1) seq_to_vtt_abcd_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_perst_l;
    (* prefix = "" *)
    method Bit#(1) nic_to_sp3_pwrflt_l;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v1p8_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_dimm_abcd_v2p5_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_v3p3_sys_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_dimm_efgh_v2p5_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v3p3_s5_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v1p8_s5_en;
    (* prefix = "" *)
    method Bit#(1) pwr_cont1_sp3_pwrok;
    (* prefix = "" *)
    interface Inout#(Bit#(1)) cipo; // Output pin, tri-state when not selected.
    (* prefix = "" *)
    method Bit#(1) pwr_cont1_sp3_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v1p5_rtc_en;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_rsmrst_v3p3_l;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v0p9_s5_en;
    (* prefix = "" *)
    method Bit#(1) pwr_cont2_sp3_pwrok;
    (* prefix = "" *)
    method Bit#(1) pwr_cont_dimm_en1;
    (* prefix = "" *)
    method Bit#(1) pwr_cont_dimm_en0;
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_comb_pg_l;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_pwr_good;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_pwr_btn_l;
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_sys_rst_l;
    (* prefix = "" *)
    method Bit#(1) pwr_cont2_sp3_en;
endinterface

(* always_enabled *)
interface PinsTop;
    (* prefix = "" *)
    interface RawInputPins in_pins;
    (* prefix = "" *)
    interface RawOutputPins out_pins;
endinterface

//This is the top-level module for the Gimlet Sequencer FPGA.
(* synthesize, default_clock_osc="clk50m" *)
module mkGimletSeqTop (PinsTop);
    Clock cur_clk <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, cur_clk);
    let synth_params = GimletSeqTopParameters {one_ms_counts: 50000};    // 1ms @ 50MHz

    ICE40::Output#(Bit#(1)) cipo <- mkOutput(OutputTriState);

    let inner <- mkGimletInnerTop(synth_params, reset_by reset_sync);

    rule test (inner.spi_pins.output_en);
        cipo <= inner.spi_pins.cipo;
    endrule

    interface SpiPeripheralPinsTop spi_pins;
        method csn = inner.spi_pins.csn;
        method sclk = inner.spi_pins.sclk;
        method copi = inner.spi_pins.copi;
        interface cipo = cipo.pad;
    endinterface
    interface SequencerInputPins in_pins = inner.in_pins;
    interface SeqOutputPins out_pins = inner.out_pins;

endmodule

module mkInputSync();

    Clock clk_sys <- exposeCurrentClock();
    Reset rst_sys <- exposeCurrentReset();

    // Synchronizers
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p1_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_rev_id0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_rev_id1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p5a_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p2_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) testpoint2 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p2_enet_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_ext_rst_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p1_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) fanhp_to_seq_fault_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) fanhp_to_seq_pwrgd <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) vtt_ef_a0_to_seq_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) vtt_gh_a0_to_seq_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio3 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio9 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio8 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio2 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_header_misc_i <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_rsw_pwren_l_via_seq <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_dimm_efgh_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio4 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_header_misc_e <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_header_misc_f <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_header_misc_g <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_header_misc_h <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio5 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) vtt_ab_a0_to_seq_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) vtt_cd_a0_to_seq_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_v1p8_sp3_vdd_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_nic_perst_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_sp_misc_a <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) dimm_to_seq_efgh_v2p5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) dimm_to_seq_abcd_v2p5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_sp_misc_d <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_v0p9_a0hp_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_dimm_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) v3p3_sys_to_seq_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) fan_to_seq_fan_fail <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_v3p3_s5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_v1p8_s5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_dimm_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_fsr_req_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_pwrgd_out <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) rstn <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_sp_misc_b <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) copi <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_dimm_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_reset_v3p3_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_thermtrip_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_slp_s3_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sclk <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) csn <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_rtc_v1p5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_pwrok_v3p3 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_v0p9_vdd_soc_s5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_slp_s5_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_sp_misc_c <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_dimm_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);

    interface
        method nic_to_seq_v1p1_pg = nic_to_seq_v1p1_pg.send;
        method seq_rev_id0 = seq_rev_id0.send;
        method seq_rev_id1 = seq_rev_id1.send;
        method nic_to_seq_v1p5a_pg = nic_to_seq_v1p5a_pg.send;
        method nic_to_seq_v1p2_pg = nic_to_seq_v1p2_pg.send;
        method testpoint2 = testpoint2.send;
        method nic_to_seq_v1p2_enet_pg = nic_to_seq_v1p2_enet_pg.send;
        method nic_to_seq_ext_rst_l = nic_to_seq_ext_rst_l.send;
        method nic_to_seq_v1p1_pg = nic_to_seq_v1p1_pg.send;
        method fanhp_to_seq_fault_l = fanhp_to_seq_fault_l.send;
        method fanhp_to_seq_pwrgd = fanhp_to_seq_pwrgd.send;
        method vtt_ef_a0_to_seq_pg = vtt_ef_a0_to_seq_pg.send;
        method vtt_gh_a0_to_seq_pg = vtt_gh_a0_to_seq_pg.send;
        method seq_to_clk_gpio3 = seq_to_clk_gpio3.send;
        method seq_to_clk_gpio9 = seq_to_clk_gpio9.send;
        method seq_to_clk_gpio8 = seq_to_clk_gpio8.send;
        method seq_to_clk_gpio2 = seq_to_clk_gpio2.send;
        method seq_to_header_misc_i = seq_to_header_misc_i.send;
        method sp3_to_rsw_pwren_l_via_seq = sp3_to_rsw_pwren_l_via_seq.send;
        method pwr_cont_dimm_efgh_pg0 = pwr_cont_dimm_efgh_pg0.send;
        method seq_to_clk_gpio1 = seq_to_clk_gpio1.send;
        method seq_to_clk_gpio4 = seq_to_clk_gpio4.send;
        method seq_to_header_misc_e = seq_to_header_misc_e.send;
        method seq_to_header_misc_f = seq_to_header_misc_f.send;
        method seq_to_header_misc_g = seq_to_header_misc_g.send;
        method seq_to_header_misc_h = seq_to_header_misc_h.send;
        method seq_to_clk_gpio5 = seq_to_clk_gpio5.send;
        method vtt_ab_a0_to_seq_pg = vtt_ab_a0_to_seq_pg.send;
        method vtt_cd_a0_to_seq_pg = vtt_cd_a0_to_seq_pg.send;
        method seq_v1p8_sp3_vdd_pg = seq_v1p8_sp3_vdd_pg.send;
        method sp3_to_seq_nic_perst_l = sp3_to_seq_nic_perst_l.send;
        method seq_to_sp_misc_a = seq_to_sp_misc_a.send;
        method dimm_to_seq_efgh_v2p5_pg = dimm_to_seq_efgh_v2p5_pg.send;
        method dimm_to_seq_abcd_v2p5_pg = dimm_to_seq_abcd_v2p5_pg.send;
        method seq_to_sp_misc_d = seq_to_sp_misc_d.send;
        method nic_v0p9_a0hp_pg = nic_v0p9_a0hp_pg.send;
        method pwr_cont_dimm_pg0 = pwr_cont_dimm_pg0.send;
        method v3p3_sys_to_seq_pg = v3p3_sys_to_seq_pg.send;
        method fan_to_seq_fan_fail = fan_to_seq_fan_fail.send;
        method sp3_to_seq_v3p3_s5_pg = sp3_to_seq_v3p3_s5_pg.send;
        method sp3_to_seq_v1p8_s5_pg = sp3_to_seq_v1p8_s5_pg.send;
        method pwr_cont_dimm_pg1 = pwr_cont_dimm_pg1.send;
        method pwr_cont1_sp3_cfp = pwr_cont1_sp3_cfp.send;
        method pwr_cont1_sp3_nvrhot = pwr_cont1_sp3_nvrhot.send;
        method sp3_to_seq_fsr_req_l = sp3_to_seq_fsr_req_l.send;
        method sp3_to_seq_pwrgd_out = sp3_to_seq_pwrgd_out.send;
        method rstn = rstn.send;
        method seq_to_sp_misc_b = seq_to_sp_misc_b.send;
        method copi = copi.send;
        method pwr_cont2_sp3_pg1 = pwr_cont2_sp3_pg1.send;
        method pwr_cont2_sp3_cfp = pwr_cont2_sp3_cfp.send;
        method pwr_cont_dimm_nvrhot = pwr_cont_dimm_nvrhot.send;
        method pwr_cont1_sp3_pg0 = pwr_cont1_sp3_pg0.send;
        method sp3_to_seq_reset_v3p3_l = sp3_to_seq_reset_v3p3_l.send;
        method sp3_to_seq_thermtrip_l = sp3_to_seq_thermtrip_l.send;
        method sp3_to_seq_slp_s3_l = sp3_to_seq_slp_s3_l.send;
        method sclk = sclk.send;
        method csn = csn.send;
        method pwr_cont1_sp3_pg1 = pwr_cont1_sp3_pg1.send;
        method sp3_to_seq_rtc_v1p5_pg = sp3_to_seq_rtc_v1p5_pg.send;
        method sp3_to_seq_pwrok_v3p3 = sp3_to_seq_pwrok_v3p3.send;
        method sp3_to_seq_v0p9_vdd_soc_s5_pg = sp3_to_seq_v0p9_vdd_soc_s5_pg.send;
        method sp3_to_seq_slp_s5_l = sp3_to_seq_slp_s5_l.send;
        method seq_to_sp_misc_c = seq_to_sp_misc_c.send;
        method pwr_cont2_sp3_pg0 = pwr_cont2_sp3_pg0.send;
        method pwr_cont2_sp3_nvrhot = pwr_cont2_sp3_nvrhot.send;
        method pwr_cont_dimm_cfp = pwr_cont_dimm_cfp.send;
    endinterface

endpackage