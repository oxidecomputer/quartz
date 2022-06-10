package SidecarMainboardControllerSpiServer;

import ClientServer::*;
import ConfigReg::*;
import Connectable::*;
import GetPut::*;

import PCIeEndpointController::*;
import RegCommon::*;
import SidecarMainboardControllerReg::*;
import Tofino2Sequencer::*;


typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;

typedef Server#(SpiRequest, SpiResponse) SpiServer;

module mkSpiServer
        #(Tofino2Sequencer::Registers tofino,
            PCIeEndpointController::Registers pcie) (SpiServer);
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
                fromInteger(tofinoSeqCtrlOffset): pack(tofino.ctrl);
                fromInteger(tofinoSeqStateOffset): pack(tofino.state);
                fromInteger(tofinoSeqStepOffset): pack(tofino.step);
                fromInteger(tofinoSeqErrorOffset): pack(tofino.error);
                fromInteger(tofinoPowerEnableOffset): pack(tofino.power_enable);
                fromInteger(tofinoPowerGoodOffset): pack(tofino.power_good);
                fromInteger(tofinoPowerFaultOffset): pack(tofino.power_fault);
                fromInteger(tofinoPowerVrhotOffset): pack(tofino.power_vrhot);
                fromInteger(tofinoPowerVidOffset): pack(tofino.vid);
                fromInteger(tofinoResetOffset): pack(tofino.tofino_reset);
                fromInteger(tofinoMiscOffset): pack(tofino.misc);
                fromInteger(pcieHotplugCtrlOffset): pack(pcie.ctrl);
                fromInteger(pcieHotplugStatusOffset): pack(pcie.status);
                default: 'hff;
            endcase};
    endrule

    // Helper which adds a rule updating the provided register if a SPI request
    // matches the given address.
    function Rules do_spi_write(Integer address, ConfigReg#(t) r)
            provisos (
                Bits#(t, sz),
                // Make sure the register type is <= 8 bits in width.
                Add#(sz, x, 8));
        return (rules
                (* fire_when_enabled *)
                rule do_spi_write (fromInteger(address) == spi_request.address);
                    // Make `r` and `wdata` equal length.
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
    addRules(do_spi_write(scratchpadOffset, scratchpad));
    addRules(do_spi_write(tofinoSeqCtrlOffset, tofino.ctrl));
    addRules(do_spi_write(pcieHotplugCtrlOffset, pcie.ctrl));

    interface Put request = toPut(asIfc(spi_request));
    interface Put response = toGet(asIfc(spi_response));
endmodule

endpackage
