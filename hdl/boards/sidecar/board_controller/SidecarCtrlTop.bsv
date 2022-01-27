// Copyright 2022 Oxide Company Company

package SidecarCtrlTop;

// BSV Core
import Clocks::*;

// Oxide
import SidecarCtrlTopIOWrapper::*;

(* synthesize, default_clock_osc="clk_50m_fpga_refclk", default_reset="sp_to_fpga_design_reset_l" *)
module mkSidecarCtrlTop (Top);
    Clock cur_clk <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, cur_clk);

    let _top <- mkSidecarCtrlTopIOWrapper(reset_by reset_sync);
    return _top;
endmodule

endpackage: SidecarCtrlTop