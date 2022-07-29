// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MDIOPeripheralModel;

export ModelEvent(..); // union
export MDIOPeripheralPins(..), MDIOPeripheralModel(..); // interfaces
export mkMDIOPeripheralModel; // module

import FIFO::*;
import GetPut::*;
import Vector::*;

import Common::*;
import MDIO::*;

// The model will emit these ModelEvents over the course of a transaction so a
// testbench can verify data and event ordering.
typedef union tagged {
    void    Abort;
    void    ReceivedSFD;
    void    ReceivedReadOp;
    void    ReceivedWriteOp;
    Bit#(5) ReceivedPhyAddr;
    Bit#(5) PhyAddrMismatch;
    Bit#(5) ReceivedRegAddr;
    Bool    ReceivedReadTA; // True if Read TA, False if Write TA
    Bit#(16) ReceivedWriteData;
    Bit#(16) TransmittedReadData;
} ModelEvent deriving (Bits, Eq, FShow);

typedef enum {
    Preamble = 0,
    StartOfFrame = 1,
    Opcode = 2,
    PhyAddress = 3,
    RegAddress = 4,
    ReadTurnaround = 5,
    WriteTurnaround = 6,
    ReceiveWrite = 7,
    TransmitRead = 8,
    Abort = 9
} ModelState deriving (Bits, Eq, FShow);

interface MDIOPeripheralPins;
    method Action mdc (Bit#(1) mdc);
    interface Tristate mdio;
endinterface

interface MDIOPeripheralModel;
    method Action mdio_ctrl_out_en(Bit#(1) mdio_ctrl_out_en);
    interface MDIOPeripheralPins pins;
    interface Get#(ModelEvent) events;
endinterface

module mkMDIOPeripheralModel #(Bit#(5) phy_address) (MDIOPeripheralModel);
    Reg#(Bit#(5)) peripheral_address        <- mkReg(phy_address);

    Reg#(Vector#(32, Bit#(16))) memory_map  <- mkReg(replicate(0));

    FIFO#(ModelEvent) outgoing_event    <- mkFIFO1();

    Reg#(Bit#(1)) mdc           <- mkReg(1);
    Reg#(Bit#(1)) mdio_out      <- mkReg(1);
    Reg#(Bit#(1)) mdio_out_en   <- mkReg(0);
    Reg#(Bit#(1)) mdio_in       <- mkReg(1);
    Wire#(Bit#(1)) ctrl_out_en  <- mkWire();

    Reg#(Bit#(1)) mdc_prev      <- mkReg(1);

    PulseWire mdc_redge <- mkPulseWire();
    PulseWire mdc_fedge <- mkPulseWire();

    Reg#(ModelState) state  <- mkReg(Preamble);
    Reg#(UInt#(5)) bit_cntr <- mkReg(0);
    Reg#(Bool) is_read      <- mkReg(False);

    Reg#(Vector#(5, Bit#(1))) address   <- mkReg(replicate(0));
    Reg#(Vector#(16, Bit#(1))) data     <- mkReg(replicate(0));

    (* fire_when_enabled *)
    rule do_mdc_edge_detect;
        mdc_prev    <= mdc;

        if (mdc == 1 && mdc_prev == 0) begin
            mdc_redge.send();
        end else if (mdc == 0 && mdc_prev == 1) begin
            mdc_fedge.send();
        end
    endrule

    (* fire_when_enabled *)
    rule do_preamble (state == Preamble);
        bit_cntr    <= 0;

        if (mdio_in == 0) begin
            state   <= StartOfFrame;
        end
    endrule

    (* fire_when_enabled *)
    rule do_start_of_frame (state == StartOfFrame && mdc_redge);
        if (bit_cntr == 0 && mdio_in == 0) begin
            bit_cntr    <= bit_cntr + 1;
        end else if (bit_cntr == 0 && mdio_in == 1) begin
            state       <= Abort;
        end

        if (bit_cntr == 1 && mdio_in == 1) begin
            bit_cntr    <= 0;
            state       <= Opcode;
            outgoing_event.enq(tagged ReceivedSFD);
        end else if (bit_cntr == 1 && mdio_in == 0) begin
            state       <= Abort;
        end
    endrule

    (* fire_when_enabled *)
    rule do_opcode (state == Opcode && mdc_redge);
        if (bit_cntr == 0) begin
            bit_cntr    <= bit_cntr + 1;
            is_read     <= mdio_in == 1;
        end

        if (bit_cntr == 1) begin
            let read_op = is_read && mdio_in == 0;
            let write_op = !is_read && mdio_in == 1;

            if (read_op || write_op) begin
                bit_cntr    <= 0;
                state       <= PhyAddress;

                if (read_op) begin
                    outgoing_event.enq(tagged ReceivedReadOp);
                end else begin
                    outgoing_event.enq(tagged ReceivedWriteOp);
                end
            end else begin
                state       <= Abort;
            end
        end
    endrule

    (* fire_when_enabled *)
    rule do_phy_address (state == PhyAddress && mdc_redge);
        address <= shiftInAt0(address, mdio_in);

        if (bit_cntr + 1 == 5) begin
            bit_cntr    <= 0;
            let addr    = {pack(address)[3:0], mdio_in};

            if (addr == peripheral_address) begin
                state   <= RegAddress;
                outgoing_event.enq(tagged ReceivedPhyAddr pack(addr));
            end else begin
                state   <= Preamble;
                outgoing_event.enq(tagged PhyAddrMismatch pack(addr));
            end
        end else begin
            bit_cntr    <= bit_cntr + 1;
        end
    endrule

    (* fire_when_enabled *)
    rule do_reg_address (state == RegAddress && mdc_redge);
        address     <= shiftInAt0(address, mdio_in);

        if (bit_cntr + 1 == 5) begin
            bit_cntr    <= 0;
            let addr    = {pack(address)[3:0], mdio_in};
            outgoing_event.enq(tagged ReceivedRegAddr addr);

            if (is_read) begin
                state   <= ReadTurnaround;
            end else begin
                state   <= WriteTurnaround;
            end
        end else begin
            bit_cntr    <= bit_cntr + 1;
        end
    endrule

    (* fire_when_enabled *)
    rule do_read_turnaround (state == ReadTurnaround && mdc_redge);
        mdio_out_en <= 1;
        mdio_out    <= 0;
        data        <= unpack(memory_map[pack(address)]);
        state       <= TransmitRead;
        outgoing_event.enq(tagged ReceivedReadTA True);
    endrule

    (* fire_when_enabled *)
    rule do_write_turnaround (state == WriteTurnaround && mdc_redge);
        if (bit_cntr == 0 && mdio_in == 1) begin
            bit_cntr    <= bit_cntr + 1;
        end else if (bit_cntr == 0 && mdio_in == 0) begin
            state       <= Abort;
        end

        if (bit_cntr == 1 && mdio_in == 0) begin
            bit_cntr    <= 0;
            state       <= ReceiveWrite;
            outgoing_event.enq(tagged ReceivedReadTA False);
        end else if (bit_cntr == 1 && mdio_in == 1) begin
            state       <= Abort;
        end
    endrule

    (* fire_when_enabled *)
    rule do_receive_write (state == ReceiveWrite && mdc_redge);
        if (bit_cntr < 16) begin
            bit_cntr    <= bit_cntr + 1;
            data        <= shiftInAt0(data, mdio_in);
        end else begin
            memory_map[pack(address)] <= pack(data);
            state               <= Preamble;
            outgoing_event.enq(tagged ReceivedWriteData pack(data));
        end
    endrule

    (* fire_when_enabled *)
    rule do_transmit_read (state == TransmitRead && mdc_redge);
        if (bit_cntr < 16) begin
            bit_cntr    <= bit_cntr + 1;
            mdio_out    <= data[bit_cntr];
        end else begin
            state       <= Preamble;
            outgoing_event.enq(tagged TransmittedReadData pack(data));
        end
    endrule

    (* fire_when_enabled *)
    rule do_abort (state == Abort);
        state   <= Preamble;
        outgoing_event.enq(tagged Abort);
    endrule

    method mdio_ctrl_out_en = ctrl_out_en._write;

    interface MDIOPeripheralPins pins;
        method mdc  = mdc._write;

        interface Tristate mdio;
            method Bit#(1) out();
                return mdio_out & ~ctrl_out_en;
            endmethod
            method out_en   = mdio_out_en;
            method in       = mdio_in._write;
        endinterface
    endinterface

    interface Get events    = toGet(outgoing_event);

endmodule

endpackage: MDIOPeripheralModel