// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MDIO;

export Parameters(..), Command(..); // structs
export Pins(..), MDIO(..); // interfaces
export mkMDIO; // module

import DefaultValue::*;
import FIFO::*;
import GetPut::*;
import Vector::*;

import Strobe::*;

import Common::*;

// Parameters used to configure various things within the block
// system_frequency_hz      - main clock domain for the design
// mdc_frequency_hz         - clock for the MDIO interface
typedef struct {
    Integer system_frequency_hz;
    Integer mdc_frequency_hz;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        system_frequency_hz: 50_000_000,
        mdc_frequency_hz: 3_000_000
    };
endinstance

// TODO: add better preamble support
typedef enum {
    Idle            = 0,
    TransmitHeader  = 1,
    TurnaroundStart = 2,
    TurnaroundEnd   = 3,
    TransmitData    = 4,
    ReceiveData     = 5
} State deriving (Eq, Bits, FShow);

typedef struct {
    Bool read;
    Bit#(5) phy_addr;
    Bit#(5) reg_addr;
    Bit#(16) write_data;
} Command deriving (Bits, Eq, FShow);

instance DefaultValue#(Command);
    defaultValue = Command {
        read: True,
        phy_addr: 5'h1F,
        reg_addr: 5'h1F,
        write_data: 16'hFFFF
    };
endinstance

interface Pins;
    interface Tristate mdio;
    method Bit#(1) mdc;
endinterface

interface MDIO;
    method Bool busy;
    interface Pins pins;
    interface Put#(Command) command;
    interface Get#(Bit#(16)) read_data;
endinterface

module mkMDIO #(Parameters parameters) (MDIO);
    // MDC toggle counter
    Integer mdc_half_period_count = 
        parameters.system_frequency_hz / parameters.mdc_frequency_hz / 2;
    Strobe#(10) mdc_toggle_strobe    <-
        mkFractionalStrobe(mdc_half_period_count, 0);

    // FIFOs for Put/Get Interfaces
    FIFO#(Command) next_command_q   <- mkFIFO1();
    FIFO#(Bit#(16)) read_data_q     <- mkFIFO1();

    // state
    Reg#(State) state                   <- mkReg(Idle);
    Reg#(Maybe#(Command)) next_command  <- mkReg(tagged Invalid);
    Reg#(Command) cur_command           <- mkReg(defaultValue);
    Wire#(Bool) valid_command           <- mkWire();

    // pin registers
    Reg#(Bit#(1)) mdc           <- mkReg(1);
    Reg#(Bit#(1)) mdint         <- mkReg(0);
    Reg#(Bit#(1)) mdio_out      <- mkReg(1);
    Reg#(Bit#(1)) mdio_out_en   <- mkReg(1);
    Reg#(Bit#(1)) mdio_in       <- mkReg(0);

    // Edge detection for MDC
    PulseWire mdc_fedge <- mkPulseWire();
    PulseWire mdc_redge <- mkPulseWire();

    // State for FSM
    Reg#(Bool) is_read                  <- mkReg(False);
    Reg#(Vector#(16, Bit#(1))) buffer   <- mkReg(replicate(0));
    Reg#(UInt#(5)) bit_cntr             <- mkReg(0);

    // Only toggle MDC when there is a transaction to do, or keep running it
    // after re-entering Idle at the end of a transaction to return it to 1 at
    // the proper time
    (* fire_when_enabled *)
    rule do_mdc_toggle_tick(state != Idle || (state == Idle && mdc == 0));
        mdc_toggle_strobe.send();
    endrule

    // Toggle MDC and generate edge pulses useful to other logic
    (* fire_when_enabled *)
    rule do_mdc_toggle(mdc_toggle_strobe);
        mdc <= ~mdc;

        if (mdc == 0 && ~mdc == 1) begin
            mdc_redge.send();
        end

        if (mdc == 1 && ~mdc == 0) begin
            mdc_fedge.send();
        end
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule do_valid_command;
        valid_command   <= isValid(next_command);
    endrule

    (* fire_when_enabled *)
    rule do_register_command(state == Idle && !valid_command);
        next_command    <= tagged Valid next_command_q.first;
    endrule

    // A future improvement to make would be to dynamically control preamble
    // length for each transaction since there is inconsistency about what
    // devices want. The standard is 32-bits (!) of preamble, but the VSC8562
    // (the device this was written for) can handle any amount or even no
    // preamble given the first transaction has at least 2 bits of it.
    (* fire_when_enabled *)
    rule do_idle(state == Idle && valid_command);
        let cmd     = fromMaybe(?, next_command);
        cur_command <= cmd;
        mdio_out_en <= 1;
        mdio_out    <= 1;
        bit_cntr    <= 0;
        buffer      <= reverse(unpack({ 2'b11, // 2-bit preamble for VSC8562
                                2'b01, // SFD
                                pack(pack(cmd.read)),
                                pack(pack(!cmd.read)),
                                cmd.phy_addr,
                                cmd.reg_addr}));
        state       <= TransmitHeader;
    endrule

    (* fire_when_enabled *)
    rule do_header(state == TransmitHeader && valid_command);
        if (mdc_fedge && bit_cntr + 1 == 16) begin
            bit_cntr    <= 0;
            state       <= TurnaroundStart;

            if (cur_command.read) begin
                mdio_out_en <= 0;
            end else begin
                mdio_out    <= 1;
            end
        end else if (mdc_fedge) begin
            bit_cntr        <= bit_cntr + 1;
        end else if (bit_cntr < 16) begin
            mdio_out        <= buffer[bit_cntr];
        end
    endrule

    (* fire_when_enabled *)
    rule do_turnaround_start(state == TurnaroundStart && valid_command && mdc_fedge);
        if (cur_command.read) begin
            state       <= ReceiveData;
        end else begin
            state       <= TurnaroundEnd;
            mdio_out    <= 0;
        end
    endrule

    (* fire_when_enabled *)
    rule do_turnaround_end(state == TurnaroundEnd && valid_command && mdc_fedge);
        if (cur_command.read) begin
            state   <= ReceiveData;
        end else begin
            buffer  <= reverse(unpack(cur_command.write_data));
            state   <= TransmitData;
        end
    endrule

    (* fire_when_enabled *)
    rule do_transmit(state == TransmitData && valid_command);
        if (mdc_fedge) begin
            bit_cntr    <= bit_cntr + 1;
        end

        if (bit_cntr < 16) begin
            mdio_out        <= buffer[bit_cntr];
        end else begin
            mdio_out_en     <= 0;
            next_command    <= tagged Invalid;
            state           <= Idle;
            next_command_q.deq();
        end
    endrule

    (* fire_when_enabled *)
    rule do_reg_receive(state == ReceiveData && valid_command);
        if (mdc_fedge) begin
            bit_cntr    <= bit_cntr + 1;
        end

        if (bit_cntr < 16) begin
            buffer[bit_cntr]    <= mdio_in;
        end else begin
            let rev_bits = pack(reverse(buffer));
            read_data_q.enq(rev_bits);
            next_command        <= tagged Invalid;
            state               <= Idle;
            next_command_q.deq();
        end
    endrule

    method Bool busy        = state != Idle;

    interface Pins pins;
        method mdc          = mdc;

        interface Tristate mdio;
            method out      = mdio_out;
            method out_en   = mdio_out_en;
            method in       = mdio_in._write;
        endinterface
    endinterface

    interface Put command;
        method put          = next_command_q.enq;
    endinterface

    interface Get read_data = toGet(read_data_q);
endmodule

endpackage: MDIO