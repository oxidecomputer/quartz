package SidecarMainboardControllerSpiServer;

import ClientServer::*;
import ConfigReg::*;
import Connectable::*;
import GetPut::*;

import RegCommon::*;
import SidecarMainboardControllerReg::*;
import Tofino2Sequencer::*;


typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;

typedef Server#(SpiRequest, SpiResponse) SpiServer;

module mkSpiServer #(Tofino2Sequencer tofino_sequencer) (SpiServer);
    Wire#(SpiRequest) spi_request <- mkDWire(SpiRequest{address: 0, wdata: 0, op: NOOP});
    Wire#(SpiResponse) spi_response <- mkWire();

    ConfigReg#(Scratchpad) scratchpad <- mkConfigReg(unpack('0));

    (* fire_when_enabled *)
    rule do_spi_read (spi_request.op == READ);
        spi_response <= SpiResponse{readdata:
            case (spi_request.address)
                fromInteger(id0Offset): 'h01;
                fromInteger(id1Offset): 'hde;
                fromInteger(id2Offset): 'haa;
                fromInteger(id3Offset): 'h55;
                fromInteger(scratchpadOffset): pack(scratchpad);
                fromInteger(tofinoSeqCtrlOffset): pack(tofino_sequencer.registers.ctrl);
                fromInteger(tofinoSeqStateOffset): pack(tofino_sequencer.registers.state);
                fromInteger(tofinoSeqStepOffset): pack(tofino_sequencer.registers.step);
                fromInteger(tofinoSeqErrorOffset): pack(tofino_sequencer.registers.error);
                fromInteger(tofinoPowerEnableOffset): pack(tofino_sequencer.registers.power_enable);
                fromInteger(tofinoPowerGoodOffset): pack(tofino_sequencer.registers.power_good);
                fromInteger(tofinoPowerFaultOffset): pack(tofino_sequencer.registers.power_fault);
                fromInteger(tofinoPowerVrhotOffset): pack(tofino_sequencer.registers.power_vrhot);
                fromInteger(tofinoPowerVidOffset): pack(tofino_sequencer.registers.vid);
                fromInteger(tofinoResetOffset): pack(tofino_sequencer.registers.tofino_reset);
                fromInteger(tofinoMiscOffset): pack(tofino_sequencer.registers.misc);
                default: 'hff;
            endcase};
    endrule

    // Helper which adds a rule updating the provided register if a SPI request
    // matches the given address.
    function Rules do_spi_write(ConfigReg#(t) r, Integer address)
            provisos (
                Bits#(t, sz),
                Add#(sz, a__, 8));
        return (rules
                (* fire_when_enabled *)
                rule do_spi_write (fromInteger(address) == spi_request.address);
                    // Make `v` and `wdata` equal length.
                    let r_bits = zeroExtend(pack(r));
                    let wdata_bits = pack(spi_request.wdata);

                    case (spi_request.op)
                        WRITE: r <= unpack(truncate(wdata_bits));
                        BITSET: r <= unpack(truncate(wdata_bits | r_bits));
                        BITCLEAR: r <= unpack(truncate(~wdata_bits & r_bits));
                    endcase
                endrule
            endrules);
    endfunction

    // Update registers on SPI requests.
    addRules(do_spi_write(scratchpad, scratchpadOffset));
    addRules(do_spi_write(tofino_sequencer.registers.ctrl, tofinoSeqCtrlOffset));

    interface Put request = toPut(asIfc(spi_request));
    interface Put response = toGet(asIfc(spi_response));
endmodule

endpackage
