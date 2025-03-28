// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MinibarController;

// BSV
import Connectable::*;

// Oxide
import Blinky::*;
import SPI::*;

// Minibar
import MinibarSpiServer::*;

typedef struct {
    Integer system_frequency_hz;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {system_frequency_hz: 50_000_000};
endinstance

interface MinibarController;
    interface SpiPeripheralPins spi;
    interface Blinky#(50_000_000) blinky;
endinterface

module mkMinibarController#(Parameters parameters) (MinibarController);
    //
    // Blinky to show sign of life
    //
    Blinky#(50_000_000) blinky_inst <- Blinky::mkBlinky();

    //
    // SPI Peripheral
    //
    SpiPeripheralPhy spi_phy    <- mkSpiPeripheralPhy();
    SpiDecodeIF spi_decoder     <- mkSpiRegDecode();
    SpiServer spi_server        <- mkSpiServer();

    mkConnection(spi_phy.decoder_if, spi_decoder.spi_byte);
    mkConnection(spi_decoder.reg_con, spi_server);

    //
    // Interfaces to physical pins
    //
    interface SpiPeripheralPins spi = spi_phy.pins;
    interface blinky                = blinky_inst;
endmodule

endpackage: MinibarController