// Copyright 2021 Oxide Computer Company

package GimletSeqTop;

// BSV-provided stuff
import Assert::*;
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
    interface NicPins nic_pins;
    interface RegPins reg_pins;
endinterface

//
// This is the "inner-top" module, meaning we expect everything to already be synchronized.
//
module mkGimletInnerTop #(GimletSeqTopParameters parameters,
                          Vector#(4, Bit#(8)) ver,
                          Vector#(4, Bit#(8)) sha) (InnerTop);
    // SPI interface
    SpiPeripheralSync spi_sync <- mkSpiPeripheralPinSync();
    SpiPeripheralPhy phy <- mkSpiPeripheralPhy();
    SpiDecodeIF decode <- mkSpiRegDecode();
    mkConnection(spi_sync.syncd_pins, phy.pins);
    mkConnection(decode.spi_byte, phy.decoder_if);  // Output of the SPI PHY block to the SPI decoder block (client/server interface)

    // Register block
    GimletRegIF regs <- mkGimletRegs(ver, sha);
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
    interface nic_pins = nic_block.pins;
    interface reg_pins = regs.pins;
   
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

        interface PowerRailModel ldo_v3p3;
        interface PowerRailModel v1p5a;
        interface PowerRailModel v1p5d;
        interface PowerRailModel v1p2_enet;
        interface PowerRailModel v1p2;
        interface PowerRailModel v1p1;
        interface PowerRailModel v0p9_a0hp;

        interface Server#(Vector#(4, Bit#(8)),Vector#(4, Bit#(8))) bfm;
        method Action pmbus_on();
        method Action pmbus_off();
        method Action thermtrip();
        method Action amd_force_reset_assert();
        method Action amd_clear_reset_assert();
        method Action amd_force_pwrok_deassert();
        method Action amd_clear_pwrok_deassert();
        // method Bool a1_ok();
        // method Action power_up();
        // method Action power_down();

endinterface

module mkBench(Bench);
    let sim_params = GimletSeqTopParameters {one_ms_counts: 500};   // Speed up sim time
    // Sentinel values for simulation (real data stamped post-P&R)
    Vector#(4, Bit#(8)) ver = reverse(unpack(32'hDEADBEEF));
    Vector#(4, Bit#(8)) sha = reverse(unpack(32'hCAFEBABE));
    InnerTop dut <- mkGimletInnerTop(sim_params, ver, sha);

    // SPI controller
    ModelSpiController controller <- mkModelSpiController();
    mkConnection(controller.pins, dut.spi_pins);

    Reg#(Bit#(1)) pwr_cont1_sp3_pg0 <- mkReg(0);
    Reg#(Bit#(1)) pwr_cont2_sp3_pg0 <- mkReg(0);
    Reg#(Bit#(1)) sp3_to_seq_nic_perst_l <- mkReg(1);
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

    // NIC rails
    PowerRailModel ldo_v3p3_rail <- mkPowerRailModel("ldo_v3p3");
    PowerRailModel v1p5a_rail <- mkPowerRailModel("v1p5a");
    PowerRailModel v1p5d_rail <- mkPowerRailModel("v1p5d");
    PowerRailModel v1p2_enet_rail <- mkPowerRailModel("v1p5d");
    PowerRailModel v1p2_rail <- mkPowerRailModel("v1p2");
    PowerRailModel v1p1_rail <- mkPowerRailModel("v1p1");
    PowerRailModel v0p9_a0hp_rail <- mkPowerRailModel("v0p9_a0hp");

    mkConnection(ldo_v3p3_rail.pins, dut.nic_pins.ldo_v3p3);
    mkConnection(v1p5a_rail.pins, dut.nic_pins.v1p5a);
    mkConnection(v1p5d_rail.pins, dut.nic_pins.v1p5d);
    mkConnection(v1p2_enet_rail.pins, dut.nic_pins.v1p2_enet);
    mkConnection(v1p2_rail.pins, dut.nic_pins.v1p2);
    mkConnection(v1p1_rail.pins, dut.nic_pins.v1p1);
    mkConnection(v0p9_a0hp_rail.pins, dut.nic_pins.v0p9_a0hp);
    mkConnection(sp3_to_seq_nic_perst_l, dut.nic_pins.sp3_to_seq_nic_perst_l);

            // method nic_to_seq_ext_rst_l = nic_to_seq_ext_rst_l._write;
            // method sp3_to_seq_nic_perst_l = sp3_to_seq_nic_perst_l._write;
            // method seq_to_nic_cld_rst_l = seq_to_nic_cld_rst_l._read;
            // method seq_to_nic_perst_l = seq_to_nic_perst_l._read;
            // method nic_to_sp3_pwrflt_l = nic_to_sp3_pwrflt_l._read;
            // method seq_to_nic_comb_pg_l = seq_to_nic_comb_pg_l._read;

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

    interface PowerRailModel ldo_v3p3 = ldo_v3p3_rail;
    interface PowerRailModel v1p5a = v1p5a_rail;
    interface PowerRailModel v1p5d = v1p5d_rail;
    interface PowerRailModel v1p2_enet = v1p2_enet_rail;
    interface PowerRailModel v1p2 = v1p2_rail;
    interface PowerRailModel v1p1 = v1p1_rail;
    interface PowerRailModel v0p9_a0hp = v0p9_a0hp_rail;

    interface Server bfm = controller.bfm;
    method Action pmbus_on();
        pwr_cont1_sp3_pg0 <= 1;
        pwr_cont2_sp3_pg0 <= 1;
    endmethod
    method Action pmbus_off();
        pwr_cont1_sp3_pg0 <= 0;
        pwr_cont2_sp3_pg0 <= 0;
    endmethod
    method Action thermtrip();
        sp3.thermtrip(True);
    endmethod
    method Action amd_force_reset_assert();
        sp3.rst_override(True);
    endmethod
    method Action amd_clear_reset_assert();
        sp3.rst_override(False);
    endmethod
    method Action amd_force_pwrok_deassert();
        sp3.pwrok_override(False);
    endmethod
    method Action amd_clear_pwrok_deassert();
        sp3.pwrok_override(True);
    endmethod
endmodule

module mkGimletTopTest(Empty);
    
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
        spiWrite(pwrCtrlOffset, pwrCtrlA1pwren | pwrCtrlA0aEn,  bench.bfm);
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
        // Enable A1+A0 (now interlocked), sunny day case
        spiWrite(nicCtrlOffset, 0,  bench.bfm);
        action
            $display("A0HP");
        endaction
        spiReadUntil(read_byte, outStatusNic2Offset, 'h22,  bench.bfm);
        delay(30);
    endseq
    );

endmodule

module mkGimletThermtripTopTest(Empty);
    
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
        spiWrite(pwrCtrlOffset, pwrCtrlA1pwren | pwrCtrlA0aEn,  bench.bfm);
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

        // Thermtrip
        bench.thermtrip();
        delay(30);
        spiReadUntil(read_byte, ifrOffset, 'h02,  bench.bfm);
        action
            $display("Thermtrip");
        endaction
        spiBitClear(ifrOffset, ifrThermtrip, bench.bfm);
        delay(30);
        spiReadUntil(read_byte, ifrOffset, 'h00,  bench.bfm);
        action
            $display("Thermtrip clear");
        endaction

    endseq
    );

endmodule

module mkGimletAMDResetTripTest(Empty);
    
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
        spiWrite(pwrCtrlOffset, pwrCtrlA1pwren | pwrCtrlA0aEn,  bench.bfm);
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
        delay(30);

        // make AMD reset trip
        bench.amd_force_reset_assert();
        delay(30);
        // Check reset counter
        spiRead(read_byte, amdRstnCntsOffset, bench.bfm);
        dynamicAssert(read_byte == 1, "Did not read proper count read #1");
        // Check IRQ cause
        spiRead(read_byte, ifrOffset, bench.bfm);
        dynamicAssert((read_byte & ifrAmdRstnFedge) != 0, "IRQ flag did not set");
        // Clear AMD trip
        bench.amd_clear_reset_assert();
        delay(30);
        // trip again (counter increases)
        bench.amd_force_reset_assert();
        delay(30);
        // Check counter
        spiRead(read_byte, amdRstnCntsOffset, bench.bfm);
        dynamicAssert(read_byte == 2, "Did not read proper count read #2");
        // Write to reg and check clear
        spiWrite(amdRstnCntsOffset, 1,  bench.bfm);
        spiRead(read_byte, amdRstnCntsOffset, bench.bfm);
        dynamicAssert(read_byte == 0, "Did not read proper count after clear");

    endseq
    );
    
endmodule

module mkGimletAMDPWROKTripTest(Empty);
    
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
        spiWrite(pwrCtrlOffset, pwrCtrlA1pwren | pwrCtrlA0aEn,  bench.bfm);
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
        delay(30);

        // make AMD reset trip
        bench.amd_force_pwrok_deassert();
        delay(30);
        // Check reset counter
        spiRead(read_byte, amdPwroknCntsOffset, bench.bfm);
        dynamicAssert(read_byte == 1, "Did not read proper count read #1");
        // Check IRQ cause
        spiRead(read_byte, ifrOffset, bench.bfm);
        dynamicAssert((read_byte & ifrAmdPwrokFedge) != 0, "IRQ flag did not set");
        // Clear AMD trip
        bench.amd_clear_pwrok_deassert();
        delay(30);
        // trip again (counter increases)
        bench.amd_force_pwrok_deassert();
        delay(30);
        // Check counter
        spiRead(read_byte, amdPwroknCntsOffset, bench.bfm);
        dynamicAssert(read_byte == 2, "Did not read proper count read #2");
        // Write to reg and check clear
        spiWrite(amdPwroknCntsOffset, 1,  bench.bfm);
        spiRead(read_byte, amdPwroknCntsOffset, bench.bfm);
        dynamicAssert(read_byte == 0, "Did not read proper count after clear");

    endseq
    );
    
endmodule


endpackage: GimletSeqTop