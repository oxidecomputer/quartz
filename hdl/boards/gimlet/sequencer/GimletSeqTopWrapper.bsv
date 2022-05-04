package GimletSeqTopWrapper;

import Clocks::*;

// Cobalt-provided stuff
import ICE40::*;

import GimletSeqTop::*;
import SPI::*;

interface SpiPeripheralPinsTop;
    (* prefix = "" *)
    method Action csn((* port = "csn" *) Bit#(1) value);   // Chip select pin, always sampled
    (* prefix = "" *)
    method Action sclk((* port = "sclk" *) Bit#(1) value);  // sclk pin, always sampled
    (* prefix = "" *)
    method Action copi((* port = "copi" *) Bit#(1) data);   // Input data pin sampled on appropriate sclk detected edge

    interface Inout#(Bit#(1)) cipo; // Output pin, tri-state when not selected.
endinterface

(* always_enabled *)
interface PinsTop;
    // SPI interface
    (* prefix = "" *)
    interface SpiPeripheralPinsTop spi_pins;
    (* prefix = "" *)
    interface SequencerInputPins in_pins;
    (* prefix = "" *)
    interface SeqOutputPins out_pins;
endinterface

//This is the top-level module for the Gimlet Sequencer FPGA.
(* synthesize, default_clock_osc="clk50m" *)
module mkGimletSeqTop (PinsTop);
    Clock cur_clk <- exposeCurrentClock();
    Reset reset_sync <- mkAsyncResetFromCR(2, cur_clk);
    let synth_params = GimletSeqTopParameters {one_ms_counts: 50000};    // 1ms @ 50MHz

    ICE40::Output#(Bit#(1)) cipo <- mkOutput(OutputTriState, False /* pull-up */);

    let inner <- mkGimletInnerTop(synth_params, reset_by reset_sync);

    rule test (inner.spi_pins.output_en);
        cipo <= inner.spi_pins.cipo;
    endrule

    interface SpiPeripheralPinsTop spi_pins;
        method csn = inner.spi_pins.csn;
        method sclk = inner.spi_pins.sclk;
        method copi = inner.spi_pins.copi;
        interface cipo = cipo.pad;
    endinterface
    interface SequencerInputPins in_pins = inner.in_pins;
    interface SeqOutputPins out_pins = inner.out_pins;

endmodule

endpackage