// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package IOSync;

export mkInputSync;
export mkInputSyncFor;
export mkOutputSyncFor;
export mkOutputSyncRegFor;
export sync, sync_inverted;

import Clocks::*;
import ConfigReg::*;
import Connectable::*;
import Vector::*;


//
// `mkInputSync` is a two cycle synchronizer for asynchronous input signals. By
// design it has no reset value, allowing the output to be used in clock or
// reset domains other than the default clock or reset without additional
// synchronization. Downstream logic is expected to discard the first two random
// values when reading from the synchronizer or be kept in reset for at least
// two cycles.
//
// This primitive is intended for generic input signals only. For high
// performance interfaces such as DDR memories or SerDes I/O you will most
// likely need more specific primitives.
//
// Note that this appropriate only for external signals entering a design. For
// other instances of clock or reset domain crossing more appropriate primitives
// should be used.
//
module mkInputSync (Reg#(bits_type))
        provisos (Bits#(bits_type, sz));
    (* hide *) ConfigReg#(Vector#(2, bits_type)) _sync <- mkConfigRegU();

    method _read = _sync[0];
    method Action _write(bits_type val);
        _sync <= shiftInAtN(_sync, val);
    endmethod
endmodule

//
// `mkInputSyncFor` is syntactic sugar for `mkInputSync`, connecting the
// `_read()` method to the given action method. This allows the synchronized
// input to be forwarded to downstream modules in a single statement, shortening
// this common usecase in top modules.
//
module mkInputSyncFor #(function Action f(bits_type val)) (Reg#(bits_type))
        provisos (Bits#(bits_type, sz));
    (* hide *) let _sync <- mkInputSync();
    mkConnection(_sync, f);

    return _sync;
endmodule

//
// `mkOutputSyncFor` acts like a wire, connecting a design output to an external
// pin, but ignoring any difference in reset context between the design and the
// external pins.
//
// This primitive works around the `bsc` generated warnings when an external
// (async) reset is synchronized in a top module, implicitly creating a new
// reset context, before being used to reset downstream modules. Outputs from
// these modules connected to method in the top interface would otherwise
// correctly be flagged for crossing a reset domain.
//
// Note that this should only be used for output signals connecting to external
// pins without any additional logic in the middle. In all other cases the
// resulting behavior is likely not what is intended and proper synchronisation
// primitives should be used.
//
module mkOutputSyncFor #(bits_type val) (ReadOnly#(bits_type))
        provisos (Bits#(bits_type, sz));
    Clock c <- exposeCurrentClock();
    (* hide *) ReadOnly#(bits_type) _sync <- mkNullCrossingWire(c, val);

    return _sync;
endmodule

//
// `mkOuputSyncRegFor` is similar to `mkOutputSyncFor`, except that an
// additional register is inserted between the connected value and the output
// pin. This may be useful to meet external setup/hold times.
//
// The somewhat implicit expectation for this module is that synthesis tools
// will map this register on the flip-flop often found in the output structure
// of IO tiles.
//
module mkOutputSyncRegFor #(bits_type val) (ReadOnly#(bits_type))
        provisos (Bits#(bits_type, sz));
    Clock c <- exposeCurrentClock();
    (* hide *) CrossingReg#(bits_type) _sync <- mkNullCrossingReg(c, val);

    method _read = _sync._read;
endmodule

//
// `sync(..)` is syntactic sugar which can be used to connect an input
// synchronizer to top interface methods, expressing that this signal is
// synchronized before being passed further into the design.
//
function (function Action f(bits_type val))
    sync(Reg#(bits_type) _sync) = _sync._write;

//
// `sync_inverted(..)` similarly can be used to connect an input synchronizer to
// a top module method, but as the name implies the incoming value is bitwise
// inverted before being synchronized.
//
// Performing the inversion where the synchronizer is connected to the top
// interface method expresses the intent that the signal is inverted before
// being consumed by the design. In addition some synthesis tools may be able to
// map the bit inversion on logic provided by the IO tile.
//
function (function Action f(bits_type val))
    sync_inverted(Reg#(bits_type) _sync)
        provisos (Bits#(bits_type, sz));
    function Action f(bits_type val) = _sync._write(unpack(~pack(val)));
    return f;
endfunction

endpackage
