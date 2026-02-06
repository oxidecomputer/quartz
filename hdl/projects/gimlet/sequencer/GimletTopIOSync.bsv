package GimletTopIOSync;

import Clocks::*;
import Connectable::*;
import ConfigReg::*;

// Cobalt-provided stuff
import ICE40::*;
import SPI::*;

// Local stuff
import Vector::*;
import GimletSeqTop::*;
import GimletSeqFpgaRegs::*;
import A1Block::*;
import A0Block::*;
import NicBlock::*;
import PowerRail::*;
import GimletRegs::*;
import VersionROM::*;


interface SpiPeripheralPinsTop;
    (* prefix = "" *)
    method Action csn((* port = "csn" *) Bit#(1) value);   // Chip select pin, always sampled
    (* prefix = "" *)
    method Action sclk((* port = "sclk" *) Bit#(1) value);  // sclk pin, always sampled
    (* prefix = "" *)
    method Action copi((* port = "copi" *) Bit#(1) data);   // Input data pin sampled on appropriate sclk detected edge
    interface Inout#(Bit#(1)) cipo; // Output pin, tri-state when not selected.
endinterface

interface InPins;
    (* prefix = "" *)
    method Action seq_rev_id0((* port="seq_rev_id0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_rev_id1((* port="seq_rev_id1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_rev_id2((* port="seq_rev_id2" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_nic_pg1((* port="pwr_cont_nic_pg1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_nic_pg0((* port="pwr_cont_nic_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_sp_nic_pwren_l((* port="sp3_to_sp_nic_pwren_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p5d_pg((* port="nic_to_seq_v1p5d_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p5a_pg((* port="nic_to_seq_v1p5a_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p2_pg((* port="nic_to_seq_v1p2_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p2_enet_pg((* port="nic_to_seq_v1p2_enet_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_ext_rst_l((* port="nic_to_seq_ext_rst_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_to_seq_v1p1_pg((* port="nic_to_seq_v1p1_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action fanhp_to_seq_fault_l((* port="fanhp_to_seq_fault_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action fanhp_to_seq_pwrgd((* port="fanhp_to_seq_pwrgd" *) Bit#(1) value);
    (* prefix = "" *)
    method Action vtt_ef_a0_to_seq_pg((* port="vtt_ef_a0_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action vtt_gh_a0_to_seq_pg((* port="vtt_gh_a0_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio2((* port="seq_to_clk_gpio2" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio3((* port="seq_to_clk_gpio3" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_header_misc_i((* port="seq_to_header_misc_i" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_rsw_pwren_l_via_seq((* port="sp3_to_rsw_pwren_l_via_seq" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_efgh_pg0((* port="pwr_cont_dimm_efgh_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio1((* port="seq_to_clk_gpio1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_clk_gpio4((* port="seq_to_clk_gpio4" *) Bit#(1) value);  // This toggles on a state change in the clock chip.
    (* prefix = "" *)
    method Action vtt_ab_a0_to_seq_pg((* port="vtt_ab_a0_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action vtt_cd_a0_to_seq_pg((* port="vtt_cd_a0_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_v1p8_sp3_vdd_pg((* port="seq_v1p8_sp3_vdd_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_nic_perst_l((* port="sp3_to_seq_nic_perst_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action dimm_to_seq_efgh_v2p5_pg((* port="dimm_to_seq_efgh_v2p5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action dimm_to_seq_abcd_v2p5_pg((* port="dimm_to_seq_abcd_v2p5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action nic_v0p9_a0hp_pg((* port="nic_v0p9_a0hp_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_pg0((* port="pwr_cont_dimm_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action v3p3_sys_to_seq_pg((* port="v3p3_sys_to_seq_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action fan_to_seq_fan_fail((* port="fan_to_seq_fan_fail" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_v3p3_s5_pg((* port="sp3_to_seq_v3p3_s5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_v1p8_s5_pg((* port="sp3_to_seq_v1p8_s5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_pg1((* port="pwr_cont_dimm_pg1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont1_sp3_cfp((* port="pwr_cont1_sp3_cfp" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont1_sp3_nvrhot((* port="pwr_cont1_sp3_nvrhot" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_fsr_req_l((* port="sp3_to_seq_fsr_req_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_pwrgd_out((* port="sp3_to_seq_pwrgd_out" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont2_sp3_cfp((* port="pwr_cont2_sp3_cfp" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont2_sp3_pg1((* port="pwr_cont2_sp3_pg1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_nvrhot((* port="pwr_cont_dimm_nvrhot" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont1_sp3_pg0((* port="pwr_cont1_sp3_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_reset_v3p3_l((* port="sp3_to_seq_reset_v3p3_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_thermtrip_l((* port="sp3_to_seq_thermtrip_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_slp_s3_l((* port="sp3_to_seq_slp_s3_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont1_sp3_pg1((* port="pwr_cont1_sp3_pg1" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_rtc_v1p5_pg((* port="sp3_to_seq_rtc_v1p5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_pwrok_v3p3((* port="sp3_to_seq_pwrok_v3p3" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_v0p9_vdd_soc_s5_pg((* port="sp3_to_seq_v0p9_vdd_soc_s5_pg" *) Bit#(1) value);
    (* prefix = "" *)
    method Action sp3_to_seq_slp_s5_l((* port="sp3_to_seq_slp_s5_l" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_sp_misc_a((* port="seq_to_sp_misc_a" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_sp_misc_b((* port="seq_to_sp_misc_b" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_sp_misc_c((* port="seq_to_sp_misc_c" *) Bit#(1) value);
    (* prefix = "" *)
    method Action seq_to_sp_misc_d((* port="seq_to_sp_misc_d" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont2_sp3_pg0((* port="pwr_cont2_sp3_pg0" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont2_sp3_nvrhot((* port="pwr_cont2_sp3_nvrhot" *) Bit#(1) value);
    (* prefix = "" *)
    method Action pwr_cont_dimm_cfp((* port="pwr_cont_dimm_cfp" *) Bit#(1) value);
endinterface

interface InPinsReversed;
    method Bit#(1) seq_rev_id0();
    method Bit#(1) seq_rev_id1();
    method Bit#(1) seq_rev_id2();
    method Bit#(1) pwr_cont_nic_pg1();
    method Bit#(1) pwr_cont_nic_pg0();
    method Bit#(1) sp3_to_sp_nic_pwren_l();
    method Bit#(1) nic_to_seq_v1p5d_pg();
    method Bit#(1) nic_to_seq_v1p5a_pg();
    method Bit#(1) nic_to_seq_v1p2_pg();
    method Bit#(1) nic_to_seq_v1p2_enet_pg();
    method Bit#(1) nic_to_seq_ext_rst_l();
    method Bit#(1) nic_to_seq_v1p1_pg();
    method Bit#(1) fanhp_to_seq_fault_l();
    method Bit#(1) fanhp_to_seq_pwrgd();
    method Bit#(1) vtt_ef_a0_to_seq_pg();
    method Bit#(1) vtt_gh_a0_to_seq_pg();
    method Bit#(1) seq_to_clk_gpio2();
    method Bit#(1) seq_to_clk_gpio3();
    // method Bit#(1) seq_to_header_misc_i();
    method Bit#(1) sp3_to_rsw_pwren_l_via_seq();
    method Bit#(1) pwr_cont_dimm_efgh_pg0();
    method Bit#(1) seq_to_clk_gpio1();
    method Bit#(1) seq_to_clk_gpio4();
    method Bit#(1) vtt_ab_a0_to_seq_pg();
    method Bit#(1) vtt_cd_a0_to_seq_pg();
    method Bit#(1) seq_v1p8_sp3_vdd_pg();
    method Bit#(1) sp3_to_seq_nic_perst_l();
    method Bit#(1) dimm_to_seq_efgh_v2p5_pg();
    method Bit#(1) dimm_to_seq_abcd_v2p5_pg();
    method Bit#(1) nic_v0p9_a0hp_pg();
    method Bit#(1) pwr_cont_dimm_pg0();
    method Bit#(1) v3p3_sys_to_seq_pg();
    method Bit#(1) fan_to_seq_fan_fail();
    method Bit#(1) sp3_to_seq_v3p3_s5_pg();
    method Bit#(1) sp3_to_seq_v1p8_s5_pg();
    method Bit#(1) pwr_cont_dimm_pg1();
    method Bit#(1) pwr_cont1_sp3_cfp();
    method Bit#(1) pwr_cont1_sp3_nvrhot();
    method Bit#(1) sp3_to_seq_fsr_req_l();
    method Bit#(1) sp3_to_seq_pwrgd_out();
    method Bit#(1) pwr_cont2_sp3_cfp();
    method Bit#(1) pwr_cont2_sp3_pg1();
    method Bit#(1) pwr_cont_dimm_nvrhot();
    method Bit#(1) pwr_cont1_sp3_pg0();
    method Bit#(1) sp3_to_seq_reset_v3p3_l();
    method Bit#(1) sp3_to_seq_thermtrip_l();
    method Bit#(1) sp3_to_seq_slp_s3_l();
    method Bit#(1) pwr_cont1_sp3_pg1();
    method Bit#(1) sp3_to_seq_rtc_v1p5_pg();
    method Bit#(1) sp3_to_seq_pwrok_v3p3();
    method Bit#(1) sp3_to_seq_v0p9_vdd_soc_s5_pg();
    method Bit#(1) sp3_to_seq_slp_s5_l();
    method Bit#(1) pwr_cont2_sp3_pg0();
    method Bit#(1) pwr_cont2_sp3_nvrhot();
    method Bit#(1) pwr_cont_dimm_cfp();
    method Bit#(1) seq_to_sp_misc_a();
    method Bit#(1) seq_to_sp_misc_b();
    method Bit#(1) seq_to_sp_misc_c();
    method Bit#(1) seq_to_sp_misc_d();
endinterface

interface OutPins;
        method Bit#(1) seq_to_clk_gpio5(); // VSC 125MHz clk enable active high.
        method Bit#(1) seq_to_clk_gpio8(); // T6 156.25MHz clk enable active high
        method Bit#(1) seq_to_clk_gpio9(); // KSZ 50MHz clock enable active high
        method Bit#(1) seq_to_nic_v1p1_en();
        method Bit#(1) seq_to_nic_v1p2_enet_en();
        method Bit#(1) seq_to_nic_v1p5a_en();
        method Bit#(1) seq_to_nic_ldo_v3p3_en();
        method Bit#(1) seq_to_nic_v1p2_en();
        method Bit#(1) seq_to_nic_cld_rst_l();
        method Bit#(1) pwr_cont_nic_en0();
        method Bit#(1) pwr_cont_nic_en1();
        method Bit#(1) seq_to_nic_v1p5d_en();
        method Bit#(1) seq_to_clk_nmr_l();
        method Bit#(1) seq_to_clk_ntest();
        method Bit#(1) seq_to_fan_hp_en();
        method Bit#(1) seq_to_vtt_efgh_en();
        method Bit#(1) seq_proxy_sp3_to_rsw_pwren_l();
        method Bit#(1) seq_to_sp_interrupt();
        method Bit#(1) seq_to_led_en_l();
        method Bit#(1) seq_to_nic_v0p9_a0hp_en();
        method Bit#(1) pwr_cont_dimm_efgh_en0();
        method Bit#(1) seq_to_vtt_abcd_en();
        method Bit#(1) seq_to_nic_perst_l();
        // method Bit#(1) nic_to_sp3_pwrflt_l();
        method Bit#(1) seq_to_sp3_v1p8_en();
        method Bit#(1) seq_to_dimm_abcd_v2p5_en();
        method Bit#(1) seq_to_v3p3_sys_en();
        method Bit#(1) seq_to_dimm_efgh_v2p5_en();
        method Bit#(1) seq_to_sp3_v3p3_s5_en();
        method Bit#(1) seq_to_sp3_v1p8_s5_en();
        method Bit#(1) pwr_cont1_sp3_en();
        method Bit#(1) seq_to_sp3_v1p5_rtc_en();
        method Bit#(1) seq_to_sp3_rsmrst_v3p3_l();
        method Bit#(1) seq_to_sp3_v0p9_s5_en();
        method Bit#(1) pwr_cont1_sp3_pwrok();
        method Bit#(1) pwr_cont2_sp3_pwrok();
        method Bit#(1) pwr_cont_dimm_en1();
        method Bit#(1) pwr_cont_dimm_en0();
        // method Bit#(1) seq_to_nic_comb_pg_l();
        method Bit#(1) seq_to_sp3_pwr_good();
        // method Bit#(1) seq_to_sp3_pwr_btn_l();
        // method Bit#(1) seq_to_sp3_sys_rst_l();
        method Bit#(1) pwr_cont2_sp3_en();
        method Bit#(1) seq_to_header_misc_e();
        method Bit#(1) seq_to_header_misc_f();
        method Bit#(1) seq_to_header_misc_g();
        method Bit#(1) seq_to_header_misc_h();
    endinterface

    interface ODPins;
        interface Inout#(Bit#(1)) seq_to_sp3_pwr_btn_l;
        interface Inout#(Bit#(1)) seq_to_sp3_sys_rst_l;
        interface Inout#(Bit#(1)) seq_to_nic_comb_pg_l;
        interface Inout#(Bit#(1)) nic_to_sp3_pwrflt_l;
    endinterface
(* always_enabled *)
interface SeqPins;
    (* prefix = "" *)
    interface SpiPeripheralPinsTop spi_pins;
    (* prefix = "" *)
    interface InPins inputs;
    (* prefix = "" *)
    interface OutPins outputs;
    (* prefix = "" *)
    interface ODPins od_outputs;
    
endinterface

interface InputSync;
    interface InPins pins;
    interface InPinsReversed syncd;
endinterface


//This is the very toplevel module for the Gimlet Sequencer FPGA.
(* default_clock_osc="clk50m" *)
module mkGimletSeqTop (SeqPins);
    Clock cur_clk <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, cur_clk);
    let synth_params = GimletSeqTopParameters {one_ms_counts: 50000};    // 1ms @ 50MHz

    Reg#(Bit#(1)) dummy_high <- mkReg(1);
    Reg#(Bit#(1)) dummy_low <- mkReg(0);
    Reg#(Bit#(1)) nic_3v3_pg <- mkReg(0);

    ICE40::Output#(Bit#(1)) cipo <- mkOutput(OutputTriState, False);
    
    ICE40::Output#(Bit#(1)) seq_to_sp3_pwr_btn_l <- mkOutput(OutputTriState, False);
    ICE40::Output#(Bit#(1)) seq_to_sp3_sys_rst_l <- mkOutput(OutputTriState, False);
    ICE40::Output#(Bit#(1)) seq_to_nic_comb_pg_l <- mkOutput(OutputTriState, False);
    ICE40::Output#(Bit#(1)) nic_to_sp3_pwrflt_l <- mkOutput(OutputTriState, False);

    InputSync sync <- mkInputSync();

    VersionROMIfc ver_rom <- mkVersionROM(reset_by reset_sync);
    let inner <- mkGimletInnerTop(synth_params, ver_rom.version, ver_rom.sha, reset_by reset_sync);
    
    ConfigReg#(BoardRev) brd_rev <- mkConfigRegU();
    
    mkConnection(brd_rev, inner.reg_pins.brd_rev);

    // A1 input connections
    mkConnection(sync.syncd.sp3_to_seq_rtc_v1p5_pg, inner.a1_pins.v1p5_rtc.pg);
    mkConnection(sync.syncd.sp3_to_seq_v0p9_vdd_soc_s5_pg, inner.a1_pins.v0p9_s5.pg);
    mkConnection(sync.syncd.sp3_to_seq_v3p3_s5_pg, inner.a1_pins.v3p3_s5.pg);
    mkConnection(sync.syncd.sp3_to_seq_v1p8_s5_pg, inner.a1_pins.v1p8_s5.pg);

    // A0 input connections
    // from sp3
    mkConnection(sync.syncd.sp3_to_sp_nic_pwren_l, inner.a0_pins.sp3.sp3_to_sp_nic_pwren_l);
    mkConnection(sync.syncd.sp3_to_seq_pwrgd_out, inner.a0_pins.sp3.sp3_to_seq_pwrgd_out);
    mkConnection(sync.syncd.sp3_to_seq_slp_s3_l, inner.a0_pins.sp3.sp3_to_seq_slp_s3_l);
    mkConnection(sync.syncd.sp3_to_seq_slp_s5_l, inner.a0_pins.sp3.sp3_to_seq_slp_s5_l);
    mkConnection(sync.syncd.sp3_to_seq_pwrok_v3p3, inner.a0_pins.sp3.sp3_to_seq_pwrok_v3p3);
    mkConnection(sync.syncd.sp3_to_seq_reset_v3p3_l, inner.a0_pins.sp3.sp3_to_seq_reset_v3p3_l);
    mkConnection(sync.syncd.sp3_to_seq_thermtrip_l, inner.a0_pins.sp3.sp3_to_seq_thermtrip_l);
    mkConnection(sync.syncd.sp3_to_seq_fsr_req_l, inner.a0_pins.sp3.sp3_to_seq_fsr_req_l);
    mkConnection(sync.syncd.pwr_cont1_sp3_pg0, inner.a0_pins.pwr_cont1_sp3_pg0);
    mkConnection(sync.syncd.pwr_cont2_sp3_pg0, inner.a0_pins.pwr_cont2_sp3_pg0);
    mkConnection(sync.syncd.pwr_cont2_sp3_cfp, inner.a0_pins.pwr_cont2_sp3_cfp);
    mkConnection(sync.syncd.pwr_cont2_sp3_nvrhot, inner.a0_pins.pwr_cont2_sp3_nvrhot);
    mkConnection(sync.syncd.pwr_cont1_sp3_cfp, inner.a0_pins.pwr_cont1_sp3_cfp);
    mkConnection(sync.syncd.pwr_cont1_sp3_nvrhot, inner.a0_pins.pwr_cont1_sp3_nvrhot);

    mkConnection(sync.syncd.v3p3_sys_to_seq_pg, inner.a0_pins.v3p3_sys.pg);
    mkConnection(sync.syncd.seq_v1p8_sp3_vdd_pg, inner.a0_pins.v1p8_sp3.pg);
    mkConnection(sync.syncd.vtt_ab_a0_to_seq_pg, inner.a0_pins.vtt_ab.pg);
    mkConnection(sync.syncd.vtt_cd_a0_to_seq_pg, inner.a0_pins.vtt_cd.pg);
    mkConnection(sync.syncd.vtt_ef_a0_to_seq_pg, inner.a0_pins.vtt_ef.pg);
    mkConnection(sync.syncd.vtt_gh_a0_to_seq_pg, inner.a0_pins.vtt_gh.pg);
    mkConnection(sync.syncd.pwr_cont_dimm_pg0, inner.a0_pins.vpp_abcd.pg);
    mkConnection(sync.syncd.pwr_cont_dimm_pg1, inner.a0_pins.vpp_efgh.pg);
    mkConnection(sync.syncd.pwr_cont1_sp3_pg1, inner.a0_pins.vdd_mem_abcd.pg);
    mkConnection(sync.syncd.pwr_cont2_sp3_pg1, inner.a0_pins.vdd_mem_efgh.pg);

    // Nic inptut connections
    mkConnection(sync.syncd.nic_to_seq_v1p5d_pg, inner.nic_pins.v1p5d.pg);
    mkConnection(sync.syncd.nic_to_seq_v1p5a_pg, inner.nic_pins.v1p5a.pg);
    mkConnection(sync.syncd.nic_to_seq_v1p2_pg, inner.nic_pins.v1p2.pg);
    mkConnection(sync.syncd.nic_to_seq_v1p2_enet_pg, inner.nic_pins.v1p2_enet.pg);
    mkConnection(sync.syncd.nic_to_seq_ext_rst_l, inner.nic_pins.nic_to_seq_ext_rst_l);
    mkConnection(sync.syncd.nic_to_seq_v1p1_pg, inner.nic_pins.v1p1.pg);
    mkConnection(sync.syncd.sp3_to_seq_nic_perst_l, inner.nic_pins.sp3_to_seq_nic_perst_l);
    mkConnection(sync.syncd.nic_v0p9_a0hp_pg, inner.nic_pins.v0p9_a0hp.pg);
    
    // this is a hack due to a revB issue where the pg doesn't actually wire to the
    // FPGA.
    // rule nic_3v3_pg_fix;
    //     let board_version = unpack({sync.pins.seq_rev_id2, sync.pins.seq_rev_id1, sync.pins.seq_rev_id0});
    //     if (board_version == 1) begin  // 0 = A, 1 = B etc
    //         nic_3v3_pg <= inner.nic_pins.ldo_v3p3.en;
    //     end else begin
    //         nic_3v3_pg <= // TODO: 3v3 feedback!!
    // endrule
    mkConnection(inner.nic_pins.ldo_v3p3.en, inner.nic_pins.ldo_v3p3.pg);

    rule tristate (inner.spi_pins.output_en);
        cipo <= inner.spi_pins.cipo;
    endrule

    rule comb_pg_l_tris (inner.nic_pins.seq_to_nic_comb_pg_l == 0);
        seq_to_nic_comb_pg_l <= 0;
    endrule

    rule pwr_btn_l_tris (inner.a0_pins.sp3.seq_to_sp3_pwr_btn_l == 0);
        seq_to_sp3_pwr_btn_l <= 0;
    endrule

    rule sys_rst_l_tris (inner.a0_pins.sp3.seq_to_sp3_sys_rst_l == 0);
        seq_to_sp3_sys_rst_l <= 0;
    endrule

    rule do_board_rev;
        brd_rev <= unpack({'0, sync.syncd.seq_rev_id2, sync.syncd.seq_rev_id1, sync.syncd.seq_rev_id0});
    endrule

    interface SpiPeripheralPinsTop spi_pins;
        method csn = inner.spi_pins.csn;
        method sclk = inner.spi_pins.sclk;
        method copi = inner.spi_pins.copi;
        interface cipo = cipo.pad;
    endinterface
    interface InPins inputs;
        method seq_rev_id0 = sync.pins.seq_rev_id0;
        method seq_rev_id1 = sync.pins.seq_rev_id1;
        method seq_rev_id2 = sync.pins.seq_rev_id2;
        method pwr_cont_nic_pg1 = sync.pins.pwr_cont_nic_pg1;
        method pwr_cont_nic_pg0 = sync.pins.pwr_cont_nic_pg0;
        method sp3_to_sp_nic_pwren_l = sync.pins.sp3_to_sp_nic_pwren_l;
        method nic_to_seq_v1p5d_pg = sync.pins.nic_to_seq_v1p5d_pg;
        method nic_to_seq_v1p5a_pg = sync.pins.nic_to_seq_v1p5a_pg;
        method nic_to_seq_v1p2_pg = sync.pins.nic_to_seq_v1p2_pg;
        method nic_to_seq_v1p2_enet_pg = sync.pins.nic_to_seq_v1p2_enet_pg;
        method nic_to_seq_ext_rst_l = sync.pins.nic_to_seq_ext_rst_l;
        method nic_to_seq_v1p1_pg = sync.pins.nic_to_seq_v1p1_pg;
        method fanhp_to_seq_fault_l = sync.pins.fanhp_to_seq_fault_l;
        method fanhp_to_seq_pwrgd = sync.pins.fanhp_to_seq_pwrgd;
        method vtt_ef_a0_to_seq_pg = sync.pins.vtt_ef_a0_to_seq_pg;
        method vtt_gh_a0_to_seq_pg = sync.pins.vtt_gh_a0_to_seq_pg;
        method seq_to_clk_gpio2 = sync.pins.seq_to_clk_gpio2;
        method seq_to_clk_gpio3 = sync.pins.seq_to_clk_gpio3;
        method sp3_to_rsw_pwren_l_via_seq = sync.pins.sp3_to_rsw_pwren_l_via_seq;
        method pwr_cont_dimm_efgh_pg0 = sync.pins.pwr_cont_dimm_efgh_pg0;
        method seq_to_clk_gpio1 = sync.pins.seq_to_clk_gpio1;
        method seq_to_clk_gpio4 = sync.pins.seq_to_clk_gpio4;
        method vtt_ab_a0_to_seq_pg = sync.pins.vtt_ab_a0_to_seq_pg;
        method vtt_cd_a0_to_seq_pg = sync.pins.vtt_cd_a0_to_seq_pg;
        method seq_v1p8_sp3_vdd_pg = sync.pins.seq_v1p8_sp3_vdd_pg;
        method sp3_to_seq_nic_perst_l = sync.pins.sp3_to_seq_nic_perst_l;
        method seq_to_sp_misc_a = sync.pins.seq_to_sp_misc_a;
        method dimm_to_seq_efgh_v2p5_pg = sync.pins.dimm_to_seq_efgh_v2p5_pg;
        method dimm_to_seq_abcd_v2p5_pg = sync.pins.dimm_to_seq_abcd_v2p5_pg;
        method seq_to_sp_misc_d = sync.pins.seq_to_sp_misc_d;
        method nic_v0p9_a0hp_pg = sync.pins.nic_v0p9_a0hp_pg;
        method pwr_cont_dimm_pg0 = sync.pins.pwr_cont_dimm_pg0;
        method v3p3_sys_to_seq_pg = sync.pins.v3p3_sys_to_seq_pg;
        method fan_to_seq_fan_fail = sync.pins.fan_to_seq_fan_fail;
        method sp3_to_seq_v3p3_s5_pg = sync.pins.sp3_to_seq_v3p3_s5_pg;
        method sp3_to_seq_v1p8_s5_pg = sync.pins.sp3_to_seq_v1p8_s5_pg;
        method pwr_cont_dimm_pg1 = sync.pins.pwr_cont_dimm_pg1;
        method pwr_cont1_sp3_cfp = sync.pins.pwr_cont1_sp3_cfp;
        method pwr_cont1_sp3_nvrhot = sync.pins.pwr_cont1_sp3_nvrhot;
        method sp3_to_seq_fsr_req_l = sync.pins.sp3_to_seq_fsr_req_l;
        method sp3_to_seq_pwrgd_out = sync.pins.sp3_to_seq_pwrgd_out;
        method seq_to_sp_misc_b = sync.pins.seq_to_sp_misc_b;
        method pwr_cont2_sp3_cfp = sync.pins.pwr_cont2_sp3_cfp;
        method pwr_cont2_sp3_pg1 = sync.pins.pwr_cont2_sp3_pg1;
        method pwr_cont_dimm_nvrhot = sync.pins.pwr_cont_dimm_nvrhot;
        method pwr_cont1_sp3_pg0 = sync.pins.pwr_cont1_sp3_pg0;
        method sp3_to_seq_reset_v3p3_l = sync.pins.sp3_to_seq_reset_v3p3_l;
        method sp3_to_seq_thermtrip_l = sync.pins.sp3_to_seq_thermtrip_l;
        method sp3_to_seq_slp_s3_l = sync.pins.sp3_to_seq_slp_s3_l;
        method pwr_cont1_sp3_pg1 = sync.pins.pwr_cont1_sp3_pg1;
        method sp3_to_seq_rtc_v1p5_pg = sync.pins.sp3_to_seq_rtc_v1p5_pg;
        method sp3_to_seq_pwrok_v3p3 = sync.pins.sp3_to_seq_pwrok_v3p3;
        method sp3_to_seq_v0p9_vdd_soc_s5_pg = sync.pins.sp3_to_seq_v0p9_vdd_soc_s5_pg;
        method sp3_to_seq_slp_s5_l = sync.pins.sp3_to_seq_slp_s5_l;
        method seq_to_sp_misc_c = sync.pins.seq_to_sp_misc_c;
        method seq_to_header_misc_i = sync.pins.seq_to_header_misc_i;
        method pwr_cont2_sp3_pg0 = sync.pins.pwr_cont2_sp3_pg0;
        method pwr_cont2_sp3_nvrhot = sync.pins.pwr_cont2_sp3_nvrhot;
        method pwr_cont_dimm_cfp = sync.pins.pwr_cont_dimm_cfp;
    endinterface
    interface OutPins outputs;
        method seq_to_clk_gpio5 = dummy_high._read; // VSC 125MHz clk enable active high.
        method seq_to_clk_gpio8 = dummy_high._read; // T6 156.25MHz clk enable active high
        method seq_to_clk_gpio9 = dummy_high._read; // KSZ 50MHz clock enable active high
        method seq_to_nic_v1p1_en = inner.nic_pins.v1p1.en;
        method seq_to_nic_v1p2_enet_en = inner.nic_pins.v1p2_enet.en;
        method seq_to_nic_v1p5a_en = inner.nic_pins.v1p5a.en;
        method seq_to_nic_ldo_v3p3_en = inner.nic_pins.ldo_v3p3.en;
        method seq_to_nic_v1p2_en = inner.nic_pins.v1p2.en;
        method seq_to_nic_cld_rst_l = inner.nic_pins.seq_to_nic_cld_rst_l;
        method pwr_cont_nic_en0 = dummy_low._read;
        method pwr_cont_nic_en1 = dummy_low._read;
        method seq_to_nic_v1p5d_en = inner.nic_pins.v1p5d.en;
        method seq_to_clk_nmr_l = dummy_high._read;
        method seq_to_clk_ntest = dummy_high._read;
        method seq_to_fan_hp_en = dummy_high._read;  // Default fo fan power enable
        method seq_to_vtt_efgh_en = inner.a0_pins.vtt_ef.en;
        method seq_proxy_sp3_to_rsw_pwren_l = ~inner.reg_pins.seq_to_rsw_pwren;
        method seq_to_sp_interrupt = inner.reg_pins.seq_to_sp_interrupt;
        method seq_to_led_en_l = dummy_low._read;  //TODO: blinky!
        method seq_to_nic_v0p9_a0hp_en = inner.nic_pins.v0p9_a0hp.en;
        method pwr_cont_dimm_efgh_en0 = inner.a0_pins.vpp_efgh.en;
        method seq_to_vtt_abcd_en = inner.a0_pins.vtt_ab.en;
        method seq_to_nic_perst_l = inner.nic_pins.seq_to_nic_perst_l;
        method seq_to_sp3_v1p8_en = inner.a0_pins.v1p8_sp3.en;
        method seq_to_dimm_abcd_v2p5_en = dummy_high._read;  // Default SPD to enable
        method seq_to_v3p3_sys_en = inner.a0_pins.v3p3_sys.en;
        method seq_to_dimm_efgh_v2p5_en = dummy_high._read;  // Default SPD to enable
        method seq_to_sp3_v3p3_s5_en = inner.a1_pins.v3p3_s5.en;
        method seq_to_sp3_v1p8_s5_en = inner.a1_pins.v1p8_s5.en;
        method pwr_cont1_sp3_en = inner.a0_pins.vdd_mem_abcd.en;
        method seq_to_sp3_v1p5_rtc_en = inner.a1_pins.v1p5_rtc.en;
        method seq_to_sp3_rsmrst_v3p3_l = inner.a1_pins.seq_to_sp3_rsmrst_v3p3_l;
        method seq_to_sp3_v0p9_s5_en = inner.a1_pins.v0p9_s5.en;
        method pwr_cont1_sp3_pwrok = inner.a0_pins.pwr_cont1_sp3_pwrok;
        method pwr_cont2_sp3_pwrok = inner.a0_pins.pwr_cont2_sp3_pwrok;
        method pwr_cont_dimm_en1 = inner.a0_pins.vpp_efgh.en;
        method pwr_cont_dimm_en0 = inner.a0_pins.vpp_abcd.en;
        method seq_to_sp3_pwr_good = inner.a0_pins.sp3.seq_to_sp3_pwr_good;
        method pwr_cont2_sp3_en = inner.a0_pins.vdd_mem_efgh.en;
        method seq_to_header_misc_e = sync.syncd.seq_to_sp_misc_a;
        method seq_to_header_misc_f = sync.syncd.seq_to_sp_misc_b;
        method seq_to_header_misc_g = sync.syncd.seq_to_sp_misc_c;
        method seq_to_header_misc_h = sync.syncd.seq_to_sp_misc_d;
    endinterface
    interface ODPins od_outputs;
       interface seq_to_sp3_pwr_btn_l = seq_to_sp3_pwr_btn_l.pad;
       interface seq_to_sp3_sys_rst_l = seq_to_sp3_sys_rst_l.pad;
       interface seq_to_nic_comb_pg_l = seq_to_nic_comb_pg_l.pad;
       interface nic_to_sp3_pwrflt_l = nic_to_sp3_pwrflt_l.pad;
    endinterface
endmodule

module mkInputSync(InputSync);

    Clock clk_sys <- exposeCurrentClock();
    Reset rst_sys <- exposeCurrentReset();

    // Synchronizers
    SyncBitIfc#(Bit#(1)) seq_rev_id0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_rev_id1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_rev_id2 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_sp_nic_pwren_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p5d_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p5a_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p2_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p2_enet_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_ext_rst_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p1_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) fanhp_to_seq_fault_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) fanhp_to_seq_pwrgd <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) vtt_ef_a0_to_seq_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) vtt_gh_a0_to_seq_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio2   <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio3 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_header_misc_i <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_rsw_pwren_l_via_seq <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_dimm_efgh_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_clk_gpio4 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
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
    SyncBitIfc#(Bit#(1)) seq_to_sp_misc_b <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_dimm_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_reset_v3p3_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_thermtrip_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_slp_s3_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont1_sp3_pg1 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_rtc_v1p5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_pwrok_v3p3 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_v0p9_vdd_soc_s5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sp3_to_seq_slp_s5_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) seq_to_sp_misc_c <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_pg0 <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont2_sp3_nvrhot <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_dimm_cfp <- mkSyncBit1(clk_sys, rst_sys, clk_sys);

    interface InPins pins;
        method seq_rev_id0 = seq_rev_id0.send;
        method seq_rev_id1 = seq_rev_id1.send;
        method seq_rev_id2 = seq_rev_id2.send;
        method pwr_cont_nic_pg1 = pwr_cont_nic_pg1.send;
        method pwr_cont_nic_pg0 = pwr_cont_nic_pg0.send;
        method sp3_to_sp_nic_pwren_l = sp3_to_sp_nic_pwren_l.send;
        method nic_to_seq_v1p5d_pg = nic_to_seq_v1p5d_pg.send;
        method nic_to_seq_v1p5a_pg = nic_to_seq_v1p5a_pg.send;
        method nic_to_seq_v1p2_pg = nic_to_seq_v1p2_pg.send;
        method nic_to_seq_v1p2_enet_pg = nic_to_seq_v1p2_enet_pg.send;
        method nic_to_seq_ext_rst_l = nic_to_seq_ext_rst_l.send;
        method nic_to_seq_v1p1_pg = nic_to_seq_v1p1_pg.send;
        method fanhp_to_seq_fault_l = fanhp_to_seq_fault_l.send;
        method fanhp_to_seq_pwrgd = fanhp_to_seq_pwrgd.send;
        method vtt_ef_a0_to_seq_pg = vtt_ef_a0_to_seq_pg.send;
        method vtt_gh_a0_to_seq_pg = vtt_gh_a0_to_seq_pg.send;
        method seq_to_clk_gpio2 = seq_to_clk_gpio2.send;
        method seq_to_clk_gpio3 = seq_to_clk_gpio3.send;
        method seq_to_header_misc_i = seq_to_header_misc_i.send;
        method sp3_to_rsw_pwren_l_via_seq = sp3_to_rsw_pwren_l_via_seq.send;
        method pwr_cont_dimm_efgh_pg0 = pwr_cont_dimm_efgh_pg0.send;
        method seq_to_clk_gpio1 = seq_to_clk_gpio1.send;
        method seq_to_clk_gpio4 = seq_to_clk_gpio4.send;
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
        method seq_to_sp_misc_b = seq_to_sp_misc_b.send;
        method pwr_cont2_sp3_cfp = pwr_cont2_sp3_cfp.send;
        method pwr_cont2_sp3_pg1 = pwr_cont2_sp3_pg1.send;
        method pwr_cont_dimm_nvrhot = pwr_cont_dimm_nvrhot.send;
        method pwr_cont1_sp3_pg0 = pwr_cont1_sp3_pg0.send;
        method sp3_to_seq_reset_v3p3_l = sp3_to_seq_reset_v3p3_l.send;
        method sp3_to_seq_thermtrip_l = sp3_to_seq_thermtrip_l.send;
        method sp3_to_seq_slp_s3_l = sp3_to_seq_slp_s3_l.send;
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
    interface InPinsReversed syncd;
        method seq_rev_id0 = seq_rev_id0.read;
        method seq_rev_id1 = seq_rev_id1.read;
        method seq_rev_id2 = seq_rev_id2.read;
        method pwr_cont_nic_pg1 = pwr_cont_nic_pg1.read;
        method pwr_cont_nic_pg0 = pwr_cont_nic_pg0.read;
        method sp3_to_sp_nic_pwren_l = sp3_to_sp_nic_pwren_l.read;
        method nic_to_seq_v1p5d_pg = nic_to_seq_v1p5d_pg.read;
        method nic_to_seq_v1p5a_pg = nic_to_seq_v1p5a_pg.read;
        method nic_to_seq_v1p2_pg = nic_to_seq_v1p2_pg.read;
        method nic_to_seq_v1p2_enet_pg = nic_to_seq_v1p2_enet_pg.read;
        method nic_to_seq_ext_rst_l = nic_to_seq_ext_rst_l.read;
        method nic_to_seq_v1p1_pg = nic_to_seq_v1p1_pg.read;
        method fanhp_to_seq_fault_l = fanhp_to_seq_fault_l.read;
        method fanhp_to_seq_pwrgd = fanhp_to_seq_pwrgd.read;
        method vtt_ef_a0_to_seq_pg = vtt_ef_a0_to_seq_pg.read;
        method vtt_gh_a0_to_seq_pg = vtt_gh_a0_to_seq_pg.read;
        method seq_to_clk_gpio2 = seq_to_clk_gpio2.read;
        method seq_to_clk_gpio3 = seq_to_clk_gpio3.read;
        method sp3_to_rsw_pwren_l_via_seq = sp3_to_rsw_pwren_l_via_seq.read;
        method pwr_cont_dimm_efgh_pg0 = pwr_cont_dimm_efgh_pg0.read;
        method seq_to_clk_gpio1 = seq_to_clk_gpio1.read;
        method seq_to_clk_gpio4 = seq_to_clk_gpio4.read;
        method vtt_ab_a0_to_seq_pg = vtt_ab_a0_to_seq_pg.read;
        method vtt_cd_a0_to_seq_pg = vtt_cd_a0_to_seq_pg.read;
        method seq_v1p8_sp3_vdd_pg = seq_v1p8_sp3_vdd_pg.read;
        method sp3_to_seq_nic_perst_l = sp3_to_seq_nic_perst_l.read;
        method seq_to_sp_misc_a = seq_to_sp_misc_a.read;
        method dimm_to_seq_efgh_v2p5_pg = dimm_to_seq_efgh_v2p5_pg.read;
        method dimm_to_seq_abcd_v2p5_pg = dimm_to_seq_abcd_v2p5_pg.read;
        method seq_to_sp_misc_d = seq_to_sp_misc_d.read;
        method nic_v0p9_a0hp_pg = nic_v0p9_a0hp_pg.read;
        method pwr_cont_dimm_pg0 = pwr_cont_dimm_pg0.read;
        method v3p3_sys_to_seq_pg = v3p3_sys_to_seq_pg.read;
        method fan_to_seq_fan_fail = fan_to_seq_fan_fail.read;
        method sp3_to_seq_v3p3_s5_pg = sp3_to_seq_v3p3_s5_pg.read;
        method sp3_to_seq_v1p8_s5_pg = sp3_to_seq_v1p8_s5_pg.read;
        method pwr_cont_dimm_pg1 = pwr_cont_dimm_pg1.read;
        method pwr_cont1_sp3_cfp = pwr_cont1_sp3_cfp.read;
        method pwr_cont1_sp3_nvrhot = pwr_cont1_sp3_nvrhot.read;
        method sp3_to_seq_fsr_req_l = sp3_to_seq_fsr_req_l.read;
        method sp3_to_seq_pwrgd_out = sp3_to_seq_pwrgd_out.read;
        method seq_to_sp_misc_b = seq_to_sp_misc_b.read;
        method pwr_cont2_sp3_cfp = pwr_cont2_sp3_cfp.read;
        method pwr_cont2_sp3_pg1 = pwr_cont2_sp3_pg1.read;
        method pwr_cont_dimm_nvrhot = pwr_cont_dimm_nvrhot.read;
        method pwr_cont1_sp3_pg0 = pwr_cont1_sp3_pg0.read;
        method sp3_to_seq_reset_v3p3_l = sp3_to_seq_reset_v3p3_l.read;
        method sp3_to_seq_thermtrip_l = sp3_to_seq_thermtrip_l.read;
        method sp3_to_seq_slp_s3_l = sp3_to_seq_slp_s3_l.read;
        method pwr_cont1_sp3_pg1 = pwr_cont1_sp3_pg1.read;
        method sp3_to_seq_rtc_v1p5_pg = sp3_to_seq_rtc_v1p5_pg.read;
        method sp3_to_seq_pwrok_v3p3 = sp3_to_seq_pwrok_v3p3.read;
        method sp3_to_seq_v0p9_vdd_soc_s5_pg = sp3_to_seq_v0p9_vdd_soc_s5_pg.read;
        method sp3_to_seq_slp_s5_l = sp3_to_seq_slp_s5_l.read;
        method seq_to_sp_misc_c = seq_to_sp_misc_c.read;
        method pwr_cont2_sp3_pg0 = pwr_cont2_sp3_pg0.read;
        method pwr_cont2_sp3_nvrhot = pwr_cont2_sp3_nvrhot.read;
        method pwr_cont_dimm_cfp = pwr_cont_dimm_cfp.read;
    endinterface
endmodule
endpackage