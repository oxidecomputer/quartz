package SidecarMainboardControllerSpiServer;

export SpiRequest(..);
export SpiResponse(..);
export SpiServer(..);
export mkSpiServer;

import ClientServer::*;
import ConfigReg::*;
import Connectable::*;
import DReg::*;
import GetPut::*;
import OInt::*;
import Vector::*;

import git_version::*;
import RegCommon::*;
import WriteOnceReg::*;

import PCIeEndpointController::*;
import SidecarMainboardControllerReg::*;
import Tofino2Sequencer::*;
import TofinoDebugPort::*;


typedef struct {
    RegOps op;
    UInt#(8) address;
    Bit#(8) wdata;
} PageRequest deriving (Bits, Eq);

instance DefaultValue#(PageRequest);
    defaultValue =
        PageRequest {
            op: NOOP,
            address: ?,
            wdata: ?};
endinstance

module mkSpiServer #(
        Tofino2Sequencer::Registers tofino,
        TofinoDebugPort::Registers tofino_debug_port,
        PCIeEndpointController::Registers pcie)
            (SpiServer)
        provisos (
            NumAlias#(3, n_pages));
    Wire#(SpiRequest) in <- mkWire();
    Wire#(SpiResponse) out <- mkWire();

    // The fan-in of requests and fan-out for responses is becoming wide,
    // especially once Ignition Controller pages are added. In order to allow
    // the placement process more freedom, latch the incoming request and
    // generate a one-hot page select signal from the address MSB. In addition,
    // a response register is allocated per page and the one-hot selector is
    // used to select the appropriate response. This reduces the demux required
    // to drive the response.
    //
    // This does come at the expense of one cycle to route the request to the
    // selected page and one cycle to collect the response.
    Reg#(Maybe#(OInt#(n_pages))) selected_page <- mkRegU();
    Reg#(Maybe#(PageRequest)) page_request <- mkRegU();
    Vector#(n_pages, Reg#(SpiResponse)) page_responses <- replicateM(mkRegU());

    Reg#(Bool) select_response <- mkDReg(False);

    (* fire_when_enabled *)
    rule do_select_page (!isValid(page_request));
        let page = in.address[15:8];
        let page_limit = fromInteger(valueOf(n_pages));

        selected_page <=
            page < page_limit ?
                tagged Valid toOInt(truncate(page)) :
                tagged Invalid;
        page_request <= tagged Valid PageRequest {
                op: in.op,
                address: unpack(in.address[7:0]),
                wdata: in.wdata};
    endrule

    (* fire_when_enabled *)
    rule do_complete_request (page_request matches tagged Valid .request);
        if (request.op == READ)
            select_response <= True;
        page_request <= tagged Invalid;
    endrule

    (* fire_when_enabled *)
    rule do_select_response (select_response);
        if (selected_page matches tagged Valid .i)
            out <= select(readVReg(page_responses), i);
        else
            out <= SpiResponse {readdata: 8'hff};
    endrule

    //
    // Guard helpers for rules responding to page requests.
    //

    function Bool page_selected(Integer i);
        return case (selected_page) matches
            tagged Valid .one_hot_selector: unpack(pack(one_hot_selector)[i]);
            tagged Invalid: False;
        endcase;
    endfunction

    function Bool read_page(Integer i);
        return page_selected(i) &&
            fromMaybe(defaultValue, page_request).op == READ;
    endfunction

    function Bool write_page(Integer i);
        let op = fromMaybe(defaultValue, page_request).op;
        let write_op = (op != NOOP && op != READ);
        return page_selected(i) && write_op;
    endfunction

    //
    // Page 0
    //

    ConfigReg#(Scratchpad) scratchpad <- mkConfigReg(unpack('0));
    Vector#(4, ConfigReg#(Bit#(8))) checksum <- replicateM(mkWriteOnceConfigReg(0));

    (* fire_when_enabled *)
    rule do_page0_read (read_page(0));
        let reader =
            case (page_request.Valid.address)
                // ID, see RDL for the (default) values.
                fromOffset(id0Offset): read(Id0'(defaultValue));
                fromOffset(id1Offset): read(Id1'(defaultValue));
                fromOffset(id2Offset): read(Id2'(defaultValue));
                fromOffset(id3Offset): read(Id3'(defaultValue));

                // Checksum
                fromOffset(cs0Offset): read(checksum[0]);
                fromOffset(cs1Offset): read(checksum[1]);
                fromOffset(cs2Offset): read(checksum[2]);
                fromOffset(cs3Offset): read(checksum[3]);

                // Version
                fromOffset(version0Offset): read(version[0]);
                fromOffset(version1Offset): read(version[1]);
                fromOffset(version2Offset): read(version[2]);
                fromOffset(version3Offset): read(version[3]);

                // SHA
                fromOffset(sha0Offset): read(sha[0]);
                fromOffset(sha1Offset): read(sha[1]);
                fromOffset(sha2Offset): read(sha[2]);
                fromOffset(sha3Offset): read(sha[3]);

                // Scratchpad
                fromOffset(scratchpadOffset): read(scratchpad);

                default: read(8'hff);
            endcase;

        let data <- reader;
        page_responses[0] <= data;
    endrule

    (* fire_when_enabled *)
    rule do_page0_write (write_page(0));
        // If this rule is enabled it is safe to assume the contents of the
        // page_request register is valid.
        let request = page_request.Valid;

        case (request.address)
            fromOffset(cs0Offset): update(request.op, checksum[0], request.wdata);
            fromOffset(cs1Offset): update(request.op, checksum[1], request.wdata);
            fromOffset(cs2Offset): update(request.op, checksum[2], request.wdata);
            fromOffset(cs3Offset): update(request.op, checksum[3], request.wdata);
            fromOffset(scratchpadOffset): update(request.op, scratchpad, request.wdata);
        endcase
    endrule

    //
    // Page 1, Tofino sequencer, PCIe endpoint
    //

    (* fire_when_enabled *)
    rule do_page1_read (read_page(1));
        let reader =
            case (page_request.Valid.address)
                // Tofino sequencer
                fromOffset(tofinoSeqCtrlOffset): read(tofino.ctrl);
                fromOffset(tofinoSeqStateOffset): read(tofino.state);
                fromOffset(tofinoSeqStepOffset): read(tofino.step);
                fromOffset(tofinoSeqErrorOffset): read(tofino.error);
                fromOffset(tofinoSeqErrorStateOffset): read(tofino.error_state);
                fromOffset(tofinoSeqErrorStepOffset): read(tofino.error_step);
                fromOffset(tofinoPowerVdd18StateOffset): read(tofino.vdd18);
                fromOffset(tofinoPowerVddcoreStateOffset): read(tofino.vddcore);
                fromOffset(tofinoPowerVddpcieStateOffset): read(tofino.vddpcie);
                fromOffset(tofinoPowerVddtStateOffset): read(tofino.vddt);
                fromOffset(tofinoPowerVdda15StateOffset): read(tofino.vdda15);
                fromOffset(tofinoPowerVdda18StateOffset): read(tofino.vdda18);
                fromOffset(tofinoPowerVidOffset): read(tofino.vid);
                fromOffset(tofinoResetOffset): read(tofino.tofino_reset);
                fromOffset(tofinoMiscOffset): read(tofino.misc);

                // PCIe
                fromOffset(pcieHotplugCtrlOffset): read(pcie.ctrl);
                fromOffset(pcieHotplugStatusOffset): read(pcie.status);

                default: read(8'hff);
            endcase;

        let data <- reader;
        page_responses[1] <= data;
    endrule

    (* fire_when_enabled *)
    rule do_page1_write (write_page(1));
        // If this rule is enabled it is safe to assume the contents of the
        // page_request register is valid.
        let request = page_request.Valid;

        case (request.address)
            fromOffset(tofinoSeqCtrlOffset): update(request.op, tofino.ctrl, request.wdata);
            fromOffset(pcieHotplugCtrlOffset): update(request.op, pcie.ctrl, request.wdata);
        endcase
    endrule

    //
    // Page 2, Tofino Debug Port
    //

    (* fire_when_enabled *)
    rule do_page2_read (read_page(2));
        let reader =
            case (page_request.Valid.address)
                fromOffset(tofinoDebugPortStateOffset): read(tofino_debug_port.state);
                fromOffset(tofinoDebugPortBufferOffset): read_volatile(tofino_debug_port.buffer);
                default: read(8'hff);
            endcase;

        let data <- reader;
        page_responses[2] <= data;
    endrule

    (* fire_when_enabled *)
    rule do_page2_write (write_page(2));
        // If this rule is enabled it is safe to assume the contents of the
        // page_request register is valid.
        let request = page_request.Valid;

        case (request.address)
            fromOffset(tofinoDebugPortStateOffset):
                update(request.op, tofino_debug_port.state, request.wdata);
            fromOffset(tofinoDebugPortBufferOffset):
                write(WRITE, tofino_debug_port.buffer._write, request.wdata);
        endcase
    endrule

    interface Put request = toPut(asIfc(in));
    interface Put response = toGet(asIfc(out));
endmodule

//
// Helpers
//

typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;
typedef Server#(SpiRequest, SpiResponse) SpiServer;

function UInt#(8) fromOffset(Integer offset);
    Bit#(16) offset_ = fromInteger(offset);
    return unpack(offset_[7:0]);
endfunction

// Turn the read of a register into an ActionValue.
function ActionValue#(SpiResponse) read(t v)
        provisos (Bits#(t, 8));
    return actionvalue
        return SpiResponse {readdata: pack(v)};
    endactionvalue;
endfunction

function ActionValue#(SpiResponse) read_volatile(ActionValue#(t) av)
        provisos (Bits#(t, 8));
    return actionvalue
        let v <- av;
        return SpiResponse {readdata: pack(v)};
    endactionvalue;
endfunction

function Action update(RegOps op, Reg#(t) r, Bit#(8) data)
        provisos (Bits#(t, 8));
    return action
        let r_ = zeroExtend(pack(r));

        case (op)
            WRITE: r <= unpack(truncate(data));
            BITSET: r <= unpack(truncate(r_ | data));
            BITCLEAR: r <= unpack(truncate(r_ & ~data));
        endcase
    endaction;
endfunction

function Action write(RegOps op, function Action f(t val), Bit#(8) data)
        provisos (Bits#(t, 8));
    return action
        if (op == WRITE) f(unpack(truncate(data)));
    endaction;
endfunction

endpackage
