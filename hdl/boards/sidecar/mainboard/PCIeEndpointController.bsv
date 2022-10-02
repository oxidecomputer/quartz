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
// control over the PCIe sideband signals between Gimlet and Sidecar.
//

(* always_enabled *)
interface Pins;
    method Bool present();
    method Bool power_fault();
    method Bool alert();
    method Action reset(Bool val);
endinterface

(* always_enabled *)
interface Registers;
    interface Reg#(PcieHotplugCtrl) ctrl;
    interface ReadOnly#(PcieHotplugStatus) status;
endinterface

interface PCIeEndpointController;
    interface Pins pins;
    interface Registers registers;
    method Bool reset_peripheral();
endinterface

module mkPCIeEndpointController (PCIeEndpointController);
    ConfigReg#(PcieHotplugCtrl) ctrl <- mkConfigReg(unpack('0));
    ConfigReg#(PcieHotplugStatus) status <- mkConfigRegU();

    interface Pins pins;
        method present = unpack(ctrl.present);
        method power_fault = unpack(ctrl.power_fault);
        method alert = unpack(ctrl.alert);
        method Action reset(Bool val);
            status.host_reset <= pack(val);
        endmethod
    endinterface

    interface Registers registers;
        interface Reg ctrl = ctrl;
        interface ReadOnly status = regToReadOnly(status);
    endinterface

    method Bool reset_peripheral();
        let software_reset =
                ctrl.override_host_reset == 1 &&
                ctrl.reset == 1;

        let host_reset =
                ctrl.override_host_reset == 0 &&
                status.host_reset == 1;

        return (software_reset || host_reset);
    endmethod
endmodule

endpackage
