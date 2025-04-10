// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MinibarSpiServer;

// BSV
import ClientServer::*;
import ConfigReg::*;
import DefaultValue::*;
import GetPut::*;
import Vector::*;

// Oxide
import git_version::*;
import CommonInterfaces::*;
import IgnitionController::*;
import IgnitionControllerRegisters::*;
import RegCommon::*;

// Minibar
import MinibarMiscRegs::*;
import MinibarPcie::*;
import MinibarRegsPkg::*;

typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;

typedef Server#(SpiRequest, SpiResponse) SpiServer;

module mkSpiServer #(
        MinibarMiscRegs::Registers misc,
        MinibarPcie::Registers pcie,
        Vector#(2, IgnitionController::Registers) ignition_controllers
    )
        (SpiServer);
    PulseWire start_request <- mkPulseWire();
    Wire#(SpiRequest) spi_request <- mkWire(); // SpiRequest{address: 0, wdata: 0, op: NOOP});
    Wire#(SpiResponse) spi_response <- mkWire();

    // registers interal to the SPI server
    ConfigReg#(Scratchpad) scratchpad   <- mkConfigReg(defaultValue);
    Vector#(4, ConfigReg#(Cs0)) checksum
        <- replicateM(mkConfigReg(defaultValue));

    (* fire_when_enabled *)
    rule do_spi_read(start_request && (spi_request.op == READ || spi_request.op == READ_NO_ADDR_INCR));
        let reader =
            case (spi_request.address)
            // ID, see RDL for the (default) values.
            fromInteger(id0Offset): read(Id0'(defaultValue));
            fromInteger(id1Offset): read(Id1'(defaultValue));
            fromInteger(id2Offset): read(Id2'(defaultValue));
            fromInteger(id3Offset): read(Id3'(defaultValue));

            // Checksum
            fromInteger(cs0Offset): read(checksum[0]);
            fromInteger(cs1Offset): read(checksum[1]);
            fromInteger(cs2Offset): read(checksum[2]);
            fromInteger(cs3Offset): read(checksum[3]);

            // Version
            fromInteger(version0Offset): read(version[0]);
            fromInteger(version1Offset): read(version[1]);
            fromInteger(version2Offset): read(version[2]);
            fromInteger(version3Offset): read(version[3]);

            // SHA
            fromInteger(sha0Offset): read(sha[0]);
            fromInteger(sha1Offset): read(sha[1]);
            fromInteger(sha2Offset): read(sha[2]);
            fromInteger(sha3Offset): read(sha[3]);

            // Scratchpad
            fromInteger(scratchpadOffset): read(scratchpad);

            // HCV
            fromInteger(hcvOffset): read(misc.hcv);

            // Sled Connector Presence
            fromInteger(sledPresenceOffset): read(misc.sled_presence);

            // Power stuff
            fromInteger(vbusSysRdbkOffset): read(misc.vbus_sys_rdbk);
            fromInteger(powerCtrlOffset): read(misc.power_ctrl);
            fromInteger(vbusSledOffset): read(misc.vbus_sled);

            // Switches
            fromInteger(switchResetCtrlOffset): read(misc.switch_reset_ctrl);

            // PCIe
            fromInteger(pciePowerCtrlOffset): read(pcie.power_ctrl);
            fromInteger(v12PcieOffset): read(pcie.v12_pcie);
            fromInteger(v3p3PcieOffset): read(pcie.v3p3_pcie);
            fromInteger(pcieRefclkCtrlOffset): read(pcie.refclk_ctrl);
            fromInteger(pcieCtrlOffset): read(pcie.pcie_ctrl);
            fromInteger(pcieRdbkOffset): read(pcie.pcie_rdbk);

            // Ignition
            fromInteger(ignitionTargetsPresentOffset): read(misc.ignition_targets_present);
            // Controller 0
            fromInteger(ignitionController0ControllerStateOffset): read(ignition_controllers[0].controller_state);
            fromInteger(ignitionController0ControllerLinkStatusOffset): read(ignition_controllers[0].controller_link_status);
            fromInteger(ignitionController0TargetSystemTypeOffset): read(ignition_controllers[0].target_system_type);
            fromInteger(ignitionController0TargetSystemStatusOffset): read(ignition_controllers[0].target_system_status);
            fromInteger(ignitionController0TargetSystemFaultsOffset): read(ignition_controllers[0].target_system_faults);
            fromInteger(ignitionController0TargetRequestStatusOffset): read(ignition_controllers[0].target_request_status);
            fromInteger(ignitionController0TargetLink0StatusOffset): read(ignition_controllers[0].target_link0_status);
            fromInteger(ignitionController0TargetLink1StatusOffset): read(ignition_controllers[0].target_link1_status);
            fromInteger(ignitionController0TargetRequestOffset): read(ignition_controllers[0].target_request);
            fromInteger(ignitionController0ControllerStatusReceivedCountOffset): read_volatile(ignition_controllers[0].controller_status_received_count);
            fromInteger(ignitionController0ControllerHelloSentCountOffset): read_volatile(ignition_controllers[0].controller_hello_sent_count);
            fromInteger(ignitionController0ControllerRequestSentCountOffset): read_volatile(ignition_controllers[0].controller_request_sent_count);
            fromInteger(ignitionController0ControllerMessageDroppedCountOffset): read_volatile(ignition_controllers[0].controller_message_dropped_count);
            fromInteger(ignitionController0ControllerLinkEventsSummaryOffset): read(ignition_controllers[0].controller_link_counters.summary);
            fromInteger(ignitionController0TargetLink0EventsSummaryOffset): read(ignition_controllers[0].target_link0_counters.summary);
            fromInteger(ignitionController0TargetLink1EventsSummaryOffset): read(ignition_controllers[0].target_link1_counters.summary);
            // Controller 0
            fromInteger(ignitionController1ControllerStateOffset): read(ignition_controllers[1].controller_state);
            fromInteger(ignitionController1ControllerLinkStatusOffset): read(ignition_controllers[1].controller_link_status);
            fromInteger(ignitionController1TargetSystemTypeOffset): read(ignition_controllers[1].target_system_type);
            fromInteger(ignitionController1TargetSystemStatusOffset): read(ignition_controllers[1].target_system_status);
            fromInteger(ignitionController1TargetSystemFaultsOffset): read(ignition_controllers[1].target_system_faults);
            fromInteger(ignitionController1TargetRequestStatusOffset): read(ignition_controllers[1].target_request_status);
            fromInteger(ignitionController1TargetLink0StatusOffset): read(ignition_controllers[1].target_link0_status);
            fromInteger(ignitionController1TargetLink1StatusOffset): read(ignition_controllers[1].target_link1_status);
            fromInteger(ignitionController1TargetRequestOffset): read(ignition_controllers[1].target_request);
            fromInteger(ignitionController1ControllerStatusReceivedCountOffset): read_volatile(ignition_controllers[1].controller_status_received_count);
            fromInteger(ignitionController1ControllerHelloSentCountOffset): read_volatile(ignition_controllers[1].controller_hello_sent_count);
            fromInteger(ignitionController1ControllerRequestSentCountOffset): read_volatile(ignition_controllers[1].controller_request_sent_count);
            fromInteger(ignitionController1ControllerMessageDroppedCountOffset): read_volatile(ignition_controllers[1].controller_message_dropped_count);
            fromInteger(ignitionController1ControllerLinkEventsSummaryOffset): read(ignition_controllers[1].controller_link_counters.summary);
            fromInteger(ignitionController1TargetLink0EventsSummaryOffset): read(ignition_controllers[1].target_link0_counters.summary);
            fromInteger(ignitionController1TargetLink1EventsSummaryOffset): read(ignition_controllers[1].target_link1_counters.summary);

            default: read(8'hff);
            endcase;

        let data <- reader;

        spi_response <= data;
    endrule

    (* fire_when_enabled *)
    rule do_spi_write(start_request);
        function do_update(r) = update(spi_request.op, r, spi_request.wdata);
        case (spi_request.address)
            fromInteger(cs0Offset): do_update(checksum[0]);
            fromInteger(cs1Offset): do_update(checksum[1]);
            fromInteger(cs2Offset): do_update(checksum[2]);
            fromInteger(cs3Offset): do_update(checksum[3]);
            fromInteger(scratchpadOffset): do_update(scratchpad);
            fromInteger(powerCtrlOffset): do_update(misc.power_ctrl);
            fromInteger(pciePowerCtrlOffset): do_update(pcie.power_ctrl);
            fromInteger(pcieCtrlOffset): do_update(pcie.pcie_ctrl);
            fromInteger(pcieRefclkCtrlOffset): do_update(pcie.refclk_ctrl);
            fromInteger(switchResetCtrlOffset): do_update(misc.switch_reset_ctrl);
            fromInteger(ignitionController0ControllerStateOffset): do_update(ignition_controllers[0].controller_state);
            fromInteger(ignitionController0TargetRequestOffset): do_update(ignition_controllers[0].target_request);
            fromInteger(ignitionController0ControllerLinkEventsSummaryOffset): do_update(ignition_controllers[0].controller_link_counters.summary);
            fromInteger(ignitionController0TargetLink0EventsSummaryOffset): do_update(ignition_controllers[0].target_link0_counters.summary);
            fromInteger(ignitionController0TargetLink1EventsSummaryOffset): do_update(ignition_controllers[0].target_link1_counters.summary);
            fromInteger(ignitionController1ControllerStateOffset): do_update(ignition_controllers[1].controller_state);
            fromInteger(ignitionController1TargetRequestOffset): do_update(ignition_controllers[1].target_request);
            fromInteger(ignitionController1ControllerLinkEventsSummaryOffset): do_update(ignition_controllers[1].controller_link_counters.summary);
            fromInteger(ignitionController1TargetLink0EventsSummaryOffset): do_update(ignition_controllers[1].target_link0_counters.summary);
            fromInteger(ignitionController1TargetLink1EventsSummaryOffset): do_update(ignition_controllers[1].target_link1_counters.summary);
        endcase
    endrule

    interface Put request;
        method Action put(new_spi_request);
            start_request.send();
            spi_request <= new_spi_request;
        endmethod
    endinterface
    interface Get response = toGet(asIfc(spi_response));
endmodule

// Turn the read of a register into an ActionValue.
function ActionValue#(SpiResponse) read(t v)
        provisos (Bits#(t, 8));
    return actionvalue
        return SpiResponse {readdata: pack(v)};
    endactionvalue;
endfunction

function ActionValue#(SpiResponse) read_volatile(ActionValue#(t) av)
        provisos (Bits#(t, 8));
    return actionvalue
        let v <- av;
        return SpiResponse {readdata: pack(v)};
    endactionvalue;
endfunction

function Action update(RegOps op, Reg#(t) r, Bit#(8) data)
        provisos (Bits#(t, 8));
    return action
        let r_ = zeroExtend(pack(r));

        case (op)
            WRITE: r <= unpack(truncate(data));
            WRITE_NO_ADDR_INCR: r <= unpack(truncate(data));
            BITSET: r <= unpack(truncate(r_ | data));
            BITCLEAR: r <= unpack(truncate(r_ & ~data));
        endcase
    endaction;
endfunction

endpackage: MinibarSpiServer