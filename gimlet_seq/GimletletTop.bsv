package SpiRegsTop;

import GetPut::*;
import ClientServer::*;
import Connectable::*;

import RegCommon::*;
import SpiPeriph::*;
import SpiDecode::*;

// This interface needs the physical spi pins, and the client interface
// Out to the register block

interface SpiTop
    method Action csn(Bit#(1) value);   // Chip select pin, always sampled
    method Action sclk(Bit#(1) value);  // sclk pin, always sampled
    method Action mosi(Bit#(1) data);   // Input data pin sampled on appropriate sclk detected edge
    method Bit#(1) miso; // Output pin, always valid, shifts on appropriate sclk detected edge