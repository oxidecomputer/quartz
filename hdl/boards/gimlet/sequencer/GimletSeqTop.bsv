// Copyright 2021 Oxide Computer Company

package GimletSeqTop;


import Clocks::*;
import Connectable::*;
import ClientServer::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import SpiDecode::*;
import NicBlock::*;
import EarlyPowerBlock::*;
import GimletRegs::*;
import A1Block::*;
import A0Block::*;
import MiscIO::*;
import RegCommon::*;  // Testbench only

(* always_enabled *)
interface Top;
    // SPI interface
    (* prefix = "" *)
    interface SpiPeripheralPins spi_pins;
    (* prefix = "" *)
    interface SequencerInputPins in_pins;
    (* prefix = "" *)
    interface SeqOutputPins out_pins;
endinterface

interface SequencerInputPins;
(* prefix = "" *)
    interface NicInputPinsRawSink nic_pins;
    (* prefix = "" *)
    interface EarlyInputPinsRawSink early_in_pins;
    (* prefix = "" *)
    interface A1InputPinsRawSink a1_pins;
    (* prefix = "" *)
    interface A0InputPinsRawSink a0_pins;
    (* prefix = "" *)
    interface MiscInputPinsRawSink misc_pins;
endinterface

interface SeqOutputPins;
    (* prefix = "" *)
    interface NicOutputPinsRawSource nic_pins;
    (* prefix = "" *)
    interface EarlyOutputPinsRawSource early_pins;
    (* prefix = "" *)
    interface A1OutputSource a1_pins;
    (* prefix = "" *)
    interface A0OutputSource a0_pins;
    (* prefix = "" *)
    interface MiscOutputSource misc_pins;
endinterface

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

// This is the top-level module for the Gimlet Sequencer FPGA.
(* synthesize, default_clock_osc="clk50m" *)
module mkGimletSeqTop (Top);
    // Sequencer Input synchronizers (meta-harden inputs)
    NicInputSync nic_pins <- mkNicInputSync();
    EarlyInputSyncBlock early_pins <- mkEarlySync();
    A1InputSyncBlock a1_pins <- mkA1Sync();
    A0InputSyncBlock a0_pins <- mkA0Sync();
    MiscInputSyncBlock misc_pins <- mkMiscSync();

    // SPI block, including synchronizer
    SpiPeripheralSync spi_sync <- mkSpiPeripheralPinSync;    
    SpiPeripheralPhy phy <- mkSpiPeripheralPhy();
    SpiDecodeIF decode <- mkSpiRegDecode();
    // Regiser block
    GimletRegIF regs <- mkGimletRegs();
    // State machine blocks
    NicBlockTop nic_block <- mkNicBlock();
    EarlyBlockTop early_block <- mkEarlyBlock();
    A1BlockTop a1_block <- mkA1Block();
    A0BlockTop a0_block <- mkA0Block();
    MiscBlockTop misc_block <- mkMiscBlock();
    // Connections
    //  SPI
    mkConnection(spi_sync.syncd_pins, phy.pins);    // Output of spi synchronizer to SPI PHY block (just pins interface)
    mkConnection(decode.spi_byte, phy.decoder_if);  // Output of the SPI PHY block to the SPI decoder block (client/server interface)
    mkConnection(decode.reg_con, regs.decoder_if);  // Client of SPI decoder to Server of registers block.
    //  NIC pins
    mkConnection(nic_pins.source, nic_block.syncd_pins);  // Synchronized pins to NIC block
    mkConnection(nic_block.reg_if, regs.nic_in_pins); // Connect registers and NIC block
    // Early block pins
    mkConnection(early_pins.syncd_pins, early_block.syncd_pins); // Synchronized pins to early block
    mkConnection(early_block.reg_if, regs.early_block); // Connect registers and early block
    // A1 block pins
    mkConnection(a1_pins.syncd_pins, a1_block.syncd_pins);
    mkConnection(a1_block.reg_if, regs.a1_block);
    // A0 block pins
    mkConnection(a0_pins.syncd_pins, a0_block.syncd_pins);
    mkConnection(a0_block.reg_if, regs.a0_block);
    // A0 block pins
    mkConnection(misc_pins.syncd_pins, misc_block.syncd_pins);
    mkConnection(misc_block.reg_if, regs.misc_block);

    interface SequencerInputPins in_pins;
        interface NicInputPinsRawSink nic_pins;
            // Feed the nic pins into the nic pin synchronizer
            method pwr_cont_nic_pg0 = nic_pins.sink.pwr_cont_nic_pg0;
            method pwr_cont_nic_nvrhot = nic_pins.sink.pwr_cont_nic_nvrhot;
            method pwr_cont_nic_cfp = nic_pins.sink.pwr_cont_nic_cfp;
            method nic_to_seq_v1p5a_pg_l = nic_pins.sink.nic_to_seq_v1p5a_pg_l;
            method nic_to_seq_v1p5d_pg_l = nic_pins.sink.nic_to_seq_v1p5d_pg_l;
            method nic_to_seq_v1p2_pg_l = nic_pins.sink.nic_to_seq_v1p2_pg_l;
            method nic_to_seq_v1p1_pg_l = nic_pins.sink.nic_to_seq_v1p1_pg_l;
            method pwr_cont_nic_pg1 = nic_pins.sink.pwr_cont_nic_pg1;
        endinterface
        interface early_in_pins = early_pins.in_pins;
        interface a1_pins = a1_pins.in_pins;
        interface a0_pins = a0_pins.in_pins;
        interface misc_pins = misc_pins.in_pins;
    endinterface

    interface SpiPeripheralPins spi_pins;
        // Feed the spi pins into the spi pin synchronizer
        method csn = spi_sync.in_pins.csn;
        method sclk = spi_sync.in_pins.sclk;
        method copi = spi_sync.in_pins.copi;
        method cipo = spi_sync.in_pins.cipo;
    endinterface

    interface SeqOutputPins out_pins;
        interface nic_pins = nic_block.out_pins;
        interface early_pins = early_block.out_pins;
        interface a1_pins = a1_block.out_pins;
        interface a0_pins = a0_block.out_pins;
        interface misc_pins = misc_block.out_pins;
    endinterface

endmodule

(* synthesize *)
module mkGimletTestTop(Empty);
    SPITestController controller <- mkSpiTestController();
    TBTestRawNicPinsSource nic_pins_bfm <- mkTestNicRawPinsSource();
    TBTestEarlyPinsSource early_pins_bfm <- mkTestEarlyPinsSource();
    TBTestA1PinsSource a1_pins_bfm <- mkTestA1PinsSource();
    TBTestA0PinsSource a0_pins_bfm <- mkTestA0PinsSource();
    TBTestMiscPinsSource misc_pins_bfm <- mkTestMiscPinsSource();

    Top gimlet_fpga_top <- mkGimletSeqTop();
    
    mkConnection(controller.pins, gimlet_fpga_top.spi_pins);
    mkConnection(nic_pins_bfm.pins, gimlet_fpga_top.in_pins.nic_pins);
    mkConnection(early_pins_bfm.pins, gimlet_fpga_top.in_pins.early_in_pins);
    mkConnection(a1_pins_bfm.pins, gimlet_fpga_top.in_pins.a1_pins);
    mkConnection(a0_pins_bfm.pins, gimlet_fpga_top.in_pins.a0_pins);
    mkConnection(misc_pins_bfm.pins, gimlet_fpga_top.in_pins.misc_pins);

    mkAutoFSM(
    seq
        // Basic read-write
        action
            Vector#(8, Bit#(8)) tx =  newVector();
            tx[0] = unpack(zeroExtend(pack(READ)));
            tx[1] = unpack('h00);
            tx[2] = unpack('h09);
            tx[3] = unpack('h01);
            tx[4] = unpack('h00);
            tx[5] = unpack('h00);
            tx[6] = unpack('h00);
            tx[7] = unpack('h00);
            controller.bfm.request.put(tx);
        endaction
        action
            let rx <- controller.bfm.response.get();
            $display(rx[0]);
            $display(rx[1]);
            $display(rx[2]);
            $display(rx[3]);
            $display(rx[4]);
            $display(rx[5]);
            $display(rx[6]);
            $display(rx[7]);
        endaction
        // Enable A1, sunny day case
         action
            Vector#(8, Bit#(8)) tx =  newVector();
            tx[0] = unpack(zeroExtend(pack(WRITE)));
            tx[1] = unpack('h00);
            tx[2] = unpack('h09);
            tx[3] = unpack('h01);
            tx[4] = unpack('h00);
            tx[5] = unpack('h00);
            tx[6] = unpack('h00);
            tx[7] = unpack('h00);
            controller.bfm.request.put(tx);
        endaction
        action
            let rx <- controller.bfm.response.get();
            $display(rx[0]);
            $display(rx[1]);
            $display(rx[2]);
            $display(rx[3]);
            $display(rx[4]);
            $display(rx[5]);
            $display(rx[6]);
            $display(rx[7]);
        endaction
        action
            Vector#(8, Bit#(8)) tx =  newVector();
            tx[0] = unpack(zeroExtend(pack(READ)));
            tx[1] = unpack('h00);
            tx[2] = unpack('h09);
            tx[3] = unpack('h00);
            tx[4] = unpack('h00);
            tx[5] = unpack('h00);
            tx[6] = unpack('h00);
            tx[7] = unpack('h00);
            controller.bfm.request.put(tx);
        endaction
        action
            let rx <- controller.bfm.response.get();
            $display(rx[0]);
            $display(rx[1]);
            $display(rx[2]);
            $display(rx[3]);
            $display(rx[4]);
            $display(rx[5]);
            $display(rx[6]);
            $display(rx[7]);
        endaction
    endseq
    );

endmodule


endpackage: GimletSeqTop