// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Common;

import Connectable::*;
import TriState::*;

// Interface to bundle signals that will connect to a TriState at the Top level
// of the FPGA design. This could get put into some sort of Oxide common package
interface Tristate;
    method Bit#(1) out;
    method Bit#(1) out_en;
    method Action in(Bit#(1) val);
endinterface

// TODO: Copied from the Tofino2Sequencer.bsv, should move to a common spot
// Helpers used to map values/internal registers onto the register interface.
function ReadOnly#(t) valueToReadOnly(t val);
    return (
        interface ReadOnly
            method _read = val;
        endinterface);
endfunction

function ReadOnly#(v) castToReadOnly(t val)
        provisos (Bits#(t, t_sz), Bits#(v, v_sz), Add#(t_sz, _, v_sz));
    return (
        interface ReadOnly
            method _read = unpack(zeroExtend(pack(val)));
        endinterface);
endfunction

endpackage: Common