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

import IgnitionController::*;
import IgnitionControllerRegisters::*;
import PCIeEndpointController::*;
import SidecarMainboardController::*;
import SidecarMainboardControllerReg::*;
import SidecarMainboardMiscSequencers::*;
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
        PCIeEndpointController::Registers pcie,
        Vector#(n_ignition_controllers, IgnitionController::Registers) ignition_pages,
        Vector#(4, FanModuleRegisters) fans)
            (SpiServer)
                provisos (
                    Add#(n_ignition_controllers, 4, n_pages),
                    Add#(TLog#(n_pages), a__, 8),
                    Add#(TLog#(n_ignition_controllers), b__, 8),
                    // Less than 40 Ignition Controllers.
                    Add#(n_ignition_controllers, c__, 40));
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
    Vector#(n_pages, Reg#(Maybe#(PageRequest))) page_request <- replicateM(mkConfigReg(tagged Invalid));
    Vector#(n_pages, Reg#(SpiResponse)) page_response <- replicateM(mkConfigRegU());
    Reg#(Maybe#(OInt#(n_pages))) response_select <- mkRegU();

    Reg#(Bool) request_in_progress <- mkDReg(False);
    Reg#(Bool) select_response <- mkDReg(False);

    (* fire_when_enabled *)
    rule do_select_page (!isValid(response_select));
        let page = in.address[15:8];
        let page_limit = fromInteger(valueOf(n_pages));

        request_in_progress <= True;
        response_select <=
            page < page_limit && in.op == READ ?
                tagged Valid toOInt(truncate(page)) :
                tagged Invalid;
    endrule

    for (Integer i = 0; i < valueOf(n_pages); i = i + 1) begin
        let page_selected = (in.address[15:8] == fromInteger(i));

        (* fire_when_enabled *)
        rule do_request_from_page (page_selected && !isValid(page_request[i]));
            page_request[i] <= tagged Valid
                PageRequest {
                    op: in.op,
                    address: unpack(in.address[7:0]),
                    wdata: in.wdata};
        endrule
    end

    (* fire_when_enabled *)
    rule do_complete_request (request_in_progress && isValid(response_select));
        select_response <= True;
    endrule

    (* fire_when_enabled *)
    rule do_select_response (select_response && isValid(response_select));
        if (response_select matches tagged Valid .i)
            out <= select(readVReg(page_response), i);
        else
            out <= SpiResponse {readdata: 8'h00};

        response_select <= tagged Invalid;
    endrule

    //
    // Guard helpers for rules responding to page requests.
    //

    function Maybe#(PageRequest) read_page(Integer i) =
        case (page_request[i]) matches
            tagged Valid .r &&& (r.op == READ): page_request[i];
            default: tagged Invalid;
        endcase;

    function Maybe#(PageRequest) update_page(Integer i) =
        case (page_request[i]) matches
            tagged Valid .r &&& (r.op != NOOP &&& r.op != READ):
                page_request[i];
            default: tagged Invalid;
        endcase;

    //
    // Page 0
    //

    ConfigReg#(Scratchpad) scratchpad <- mkConfigReg(unpack('0));
    Vector#(4, ConfigReg#(Bit#(8))) checksum <- replicateM(mkWriteOnceConfigReg(0));

    (* fire_when_enabled *)
    rule do_page0_read (read_page(0) matches tagged Valid .request);
        let reader =
            case (request.address)
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

                // Fans
                fromOffset(fan0StateOffset): read(fans[0].state);
                fromOffset(fan1StateOffset): read(fans[1].state);
                fromOffset(fan2StateOffset): read(fans[2].state);
                fromOffset(fan3StateOffset): read(fans[3].state);

                default: read(8'hff);
            endcase;

        let data <- reader;

        page_request[0] <= tagged Invalid;
        page_response[0] <= data;
    endrule

    (* fire_when_enabled *)
    rule do_page0_update (update_page(0) matches tagged Valid .request);
        case (request.address)
            fromOffset(cs0Offset): update(request.op, checksum[0], request.wdata);
            fromOffset(cs1Offset): update(request.op, checksum[1], request.wdata);
            fromOffset(cs2Offset): update(request.op, checksum[2], request.wdata);
            fromOffset(cs3Offset): update(request.op, checksum[3], request.wdata);
            fromOffset(scratchpadOffset): update(request.op, scratchpad, request.wdata);
            fromOffset(fan0StateOffset): update(request.op, fans[0].state, request.wdata);
            fromOffset(fan1StateOffset): update(request.op, fans[1].state, request.wdata);
            fromOffset(fan2StateOffset): update(request.op, fans[2].state, request.wdata);
            fromOffset(fan3StateOffset): update(request.op, fans[3].state, request.wdata);
        endcase

        page_request[0] <= tagged Invalid;
    endrule

    //
    // Page 1, Tofino sequencer, PCIe endpoint
    //

    (* fire_when_enabled *)
    rule do_page1_read (read_page(1) matches tagged Valid .request);
        let reader =
            case (request.address)
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

                default: read(8'h00);
            endcase;

        let data <- reader;

        page_request[1] <= tagged Invalid;
        page_response[1] <= data;
    endrule

    (* fire_when_enabled *)
    rule do_page1_update (update_page(1) matches tagged Valid .request);
        case (request.address)
            fromOffset(tofinoSeqCtrlOffset): update(request.op, tofino.ctrl, request.wdata);
            fromOffset(pcieHotplugCtrlOffset): update(request.op, pcie.ctrl, request.wdata);
        endcase

        page_request[1] <= tagged Invalid;
    endrule

    //
    // Page 2, Tofino Debug Port
    //

    (* fire_when_enabled *)
    rule do_page2_read (read_page(2) matches tagged Valid .request);
        let reader =
            case (request.address)
                fromOffset(tofinoDebugPortStateOffset): read(tofino_debug_port.state);
                fromOffset(tofinoDebugPortBufferOffset): read_volatile(tofino_debug_port.buffer);
                default: read(8'h00);
            endcase;

        let data <- reader;

        page_request[2] <= tagged Invalid;
        page_response[2] <= data;
    endrule

    (* fire_when_enabled *)
    rule do_page2_update (update_page(2) matches tagged Valid .request);
        case (request.address)
            fromOffset(tofinoDebugPortStateOffset):
                update(request.op, tofino_debug_port.state, request.wdata);
            fromOffset(tofinoDebugPortBufferOffset):
                write(WRITE, tofino_debug_port.buffer._write, request.wdata);
        endcase

        page_request[2] <= tagged Invalid;
    endrule

    //
    // Ignition Pages
    //

    ConfigReg#(Vector#(5, Bit#(8))) target_present_summary <- mkConfigRegU();

    (* fire_when_enabled *)
    rule do_demux_target_present_summary;
        // Collect a summary of the Target present bits as a 64 bit-vector.
        function target_present(registers) =
            registers.controller_state.target_present;

        target_present_summary <=
            unpack(extend(pack(map(target_present, ignition_pages))));
    endrule

    (* fire_when_enabled *)
    rule do_ignition_summary_page_read (
            read_page(3) matches tagged Valid .request);
        let reader =
            case (request.address)
                fromOffset(ignitionControllersCountOffset):
                    read(Bit#(8)'(fromInteger(valueOf(n_ignition_controllers))));
                fromOffset(ignitionTargetsPresent0Offset): read(target_present_summary[0]);
                fromOffset(ignitionTargetsPresent1Offset): read(target_present_summary[1]);
                fromOffset(ignitionTargetsPresent2Offset): read(target_present_summary[2]);
                fromOffset(ignitionTargetsPresent3Offset): read(target_present_summary[3]);
                fromOffset(ignitionTargetsPresent4Offset): read(target_present_summary[4]);
                default: read(8'h00);
            endcase;

        let data <- reader;

        page_request[3] <= tagged Invalid;
        page_response[3] <= data;
    endrule

    for (Integer i = 0; i < valueOf(n_ignition_controllers); i = i + 1) begin
        let page_id = i + 4;
        let registers = asIfc(ignition_pages[i]);

        (* fire_when_enabled *)
        rule do_ignition_page_read (
                read_page(page_id) matches tagged Valid ._request);
            let reader =
                case (_request.address)
                    // Controller state
                    fromInteger(controllerStateOffset):
                        read(registers.controller_state);
                    fromInteger(controllerLinkStatusOffset):
                        read(registers.controller_link_status);
                    fromInteger(targetSystemTypeOffset):
                        read(registers.target_system_type);
                    fromInteger(targetSystemStatusOffset):
                        read(registers.target_system_status);
                    fromInteger(targetSystemFaultsOffset):
                        read(registers.target_system_faults);
                    fromInteger(targetRequestStatusOffset):
                        read(registers.target_request_status);
                    fromInteger(targetLink0StatusOffset):
                        read(registers.target_link0_status);
                    fromInteger(targetLink1StatusOffset):
                        read(registers.target_link1_status);

                    // Target Request
                    fromInteger(targetRequestOffset):
                        read(registers.target_request);

                    // Controller Counters
                    fromInteger(controllerStatusReceivedCountOffset):
                        read_volatile(registers.controller_status_received_count);
                    fromInteger(controllerHelloSentCountOffset):
                        read_volatile(registers.controller_hello_sent_count);
                    fromInteger(controllerRequestSentCountOffset):
                        read_volatile(registers.controller_request_sent_count);
                    fromInteger(controllerMessageDroppedCountOffset):
                        read_volatile(registers.controller_message_dropped_count);

                    // Controller Link Events
                    fromInteger(controllerLinkEventsSummaryOffset):
                        read(registers.controller_link_counters.summary);

                    // Target Link 0 Events
                    fromInteger(targetLink0EventsSummaryOffset):
                        read(registers.target_link0_counters.summary);

                    // Target Link 1 Events
                    fromInteger(targetLink1EventsSummaryOffset):
                        read(registers.target_link1_counters.summary);

                    default: read(8'h00);
                endcase;

            let data <- reader;

            page_request[page_id] <= tagged Invalid;
            page_response[page_id] <= data;
        endrule

        (* fire_when_enabled *)
        rule do_ignition_page_update (
                update_page(page_id) matches tagged Valid ._request);
            function do_update(r) = update(_request.op, r, _request.wdata);

            case (_request.address)
                fromInteger(controllerStateOffset):
                    do_update(registers.controller_state);
                fromInteger(targetRequestOffset):
                    do_update(registers.target_request);
                fromInteger(controllerLinkEventsSummaryOffset):
                    do_update(registers.controller_link_counters.summary);
                fromInteger(targetLink0EventsSummaryOffset):
                    do_update(registers.target_link0_counters.summary);
                fromInteger(targetLink1EventsSummaryOffset):
                    do_update(registers.target_link1_counters.summary);
            endcase

            page_request[page_id] <= tagged Invalid;
        endrule
    end

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
