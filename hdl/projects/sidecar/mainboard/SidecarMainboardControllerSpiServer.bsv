package SidecarMainboardControllerSpiServer;

export SpiRequest(..);
export SpiResponse(..);
export SpiServer(..);
export mkSpiServer;

import BuildVector::*;
import ClientServer::*;
import ConfigReg::*;
import Connectable::*;
import DReg::*;
import GetPut::*;
import OInt::*;
import Vector::*;

import CounterRAM::*;
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


module mkSpiServer #(
        Tofino2Sequencer::Registers tofino,
        TofinoDebugPort::Registers tofino_debug_port,
        PCIeEndpointController::Registers pcie,
        IgnitionController::Controller#(n_ignition_controllers) ignition,
        Vector#(4, FanModuleRegisters) fans,
        Reg#(PowerRailState) front_io_hsc)
            (SpiServer)
                provisos (
                    NumAlias#(6, n_pages),
                    // Allow up to 64 Ignition Controllers given the SPI address
                    // width and the way Controllers are mapped into this space.
                    Add#(TLog#(n_ignition_controllers), a__, 6),
                    Add#(n_ignition_controllers, b__, 64));
    Wire#(SpiRequest) in <- mkWire();
    Wire#(SpiResponse) out <- mkWire();

    Reg#(Maybe#(OInt#(n_pages))) response_select <- mkReg(tagged Invalid);
    Reg#(UInt#(4)) cycles_until_response_needed <- mkRegU();

    RegisterPage page0 <- mkPage0(fans, front_io_hsc);
    RegisterPage page1 <- mkPage1(tofino, pcie);
    RegisterPage page2 <- mkPage2(tofino_debug_port);
    RegisterPage ignition_general_page <-
            mkIgnitionGeneralPage(ignition);
    RegisterPage ignition_registers_page <-
            mkIgnitionRegistersPage(ignition.registers);
    RegisterPage ignition_counters_page <-
            mkIgnitionCountersPage(ignition.counters);

    Vector#(n_pages, RegisterPage) pages =
            vec(page0,
                page1,
                page2,
                ignition_general_page,
                ignition_registers_page,
                ignition_counters_page);

    (* fire_when_enabled *)
    rule do_select_page (!isValid(response_select));
        function ActionValue#(Bool)
                offer_request(RegisterPage page) = page.offer(in);

        // Dispatch the incoming request to all pages, calling their `offer`
        // method. This returns a vector of booleans indicating whether or not
        // the page accepted the request. The assumption is that the acceptance
        // criteria of the pages are mutually exclusive, resulting in the vector
        // containing zero or one True values.
        let accepted <- mapM(offer_request, pages);

        if (\or (accepted)) begin
            // If one of the accept bits is set, store the vector as OInt,
            // allowing one-hot selection of the response.
            response_select <= tagged Valid unpack(pack(accepted));
            cycles_until_response_needed <= 8;
        end
        else begin
            out <= SpiResponse {readdata: 'h00};
        end
    endrule

    (* fire_when_enabled *)
    rule do_select_response (response_select matches tagged Valid .i);
        function read_page(page) = page.read;

        if (cycles_until_response_needed == 0) begin
            out <= select(map(read_page, pages), i);
            response_select <= tagged Invalid;
        end
        else begin
            cycles_until_response_needed <= cycles_until_response_needed - 1;
        end
    endrule

    interface Put request;
        method put if (!isValid(response_select)) = in._write;
    endinterface

    interface Get response = toGet(asIfc(out));
endmodule

//
// Register pages
//

interface RegisterPage;
    method ActionValue#(Bool) offer(SpiRequest request);
    method SpiResponse read();
endinterface

//
// Page 0
//

module mkPage0 #(
            Vector#(4, FanModuleRegisters) fans,
            Reg#(PowerRailState) front_io_hsc)
                (RegisterPage);
    Reg#(SpiResponse) response <- mkConfigRegU();
    Reg#(Maybe#(RegOps)) maybe_op <- mkReg(tagged Invalid);
    Reg#(Bit#(8)) address <- mkRegU();
    Reg#(Bit#(8)) wdata <- mkRegU();

    ConfigReg#(Scratchpad) scratchpad <- mkConfigReg(unpack('0));
    Vector#(4, ConfigReg#(Bit#(8)))
            checksum <- replicateM(mkWriteOnceConfigReg(0));

    (* fire_when_enabled *)
    rule do_page1_read (maybe_op matches tagged Valid .op &&& op == READ);
        let reader =
            case (address)
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

                // Front IO
                fromOffset(frontIoStateOffset): read(front_io_hsc);

                default: read(8'hff);
            endcase;

        let rdata <- reader;

        maybe_op <= tagged Invalid;
        response <= rdata;
    endrule

    (* fire_when_enabled *)
    rule do_page0_upate (maybe_op matches tagged Valid .op &&& op != READ);
        case (address)
            fromOffset(cs0Offset): update(op, checksum[0], wdata);
            fromOffset(cs1Offset): update(op, checksum[1], wdata);
            fromOffset(cs2Offset): update(op, checksum[2], wdata);
            fromOffset(cs3Offset): update(op, checksum[3], wdata);
            fromOffset(scratchpadOffset): update(op, scratchpad, wdata);
            fromOffset(fan0StateOffset): update(op, fans[0].state, wdata);
            fromOffset(fan1StateOffset): update(op, fans[1].state, wdata);
            fromOffset(fan2StateOffset): update(op, fans[2].state, wdata);
            fromOffset(fan3StateOffset): update(op, fans[3].state, wdata);
            fromOffset(frontIoStateOffset): update(op, front_io_hsc, wdata);
        endcase

        maybe_op <= tagged Invalid;
    endrule

    method ActionValue#(Bool) offer(SpiRequest request) if (!isValid(maybe_op));
        let accepted = (request.address[15:8] == 0 && request.op != NOOP);

        if (accepted) begin
            maybe_op <= tagged Valid request.op;
            address <= request.address[7:0];
            wdata <= request.wdata;
        end

        return accepted;
    endmethod

    method read = response;
endmodule

//
// Page 1, Tofino sequencer, PCIe endpoint
//

module mkPage1 #(
            Tofino2Sequencer::Registers tofino,
            PCIeEndpointController::Registers pcie)
                (RegisterPage);
    Reg#(SpiResponse) response <- mkConfigRegU();
    Reg#(Maybe#(RegOps)) maybe_op <- mkReg(tagged Invalid);
    Reg#(Bit#(8)) address <- mkRegU();
    Reg#(Bit#(8)) wdata <- mkRegU();

    (* fire_when_enabled *)
    rule do_page1_read (maybe_op matches tagged Valid .op &&& op == READ);
        let reader =
            case (address)
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

                // PCIe control
                fromOffset(pcieHotplugCtrlOffset): read(pcie.ctrl);
                fromOffset(pcieHotplugStatusOffset): read(pcie.status);

                default: read(8'h00);
            endcase;

        let rdata <- reader;

        maybe_op <= tagged Invalid;
        response <= rdata;
    endrule

    (* fire_when_enabled *)
    rule do_page1_update (maybe_op matches tagged Valid .op &&& op != READ);
        case (address)
            fromOffset(tofinoSeqCtrlOffset): update(op, tofino.ctrl, wdata);
            fromOffset(pcieHotplugCtrlOffset): update(op, pcie.ctrl, wdata);
        endcase

        maybe_op <= tagged Invalid;
    endrule

    method ActionValue#(Bool) offer(SpiRequest request) if (!isValid(maybe_op));
        let accepted = (request.address[15:8] == 1 && request.op != NOOP);

        if (accepted) begin
            maybe_op <= tagged Valid request.op;
            address <= request.address[7:0];
            wdata <= request.wdata;
        end

        return accepted;
    endmethod

    method read = response;
endmodule

//
// Page 2, Tofino Debug Port
//

module mkPage2 #(TofinoDebugPort::Registers tofino_debug_port) (RegisterPage);
    Reg#(SpiResponse) response <- mkConfigRegU();
    Reg#(Maybe#(RegOps)) maybe_op <- mkReg(tagged Invalid);
    Reg#(Bit#(8)) address <- mkRegU();
    Reg#(Bit#(8)) wdata <- mkRegU();

    (* fire_when_enabled *)
    rule do_page2_read (maybe_op matches tagged Valid .op &&& op == READ);
        let reader =
            case (address)
                fromOffset(tofinoDebugPortStateOffset):
                        read(tofino_debug_port.state);
                fromOffset(tofinoDebugPortBufferOffset):
                        read_volatile(tofino_debug_port.buffer);
                default: read(8'h00);
            endcase;

        let rdata <- reader;

        maybe_op <= tagged Invalid;
        response <= rdata;
    endrule

    (* fire_when_enabled *)
    rule do_page2_update (maybe_op matches tagged Valid .op &&& op != READ);
        case (address)
            fromOffset(tofinoDebugPortStateOffset):
                update(op, tofino_debug_port.state, wdata);
            fromOffset(tofinoDebugPortBufferOffset):
                write(WRITE, tofino_debug_port.buffer._write, wdata);
        endcase

        maybe_op <= tagged Invalid;
    endrule

    method ActionValue#(Bool) offer(SpiRequest request) if (!isValid(maybe_op));
        let accepted = (request.address[15:8] == 2 && request.op != NOOP);

        if (accepted) begin
            maybe_op <= tagged Valid request.op;
            address <= request.address[7:0];
            wdata <= request.wdata;
        end

        return accepted;
    endmethod

    method read = response;
endmodule

module mkIgnitionGeneralPage
        #(IgnitionController::Controller#(n_ignition_controllers) ignition)
            (RegisterPage)
                provisos (Add#(n_ignition_controllers, a__, 64));
    Reg#(Maybe#(Bit#(8))) maybe_address <- mkReg(tagged Invalid);
    Reg#(SpiResponse) response <- mkConfigRegU();

    Vector#(8, Bit#(8)) presence_summary =
            unpack(extend(pack(ignition.presence_summary)));

    (* fire_when_enabled *)
    rule do_get_response (maybe_address matches tagged Valid .address);
        let reader =
            case (address)
                fromOffset(ignitionControllersCountOffset):
                        read(Bit#(8)'(fromInteger(
                            valueOf(n_ignition_controllers))));
                fromOffset(ignitionTargetsPresent0Offset):
                        read(presence_summary[0]);
                fromOffset(ignitionTargetsPresent1Offset):
                        read(presence_summary[1]);
                fromOffset(ignitionTargetsPresent2Offset):
                        read(presence_summary[2]);
                fromOffset(ignitionTargetsPresent3Offset):
                        read(presence_summary[3]);
                fromOffset(ignitionTargetsPresent4Offset):
                        read(presence_summary[4]);
                default: read(8'h00);
            endcase;

        let rdata <- reader;

        maybe_address <= tagged Invalid;
        response <= rdata;
    endrule

    method ActionValue#(Bool) offer(SpiRequest request)
            if (!isValid(maybe_address));
        let accepted = (request.address[15:8] == 3 && request.op != NOOP);

        if (accepted) begin
            maybe_address <= tagged Valid request.address[7:0];
        end

        return accepted;
    endmethod

    method read = response;
endmodule

module mkIgnitionRegistersPage #(RegisterServer#(n) registers) (RegisterPage)
            provisos (Add#(TLog#(n), a__, 6));
    Reg#(Bool) await_response <- mkReg(False);
    Reg#(SpiResponse) response <- mkConfigRegU();

    (* fire_when_enabled *)
    rule do_get_response (await_response);
        let data <- registers.response.get;

        await_response <= False;
        response <= SpiResponse {readdata: data};
    endrule

    method ActionValue#(Bool) offer(SpiRequest request) if (!await_response);
        let accepted = ({request.address[15:14], request.address[7]} == 3'b010);

        ControllerId#(n) controller = unpack(truncate(request.address[13:8]));

        if (accepted) begin
            // Determine if the request is for a live register.
            let maybe_register =
                case (request.address[7:0])
                    fromInteger(transceiverStateOffset):
                        tagged Valid TransceiverState;
                    fromInteger(controllerStateOffset):
                        tagged Valid ControllerState;
                    fromInteger(targetSystemTypeOffset):
                        tagged Valid TargetSystemType;
                    fromInteger(targetSystemStatusOffset):
                        tagged Valid TargetSystemStatus;
                    fromInteger(targetSystemEventsOffset):
                        tagged Valid TargetSystemEvents;
                    fromInteger(targetSystemPowerRequestStatusOffset):
                        tagged Valid TargetSystemPowerRequestStatus;
                    fromInteger(targetLink0StatusOffset):
                        tagged Valid TargetLink0Status;
                    fromInteger(targetLink1StatusOffset):
                        tagged Valid TargetLink1Status;
                    default:
                        tagged Invalid;
                endcase;

            if (maybe_register matches tagged Valid .register &&&
                        request.op == READ) begin
                await_response <= True;
                registers.request.put(
                        RegisterRequest {
                            id: controller,
                            register: register,
                            op: tagged Read});
            end
            else if
                    (maybe_register matches tagged Valid .register &&&
                        request.op == WRITE) begin
                registers.request.put(
                        RegisterRequest {
                            id: controller,
                            register: register,
                            op: tagged Write request.wdata});
            end
            else begin
                response <= SpiResponse {readdata: 'h00};
            end
        end

        return accepted;
    endmethod

    method read = response;
endmodule

module mkIgnitionCountersPage #(CounterServer#(n) counters) (RegisterPage)
            provisos (Add#(TLog#(n), a__, 6));
    Reg#(Bool) await_response <- mkReg(False);
    Reg#(SpiResponse) response <- mkConfigRegU();

    (* fire_when_enabled *)
    rule do_get_response (await_response);
        let data <- counters.response.get;

        await_response <= False;
        response <= SpiResponse {readdata: pack(data)};
    endrule

    method ActionValue#(Bool) offer(SpiRequest request) if (!await_response);
        let accepted = ({request.address[15:14], request.address[7]} == 3'b011);

        ControllerId#(n) controller = unpack(truncate(request.address[13:8]));
        CounterId counter = unpack(request.address[5:0]);

        if (accepted) begin
            await_response <= True;
            counters.request.put(
                    CounterAddress {
                        controller: controller,
                        counter: counter});
        end

        return accepted;
    endmethod

    method read = response;
endmodule

//
// Helpers
//

typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;
typedef Server#(SpiRequest, SpiResponse) SpiServer;

function Bit#(8) fromOffset(Integer offset);
    Bit#(16) offset_ = fromInteger(offset);
    return offset_[7:0];
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
