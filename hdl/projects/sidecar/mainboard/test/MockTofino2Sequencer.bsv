package MockTofino2Sequencer;

export Tofino2Sequencer::*;
export mkMockTofino2Sequencer;

import ConfigReg::*;

import CommonFunctions::*;
import SidecarMainboardControllerReg::*;
import Tofino2Sequencer::*;


// Mock the Tofino2Sequencer, bypassing most of its behavior while leaving the
// interface in tact, allowing the tests above to focus on just the behavior of
// the PERST and Power Fault pins.
module mkMockTofino2Sequencer (Tofino2Sequencer);
    (* hide *) Tofino2Sequencer _mock <- mkTofino2Sequencer(defaultValue);
    ConfigReg#(TofinoSeqCtrl) ctrl <- mkConfigReg(defaultValue);
    ConfigReg#(Error) mock_error <- mkConfigReg(None);

    PulseWire pcie_reset_request <- mkPulseWire();
    RWire#(TofinoSeqCtrl) ctrl_next <- mkRWire();

    (* fire_when_enabled *)
    rule do_update_state;
        if (ctrl_next.wget matches tagged Valid .next) begin
            if (next.clear_error == 1) begin
                ctrl.en <= 0;
                mock_error <= None;
            end else begin
                ctrl.en <= next.en;
            end

        // Fault when the sequencer is enabled.
        end else if (ctrl.en == 1 && mock_error == None) begin
            mock_error <= PowerFault;
        end
    endrule

    // Override reset behavior of the mock.
    _mock.pcie_reset = pcie_reset_request.send;
        _mock.pins.resets =
                Tofino2Resets {
                    pwron: False,
                    pcie: pcie_reset_request};

    // Override control and error register behavior of the mock.
    _mock.registers.ctrl =
        (interface Reg
            method _read = ctrl;
            method _write = ctrl_next.wset;
        endinterface);

    _mock.registers.error = castToReadOnly(mock_error);

    return _mock;
endmodule

endpackage
