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
import PowerRail::*;
import SPI::*;

// Minibar
import MinibarSpiServer::*;

// Parameters used to configure various things within the design
// system_frequency_hz      - main clock domain for the design
// power_good_timeout_ms    - how long to wait for PG on the PHY rails before
//                            aborting
typedef struct {
    Integer system_frequency_hz;
    Integer power_good_timeout_ms;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        system_frequency_hz: 50_000_000,
        power_good_timeout_ms: 25 // arbitrarily chosen
    };
endinstance

interface MinibarController;
    interface MinibarSpiServer::MinibarTopRegs top_regs;
    interface Blinky#(50_000_000) blinky;
    interface PowerRail::Pins v12_pcie;
    interface PowerRail::Pins v3p3_pcie;
    interface PowerRail::Pins vbus_sled;
    interface SpiPeripheralPins spi;
endinterface

module mkMinibarController#(Parameters parameters) (MinibarController);
    //
    // Blinky to show sign of life
    //
    Blinky#(50_000_000) blinky_inst <- Blinky::mkBlinky();

    //
    // Power Rails under FPGA control
    //
    PowerRail#(8) v12_rail  <- mkPowerRailDisableOnAbort(parameters.power_good_timeout_ms);
    PowerRail#(8) v3p3_rail <- mkPowerRailDisableOnAbort(parameters.power_good_timeout_ms);
    PowerRail#(8) vbus_rail <- mkPowerRailDisableOnAbort(parameters.power_good_timeout_ms);

    //
    // SPI Peripheral
    //
    SpiPeripheralPhy spi_phy    <- mkSpiPeripheralPhy();
    SpiDecodeIF spi_decoder     <- mkSpiRegDecode();
    MinibarSpiServer spi_server <- mkSpiServer();

    mkConnection(spi_phy.decoder_if, spi_decoder.spi_byte);
    mkConnection(spi_decoder.reg_con, spi_server.spi_if);

    //
    // Interfaces to physical pins
    //
    interface MinibarSpiServer::MinibarTopRegs top_regs = spi_server.top_regs;
    interface blinky                    = blinky_inst;
    interface PowerRail::Pins v12_pcie  = v12_rail.pins;
    interface PowerRail::Pins v3p3_pcie = v3p3_rail.pins;
    interface PowerRail::Pins vbus_sled = vbus_rail.pins;
    interface SpiPeripheralPins spi     = spi_phy.pins;
endmodule

endpackage: MinibarController