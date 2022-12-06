// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MDIOTests;

import Assert::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import FIFO::*;
import StmtFSM::*;

import Bidirection::*;

import MDIO::*;
import MDIOPeripheralModel::*;

// Make the ratio between the clocks small to help sim time
Parameters test_params = Parameters {
    system_frequency_hz: 100,
    mdc_frequency_hz: 10
};

// Arbitrary PHY Address
Bit#(5) model_peripheral_addr = 5'h1D;

// The Model will emit ModelEvents as it progresses through a transaction. This
// function lets us quickly check that things match expectations.
function Action check_model_event(MDIOPeripheralModel model,
                                        ModelEvent expected,
                                        String message) = 
    action
        let e <- model.events.get();
        $display("Actual:   ", fshow(e));
        $display("Expected: ", fshow(expected));
        dynamicAssert (e == expected, message);
    endaction;

interface Bench;
    method Action command (Command cmd);
    method Bool busy();
endinterface

module mkBench(Bench);
    // Instatiations of the actual MDIO DUT and the model to test against
    MDIO dut    <- mkMDIO(test_params);
    MDIOPeripheralModel model
        <- mkMDIOPeripheralModel(model_peripheral_addr);

    // wire the DUT to the model
    mkConnection(dut.pins.mdc, model.pins.mdc);
    mkConnection(dut.pins.mdio.out, model.pins.mdio.in);
    mkConnection(dut.pins.mdio.in, model.pins.mdio.out);
    // Since bluesim cannot simulate tristates, use the out_en pin of the
    // controller to squelch the output of the model
    mkConnection(dut.pins.mdio.out_en, model.mdio_ctrl_out_en);

    Reg#(Command) command_r     <- mkReg(defaultValue);
    // Remember the last word written to compare when it is read back out. A
    // better way to do this would be to expose an interface to the model's
    // internal memory map so this could be done more dynamically.
    Reg#(Bit#(16)) last_written <- mkReg(0);

    // MDIO is a very straightforward protocol, so this sequence verifies
    // everything happens in the proper order.
    FSM cmd_seq <- mkFSM(seq
        dut.command.put(command_r);

        check_model_event(model, tagged ReceivedSFD, "Expected Start of Frame Delimiter");

        if (command_r.read) seq
            check_model_event(model, tagged ReceivedReadOp, "Expected Read Opcode");
        endseq else seq
            check_model_event(model, tagged ReceivedWriteOp, "Expected Write Opcode");
        endseq

        if (command_r.phy_addr == model_peripheral_addr) seq
            check_model_event(model, tagged ReceivedPhyAddr command_r.phy_addr, "Expected matching PHY Address");
            check_model_event(model, tagged ReceivedRegAddr command_r.reg_addr, "Expected matching Register Address");
            check_model_event(model, tagged ReceivedReadTA command_r.read, "Expected Turnaround type to match Opcode");

            if (command_r.read) seq
                check_model_event(model, tagged TransmittedReadData last_written, "Expected Read Opcode");
            endseq else seq
                check_model_event(model, tagged ReceivedWriteData command_r.write_data, "Expected received Write Data to match what was sent");
                last_written    <= command_r.write_data;
            endseq
        endseq else seq
            check_model_event(model, tagged PhyAddrMismatch command_r.phy_addr, "Expected matching PHY Address");
        endseq
    endseq);

    method busy = !cmd_seq.done();

    method Action command(Command cmd) if (cmd_seq.done());
        command_r   <= cmd;
        cmd_seq.start();
    endmethod
endmodule

(* synthesize *)
module mkMDIOReadTest (Empty);
    Bench bench <- mkBench();

    Command cmd = Command {
        read: True,
        phy_addr: model_peripheral_addr,
        reg_addr: 5'h0A,
        write_data: 16'hFF
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkMDIOWriteTest (Empty);
    Bench bench <- mkBench();

    Command write_cmd = Command {
        read: False,
        phy_addr: model_peripheral_addr,
        reg_addr: 5'h0A,
        write_data: 16'hBEEF
    };

    Command read_cmd = Command {
        read: True,
        phy_addr: model_peripheral_addr,
        reg_addr: 5'h0A,
        write_data: 16'hFF
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(write_cmd);
        bench.command(read_cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkMDIOIgnoreWrongPhyAddrTest (Empty);
    Bench bench <- mkBench();

    Command cmd = Command {
        read: True,
        phy_addr: 5'h1F,
        reg_addr: 5'h0A,
        write_data: 16'hFF
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(cmd);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

endpackage: MDIOTests
