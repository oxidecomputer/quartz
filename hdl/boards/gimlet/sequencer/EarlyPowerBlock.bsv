package EarlyPowerBlock;

import Clocks::*;
import ClientServer::*;
import Connectable::*;
import GetPut::*;
import GimletSeqFpgaRegs::*;

    // Interface for output pins
    interface EarlyOutputPinsRawSource;
        method Bit#(1) seq_to_fanhp_restart_l;
        method Bit#(1) seq_to_fan_hp_en;
        method Bit#(1) seq_to_dimm_efgh_v2p5_en;
        method Bit#(1) seq_to_dimm_abcd_v2p5_en;
    endinterface

    // Catching input pins
    interface EarlyInputPinsRawSink;
        method Action fanhp_to_seq_fault_l(Bit#(1) value);
        method Action fan_to_seq_fan_fail(Bit#(1) value);
        method Action fanhp_to_seq_pwrgd(Bit#(1) value);
        method Action dimm_to_seq_abcd_v2p5_pg(Bit#(1) value);
        method Action dimm_to_seq_efgh_v2p5_pg(Bit#(1) value);
    endinterface

    interface EarlyInputPinsRawSource;
        method Bit#(1) fanhp_to_seq_fault_l;
        method Bit#(1) fan_to_seq_fan_fail;
        method Bit#(1) fanhp_to_seq_pwrgd;
        method Bit#(1) dimm_to_seq_abcd_v2p5_pg;
        method Bit#(1) dimm_to_seq_efgh_v2p5_pg;
    endinterface

    instance Connectable#(EarlyInputPinsRawSource, EarlyInputPinsRawSink);
        module mkConnection#(EarlyInputPinsRawSource source, EarlyInputPinsRawSink sink) (Empty);
            mkConnection(source.fanhp_to_seq_fault_l, sink.fanhp_to_seq_fault_l);
            mkConnection(source.fan_to_seq_fan_fail, sink.fan_to_seq_fan_fail);
            mkConnection(source.fanhp_to_seq_pwrgd, sink.fanhp_to_seq_pwrgd);
            mkConnection(source.dimm_to_seq_abcd_v2p5_pg, sink.dimm_to_seq_abcd_v2p5_pg);
            mkConnection(source.dimm_to_seq_efgh_v2p5_pg, sink.dimm_to_seq_efgh_v2p5_pg);
        endmodule
    endinstance

    // Synchronizer interface, pins in, syncd_pins struct out
    interface EarlyInputSyncBlock;
        interface EarlyInputPinsRawSink in_pins;
        method EarlyRbks syncd_pins;
    endinterface

    // Early -related interface at the
    interface EarlyRegs; // Interface at this block to the register block
        // Normalized pin readbacks to registers
        method EarlyRbks input_readbacks; // Input sampling
        method EarlyPwrStatus output_readbacks; // Output sampling
        method Action output_ctrl(EarlyPowerCtrl value); // Output control
    endinterface

    // Early -related interface at the
    interface EarlyRegsReverse; // Interface at register block
        // Normalized pin readbacks to registers
        method Action input_readbacks(EarlyRbks value); // Input sampling
        method Action output_readbacks(EarlyPwrStatus value); // Output sampling
        method EarlyPowerCtrl output_ctrl; // Output control
    endinterface

    instance Connectable#(EarlyRegs, EarlyRegsReverse);
        module mkConnection#(EarlyRegs source, EarlyRegsReverse sink) (Empty);
            mkConnection(source.input_readbacks, sink.input_readbacks);
            mkConnection(source.output_readbacks, sink.output_readbacks);
            mkConnection(source.output_ctrl, sink.output_ctrl);
        endmodule
    endinstance

    interface EarlyBlockTop;
        method Action syncd_pins(EarlyRbks value);
        interface EarlyRegs reg_if;
        interface EarlyOutputPinsRawSource out_pins;
    endinterface

    // Simple input synchronization block
    module mkEarlySync(EarlyInputSyncBlock);
        Clock clk_sys <- exposeCurrentClock();
        Reset rst_sys <- exposeCurrentReset();

        // Synchronizers
        SyncBitIfc#(Bit#(1)) fanhp_to_seq_fault_l <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) fan_to_seq_fan_fail <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) fanhp_to_seq_pwrgd <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) dimm_to_seq_abcd_v2p5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
        SyncBitIfc#(Bit#(1)) dimm_to_seq_efgh_v2p5_pg <- mkSyncBit1(clk_sys, rst_sys, clk_sys);

        // Output combo
        Wire#(EarlyRbks) cur_syncd_pins <- mkDWire(unpack(0));

        // Put sync'd bits into a combo structure to make passing it around easier
        rule do_structurize;
            cur_syncd_pins <= EarlyRbks {
                efgh_v2p5_spd_pg: dimm_to_seq_efgh_v2p5_pg.read(),
                abcd_v2p5_spd_pg: dimm_to_seq_abcd_v2p5_pg.read(),
                fan_to_seq_fan_fail: fan_to_seq_fan_fail.read(),
                fanhp_to_seq_pwrgd: fanhp_to_seq_pwrgd.read(),
                fanhp_to_seq_fault: ~fanhp_to_seq_fault_l.read()
            };
        endrule

        interface EarlyInputPinsRawSink in_pins;
            method fanhp_to_seq_fault_l = fanhp_to_seq_fault_l.send;
            method fan_to_seq_fan_fail = fan_to_seq_fan_fail.send;
            method fanhp_to_seq_pwrgd = fanhp_to_seq_pwrgd.send;
            method dimm_to_seq_abcd_v2p5_pg = dimm_to_seq_abcd_v2p5_pg.send;
            method dimm_to_seq_efgh_v2p5_pg = dimm_to_seq_efgh_v2p5_pg.send;
        endinterface

        method syncd_pins = cur_syncd_pins._read;
    endmodule

    module mkEarlyBlock(EarlyBlockTop);

        // Output registers
        Reg#(Bit#(1)) seq_to_fanhp_restart_l <- mkReg(unpack(0));
        Reg#(Bit#(1)) seq_to_fan_hp_en <- mkReg(unpack(0));
        Reg#(Bit#(1)) seq_to_dimm_efgh_v2p5_en <- mkReg(unpack(0));
        Reg#(Bit#(1)) seq_to_dimm_abcd_v2p5_en <- mkReg(unpack(0));

        // Combo output readback

        // Combo input wires
        Wire#(EarlyRbks) cur_syncd_pins <- mkDWire(unpack(0));
        Wire#(EarlyPwrStatus) cur_out_pins <- mkDWire(unpack(0));
        Wire#(EarlyPowerCtrl) dbg_out_pins <- mkDWire(unpack(0));

        rule do_pack_output_readbacks;
            cur_out_pins <= EarlyPwrStatus {
                fanhp_restart: ~seq_to_fanhp_restart_l,
                efgh_spd_en: seq_to_dimm_efgh_v2p5_en,
                abcd_spd_en: seq_to_dimm_abcd_v2p5_en,
                fanpwren: seq_to_fan_hp_en
            };
        endrule

        rule do_output_pins;
            seq_to_fanhp_restart_l <= ~dbg_out_pins.fanhp_restart;  // TODO need a one-shot here eventually
            seq_to_fan_hp_en <= dbg_out_pins.fanpwren;
            seq_to_dimm_abcd_v2p5_en <= dbg_out_pins.abcd_spd_en;
            seq_to_dimm_efgh_v2p5_en <= dbg_out_pins.efgh_spd_en;
        endrule

        method syncd_pins = cur_syncd_pins._write;
        interface EarlyRegs reg_if;
            method input_readbacks = cur_syncd_pins._read; // Input sampling
            method output_readbacks = cur_out_pins._read; // Output sampling
            method output_ctrl = dbg_out_pins._write;
        endinterface
        interface EarlyOutputPinsRawSource out_pins;
            method seq_to_fanhp_restart_l = seq_to_fanhp_restart_l._read;
            method seq_to_fan_hp_en = seq_to_fan_hp_en._read;
            method seq_to_dimm_efgh_v2p5_en = seq_to_dimm_efgh_v2p5_en._read;
            method seq_to_dimm_abcd_v2p5_en = seq_to_dimm_abcd_v2p5_en._read;
        endinterface

    endmodule

    interface TBTestEarlyPinsSource;
        interface Client#(Bit#(8), Bool) bfm;
        interface EarlyInputPinsRawSource pins;
    endinterface

    module mkTestEarlyPinsSource(TBTestEarlyPinsSource);
        Reg#(Bit#(1)) fanhp_to_seq_fault_l <- mkReg(0);
        Reg#(Bit#(1)) fan_to_seq_fan_fail <- mkReg(0);
        Reg#(Bit#(1)) fanhp_to_seq_pwrgd <- mkReg(0);
        Reg#(Bit#(1)) dimm_to_seq_abcd_v2p5_pg <- mkReg(0);
        Reg#(Bit#(1)) dimm_to_seq_efgh_v2p5_pg <- mkReg(0);


        interface EarlyInputPinsRawSource pins;
            method fanhp_to_seq_fault_l = fanhp_to_seq_fault_l._read;
            method fan_to_seq_fan_fail = fan_to_seq_fan_fail._read;
            method fanhp_to_seq_pwrgd = fanhp_to_seq_pwrgd._read;
            method dimm_to_seq_abcd_v2p5_pg = dimm_to_seq_abcd_v2p5_pg._read;
            method dimm_to_seq_efgh_v2p5_pg = dimm_to_seq_efgh_v2p5_pg._read;
        endinterface
        interface Client bfm;
            interface Get request;
            endinterface
            interface Put response;
            endinterface
        endinterface
    endmodule
endpackage