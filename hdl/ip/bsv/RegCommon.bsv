// This module will take spi bytes via a server interface
// And pass out requests via a client interface.

package RegCommon;

import GetPut::*;
import ClientServer::*;
import Connectable::*;


typedef enum {
    // Sequential write where SPI peripheral increments the address
    // automatically after each word.
    WRITE,
    // Sequential write where SPI peripheral increments the address
    // automatically after each word.
    READ,
    // Bitwise logical OR a payload into a destination register, making sure any
    // bits set in the payload get set in the destination.
    BITSET,
    // Bitwise logical AND and inverse payload into a target register, making
    // sure any bits set in the payload get cleared in the destination.
    BITCLEAR,
    // No operation.
    NOOP,
    // Sequential write where the SPI peripheral does not increment the address
    // after each word. This is useful when writing into a FIFO where the full
    // contents need not be addressed in parallel.
    WRITE_NO_ADDR_INCR,
    // Sequential read where the SPI peripheral does not increment the address
    // after each word. This is useful when writing into a FIFO where the full
    // contents need not be addressed in parallel.
    READ_NO_ADDR_INCR
} RegOps deriving (Eq, Bits);

typedef struct {
   Bit#(addrWidth) address;
   Bit#(dataWidth) wdata;
   RegOps   op;
} RegRequest#(numeric type addrWidth, numeric type dataWidth) deriving (Bits);

typedef struct {
   Bit#(dataWidth) readdata;
} RegResp#(numeric type dataWidth) deriving (Bits);

// This function deals with the write, bitset, bitclear etc
// TODO, would like to better deal with software enables etc or generate this whole thing
function treg reg_update(
        treg current_value,
        treg next_value,
        taddr address,
        Integer my_address,
        RegOps operation,
        Bit#(bitSize) writedata)
    provisos(
        Bits#(treg, bitSize),
        Eq#(taddr),
        Literal#(taddr),
        Bits#(taddr, addrSize)
    );
    let reg_out = current_value;  // Default to hold current value
    if (address == fromInteger(my_address)) begin
        if (operation == WRITE || operation == WRITE_NO_ADDR_INCR) begin
            reg_out = unpack(writedata);
        end else if (operation == BITSET) begin
            reg_out = unpack(writedata | pack(current_value));
        end else if  (operation == BITCLEAR) begin
            reg_out = unpack(~writedata & pack(current_value));
        end else begin
            reg_out = next_value;
        end
    end else begin
        reg_out = next_value;
    end
        return reg_out;
endfunction

endpackage
