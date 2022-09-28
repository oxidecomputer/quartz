// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package QsfpX32ControllerTopRegs;

import DefaultValue::*;

import CommonFunctions::*;
import QsfpX32ControllerRegsPkg::*;

// This interface takes signals that for various reasons do not make sense to
// wire directly into any modules but need to make it into registers for SW
interface Pins;
    method Bit#(1) led_controller_reset;
    method Bit#(1) led_controller_output_en;
    method Action fpga_app_id(Bit#(1) val);
endinterface

interface Registers;
    interface ReadOnly#(FpgaId) fpga_app_id;
    interface Reg#(LedCtrl) led_ctrl;
endinterface

interface QsfpX32ControllerTopRegs;
    interface Pins pins;
    interface Registers registers;
endinterface

module mkQsfpX32ControllerTopRegs (QsfpX32ControllerTopRegs);

    Reg#(Bit#(1)) fpga_app  <- mkReg(0);
    Reg#(LedCtrl) led_ctrl  <- mkReg(defaultValue);

    interface Registers registers;
        interface ReadOnly fpga_app_id  = valueToReadOnly(FpgaId {id: fpga_app});
        interface Reg led_ctrl          = led_ctrl;
    endinterface

    interface Pins pins;
        method fpga_app_id = fpga_app._write;
        method led_controller_reset     = led_ctrl.reset;
        method led_controller_output_en = led_ctrl.oe;
    endinterface
endmodule

endpackage: QsfpX32ControllerTopRegs