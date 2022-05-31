// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package PCIeEndpointController;

import ConfigReg::*;

import SidecarMainboardControllerReg::*;

//
// `PCIeEndpointController(..)` implements a minimal interface to allow software
// control over the PCIe control signals between Gimlet and Sidecar.
//

(* always_enabled *)
interface Pins;
    method Bool present();
    method Bool power_fault();
    method Bool alert();
    method Action reset(Bool val);
endinterface

interface PCIeEndpointController;
    interface Pins pins;
    interface Reg#(PcieHotplugCtrl) ctrl;
    interface ReadOnly#(PcieHotplugStatus) status;
endinterface

module mkPCIeEndpointController (PCIeEndpointController);
    ConfigReg#(PcieHotplugCtrl) ctrl_r <- mkConfigReg(unpack('0));
    ConfigReg#(PcieHotplugStatus) status_r <- mkConfigRegU();

    interface Pins pins;
        method present = unpack(ctrl_r.present);
        method power_fault = unpack(ctrl_r.power_fault);
        method alert = unpack(ctrl_r.alert);
        method Action reset(Bool val);
            status_r.host_reset <= pack(val);
        endmethod
    endinterface

    interface Reg ctrl = ctrl_r;
    interface ReadOnly status = regToReadOnly(status_r);
endmodule

endpackage
