// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Version ROM for post-P&R stamping.
//
// A 256x8 BRAM ROM initialized with sentinel values. After place and
// route, icebram/ecpbram replaces the sentinel pattern with real git
// version and SHA data. This avoids volatile genrules that invalidate
// the build cache on every commit.
//
// Memory layout:
//   [0:3]   - Version (commit count), sentinel: DE AD BE EF
//   [4:7]   - SHA (short git hash), sentinel: CA FE BA BE
//   [8:255] - Reserved (zeros)
//
// On startup, a small FSM reads bytes 0-7 from the BRAM and latches
// them into output registers. READY asserts after 9 clock cycles.

module VersionROM(
    input CLK,
    output [31:0] VERSION,
    output [31:0] SHA,
    output READY
);

(* ram_style = "block" *)
reg [7:0] mem [0:255];

initial begin : init_mem
    integer i;
    for (i = 0; i < 256; i = i + 1)
        mem[i] = 8'h00;
    // Version sentinel
    mem[0] = 8'hDE;
    mem[1] = 8'hAD;
    mem[2] = 8'hBE;
    mem[3] = 8'hEF;
    // SHA sentinel
    mem[4] = 8'hCA;
    mem[5] = 8'hFE;
    mem[6] = 8'hBA;
    mem[7] = 8'hBE;
end

reg [3:0] cnt = 4'd0;
reg [7:0] rom_rdata;
reg [31:0] version_r = 32'd0;
reg [31:0] sha_r = 32'd0;
reg ready_r = 1'b0;

// BRAM read: address driven by counter, data available next cycle
always @(posedge CLK)
    rom_rdata <= mem[cnt[2:0]];

// Latch bytes into output registers as they arrive from BRAM
always @(posedge CLK) begin
    if (!ready_r) begin
        case (cnt)
            4'd1: version_r[31:24] <= rom_rdata;
            4'd2: version_r[23:16] <= rom_rdata;
            4'd3: version_r[15:8]  <= rom_rdata;
            4'd4: version_r[7:0]   <= rom_rdata;
            4'd5: sha_r[31:24]     <= rom_rdata;
            4'd6: sha_r[23:16]     <= rom_rdata;
            4'd7: sha_r[15:8]      <= rom_rdata;
            4'd8: begin
                sha_r[7:0] <= rom_rdata;
                ready_r    <= 1'b1;
            end
        endcase
        cnt <= cnt + 4'd1;
    end
end

assign VERSION = version_r;
assign SHA = sha_r;
assign READY = ready_r;

endmodule
