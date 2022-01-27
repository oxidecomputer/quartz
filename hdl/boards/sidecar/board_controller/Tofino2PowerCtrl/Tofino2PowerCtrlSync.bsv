package Tofino2PowerCtrlSync;

// BSV Core
import Clocks::*;
// Oxide
import SidecarCtrlTopPhysIfs::*;
import SyncBits::*;

typedef struct {
    Bit#(1) vdd1p8_pg;
    Bit#(1) vddcore_pg;
    Bit#(1) v0p75_pcie_pg;
    Bit#(1) vddt_pg;
    Bit#(1) vdda15_pg;
    Bit#(1) vdda1p8_pg;
    Bit#(1) v1p8_fault;
    Bit#(1) vddcore_fault;
    Bit#(1) vdda1p5_vddt_fault;
    Bit#(3) vid;
    Bit#(1) vddcore_vrhot;
    Bit#(1) vdda1p5_vddt_vrhot;
    Bit#(1) vr_hot;
    Bit#(1) temp_therm;
} TofinoControlSynced deriving (Bits, Eq, FShow);

interface TofinoControlSync;
    interface TofinoControlInputs in_pins;
    method TofinoControlSynced _read;
endinterface

module mkTofinoControlSync(TofinoControlSync);
    Clock clk_sys <- exposeCurrentClock();
    Reset rst_sys <- exposeCurrentReset();

    SyncBitIfc#(Bit#(1)) vdd1p8_pg_sync             <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vddcore_pg_sync            <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) v0p75_pcie_pg_sync         <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vddt_pg_sync               <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vdda15_pg_sync             <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vdda1p8_pg_sync            <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) v1p8_fault_sync            <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vddcore_fault_sync         <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vdda1p5_vddt_fault_sync    <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitsIfc#(Bit#(3)) vid_sync                  <- mkSyncBitsToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vddcore_vrhot_l_sync       <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vdda1p5_vddt_vrhot_l_sync  <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) vr_hot_l_sync              <- mkSyncBitToCC(clk_sys, rst_sys);
    SyncBitIfc#(Bit#(1)) temp_therm_l_sync          <- mkSyncBitToCC(clk_sys, rst_sys);

    interface TofinoControlInputs in_pins;
        method vr_tf_v1p8_to_fpga_vdd1p8_pg     = vdd1p8_pg_sync.send;
        method vr_tf_vddcore_to_fpga_pg         = vddcore_pg_sync.send;
        method ldo_to_fpga_v0p75_tf_pcie_pg     = v0p75_pcie_pg_sync.send;
        method vr_tf_vddx_to_fpga_vddt_pg       = vddt_pg_sync.send;
        method vr_tf_vddx_to_fpga_vdda15_pg     = vdda15_pg_sync.send;
        method vr_tf_v1p8_to_fpga_vdda1p8_pg    = vdda1p8_pg_sync.send;
        method vr_tf_v1p8_to_fpga_fault         = v1p8_fault_sync.send;
        method vr_tf_vddcore_to_fpga_fault      = vddcore_fault_sync.send;
        method vr_tf_vddx_to_fpga_fault         = vdda1p5_vddt_fault_sync.send;
        method tf_to_fpga_vid                   = vid_sync.send;
        method vr_tf_vddcore_to_fpga_vrhot_l    = vddcore_vrhot_l_sync.send;
        method vr_tf_vddx_to_fpga_vrhot         = vdda1p5_vddt_vrhot_l_sync.send;
        method vr_tf_v1p8_to_fpga_vr_hot_l      = vr_hot_l_sync.send;
        method tf_to_fpga_temp_therm_l          = temp_therm_l_sync.send;
    endinterface

    method TofinoControlSynced _read();
        return TofinoControlSynced {
            vdd1p8_pg:          vdd1p8_pg_sync.read(),
            vddcore_pg:         vddcore_pg_sync.read(),
            v0p75_pcie_pg:      v0p75_pcie_pg_sync.read(),
            vddt_pg:            vddt_pg_sync.read(),
            vdda15_pg:          vdda15_pg_sync.read(),
            vdda1p8_pg:         vdda1p8_pg_sync.read(),
            v1p8_fault:         v1p8_fault_sync.read(),
            vddcore_fault:      vddcore_fault_sync.read(),
            vdda1p5_vddt_fault: vdda1p5_vddt_fault_sync.read(),
            vid:                vid_sync.read(),
            vddcore_vrhot:      invert(vddcore_vrhot_l_sync.read()),
            vdda1p5_vddt_vrhot: invert(vdda1p5_vddt_vrhot_l_sync.read()),
            vr_hot:             invert(vr_hot_l_sync.read()),
            temp_therm:         invert(temp_therm_l_sync.read())
        };
    endmethod
endmodule

endpackage: Tofino2PowerCtrlSync