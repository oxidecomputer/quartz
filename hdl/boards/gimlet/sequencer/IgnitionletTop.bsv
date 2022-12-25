package IgnitionletTop;
// BSV library imports
import ClientServer::*;
import Connectable::*;
import GetPut::*;
// Oxide and local imports
import Regs::*;
import SPI::*;


(* always_enabled *)
interface Top;
    (* prefix = "" *) // <- this is fine and does something
    interface SpiPeripheralPins pins;
    (* prefix = "" *) // <- This does nothing and is redundant
    method Bit#(1) led1();
    method Bit#(1) led2();
endinterface

(* default_clock_osc="clk_50mhz" *)
module mkIgnitionletTop(Top);
    SpiPeripheralPhy phy <- mkSpiPeripheralPhy();
    SpiDecodeIF decode <- mkSpiRegDecode();
    RegIF regs <- mkRegResponder();

    // use longer names.
    // Don't postfix interfaces with IF/IFC doesn't add much value
    // Top level interfaces want (* always_enabled *) only applies to inputs and the outputs imply *always_ready*

    // Synchronizers
    Reg#(Bit#(1)) csn_sync  <- mkReg(1);
    Reg#(Bit#(1)) sclk_sync <- mkReg(1);
    Reg#(Bit#(1)) copi_sync <- mkReg(1);

    mkConnection(decode.reg_con, regs.decoder_if);  // client-server interface between decoder and reg
    mkConnection(decode.spi_byte, phy.decoder_if);  // client-server interface between phy and decoder

    // Synchronizer hack for now
    mkConnection(copi_sync, phy.pins.copi);
    mkConnection(sclk_sync, phy.pins.sclk);
    mkConnection(csn_sync, phy.pins.csn);
    // connect all the gpio pins

    interface SpiPeripheralPins pins;
        // Inputs
        method csn = csn_sync._write;  // Bind action method to _write
        method sclk = sclk_sync._write;
        method copi = copi_sync._write;
        // Outputs
        method cipo = phy.pins.cipo;
    endinterface
    method led1 = regs.led0; // <- This is implicitly calling the _read()
    method led2 = regs.led1;

endmodule


endpackage