// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package VersionROM;

export VersionROMIfc(..);
export mkVersionROM;

import Vector::*;

// Public interface matching the original git_version package layout.
// version[0] is the LSB of the commit count, version[3] is MSB.
// sha[0] is the LSB of the short hash, sha[3] is MSB.
interface VersionROMIfc;
    method Vector#(4, Bit#(8)) version;
    method Vector#(4, Bit#(8)) sha;
endinterface

// Raw BVI interface matching the Verilog output ports.
interface VersionROM_BVI;
    method Bit#(32) version_raw;
    method Bit#(32) sha_raw;
    method Bool ready;
endinterface

import "BVI" VersionROM =
    module vVersionROM(VersionROM_BVI);
        default_clock clk(CLK, (* unused *) CLK_GATE);
        no_reset;

        method VERSION version_raw();
        method SHA sha_raw();
        method READY ready();

        schedule (version_raw) CF (version_raw, sha_raw, ready);
        schedule (sha_raw) CF (sha_raw, ready);
        schedule (ready) CF (ready);
    endmodule

// Wrapper that converts Bit#(32) outputs to Vector#(4, Bit#(8)).
// The ROM stores bytes in big-endian order (MSB at lowest address),
// so we reverse after unpack to put the LSB at index 0, matching the
// original git_version package convention.
// No implicit conditions — values are zero for the first 9 clock
// cycles after reset, then hold the ROM contents (sentinel pattern
// until post-P&R stamping replaces them with real git data).
module mkVersionROM(VersionROMIfc);
    VersionROM_BVI rom <- vVersionROM;

    method Vector#(4, Bit#(8)) version;
        return reverse(unpack(rom.version_raw));
    endmethod

    method Vector#(4, Bit#(8)) sha;
        return reverse(unpack(rom.sha_raw));
    endmethod
endmodule

endpackage
