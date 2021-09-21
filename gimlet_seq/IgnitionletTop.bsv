package IgnitionletTop;
// BSV library imports
import ClientServer::*;
import Connectable::*;
import GetPut::*;
// Oxide and local imports
import Regs::*;
import SpiDecode::*;


(* always_enabled *)
interface Top;
    (* prefix = "" *)
    interface SpiPeriphPins pins;
    (* prefix = "" *)
    method Bit#(1) led1();
    method Bit#(1) led2();
endinterface

(* synthesize, default_clock_osc="clk_50mhz" *)
module mkIgnitionletTop(Top);
    SpiPeriphPhyIF phy <- mkSpiPeriphPhy();
    SpiDecodeIF decode <- mkSpiRegDecode();
    RegIF regs <- mkRegResponder();

    //Synchronizers
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
    
    interface SpiPeriphPins pins;
        // Chip select pin, always sampled
        method Action csn(Bit#(1) value);
            csn_sync <= value;
        endmethod
        method Action sclk(Bit#(1) value);  // sclk pin, always sampled
            sclk_sync <= value;
        endmethod
        method Action copi(Bit#(1) data);
            copi_sync <= data;
        endmethod
        method cipo = phy.pins.cipo;
    endinterface
    method led1 = regs.led0;
    method led2 = regs.led1;

endmodule


endpackage