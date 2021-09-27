// Copyright 2021 Oxide Computer Company

package GimletSeqTop;

import Clocks::*;
import Connectable::*;

import SpiDecode::*;
import NicBlock::*;
(* always_enabled *)
interface Top;
    // SPI interface
    (* prefix = "" *)
    interface SpiPeripheralPins spi_pins;
    (* prefix = "" *)
    interface SequencerInputPins in_pins;
endinterface

interface SequencerInputPins;
    // SP general
    // method Action seq_to_sp_misc_a(Bit#(1) value);
    // method Action seq_to_sp_misc_b(Bit#(1) value);
    // method Action seq_to_sp_misc_c(Bit#(1) value);
    // method Action seq_to_sp_misc_d(Bit#(1) value);
    // // Early signals
    // method Action dimm_to_seq_abcd_v2p5_pg(Bit#(1) value);
    // method Action dimm_to_seq_efgh_v2p5_pg(Bit#(1) value);
    // NIC input interface
    interface NicInputPinsRawSink nic_pins;
    // General AMD
    // method Action sp3_to_seq_thermtrip_l(Bit#(1) value);
    // method Action sp3_to_seq_fsr_req_l(Bit#(1) value);
    // method Action sp3_to_seq_pwrgd_out(Bit#(1) value);
    // // Fans interface
    // method Action fanhp_to_seq_fault_l(Bit#(1) value);
    // method Action fan_to_seq_fan_fail(Bit#(1) value);
    // method Action fanhp_to_seq_pwrgd(Bit#(1) value);
    // // Clock gen interface
    // method Action seq_to_clk_gpio1        // TODO: input or output?(Bit#(1) value);
    // method Action seq_to_clk_gpio2        // TODO: input or output?(Bit#(1) value);
    // method Action seq_to_clk_gpio3        // TODO: input or output?(Bit#(1) value);
    // method Action seq_to_clk_gpio4        // TODO: input or output?(Bit#(1) value);
    // method Action seq_to_clk_gpio5        // TODO: input or output?(Bit#(1) value);
    // method Action seq_to_clk_gpio8        // TODO: input or output?(Bit#(1) value);
    // method Action seq_to_clk_gpio9        // TODO: input or output?(Bit#(1) value);
    // // A1 Power-related
    // method Action sp3_to_seq_v1p8_s5_pg(Bit#(1) value);
    // method Action sp3_to_seq_rtc_v1p5_en(Bit#(1) value);
    // method Action sp3_to_seq_v3p3_s5_pg(Bit#(1) value);
    // method Action sp3_to_seq_v0p9_vdd_soc_s5_pg(Bit#(1) value);
    // // A0 Power-related
    // method Action sp3_to_sp_slp_s3_l(Bit#(1) value);
    // method Action sp3_to_sp_slp_s5_l(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_pg0(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_pg1(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_pg2(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_cfp(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_nvrhot(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_pg0(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_pg1(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_pg2(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_cfp(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_nvrhot(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_cfp(Bit#(1) value);
    // method Action pwr_cont1_sp3_nvrhot(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_pg0(Bit#(1) value);
    // method Action pwr_cont1_sp3_cfp(Bit#(1) value);
    // method Action pwr_cont2_sp3_pg1(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_pg2(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_cfp(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_pg1(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_pg0(Bit#(1) value);
    // method Action sp3_to_sp_slp_s3_l(Bit#(1) value);
    // method Action pwr_cont2_sp3_pg0(Bit#(1) value);
    // method Action sp3_to_sp_slp_s5_l(Bit#(1) value);
    // method Action vtt_efgh_a0_to_seq_pg_l(Bit#(1) value);
    // method Action pwr_cont1_sp3_pg1(Bit#(1) value);
    // method Action pwr_cont2_sp3_nvrhot(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_pg2(Bit#(1) value);
    // method Action pwr_cont1_sp3_pg0(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_pg1(Bit#(1) value);
    // method Action pwr_cont2_sp3_cfp(Bit#(1) value);
    // method Action seq_v1p8_sp3_vdd_pg_l(Bit#(1) value);
    // method Action sp3_to_seq_pwrok_v3p3(Bit#(1) value);
    // method Action pwr_cont_dimm_efgh_nvrhot(Bit#(1) value);
    // method Action sp3_to_seq_reset_v3p3_l(Bit#(1) value);
    // method Action pwr_cont_dimm_abcd_nvrhot(Bit#(1) value);
    // method Action vtt_abcd_a0_to_seq_pg_l(Bit#(1) value);
    
endinterface

// interface SeqOutputPins;
//     // Fans interface
//     method Bit#(1) seq_to_fanhp_restart_l;
//     method Bit#(1) seq_to_fan_hp_en;

//     // A1-related

    
//     method Bit#(1) seq_to_dimm_efgh_v2p5_en;
//     method Bit#(1) pwr_cont_dimm_abcd_en1;
//     method Bit#(1) seq_to_nic_v1p2_enet_en;
//     method Bit#(1) seq_to_nic_comb_pg;
//     method Bit#(1) pwr_cont_dimm_efgh_en0;
//     method Bit#(1) pwr_cont_dimm_efgh_en2;
//     method Bit#(1) sp3_to_seq_rtc_v1p5_en;
//     method Bit#(1) pwr_cont1_sp3_cfp;
//     method Bit#(1) seq_to_sp3_v1p8_en;
//     method Bit#(1) pwr_cont2_sp3_en;
//     method Bit#(1) seq_to_dimm_abcd_v2p5_en;
//     method Bit#(1) seq_to_sp3_v1p5_rtc_en;
//     method Bit#(1) pwr_cont_nic_en1;
//     method Bit#(1) seq_to_sp3_v1p8_s5_en;
//     method Bit#(1) pwr_cont_dimm_abcd_en2;
//     method Bit#(1) pwr_cont_nic_en0;
//     method Bit#(1) pwr_cont_dimm_abcd_en0;
//     method Bit#(1) seq_to_nic_cld_rst_l;
//     method Bit#(1) seq_to_sp3_v0p9_s5_en;
//     method Bit#(1) pwr_cont_dimm_efgh_en1;
//     method Bit#(1) clk_to_seq_nmr_l;
//     method Bit#(1) sp_to_sp3_pwr_btn_l;
//     method Bit#(1) seq_to_nic_v1p5a_en;
//     method Bit#(1) seq_to_nic_v1p5d_en;
//     method Bit#(1) seq_to_nic_v1p2_en;
//     method Bit#(1) seq_to_nic_ldo_v3p3_en;
//     method Bit#(1) seq_to_vtt_efgh_en;
//     method Bit#(1) seq_to_sp3_pwr_good;

//     method Bit#(1) seq_to_sp3_rsmrst_v3p3_l;
    
//     method Bit#(1) seq_to_vtt_abcd_a0_en;
// endinterface

interface NicInputSync;
    interface NicInputPinsRawSink sink;
    interface NicInputPinsNormalizedSource source;
endinterface

module mkNicInputSync(NicInputSync);
    Clock clk_sys <- exposeCurrentClock();
    Reset rst_sys <- exposeCurrentReset();

    // Synchronizers
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_pg0_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_nvrhot_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_cfp_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p5a_pg_l_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p5d_pg_l_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p2_pg_l_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) nic_to_seq_v1p1_pg_l_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) pwr_cont_nic_pg1_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);

    interface NicInputPinsRawSink sink;
        method pwr_cont_nic_pg0 = pwr_cont_nic_pg0_sync.send;
        method pwr_cont_nic_nvrhot = pwr_cont_nic_nvrhot_sync.send;
        method pwr_cont_nic_cfp = pwr_cont_nic_cfp_sync.send;
        method nic_to_seq_v1p5a_pg_l = nic_to_seq_v1p5a_pg_l_sync.send;
        method nic_to_seq_v1p5d_pg_l = nic_to_seq_v1p5d_pg_l_sync.send;
        method nic_to_seq_v1p2_pg_l = nic_to_seq_v1p2_pg_l_sync.send;
        method nic_to_seq_v1p1_pg_l = nic_to_seq_v1p1_pg_l_sync.send;
        method pwr_cont_nic_pg1 = pwr_cont_nic_pg1_sync.send;
    endinterface

    interface NicInputPinsNormalizedSource source;
        method pwr_cont_nic_pg0 = pwr_cont_nic_pg0_sync.read;
        method pwr_cont_nic_nvrhot = pwr_cont_nic_nvrhot_sync.read;
        method pwr_cont_nic_cfp = pwr_cont_nic_cfp_sync.read;
        method pwr_cont_nic_pg1 = pwr_cont_nic_pg1_sync.read;
        // Invert the active low signals
        method Bit#(1) nic_to_seq_v1p5a_pg;
            return ~nic_to_seq_v1p5a_pg_l_sync.read();
        endmethod
        method Bit#(1) nic_to_seq_v1p5d_pg;
            return ~nic_to_seq_v1p5d_pg_l_sync.read();
        endmethod
        method Bit#(1) nic_to_seq_v1p2_pg;
            return ~nic_to_seq_v1p2_pg_l_sync.read();
        endmethod
        method Bit#(1) nic_to_seq_v1p1_pg;
            return ~nic_to_seq_v1p1_pg_l_sync.read();
        endmethod
    endinterface

endmodule

(* synthesize, default_clock_osc="clk50m" *)
module mkGimletSeq (Top);
    // Sequencer Input synchronizers (meta-harden inputs)
    NicInputSync nic_pins <- mkNicInputSync();
    


    // SPI block, including synchronizer
    SpiPeripheralSync spi_sync <- mkSpiPeripheralPinSync;    
    SpiPeripheralPhy phy <- mkSpiPeripheralPhy();
    SpiDecodeIF decode <- mkSpiRegDecode();
    // Regiser block
    // State machine blocks

    // Connections
    mkConnection(spi_sync.syncd_pins, phy.pins);
    mkConnection(decode.spi_byte, phy.decoder_if); 


    interface SequencerInputPins in_pins;
        interface NicInputPinsRawSink nic_pins;
            method pwr_cont_nic_pg0 = nic_pins.sink.pwr_cont_nic_pg0;
            method pwr_cont_nic_nvrhot = nic_pins.sink.pwr_cont_nic_nvrhot;
            method pwr_cont_nic_cfp = nic_pins.sink.pwr_cont_nic_cfp;
            method nic_to_seq_v1p5a_pg_l = nic_pins.sink.nic_to_seq_v1p5a_pg_l;
            method nic_to_seq_v1p5d_pg_l = nic_pins.sink.nic_to_seq_v1p5d_pg_l;
            method nic_to_seq_v1p2_pg_l = nic_pins.sink.nic_to_seq_v1p2_pg_l;
            method nic_to_seq_v1p1_pg_l = nic_pins.sink.nic_to_seq_v1p1_pg_l;
            method pwr_cont_nic_pg1 = nic_pins.sink.pwr_cont_nic_pg1;
        endinterface
    endinterface

    interface SpiPeripheralPins spi_pins;
        method csn = spi_sync.in_pins.csn;
        method sclk = spi_sync.in_pins.sclk;
        method copi = spi_sync.in_pins.copi;
        method cipo = spi_sync.in_pins.cipo;
    endinterface


endmodule

(* synthesize *)
module mkGimletTestTop(Empty);
    SPITestController controller <- mkSpiTestController();
    TBTestRawNicPinsSource nic_pins_bfm <- mkTestNicRawPinsSource();

    Top gimlet_fpga_top <- mkGimletSeq();
    
    mkConnection(controller.pins, gimlet_fpga_top.spi_pins);
    mkConnection(gimlet_fpga_top.in_pins.nic_pins, nic_pins_bfm.pins);
    // TODO: nic_pins_bfm client inter

endmodule


endpackage: GimletSeqTop