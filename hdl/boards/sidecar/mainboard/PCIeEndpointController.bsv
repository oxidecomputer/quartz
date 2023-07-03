// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package PCIeEndpointController;

import ConfigReg::*;

import CommonFunctions::*;
import SidecarMainboardControllerReg::*;
import Tofino2Sequencer::*;


//
// `PCIeEndpointController(..)` implements a minimal interface to allow software
// control over the PCIe sideband signals between Gimlet and Sidecar.
//

(* always_enabled *)
interface Pins;
    method Bool present();
    method Bool power_fault();
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
endinterface

module mkPCIeEndpointController
        #(Tofino2Sequencer sequencer)
            (PCIeEndpointController);
    ConfigReg#(PcieHotplugCtrl) ctrl <- mkConfigReg(unpack('0));
    ConfigReg#(Bool) host_reset <- mkConfigReg(False);
    ConfigReg#(Bool) power_fault <- mkConfigReg(False);

    (* fire_when_enabled *)
    rule do_set_sequencer_pcie_reset;
        let software_reset =
                ctrl.override_host_reset == 1 &&
                ctrl.reset == 1;

        let host_reset_ =
                ctrl.override_host_reset == 0 &&
                host_reset;

        if (software_reset || host_reset_) begin
            sequencer.pcie_reset();
        end
    endrule

    (* fire_when_enabled *)
    rule do_set_power_fault;
        let software_power_fault =
                ctrl.override_seq_power_fault == 1 &&
                ctrl.power_fault == 1;

        let sequencer_power_fault =
                ctrl.override_seq_power_fault == 0 &&
                sequencer.registers.error.error != 0;

        power_fault <= (software_power_fault || sequencer_power_fault);
    endrule

    interface Pins pins;
        method present = unpack(ctrl.present);
        method reset = host_reset._write;
        method power_fault = power_fault;
    endinterface

    interface Registers registers;
        interface Reg ctrl = ctrl;
        interface ReadOnly status =
            valueToReadOnly(PcieHotplugStatus {
                present: ctrl.present,
                host_reset: pack(host_reset),
                power_fault: pack(power_fault)});
    endinterface
endmodule

endpackage
