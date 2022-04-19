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
import NicBlock::*;
import EarlyPowerBlock::*;
import GimletRegs::*;
import GimletSeqFpgaRegs::*;
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
    method Bit#(1) seq_to_sp_interrupt;
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

typedef struct {
    Integer one_ms_counts;
} GimletSeqTopParameters;



module mkGimletInnerTop #(GimletSeqTopParameters parameters) (Top);
    Clock cur_clk <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, cur_clk);


    // Sequencer Input synchronizers (meta-harden inputs)
    NicInputSync nic_pins <- mkNicInputSync();
    EarlyInputSyncBlock early_pins <- mkEarlySync();
    A1InputSyncBlock a1_pins <- mkA1Sync();
    A0InputSyncBlock a0_pins <- mkA0Sync();
    MiscInputSyncBlock misc_pins <- mkMiscSync();

    // SPI block, including synchronizer
    SpiPeripheralSync spi_sync <- mkSpiPeripheralPinSync();    
    SpiPeripheralPhy phy <- mkSpiPeripheralPhy();
    SpiDecodeIF decode <- mkSpiRegDecode();
    // Regiser block
    GimletRegIF regs <- mkGimletRegs();
    // State machine blocks
    NicBlockTop nic_block <- mkNicBlock(parameters.one_ms_counts);
    EarlyBlockTop early_block <- mkEarlyBlock();
    A1BlockTop a1_block <- mkA1Block(parameters.one_ms_counts);
    A0BlockTop a0_block <- mkA0Block(parameters.one_ms_counts);
    MiscBlockTop misc_block <- mkMiscBlock();
    // Connections
    //  SPI
    mkConnection(spi_sync.syncd_pins, phy.pins);    // Output of spi synchronizer to SPI PHY block (just pins interface)
    mkConnection(decode.spi_byte, phy.decoder_if);  // Output of the SPI PHY block to the SPI decoder block (client/server interface)
    mkConnection(decode.reg_con, regs.decoder_if);  // Client of SPI decoder to Server of registers block.

     //mkConnection(spi_sync.syncd_pins.cipo, spi_cipo_enabled._write);
    //  NIC pins
    mkConnection(nic_pins.source, nic_block.syncd_pins);  // Synchronized pins to NIC block
    mkConnection(nic_block.reg_if, regs.nic_block); // Connect registers and NIC block
    // Early block pins
    mkConnection(early_pins.syncd_pins, early_block.syncd_pins); // Synchronized pins to early block
    mkConnection(early_block.reg_if, regs.early_block); // Connect registers and early block
    // A1 block pins
    mkConnection(a1_pins.syncd_pins, a1_block.syncd_pins);
    mkConnection(a1_block.reg_if, regs.a1_block);
    // A1 -> A0 interlock
    mkConnection(a1_block.a1_ok, a0_block.upstream_ok);
    mkConnection(a0_block.a0_idle, a1_block.a0_idle);
    mkConnection(a0_block.a0_ok, nic_block.upstream_ok);
    // A0 block pins
    mkConnection(a0_pins.syncd_pins, a0_block.syncd_pins);
    mkConnection(a0_block.reg_if, regs.a0_block);
    // Misc block pins
    mkConnection(misc_pins.syncd_pins, misc_block.syncd_pins);
    mkConnection(misc_block.reg_if, regs.misc_block);
    mkConnection(misc_block.thermtrip, a0_block.thermtrip);

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
        method output_en = spi_sync.in_pins.output_en;
    endinterface

    interface SeqOutputPins out_pins;
        method seq_to_sp_interrupt = regs.seq_to_sp_interrupt;
        interface nic_pins = nic_block.out_pins;
        interface early_pins = early_block.out_pins;
        interface a1_pins = a1_block.out_pins;
        interface a0_pins = a0_block.out_pins;
        interface misc_pins = misc_block.out_pins;
    endinterface
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

(* synthesize *)
module mkGimletTestTop(Empty);
    let sim_params = GimletSeqTopParameters {one_ms_counts: 500};   // Speed up sim time
    ModelSpiController controller <- mkModelSpiController();
    TBTestEarlyPinsSource early_pins_bfm <- mkTestEarlyPinsSource();
    TBTestA1PinsSource a1_pins_bfm <- mkTestA1PinsSource();
    TBTestA0PinsSource a0_pins_bfm <- mkTestA0PinsSource();
    TBTestMiscPinsSource misc_pins_bfm <- mkTestMiscPinsSource();
    TBTestNicPinsSource nic_pins_bfm <- mkTestNicPinsSource();

    Top gimlet_fpga_top <- mkGimletInnerTop(sim_params);
    
    Reg#(Bit#(8)) read_byte <- mkReg(0);
    mkConnection(controller.pins, gimlet_fpga_top.spi_pins);
    mkConnection(early_pins_bfm.pins, gimlet_fpga_top.in_pins.early_in_pins);
    // A1 testbench connections
    mkConnection(a1_pins_bfm.tb_pins_src, gimlet_fpga_top.in_pins.a1_pins);
    mkConnection(gimlet_fpga_top.out_pins.a1_pins, a1_pins_bfm.tb_pins_sink);
    // A0 testbench connections
    mkConnection(a0_pins_bfm.tb_pins_src, gimlet_fpga_top.in_pins.a0_pins);
    mkConnection(gimlet_fpga_top.out_pins.a0_pins, a0_pins_bfm.tb_pins_sink);
    // misc connections
    mkConnection(misc_pins_bfm.pins, gimlet_fpga_top.in_pins.misc_pins);
    // Nic testbench connections
    mkConnection(nic_pins_bfm.tb_pins_src, gimlet_fpga_top.in_pins.nic_pins);
    mkConnection(gimlet_fpga_top.out_pins.nic_pins, nic_pins_bfm.tb_pins_sink);

    //HLIST
    //
    mkAutoFSM(
    seq
        // Basic read
        spiRead(read_byte, id0Offset, controller.bfm);
        // Enable A1+A0 (now interlocked), sunny day case
        spiWrite(pwrctrlOffset, pwrctrlA1pwren | pwrctrlA0aEn, controller.bfm);
        action
            $display("Delay for A1 SM good...");
        endaction
        spiReadUntil(read_byte, a1smstatusOffset, 'h05, controller.bfm);
        action
            $display("Delay for A0 SM good...");
        endaction
        spiReadUntil(read_byte, a0smstatusOffset, 'h0c, controller.bfm);
        action
            $display("Design Up");
        endaction
        //delay(4100010); // TODO: Be smarter about a Wait for A0 SM good
        // prove that when A0 is up we can't disable A1
        //spiWrite('h09, 'h02, controller.bfm);
        action
            $display("Test thermal trip");
            let thermtrip_set_pins = MiscInPinsRawStruct {
                sp3_to_seq_thermtrip_l: 0,
                sp3_to_seq_fsr_req_l: 1,
                seq_to_clk_gpio3: 0,
                seq_to_clk_gpio9: 0,
                seq_to_clk_gpio8: 0,
                seq_to_clk_gpio2: 0,
                seq_to_clk_gpio1: 0,
                seq_to_clk_gpio5: 0,
                seq_to_clk_gpio4: 0
            };
            misc_pins_bfm.bfm.request.put(thermtrip_set_pins);
        endaction
        spiReadUntil(read_byte, a0smstatusOffset, 'h00, controller.bfm);
        action
            $display("Design Faulted A0 off.");
            $display("Attempting restart.");
        endaction
        action
            // Reset therm-trip pin
            let thermtrip_set_pins = MiscInPinsRawStruct {
                sp3_to_seq_thermtrip_l: 1,
                sp3_to_seq_fsr_req_l: 1,
                seq_to_clk_gpio3: 0,
                seq_to_clk_gpio9: 0,
                seq_to_clk_gpio8: 0,
                seq_to_clk_gpio2: 0,
                seq_to_clk_gpio1: 0,
                seq_to_clk_gpio5: 0,
                seq_to_clk_gpio4: 0
            };
            misc_pins_bfm.bfm.request.put(thermtrip_set_pins);
        endaction
        spiWrite(pwrctrlOffset, pwrctrlA1pwren, controller.bfm);
        delay(100);
        spiWrite(pwrctrlOffset, pwrctrlA0aEn | pwrctrlA1pwren, controller.bfm);
        action
            $display("Delay for A1 SM good...");
        endaction
        spiReadUntil(read_byte, a1smstatusOffset, 'h05, controller.bfm);
        action
            $display("Delay for A0 SM good...");
        endaction
        spiReadUntil(read_byte, a0smstatusOffset, 'h0c, controller.bfm);
        action
            $display("Design Up");
        endaction
        delay(3000);
        spiWrite(pwrctrlOffset, pwrctrlNicpwren | pwrctrlA0aEn | pwrctrlA1pwren, controller.bfm);
        delay(6000);
         action
            $display("Design Up");
        endaction
        // Make interrupts go
        spiWrite(ierOffset, 'hff, controller.bfm);  // enable all interrupts
        spiBitSet(ifrOffset, ifrFantimeout, controller.bfm);  // use debug to fire an interrupt
        spiBitClear(ifrOffset, ifrFantimeout, controller.bfm);  // use bitclear to clear pending interrupt
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