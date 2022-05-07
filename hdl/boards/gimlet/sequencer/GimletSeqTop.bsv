// Copyright 2021 Oxide Computer Company

package GimletSeqTop;

// BSV-provided stuff
import Clocks::*;
import Connectable::*;
import ClientServer::*;
import DefaultValue::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

// Local stuff
import SPI::*;

// import EarlyPowerBlock::*;
import GimletRegs::*;
import GimletSeqFpgaRegs::*;
import A1Block::*;
import A0Block::*;
import NicBlock::*;
// import MiscIO::*;
import RegCommon::*;  // Testbench only
import PowerRail::*;  // Testbench only


typedef struct {
    Integer one_ms_counts;
} GimletSeqTopParameters;

interface InnerTop;
    interface SpiPeripheralPins spi_pins;
    interface A1Pins a1_pins;
    interface A0Pins a0_pins;
endinterface

//
// This is the "inner-top" module, meaning we expect everything to already be synchronized.
//
module mkGimletInnerTop #(GimletSeqTopParameters parameters) (InnerTop);
    // SPI interface
    SpiPeripheralSync spi_sync <- mkSpiPeripheralPinSync();
    SpiPeripheralPhy phy <- mkSpiPeripheralPhy();
    SpiDecodeIF decode <- mkSpiRegDecode();
    mkConnection(spi_sync.syncd_pins, phy.pins);
    mkConnection(decode.spi_byte, phy.decoder_if);  // Output of the SPI PHY block to the SPI decoder block (client/server interface)
   
    // Register block
    GimletRegIF regs <- mkGimletRegs();
    mkConnection(decode.reg_con, regs.decoder_if);  // Client of SPI decoder to Server of registers block.
    // State machine blocks
    // NicBlockTop nic_block <- mkNicBlock(parameters.one_ms_counts);
    // EarlyBlockTop early_block <- mkEarlyBlock();
    //
    // A1 Block
    A1BlockTop a1_block <- mkA1BlockSeq(parameters.one_ms_counts);
    mkConnection(a1_block.reg_if, regs.a1_block);
    //
    // A0 Block
    A0BlockTop a0_block <- mkA0BlockSeq(parameters.one_ms_counts);
    mkConnection(a0_block.reg_if, regs.a0_block);
    mkConnection(a0_block.a0_idle, a1_block.a0_idle);
    mkConnection(a0_block.a1_ok, a1_block.a1_ok);

    // 
    // Nic Block
    NicBlockTop nic_block <- mkNicBlockSeq(parameters.one_ms_counts);
    mkConnection(nic_block.reg_if, regs.nic_block);
    mkConnection(a0_block.a0_ok, nic_block.a0_ok);
    Reg#(Bool) hp_idle <- mkReg(True);
    mkConnection(hp_idle, a0_block.hp_idle);

    interface spi_pins = spi_sync.in_pins;
    interface a1_pins = a1_block.pins;
    interface a0_pins = a0_block.pins;
   

    //  //mkConnection(spi_sync.syncd_pins.cipo, spi_cipo_enabled._write);
    // //  NIC pins
    // mkConnection(nic_pins.source, nic_block.syncd_pins);  // Synchronized pins to NIC block
    // mkConnection(nic_block.reg_if, regs.nic_block); // Connect registers and NIC block
    // // Early block pins
    // mkConnection(early_pins.syncd_pins, early_block.syncd_pins); // Synchronized pins to early block
    // mkConnection(early_block.reg_if, regs.early_block); // Connect registers and early block
    // // A1 block pins
    // mkConnection(a1_pins.syncd_pins, a1_block.syncd_pins);
    
    // // A1 -> A0 interlock
    // mkConnection(a1_block.a1_ok, a0_block.upstream_ok);
    // mkConnection(a0_block.a0_idle, a1_block.a0_idle);
    // mkConnection(a0_block.a0_ok, nic_block.upstream_ok);
    // // A0 block pins
    // mkConnection(a0_pins.syncd_pins, a0_block.syncd_pins);
    // mkConnection(a0_block.reg_if, regs.a0_block);
    // // Misc block pins
    // mkConnection(misc_pins.syncd_pins, misc_block.syncd_pins);
    // mkConnection(misc_block.reg_if, regs.misc_block);
    // mkConnection(misc_block.thermtrip, a0_block.thermtrip);

    // interface SequencerInputPins in_pins;
    //     interface NicInputPinsRawSink nic_pins;
    //         // Feed the nic pins into the nic pin synchronizer
    //         method pwr_cont_nic_pg0 = nic_pins.sink.pwr_cont_nic_pg0;
    //         method pwr_cont_nic_nvrhot = nic_pins.sink.pwr_cont_nic_nvrhot;
    //         method pwr_cont_nic_cfp = nic_pins.sink.pwr_cont_nic_cfp;
    //         method nic_to_seq_v1p5a_pg_l = nic_pins.sink.nic_to_seq_v1p5a_pg_l;
    //         method nic_to_seq_v1p5d_pg_l = nic_pins.sink.nic_to_seq_v1p5d_pg_l;
    //         method nic_to_seq_v1p2_pg_l = nic_pins.sink.nic_to_seq_v1p2_pg_l;
    //         method nic_to_seq_v1p1_pg_l = nic_pins.sink.nic_to_seq_v1p1_pg_l;
    //         method pwr_cont_nic_pg1 = nic_pins.sink.pwr_cont_nic_pg1;
    //     endinterface
    //     interface early_in_pins = early_pins.in_pins;
    //     interface a1_pins = a1_pins.in_pins;
    //     interface a0_pins = a0_pins.in_pins;
    //     interface misc_pins = misc_pins.in_pins;
    // endinterface

    // interface SpiPeripheralPins spi_pins;
    //     // Feed the spi pins into the spi pin synchronizer
    //     method csn = spi_sync.in_pins.csn;
    //     method sclk = spi_sync.in_pins.sclk;
    //     method copi = spi_sync.in_pins.copi;
    //     method cipo = spi_sync.in_pins.cipo;
    //     method output_en = spi_sync.in_pins.output_en;
    // endinterface

    // interface SeqOutputPins out_pins;
    //     method seq_to_sp_interrupt = regs.seq_to_sp_interrupt;
    //     interface nic_pins = nic_block.out_pins;
    //     interface early_pins = early_block.out_pins;
    //     interface a1_pins = a1_block.out_pins;
    //     interface a0_pins = a0_block.out_pins;
    //     interface misc_pins = misc_block.out_pins;
    // endinterface
endmodule

function Stmt spiRead(Reg#(Bit#(8)) read_data, Integer addr, Server#(Vector#(4, Bit#(8)),Vector#(4, Bit#(8))) bfm);
    return seq
        action
            Vector#(4, Bit#(8)) tx =  newVector();
            tx[0] = unpack(zeroExtend(pack(READ)));
            tx[1] = unpack('h00);
            tx[2] = unpack(fromInteger(addr));
            tx[3] = unpack('h00);
            bfm.request.put(tx);
        endaction
        action
            let rx <- bfm.response.get();
            // $display("0x%x", rx[0]);
            // $display("0x%x", rx[1]);
            // $display("0x%x", rx[2]);
            // $display("0x%x", rx[3]);
            // $display("0x%x", rx[4]);
            // $display("0x%x", rx[5]);
            // $display("0x%x", rx[6]);
            // $display("0x%x", rx[7]);
            read_data <= rx[3];
        endaction
    endseq;
endfunction
function Stmt spiWrite(Integer addr, Bit#(8) data, Server#(Vector#(4, Bit#(8)),Vector#(4, Bit#(8))) bfm);
    return seq
         action
            Vector#(4, Bit#(8)) tx =  newVector();
            tx[0] = unpack(zeroExtend(pack(WRITE)));
            tx[1] = unpack('h00);
            tx[2] = unpack(fromInteger(addr));
            tx[3] = unpack(data);  
            bfm.request.put(tx);
        endaction
        action
            let rx <- bfm.response.get();
        endaction
    endseq;
endfunction
function Stmt spiBitSet(Integer addr, Bit#(8) data, Server#(Vector#(4, Bit#(8)),Vector#(4, Bit#(8))) bfm);
    return seq
         action
            Vector#(4, Bit#(8)) tx =  newVector();
            tx[0] = unpack(zeroExtend(pack(BITSET)));
            tx[1] = unpack('h00);
            tx[2] = unpack(fromInteger(addr));
            tx[3] = unpack(data);  
            bfm.request.put(tx);
        endaction
        action
            let rx <- bfm.response.get();
        endaction
    endseq;
endfunction
function Stmt spiBitClear(Integer addr, Bit#(8) data, Server#(Vector#(4, Bit#(8)),Vector#(4, Bit#(8))) bfm);
    return seq
         action
            Vector#(4, Bit#(8)) tx =  newVector();
            tx[0] = unpack(zeroExtend(pack(BITCLEAR)));
            tx[1] = unpack('h00);
            tx[2] = unpack(fromInteger(addr));
            tx[3] = unpack(data);  
            bfm.request.put(tx);
        endaction
        action
            let rx <- bfm.response.get();
        endaction
    endseq;
endfunction

function Stmt spiReadUntil(
    Reg#(Bit#(8)) read_data, 
    Integer addr, 
    Bit#(8) expected, 
    Server#(Vector#(4, Bit#(8)),Vector#(4, Bit#(8))) bfm);
   return seq
         action
             read_data <= ~expected;
         endaction
         while (read_data != expected) seq
             delay(300);
             spiRead(read_data, fromInteger(addr), bfm);
         endseq
     endseq;
 endfunction

interface Bench;
        interface PowerRailModel v3p3_s5;
        interface PowerRailModel v1p5_rtc;
        interface PowerRailModel v1p8_s5;
        interface PowerRailModel v0p9_s5;
        
        interface PowerRailModel vpp_abcd;
        interface PowerRailModel vpp_efgh;
        interface PowerRailModel v3p3_sys;
        interface PowerRailModel v1p8_sp3;
        interface PowerRailModel vdd_mem_abcd;
        interface PowerRailModel vdd_mem_efgh;
        interface PowerRailModel vtt_ab;
        interface PowerRailModel vtt_cd;
        interface PowerRailModel vtt_ef;
        interface PowerRailModel vtt_gh;

        interface Server#(Vector#(4, Bit#(8)),Vector#(4, Bit#(8))) bfm;
        method Action pmbus_on();
        method Action pmbus_off();
        // method Bool a1_ok();
        // method Action power_up();
        // method Action power_down();

endinterface

module mkBench(Bench);
    let sim_params = GimletSeqTopParameters {one_ms_counts: 500};   // Speed up sim time
    
    InnerTop dut <- mkGimletInnerTop(sim_params);

    // SPI controller
    ModelSpiController controller <- mkModelSpiController();
    mkConnection(controller.pins, dut.spi_pins);

    Reg#(Bit#(1)) pwr_cont1_sp3_pg0 <- mkReg(0);
    Reg#(Bit#(1)) pwr_cont2_sp3_pg0 <- mkReg(0);
    mkConnection(pwr_cont1_sp3_pg0, dut.a0_pins.pwr_cont1_sp3_pg0);
    mkConnection(pwr_cont2_sp3_pg0, dut.a0_pins.pwr_cont2_sp3_pg0);

    // Fake SP3
    SP3Model sp3 <- mkSP3Model();
    mkConnection(dut.a0_pins.sp3, sp3.pins);

    // A1 Power rails
    PowerRailModel v3p3_s5_rail <- mkPowerRailModel("v3p3_s5");
    PowerRailModel v1p5_rtc_rail <- mkPowerRailModel("v1p5_rtc");
    PowerRailModel v1p8_s5_rail <- mkPowerRailModel("v1p8_s5");
    PowerRailModel v0p9_s5_rail <- mkPowerRailModel("v0p9_s5");
    mkConnection(v3p3_s5_rail.pins, dut.a1_pins.v3p3_s5);
    mkConnection(v1p5_rtc_rail.pins, dut.a1_pins.v1p5_rtc);
    mkConnection(v1p8_s5_rail.pins, dut.a1_pins.v1p8_s5);
    mkConnection(v0p9_s5_rail.pins, dut.a1_pins.v0p9_s5);

    // A0 Power rails
    PowerRailModel vpp_abcd_rail <- mkPowerRailModel("vpp_abcd");
    PowerRailModel vpp_efgh_rail <- mkPowerRailModel("vpp_efgh");
    PowerRailModel v3p3_sys_rail <- mkPowerRailModel("v3p3_sys");
    PowerRailModel v1p8_sp3_rail <- mkPowerRailModel("v1p8_sp3");
    PowerRailModel vdd_mem_abcd_rail <- mkPowerRailModel("vdd_mem_abcd");
    PowerRailModel vdd_mem_efgh_rail <- mkPowerRailModel("vdd_mem_efgh");
    PowerRailModel vtt_ab_rail <- mkPowerRailModel("vtt_ab");
    PowerRailModel vtt_cd_rail <- mkPowerRailModel("vtt_cd");
    PowerRailModel vtt_ef_rail <- mkPowerRailModel("vtt_ef");
    PowerRailModel vtt_gh_rail <- mkPowerRailModel("vtt_gh");

    mkConnection(vpp_abcd_rail.pins, dut.a0_pins.vpp_abcd);
    mkConnection(vpp_efgh_rail.pins, dut.a0_pins.vpp_efgh);
    mkConnection(v3p3_sys_rail.pins, dut.a0_pins.v3p3_sys);
    mkConnection(v1p8_sp3_rail.pins, dut.a0_pins.v1p8_sp3);
    mkConnection(vdd_mem_abcd_rail.pins, dut.a0_pins.vdd_mem_abcd);
    mkConnection(vdd_mem_efgh_rail.pins, dut.a0_pins.vdd_mem_efgh);
    mkConnection(vtt_ab_rail.pins, dut.a0_pins.vtt_ab);
    mkConnection(vtt_cd_rail.pins, dut.a0_pins.vtt_cd);
    mkConnection(vtt_ef_rail.pins, dut.a0_pins.vtt_ef);
    mkConnection(vtt_gh_rail.pins, dut.a0_pins.vtt_gh);

    interface PowerRailModel v3p3_s5 = v3p3_s5_rail;
    interface PowerRailModel v1p5_rtc = v1p5_rtc_rail;
    interface PowerRailModel v1p8_s5 = v1p8_s5_rail;
    interface PowerRailModel v0p9_s5 = v0p9_s5_rail;
    interface PowerRailModel vpp_abcd = vpp_abcd_rail;
    interface PowerRailModel vpp_efgh = vpp_efgh_rail;
    interface PowerRailModel v3p3_sys = v3p3_sys_rail;
    interface PowerRailModel v1p8_sp3 = v1p8_sp3_rail;
    interface PowerRailModel vdd_mem_abcd = vdd_mem_abcd_rail;
    interface PowerRailModel vdd_mem_efgh = vdd_mem_efgh_rail;
    interface PowerRailModel vtt_ab = vtt_ab_rail;
    interface PowerRailModel vtt_cd = vtt_cd_rail;
    interface PowerRailModel vtt_ef = vtt_ef_rail;
    interface PowerRailModel vtt_gh = vtt_gh_rail;
    interface Server bfm = controller.bfm;
    method Action pmbus_on();
        pwr_cont1_sp3_pg0 <= 1;
        pwr_cont2_sp3_pg0 <= 1;
    endmethod
    method Action pmbus_off();
        pwr_cont1_sp3_pg0 <= 0;
        pwr_cont2_sp3_pg0 <= 0;
    endmethod

endmodule

(* synthesize *)
module mkGimletTestTop(Empty);
    
    Bench bench <- mkBench();

    // Sim book-keeping stuff
    Reg#(Bit#(8)) read_byte <- mkReg(0);

    //HLIST
    //
    mkAutoFSM(
    seq
        // Basic read
        spiRead(read_byte, id0Offset, bench.bfm);
        // Enable A1+A0 (now interlocked), sunny day case
        spiWrite(pwrctrlOffset, pwrctrlA1pwren | pwrctrlA0aEn,  bench.bfm);
        action
            $display("Delay for A1 SM good...");
        endaction
        spiReadUntil(read_byte, a1smstatusOffset, 'h05,  bench.bfm);
         action
            $display("A1 SM good!!!");
        endaction
        action
            $display("Delay for A0 SM pmbus...");
        endaction
        spiReadUntil(read_byte, a0smstatusOffset, 'h07,  bench.bfm);
        delay(30);
        action
             $display("Enable PMBus");
        endaction
        bench.pmbus_on();
        spiReadUntil(read_byte, a0smstatusOffset, 'h0c,  bench.bfm);
        action
             $display("Design Up");
        endaction
        //delay(4100010); // TODO: Be smarter about a Wait for A0 SM good
        // prove that when A0 is up we can't disable A1
        //spiWrite('h09, 'h02, controller.bfm);
        // action
        //     $display("Test thermal trip");
        //     let thermtrip_set_pins = MiscInPinsRawStruct {
        //         sp3_to_seq_thermtrip_l: 0,
        //         sp3_to_seq_fsr_req_l: 1,
        //         seq_to_clk_gpio3: 0,
        //         seq_to_clk_gpio9: 0,
        //         seq_to_clk_gpio8: 0,
        //         seq_to_clk_gpio2: 0,
        //         seq_to_clk_gpio1: 0,
        //         seq_to_clk_gpio5: 0,
        //         seq_to_clk_gpio4: 0
        //     };
        //     misc_pins_bfm.bfm.request.put(thermtrip_set_pins);
        // endaction
        // spiReadUntil(read_byte, a0smstatusOffset, 'h00, controller.bfm);
        // action
        //     $display("Design Faulted A0 off.");
        //     $display("Attempting restart.");
        // endaction
        // action
        //     // Reset therm-trip pin
        //     let thermtrip_set_pins = MiscInPinsRawStruct {
        //         sp3_to_seq_thermtrip_l: 1,
        //         sp3_to_seq_fsr_req_l: 1,
        //         seq_to_clk_gpio3: 0,
        //         seq_to_clk_gpio9: 0,
        //         seq_to_clk_gpio8: 0,
        //         seq_to_clk_gpio2: 0,
        //         seq_to_clk_gpio1: 0,
        //         seq_to_clk_gpio5: 0,
        //         seq_to_clk_gpio4: 0
        //     };
        //     misc_pins_bfm.bfm.request.put(thermtrip_set_pins);
        // endaction
        // spiWrite(pwrctrlOffset, pwrctrlA1pwren,  bench.bm);
        // delay(100);
        // spiWrite(pwrctrlOffset, pwrctrlA0aEn | pwrctrlA1pwren, controller.bfm);
        // action
        //     $display("Delay for A1 SM good...");
        // endaction
        // spiReadUntil(read_byte, a1smstatusOffset, 'h05, controller.bfm);
        // action
        //     $display("Delay for A0 SM good...");
        // endaction
        // spiReadUntil(read_byte, a0smstatusOffset, 'h0c, controller.bfm);
        // action
        //     $display("Design Up");
        // endaction
        // delay(3000);
        // spiWrite(pwrctrlOffset, pwrctrlNicpwren | pwrctrlA0aEn | pwrctrlA1pwren, controller.bfm);
        // delay(6000);
        //  action
        //     $display("Design Up");
        // endaction
        // // Make interrupts go
        // spiWrite(ierOffset, 'hff, controller.bfm);  // enable all interrupts
        // spiBitSet(ifrOffset, ifrFantimeout, controller.bfm);  // use debug to fire an interrupt
        // spiBitClear(ifrOffset, ifrFantimeout, controller.bfm);  // use bitclear to clear pending interrupt
        delay(30000);
        // action
        //     Vector#(8, Bit#(8)) tx =  newVector();
        //     tx[0] = unpack(zeroExtend(pack(READ)));
        //     tx[1] = unpack('h00);
        //     tx[2] = unpack('h09);
        //     tx[3] = unpack('h00);
        //     tx[4] = unpack('h00);
        //     tx[5] = unpack('h00);
        //     tx[6] = unpack('h00);
        //     tx[7] = unpack('h00);
        //     controller.bfm.request.put(tx);
        // endaction
        // action
        //     let rx <- controller.bfm.response.get();
        //     $display(rx[0]);
        //     $display(rx[1]);
        //     $display(rx[2]);
        //     $display(rx[3]);
        //     $display(rx[4]);
        //     $display(rx[5]);
        //     $display(rx[6]);
        //     $display(rx[7]);
        // endaction
        // TODO: enable A0, sunny day case.
        // TODO: wait for pmbus state
    endseq
    );

endmodule


endpackage: GimletSeqTop