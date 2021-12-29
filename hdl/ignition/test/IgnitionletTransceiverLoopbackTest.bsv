package IgnitionletTransceiverLoopbackTest;

import StmtFSM::*;

import SerialIO::*;
import Strobe::*;
import TestUtils::*;

import Encoding8b10b::*;

import Board::*;
import IgnitionProtocol::*;
import IgnitionTestHelpers::*;
import IgnitionTransceiver::*;


module mkTransceiverLoopbackTest (Test#(LinkStatus, Bit#(4)));
    Transceiver txr <- mkTransceiver();

    Strobe#(2) tx_strobe <- mkPowerTwoStrobe(1, 0);
    SerialIOAdapter#(4) serial_adapter <-
        mkSerialIOAdapter(tx_strobe, txr.serial);

    mkFreeRunningStrobe(tx_strobe);

    Reg#(Bool) connected <- mkReg(True);

    (* fire_when_enabled *)
    rule do_tx;
        let b = connected ? serial_adapter.tx : 0;
        serial_adapter.rx(b);
    endrule

    FSM test <- mkFSM(seq
        repeat(400) noAction;
        connected <= True;
        await(txr.status.receiver_locked);
    endseq);

    method Action start = test.start;
    method Bool pass = test.done;
    method Bool fail = False;
    method Bool timeout = False;
    method LinkStatus status = txr.status;
    method Bit#(4) debug = {
        pack(txr.debug.character_accepted),
        serial_adapter.rx_sampled,
        serial_adapter.tx,
        pack(tx_strobe)};
endmodule

(* synthesize, default_clock_osc = "clk_50mhz", default_reset = "rst_nc" *)
module mkIgnitionletTransceiverLoopbackTestTop (IgnitionletSequencer);
    (* hide *) IgnitionletSequencer _test <-
        mkTestWrapper(mkTransceiverLoopbackTest);
    return _test;
endmodule

(* synthesize *)
module mkIgnitionletTransceiverLoopbackTest (Empty);
    (* hide *) Test#(LinkStatus, Bit#(4)) _test <- mkTransceiverLoopbackTest();

    mkAutoFSM(seq
        $display("%h", mk_k(28, 1));
        _test.start();
        await(_test.pass || _test.fail || _test.timeout);
        action
            assert_true(_test.pass, "expected pass");
            assert_false(_test.fail, "expected no failure");
        endaction
    endseq);

    mkTestWatchdog(40 * 20);
endmodule

endpackage
