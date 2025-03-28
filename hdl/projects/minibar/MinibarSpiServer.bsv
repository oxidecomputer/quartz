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
import RegCommon::*;

// Minibar
import MinibarRegsPkg::*;

typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;

typedef Server#(SpiRequest, SpiResponse) SpiServer;

interface MinibarTopRegs;
    method Action vbus_sys_fault(Bit#(1) val);
    method Action hcv_code(Bit#(3) val);
endinterface

interface MinibarSpiServer;
    interface SpiServer spi_if;
    interface MinibarTopRegs top_regs;
endinterface

module mkSpiServer (MinibarSpiServer);
    Reg#(SpiRequest) spi_request <- mkReg(SpiRequest{address: 0, wdata: 0, op: NOOP});
    Wire#(SpiResponse) spi_response <- mkWire();

    // Signals to map to registers
    Wire#(Bit#(1)) vbus_sys_fault_w <- mkWire();
    Wire#(Bit#(3)) hcv_code_w       <- mkWire();

    // registers interal to the SPI server
    ConfigReg#(Scratchpad) scratchpad   <- mkConfigReg(defaultValue);
    Vector#(4, ConfigReg#(Cs0)) checksum
        <- replicateM(mkConfigReg(defaultValue));
    ConfigReg#(Hcv) hcv_reg <- mkConfigReg(defaultValue);
    ConfigReg#(VbusSysRdbk) vbus_sys_reg <- mkConfigReg(defaultValue);

    (* fire_when_enabled *)
    rule do_spi_read(spi_request.op == READ || spi_request.op == READ_NO_ADDR_INCR);
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
            fromInteger(hcvOffset): read( Hcv {
                code: hcv_code_w
            });

            // VBUS SYS readbacks
            fromInteger(vbusSysRdbkOffset): read( VbusSysRdbk {
                fault: vbus_sys_fault_w
            });

            default: read(8'hff);
            endcase;

        let data <- reader;

        spi_response <= data;
    endrule

    (* fire_when_enabled *)
    rule do_spi_write;
        case (spi_request.address)
            fromInteger(cs0Offset): update(spi_request.op, checksum[0], spi_request.wdata);
            fromInteger(cs1Offset): update(spi_request.op, checksum[1], spi_request.wdata);
            fromInteger(cs2Offset): update(spi_request.op, checksum[2], spi_request.wdata);
            fromInteger(cs3Offset): update(spi_request.op, checksum[3], spi_request.wdata);
            fromInteger(scratchpadOffset): update(spi_request.op, scratchpad, spi_request.wdata);
        endcase
    endrule

    interface MinibarTopRegs top_regs;
        method vbus_sys_fault = vbus_sys_fault_w._write;
        method hcv_code = hcv_code_w._write;
    endinterface

    interface SpiServer spi_if;
        interface Put request = toPut(asIfc(spi_request));
        interface Get response = toGet(asIfc(spi_response));
    endinterface
endmodule

// Turn the read of a register into an ActionValue.
function ActionValue#(SpiResponse) read(t v)
        provisos (Bits#(t, 8));
    return actionvalue
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