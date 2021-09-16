package SpiDecode;

import GetPut::*;
import ClientServer::*;
import Connectable::*;
import StmtFSM::*;
import Vector::*;

import RegCommon::*;

interface SpiDecodeIF;
    interface Server#(SpiRx, Bit#(8)) spi_byte;
    interface Client#(RegRequest#(16, 8), RegResp#(8)) reg_con;
endinterface


typedef struct {
    Maybe#(Bit#(8)) spi_rx_byte;
    Bool done;
} SpiRx deriving (Bits, Eq);

typedef enum {CMD, ADDR1, ADDR2, DO_READ, DO_WRITE, READ_WAIT, WRITE_WAIT} State deriving (Eq, Bits);

module mkSpiRegDecode(SpiDecodeIF);
    // Registers
    Reg#(State) state <- mkReg(CMD);
    Reg#(Bit#(16)) addr_reg <- mkRegU();
    Reg#(RegOps) operation <- mkRegU();
    Reg#(Maybe#(Bit#(8))) reg_read_data <- mkReg(tagged Invalid);
    Reg#(Maybe#(Bit#(8))) reg_write_data <- mkReg(tagged Invalid);


    // comb signals
    RWire#(Bit#(8)) data <- mkRWire();
    PulseWire done <- mkPulseWire();
    PulseWire got_data <- mkPulseWire();
    PulseWire do_reg_txn <- mkPulseWire();
    let my_data = fromMaybe(?, data.wget());

    // Store first byte which is the opcode
    rule store_op (state == CMD);
        if (done) begin
            state <= CMD;
        end else if (got_data) begin
            // Turn opcode byte into an actual opcode
            operation <= unpack(truncate(my_data));
             state <= ADDR1;
        end
    endrule

    // Store first byte which is the MSB of address
    rule do_addr1 (state == ADDR1);
        if (done) begin
            state <= CMD;
        end else if (got_data) begin
            state <= ADDR2;
            addr_reg <= {pack(my_data), addr_reg[7:0]};
        end
    endrule

    // Store first byte which is the LSB of address
    // If we're doing a read, we need to prime the pump by fetching a read
    // at this address immediately since we'll need to shift it out starting
    // at the next SPI clock cycle
    rule do_addr2 (state == ADDR2);
        let next_state = operation == READ ? DO_READ : WRITE_WAIT;
        if (done) begin
            state <= CMD;
        end else if (got_data) begin
            state <= next_state;
            addr_reg <= {addr_reg[15:8], pack(my_data)};
        end
    endrule

    // This is a single-cycle state where the Client request
    // is sent to the register block
    rule do_txn (state == DO_READ || state == DO_WRITE);
        if (done) begin
            state <= CMD;
        end else begin
            let next_state = operation == READ ? READ_WAIT : WRITE_WAIT;
            state <= next_state;
            addr_reg <= addr_reg + 1;  // get ready for the next read/write
            // Clear valid flag since this write data was consumed.
            reg_write_data <= tagged Invalid;
        end
    endrule

    // When doing reads or writes, we're going to auto-increment the address
    rule do_wait (state == READ_WAIT || state == WRITE_WAIT);
        let next_state = operation == READ ? DO_READ : DO_WRITE;
        if (done) begin
            state <= CMD;
        end else if (got_data) begin
            state <= next_state;
            // We got data while waiting. If this is a read,
            // we don't care what happens here, if this is a write
            // we store the data to build the transaction.
            reg_write_data <= tagged Valid my_data;
        end
    endrule

    // Do the interface to/from the shifter.
    // This is a server interface since the shifter drives this interface
    // Request spi_rx_structs come in, 8bit bytes go out.
    interface Server spi_byte;
        interface Put request;
            method Action put(spi_rx_struct);
                got_data.send();
                if (spi_rx_struct.done) begin
                    done.send();
                end
                if (isValid(spi_rx_struct.spi_rx_byte)) begin
                    data.wset(fromMaybe(?, spi_rx_struct.spi_rx_byte));
                end
            endmethod
        endinterface
        // TODO: when is this valid?
        interface Get response;
            method ActionValue#(Bit#(8)) get() if (isValid(reg_read_data));
                let ret_data = fromMaybe(?, reg_read_data);
                reg_read_data <= tagged Invalid;
                return ret_data;
            endmethod
        endinterface
    endinterface

    // Do the interface to the register block
    interface Client reg_con;
        // Request for register command
        interface Get request;
            method ActionValue#(RegRequest#(16, 8)) get() if (state == DO_READ || state == DO_WRITE);
                let ret = RegRequest {
                    address: addr_reg, 
                    wdata: fromMaybe(?, reg_write_data),
                    op: operation
                };
                return ret;
            endmethod
        endinterface
        interface Put response;
            method Action put(resp) if (!isValid(reg_read_data));
                reg_read_data <= tagged Valid resp.readdata;
            endmethod
        endinterface
    endinterface


endmodule

// This is a server instance meant to be used in testing  the SPI
// decode block by acting like a register server interface.
//
// It has a single register that stores the results of the last write
// and can be operated on. The address written don't matter to this
// block.
// Any read will return the data currently in the single register.
module mkTestRegResponder(Server#(RegRequest#(16, 8), RegResp#(8)));
    PulseWire do_read <- mkPulseWire();
    PulseWire do_write <- mkPulseWire();
    PulseWire do_bitset <- mkPulseWire();
    PulseWire do_bitclear <- mkPulseWire();
    Reg#(Bit#(8)) only_reg <- mkReg(06);

    RWire#(Bit#(8)) rd_reg <- mkRWire();

    interface Put request;
            method Action put(request);
                if (request.op == WRITE) begin
                    only_reg <= request.wdata;
                    do_write.send();
                end else if (request.op == BITSET) begin
                    only_reg <= only_reg | request.wdata;
                    do_bitset.send();
                end else if (request.op == BITCLEAR) begin
                    only_reg <= only_reg & (~request.wdata);
                    do_bitclear.send();
                end else if (request.op == READ) begin
                    do_read.send();
                    rd_reg.wset(only_reg);
                end

            endmethod
        endinterface
        interface Get response;
            method ActionValue#(RegResp#(8)) get() if (isValid(rd_reg.wget()));
                return RegResp {readdata: fromMaybe(?, rd_reg.wget())};
            endmethod
        endinterface
endmodule

// Test bench
(* synthesize *)
module mkTestSpiDecode(Empty);
    SpiDecodeIF decode <- mkSpiRegDecode();
    Server#(RegRequest#(16, 8), RegResp#(8)) fake_reg <- mkTestRegResponder();
    mkConnection(decode.reg_con, fake_reg);
    
    let a_byte = tagged Valid ('hff);
    let read_byte = SpiRx {spi_rx_byte:  tagged Valid (zeroExtend(pack(READ))), done: False};
    let write_byte = SpiRx {spi_rx_byte:  tagged Valid (zeroExtend(pack(WRITE))), done: False};
    let zero_byte = SpiRx {spi_rx_byte: tagged Valid 'hff, done:False};
    let done_byte = SpiRx {spi_rx_byte: a_byte, done: True};

    function SpiRx make_byte (Bit#(8) data, Bool last);
        return SpiRx {spi_rx_byte: tagged Valid (data), done: last};
    endfunction

    // Simple function to do spi wites (or bitset, bitclears)
    function Stmt do_write(RegOps opcode, Bit#(16) address, Bit#(8) data);
        return seq
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(opcode)), False));  // CMD
            decode.spi_byte.request.put(make_byte(address[15:8], False));  // Addr1
            decode.spi_byte.request.put(make_byte(address[7:0], False));  // Addr2
            decode.spi_byte.request.put(make_byte(data, False)); // Data word
            decode.spi_byte.request.put(make_byte(data, True)); // Dummy data word
        endseq;
    endfunction

    // Simple function to test bitset
    function Stmt do_bitset();
        return seq
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(WRITE)), False));  // CMD
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h05, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(BITSET)), False));  // CMD
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h50, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
        endseq;
    endfunction
    // Simple function to test bitclear
    function Stmt do_bitclear();
        return seq
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(WRITE)), False));  // CMD
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h05, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(BITCLEAR)), False));  // CMD
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h05, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
        endseq;
    endfunction

    function Stmt do_read();
        return seq
             decode.spi_byte.request.put(make_byte(zeroExtend(pack(WRITE)), False));  // CMD
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h05, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});

            decode.spi_byte.request.put(make_byte(zeroExtend(pack(READ)), False));  // CMD
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte(0, False)); // Data word
            // We should read a 'h05
            //$display(decode.spi_byte.response.get());
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
        endseq;
    endfunction

    mkAutoFSM(
        do_read()
    );

endmodule

// Physical pins interface for a SPI peripheral
interface SpiPeriphPins;
    (* prefix = "" *)
    method Action csn(Bit#(1) value);   // Chip select pin, always sampled
    method Action sclk(Bit#(1) value);  // sclk pin, always sampled
    method Action copi(Bit#(1) data);   // Input data pin sampled on appropriate sclk detected edge
    method Bit#(1) cipo; // Output pin, always valid, shifts on appropriate sclk detected edge
endinterface

// Physical pins interface for a SPI controller
interface SpiControllerPins;
    method Bit#(1) csn;  // CSN output
    method Bit#(1) sclk; // sclk output
    method Bit#(1) copi; // data output
    method Action cipo(Bit#(1) data);
endinterface

interface SpiPeriphPhyIF;
    (* prefix = "" *)
    interface SpiPeriphPins pins;  // Physical pins interface
    // Interface to decoderinterface Server#(SpiRx, Bit#(8)) spi_byte;
    interface Client#(SpiRx, Bit#(8)) decoder_if;
endinterface

// Main shift registers for a SPI peripheral
module mkSpiPeriphPhy(SpiPeriphPhyIF);
    // Module registers
    Reg#(Vector#(9, Bit#(1))) tx_shift <- mkRegU();
    Reg#(Vector#(9, Bit#(1))) rx_shift <- mkRegU();
    Reg#(Bit#(1)) sclk_last <- mkRegU();
    Reg#(Bit#(1)) csn_last <- mkRegU();
    Reg#(Maybe#(Bit#(8))) new_tx_data <- mkReg(tagged Invalid);

    // Module combo things
    PulseWire sclk_redge  <- mkPulseWire();
    PulseWire sclk_fedge  <- mkPulseWire();
    PulseWire deselected  <- mkPulseWire();
    
    RWire#(Vector#(9, Bit#(1))) new_rx_data <- mkRWire();
    RWire#(Bit#(1)) cur_sclk <- mkRWire();
    RWire#(Bit#(1)) cur_csn  <- mkRWire();
    RWire#(Bit#(1)) cur_copi <- mkRWire();

    (* fire_when_enabled *)
    rule do_lasts;
        sclk_last <= fromMaybe(sclk_last, cur_sclk.wget());
        csn_last <= fromMaybe(csn_last, cur_csn.wget());
    endrule

    // Detect rising and falling edges of the SPI clock when we're enabled (csn=0)
    (* fire_when_enabled *)
    rule do_edge_detect (fromMaybe(1, cur_csn.wget()) == 0);
        let sclk = fromMaybe(sclk_last, cur_sclk.wget());
        if (sclk_last == 0 && sclk == 1) begin
            sclk_redge.send();
        end
        if (sclk_last == 1 && sclk == 0) begin
            sclk_fedge.send();
        end
    endrule

    // Detect when we've lost the SPI select (rising edge of csn)
    (* fire_when_enabled *)
    rule do_lost_select_flag;
        if (csn_last == 0 && fromMaybe(csn_last, cur_csn.wget()) == 1) begin
            deselected.send();
        end
    endrule

    // Reset shifters when we've lost the peripheral select
    (* fire_when_enabled *)
    rule do_tx_shifter (sclk_fedge);
        if (isValid(new_tx_data)) begin
            tx_shift <= unpack({fromMaybe(?, new_tx_data), 1});
            new_tx_data <= tagged Invalid;
        end else begin
            tx_shift <= shiftInAt0(tx_shift, 0);
        end
    endrule

    // SPI mode 0,0 so shift in sampled on rising edge
    (* fire_when_enabled *)
    rule do_shift_in;
        if (rx_shift[8] == 1) begin
            new_rx_data.wset(rx_shift);
            rx_shift <= unpack(1);
        end else if (fromMaybe(1, cur_csn.wget()) == 1) begin
            rx_shift <= unpack(1);
        end else if (sclk_redge && rx_shift[8] != 1) begin
            rx_shift <= shiftInAt0(rx_shift, fromMaybe(?, cur_copi.wget()));
        end
    endrule

    interface SpiPeriphPins pins;
        // Chip select pin, always sampled
        method Action csn(Bit#(1) value);   
            cur_csn.wset(value);
        endmethod
        // sclk pin, always sampled
        method Action sclk(Bit#(1) value);
            cur_sclk.wset(value);
        endmethod
        // Input data pin latched on appropriate sclk detected edge
        method Action copi(Bit#(1) data);
            cur_copi.wset(data);
        endmethod
        // Output pin, always valid, shifts on appropriate sclk detected edge
        method Bit#(1) cipo;
            return tx_shift[8];
        endmethod

    endinterface

    interface Client decoder_if;
        // Send byte to the decoder when we have a new valid byte or
        interface Get request;
            method ActionValue#(SpiRx) get() if (isValid(new_rx_data.wget()));
                Maybe#(Bit#(8)) data_byte = !deselected ? tagged Valid (pack(new_rx_data.wget())[7:0]) : tagged Invalid;
                let ret = SpiRx {spi_rx_byte: data_byte, done: deselected};
                return ret;
            endmethod
        endinterface
        // accept byte from the decoder when it hands one to us.
        interface Put response;
            method Action put(resp) if (!isValid(new_tx_data) && !sclk_fedge);
                new_tx_data <= tagged Valid resp;
            endmethod
        endinterface
    endinterface

endmodule


interface SPITestController;
    interface SpiControllerPins pins;
    interface Server#(Vector#(8, Bit#(8)),Vector#(8, Bit#(8))) bfm;
endinterface

typedef enum {IDLE, CS_START, SHIFTING, CS_STOP} ContState deriving (Eq, Bits);
typedef struct {
    Vector#(arrayWidth, Bit#(8)) data;
} ContData#(numeric type arrayWidth);

module mkSpiTestController(SPITestController);

    Reg#(Vector#(8, Bit#(8))) tx_buffer <- mkRegU();
    Reg#(Vector#(8, Bit#(8))) rx_buffer <- mkRegU();
    Reg#(UInt#(4)) sclk_cntr <- mkRegU();
    Reg#(Bit#(1)) sclk <- mkReg(0);
    Reg#(Bit#(1)) sclk_last <- mkReg(0);
    Reg#(Bit#(1)) csn <- mkReg(1);
    Reg#(Bit#(1)) cipo <- mkReg(0);
    Reg#(Bit#(8)) rem_bytes <- mkReg(0);
    Reg#(UInt#(4)) cs_cntr   <- mkReg(0);
    Reg#(ContState) state <- mkReg(IDLE);

    Reg#(Vector#(9, Bit#(1))) out_shifter <- mkReg(unpack('h00));
    Reg#(Vector#(9, Bit#(1))) in_shifter <- mkReg(unpack('h01));

    PulseWire start <- mkPulseWire();
    PulseWire sclk_redge <- mkPulseWire();
    PulseWire sclk_fedge <- mkPulseWire();

    rule do_csn;
        if (state != IDLE) begin
            csn <= 0;
        end else begin
            csn <= 1;
        end
    endrule

    rule do_sclk (state == SHIFTING);
        sclk_cntr <= sclk_cntr + 1;
        if (sclk_cntr == 1) begin
            sclk <= 1;
        end
        if (sclk_cntr == 9) begin
            sclk <= 0;
        end
        sclk_last <= sclk;
    endrule

    rule do_edges (state == SHIFTING);
        if (sclk_last == 0 && sclk == 1) begin
           sclk_redge.send();
       end
        if (sclk_last == 1 && sclk == 0) begin
            sclk_fedge.send();
        end
    endrule

    rule do_idle (state == IDLE);
        if (start) begin
          sclk_cntr <= 0;
          state <= CS_START;
        end
    endrule

    rule do_cs_start (state == CS_START);
        cs_cntr <= cs_cntr + 1;
        if (cs_cntr == 'h0f) begin
            state <= SHIFTING;
        end
        // Load the first word
        out_shifter <= unpack({pack(tx_buffer[0]), 1});
    endrule

    rule do_shift_out (state == SHIFTING && sclk_fedge);
        // Done with bytes?
        if (rem_bytes == 0) begin
            state <= CS_STOP;
            cs_cntr <= 0;
        end
        // Load data to be tx'd
        if (pack(out_shifter)[7:0] == 'h80) begin
            let head_data = tx_buffer[8-rem_bytes+1];
            out_shifter <= unpack({pack(head_data), 1});
            rem_bytes <= rem_bytes - 1;
        end else begin
            // On falling edge, shift until done (== 'h100).
            out_shifter <= shiftInAt0(out_shifter, 0);
        end

    endrule

    rule do_shift_in (state == SHIFTING && sclk_redge);
        if (in_shifter[8] == 1) begin
            rx_buffer[8-rem_bytes+1] <= pack(in_shifter)[7:0];
            in_shifter <= shiftInAt0(unpack('h01), cipo);
        end else begin
            in_shifter <= shiftInAt0(in_shifter, cipo);
        end
    endrule

    rule do_cs_stop (state == CS_STOP);
        if (cs_cntr == 'h0f) begin
            state <= IDLE;
            cs_cntr <= 0;
        end else begin
            cs_cntr <= cs_cntr + 1;
        end
    endrule

    interface SpiControllerPins pins;
        method Bit#(1) csn();  // CSN output
            return csn;
        endmethod
        method Bit#(1) sclk(); // sclk output
            return sclk;
        endmethod
        method Bit#(1) copi(); // data output
            return out_shifter[8];
        endmethod
        method Action cipo(Bit#(1) data);
            cipo <= data;
        endmethod
    endinterface

    interface Server bfm;
        interface Get response;
            method ActionValue#(Vector#(8, Bit#(8))) get() if (state == CS_STOP);
                return rx_buffer;
            endmethod

        endinterface

        interface Put request;
            method Action put(request) if (state == IDLE);
                tx_buffer <= request;
                rem_bytes <= 8;
                start.send();
            endmethod
        endinterface
    endinterface

endmodule

// Test bench
(* synthesize *)
module mkTestBenchSpiPhy(Empty);
    SPITestController controller <- mkSpiTestController();
    SpiDecodeIF decode <- mkSpiRegDecode();
    SpiPeriphPhyIF phy <- mkSpiPeriphPhy();
    Server#(RegRequest#(16, 8), RegResp#(8)) fake_reg <- mkTestRegResponder();
    
    mkConnection(decode.reg_con, fake_reg); // client-server interface between decoder and reg
    mkConnection(decode.spi_byte, phy.decoder_if); // client-server interface between phy and decoder
    // connect all the gpio pins
    mkConnection(phy.pins.csn, controller.pins.csn);
    mkConnection(phy.pins.cipo, controller.pins.cipo);
    mkConnection(phy.pins.copi, controller.pins.copi);
    mkConnection(phy.pins.sclk, controller.pins.sclk);


    mkAutoFSM(
        seq
            action
                Vector#(8, Bit#(8)) tx =  newVector();
                tx[0] = unpack(zeroExtend(pack(READ)));
                tx[1] = unpack('hBA);
                tx[2] = unpack('hBB);
                controller.bfm.request.put(tx);
            endaction
            action
                let rx <- controller.bfm.response.get();
                $display(rx[0]);
                $display(rx[1]);
                $display(rx[2]);
                $display(rx[3]);
                $display(rx[4]);
                $display(rx[5]);
                $display(rx[6]);
            endaction
        endseq
    );

endmodule
endpackage