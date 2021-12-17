package Tofino2PowerCtrl;

// BSV Core
import ConfigReg::*;
import Connectable::*;
import DefaultValue::*;
import DReg::*;
import StmtFSM::*;

// Oxide
import Tofino2PowerCtrlSync::*;
import SidecarSeqRegs::*;

instance Connectable#(TofinoControlSynced, Tofino2SequenceControl);
    module mkConnection#(TofinoControlSynced syncd_in, Tofino2SequenceControl tf2_seq) (Empty);
        mkConnection(syncd_in.vdd1p8_pg, tf2_seq.vdd18.pins.pg);
        mkConnection(syncd_in.vddcore_pg, tf2_seq.vddcore.pins.pg);
        mkConnection(syncd_in.v0p75_pcie_pg, tf2_seq.vddpcie.pins.pg);
        mkConnection(syncd_in.vddt_pg, tf2_seq.vddt.pins.pg);
        mkConnection(syncd_in.vdda15_pg, tf2_seq.vdda15.pins.pg);
        mkConnection(syncd_in.vdda1p8_pg, tf2_seq.vdda18.pins.pg);
        mkConnection(syncd_in.v1p8_fault, tf2_seq.vdd18.pins.fault);
        mkConnection(syncd_in.vddcore_fault, tf2_seq.vddcore.pins.fault);
        mkConnection(syncd_in.vdda1p5_vddt_fault, tf2_seq.vddt.pins.fault);
        mkConnection(syncd_in.vdda1p5_vddt_fault, tf2_seq.vdda15.pins.fault);
        mkConnection(syncd_in.vid, tf2_seq.vid);
        mkConnection(syncd_in.vddcore_vrhot, tf2_seq.vddcore.pins.vrhot);
        mkConnection(syncd_in.vdda1p5_vddt_vrhot, tf2_seq.vddt.pins.vrhot);
        mkConnection(syncd_in.vdda1p5_vddt_vrhot, tf2_seq.vdda15.pins.vrhot);
        mkConnection(syncd_in.vr_hot, tf2_seq.vdd18.pins.vrhot);
        mkConnection(syncd_in.vr_hot, tf2_seq.vdda18.pins.vrhot);
        mkConnection(syncd_in.temp_therm, tf2_seq.temp_therm);
    endmodule
endinstance

interface PowerPins;
    method Bit#(1) en();
    method Action pg(Bit#(1) pg);
    method Action fault(Bit#(1) fault);
    method Action vrhot(Bit#(1) vrhot);
endinterface

interface PowerRail;
    interface PowerPins pins;

    method Bool enabled();
    method Action set_enabled(Bool en);
    method Bool good();
    method Integer timeout();
endinterface

module mkPowerRail #(Integer timeout_) (PowerRail);
    ConfigReg#(Bool) enabled_r <- mkReg(False);
    Wire#(Bool) power_good <- mkDWire(False);
    Wire#(Bool) fault <- mkDWire(False);
    Wire#(Bool) vrhot <- mkDWire(False);

    interface PowerPins pins;
        method en = pack(enabled_r);
        method Action pg(Bit#(1) val) = power_good._write(unpack(val));
        method Action fault(Bit#(1) val) = fault._write(unpack(val));
        method Action vrhot(Bit#(1) val) = vrhot._write(unpack(val));
    endinterface

    method enabled = enabled_r;

    method Action set_enabled(Bool en);
        enabled_r <= en;
    endmethod

    method good = power_good;

    method timeout = timeout_;
endmodule

typedef enum {
    Invalid = 0,
    AwaitPowerUp = 1,
    AwaitVdd18PowerGood = 2,
    AwaitVddCorePowerGood = 3,
    AwaitVddPCIePowerGood = 4,
    AwaitVddtPowerGood = 5,
    AwaitVdda15PowerGood = 6,
    AwaitVdda18PowerGood = 7,
    AwaitVIDDelay = 8,
    AwaitPCIeDelay = 9,
    AwaitPowerDown = 10
} Tofino2SequencingState deriving (Eq, Bits, FShow);

typedef enum {
    None = 0,
    PowerGoodTimeout = 1
} Tofino2SequencingError deriving (Eq, Bits, FShow);

interface Tofino2PowerCtrlRegs;
    method Bit#(4) vid;
    method Bit#(1) irq;
    method TofinoPowerEnables ens;
    method TofinoPowerGoods pgs;
    method Tofino2SequencingState state;
    method Tofino2SequencingError error;
endinterface

interface Tofino2SequenceControl;
    interface PowerRail vdd18;
    interface PowerRail vddcore;
    interface PowerRail vddpcie;
    interface PowerRail vddt;
    interface PowerRail vdda15;
    interface PowerRail vdda18;

    interface PulseWire tick_1ms;

    interface Tofino2PowerCtrlRegs regs;

    method Action start_power_up();
    method Action start_power_down();

    method Action vid(Bit#(3) val);
    method Action temp_therm(Bit#(1) val);

    method Bit#(1) pwron_rst_l();
    method Bit#(1) pcie_rst_l();
    method Bit#(1) core_rst_l();
    method Bit#(1) tofino_power_good();
endinterface

typedef struct {
    // max time a supply has to assert PG
    Integer power_good_timeout;
    // min time to wait after PG is asserted to enable next supply
    Integer power_good_delay;
    // delay after VDD1P8 is stable before VID bits should be sampled
    Integer vid_delay;
    // delay after pwron_rst_l is released before pcie_rst_l should be released
    Integer pcie_delay;
} Tofino2SequenceControlParameters;

module mkTofino2SequenceControl
        #(Tofino2SequenceControlParameters parameters )
            (Tofino2SequenceControl);
    PowerRail vdd18_rail <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vddcore_rail <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vddpcie_rail <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vddt_rail <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vdda15_rail <- mkPowerRail(parameters.power_good_timeout);
    PowerRail vdda18_rail <- mkPowerRail(parameters.power_good_timeout);

    PulseWire tick <- mkPulseWire();

    ConfigReg#(Tofino2SequencingState) state_r <- mkReg(Invalid);
    ConfigReg#(Tofino2SequencingError) error_r <- mkReg(None);

    ConfigReg#(Bit#(1)) pwron_rst_l_r <- mkReg(0);
    ConfigReg#(Bit#(1)) pcie_rst_l_r <- mkReg(0);
    ConfigReg#(Bit#(1)) tofino_power_good_r <- mkReg(0);

    Reg#(Bit#(3)) vid_r <- mkReg(0);

    Reg#(UInt#(8)) ticks_count <- mkReg(0);
    RWire#(UInt#(8)) ticks_count_next <- mkRWireSBR();
    Reg#(UInt#(8)) rail_pg_timeout <- mkReg(0);

    Reg#(Bool) abort <- mkDReg(False);
    PulseWire fault <- mkPulseWire();

    function Action enable_rail(PowerRail rail, Tofino2SequencingState s) =
        action
            rail.set_enabled(True);
            rail_pg_timeout <= fromInteger(rail.timeout);
            state_r <= s;
        endaction;

    function Action disable_rail(PowerRail rail, Tofino2SequencingState s) = 
        action
            rail.set_enabled(False);
            state_r <= s;
        endaction;

    function Action await_power_good(PowerRail rail) =
        action
            // TODO: check timeout/fault.
            await(rail.good());
            ticks_count_next.wset(fromInteger(parameters.power_good_delay + 1));
            await(ticks_count == 0);
        endaction;

    FSM tofino2_power_up_seq <- mkFSMWithPred(seq
        ticks_count_next.wset(fromInteger(parameters.power_good_delay + 1));
        enable_rail(vdd18_rail, AwaitVdd18PowerGood);
        await_power_good(vdd18_rail);
        enable_rail(vddcore_rail, AwaitVddCorePowerGood);
        await_power_good(vddcore_rail);
        enable_rail(vddpcie_rail, AwaitVddPCIePowerGood);
        await_power_good(vddpcie_rail);
        enable_rail(vddt_rail, AwaitVddtPowerGood);
        await_power_good(vddt_rail);
        enable_rail(vdda15_rail, AwaitVdda15PowerGood);
        await_power_good(vdda15_rail);
        enable_rail(vdda18_rail, AwaitVdda18PowerGood);
        await_power_good(vdda18_rail);
        action
            rail_pg_timeout <= 0;
            state_r <= AwaitVIDDelay;
            ticks_count_next.wset(fromInteger(parameters.vid_delay + 1));
        endaction
        await(ticks_count == 0);
        pwron_rst_l_r <= 1;
        action
            state_r <= AwaitPCIeDelay;
            ticks_count_next.wset(fromInteger(parameters.pcie_delay + 1));
        endaction
        await(ticks_count == 0);
        pcie_rst_l_r <= 1;
        state_r <= AwaitPowerDown;
        tofino_power_good_r <= 1;
    endseq, !abort && (state_r != Invalid));

    FSM tofino2_power_down_seq <- mkFSMWithPred(seq
        action
            tofino_power_good_r <= 0;
            pcie_rst_l_r <= 0;
            pwron_rst_l_r <= 0;
            disable_rail(vdda18_rail, AwaitVdda18PowerGood);
        endaction
        disable_rail(vdda15_rail, AwaitVdda18PowerGood);
        disable_rail(vddt_rail, AwaitVddtPowerGood);
        disable_rail(vddpcie_rail, AwaitVddPCIePowerGood);
        disable_rail(vddcore_rail, AwaitVddCorePowerGood);
        disable_rail(vdd18_rail, AwaitVdd18PowerGood);
        state_r <= AwaitPowerUp;
    endseq, tick && !abort);

    (* fire_when_enabled *)
    rule do_reset_sequencer (state_r == Invalid);
        state_r <= AwaitPowerUp;
    endrule

    (* fire_when_enabled *)
    rule do_set_ticks_count (ticks_count_next.wget matches tagged Valid .value);
        ticks_count <= value;
    endrule

    (* fire_when_enabled *)
    rule do_count_ticks (tick && !isValid(ticks_count_next.wget));
        ticks_count <= satMinus(Sat_Zero, ticks_count, 1);
    endrule

    (* fire_when_enabled *)
    rule do_rail_pg_timeout (tick && !tofino2_power_up_seq.done() && rail_pg_timeout != 0);
        rail_pg_timeout <= rail_pg_timeout - 1;
        if (rail_pg_timeout == 1) begin
            abort <= True;
            error_r <= PowerGoodTimeout;
        end
    endrule

    (* fire_when_enabled *)
    rule do_abort (abort);
        tofino2_power_up_seq.abort();
        tofino2_power_down_seq.start();
    endrule

    interface PowerRail vdd18 = vdd18_rail;
    interface PowerRail vddcore = vddcore_rail;
    interface PowerRail vddpcie = vddpcie_rail;
    interface PowerRail vddt = vddt_rail;
    interface PowerRail vdda15 = vdda15_rail;
    interface PowerRail vdda18 = vdda18_rail;

    interface PulseWire tick_1ms = tick;

    interface Tofino2PowerCtrlRegs regs; 
        method vid = {1, vid_r}; // MSB tied to 1 to match datasheet
        method irq = 0;
        method state = state_r;
        method error = error_r;
        method ens = TofinoPowerEnables {
            vdda_1p8_en:    pack(vdda18_rail.enabled),
            vdda_1p5_en:    pack(vdda15_rail.enabled),
            vdd_vddt_en:    pack(vddt_rail.enabled),
            vdd_pcie_en:    pack(vddpcie_rail.enabled),
            vdd_core_en:    pack(vddcore_rail.enabled),
            vdd_1p8_en:     pack(vdd18_rail.enabled)
        };
        method pgs = TofinoPowerGoods {
            vdda_1p8_pg:    pack(vdda18_rail.good),
            vdda_1p5_pg:    pack(vdda15_rail.good),
            vdd_vddt_pg:    pack(vddt_rail.good),
            vdd_pcie_pg:    pack(vddpcie_rail.good),
            vdd_core_pg:    pack(vddcore_rail.good),
            vdd_1p8_pg:     pack(vdd18_rail.good)
        };
    endinterface

    method Action vid(Bit#(3) val) = vid_r._write(val);

    method Action start_power_up if (state_r == AwaitPowerUp);
        $display("Initiate Tofino 2 power up");
        tofino2_power_up_seq.start();
    endmethod

    method Action start_power_down if (!fault && !abort);
        $display("Initiate Tofino 2 power down");
        tofino2_power_down_seq.start();
    endmethod

    method pwron_rst_l = pwron_rst_l_r;
    method pcie_rst_l = pcie_rst_l_r;
    method core_rst_l = 1;
    method tofino_power_good = tofino_power_good_r;

endmodule

endpackage: Tofino2PowerCtrl