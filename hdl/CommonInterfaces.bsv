// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package CommonInterfaces;

// Interface to bundle signals that will connect to a TriState at the Top level
// of the FPGA design.
interface Tristate;
    method Bit#(1) out;
    method Bit#(1) out_en;
    method Action in(Bit#(1) val);
endinterface

endpackage: CommonInterfaces