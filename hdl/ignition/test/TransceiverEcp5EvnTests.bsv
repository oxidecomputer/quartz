package TransceiverEcp5EvnTests;

import StmtFSM::*;

import Board::*;
import TestUtils::*;

import IgnitionProtocol::*;
import IgnitionTestHelpers::*;
import IgnitionTransceiver::*;


module mkLoopbackTest (Test#(LinkStatus, Bit#(1)));
    Transceiver txr <- mkTransceiver();
    Loopback loopback <- mkLoopback(
        txr,
        False, // Polarity not inverted.
        default_disconnect_pattern);

    FSM test <- mkFSM(seq
        await(txr.status.receiver_locked);
    endseq);

    method Action start = test.start;
    method Bool pass = test.done;
    method Bool fail = False;
    method Bool timeout = False;
    method LinkStatus status = txr.status;
    method Bit#(1) debug = loopback;
endmodule

(* synthesize, default_clock_osc="CLK_12mhz", default_reset="GSR_N" *)
module mkTransceiverLoopbackEcp5EvnTestTop (TestTop);
    (* hide *) TestTop _test <- mkTestWrapper(mkLoopbackTest);
    return _test;
endmodule

endpackage
