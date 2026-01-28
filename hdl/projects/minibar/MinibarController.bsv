// Copyright 2025 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package MinibarController;

// BSV
import Connectable::*;
import Vector::*;

// Oxide
import Blinky::*;
import IgnitionController::*;
import PowerRail::*;
import SPI::*;
import Strobe::*;

// Minibar
import MinibarMiscRegs::*;
import MinibarPcie::*;
import MinibarSpiServer::*;

// Parameters used to configure various things within the design
// system_frequency_hz  - main clock domain for the design
// vbus_pg_timeout_ms   - how long to wait for PG on the VBUS rail before aborting
// pcie_pg_timeout_ms   -- how long to wait for PG on the PCIE rails before aborting
//
typedef struct {
    Integer system_frequency_hz;
    Integer vbus_pg_timeout_ms;
    Integer pcie_pg_timeout_ms;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {
        system_frequency_hz: 50_000_000,
        vbus_pg_timeout_ms: 500, // arbitrarily chosen
        pcie_pg_timeout_ms: 25  // arbitrarily chosen
    };
endinstance

interface MinibarController;
    interface Blinky#(50_000_000) blinky;
    interface MinibarMiscRegs::Pins misc;
    interface MinibarPcie::Pins pcie;
    interface SpiPeripheralPins spi;
    interface Vector#(2, Controller) ignition_controllers;
endinterface

module mkMinibarController#(Parameters parameters) (MinibarController);
    //
    // Blinky to show sign of life
    //
    Blinky#(50_000_000) blinky_inst <- Blinky::mkBlinky();

    //
    // Useful timers for the rest of the design
    //
    Strobe#(20) tick_1khz   <-
        mkLimitStrobe(1, parameters.system_frequency_hz / 1_000, 0);
    mkFreeRunningStrobe(tick_1khz);

    Strobe#(6) tick_1mhz <-
        mkLimitStrobe(1, (parameters.system_frequency_hz / 1_000_000), 0);
    mkFreeRunningStrobe(tick_1mhz);

    //
    // A collection of miscellaneous registers we wrap up in a single module
    //
    MinibarMiscRegs misc_regs <- mkMinibarMiscRegs(parameters.vbus_pg_timeout_ms);
    mkConnection(asIfc(tick_1khz), asIfc(misc_regs.tick_1ms));

    //
    // A block to support the operations and test sled<->CEM PCIe
    //
    MinibarPcie pcie_ <- mkMinibarPcie(parameters.pcie_pg_timeout_ms);
    mkConnection(asIfc(tick_1khz), asIfc(pcie_.tick_1ms));
    mkConnection(asIfc(tick_1mhz), asIfc(pcie_.tick_1us));
    mkConnection(misc_regs.pcie_connector_present, pcie_.sled_present);

    //
    // Ignition Controllers
    //
    Vector#(2, IgnitionController::Controller)
        ignition_controllers_ <- replicateM(mkController(defaultValue));
    mkConnection(asIfc(tick_1khz), asIfc(ignition_controllers_[0].tick_1khz));
    mkConnection(asIfc(tick_1khz), asIfc(ignition_controllers_[1].tick_1khz));
    mkConnection(ignition_controllers_[0].status().target_present, misc_regs.ignition_target0_present);
    mkConnection(ignition_controllers_[1].status().target_present, misc_regs.ignition_target1_present);

    //
    // SPI Peripheral
    //
    SpiPeripheralPhy spi_phy    <- mkSpiPeripheralPhy();
    SpiDecodeIF spi_decoder     <- mkSpiRegDecode();
    SpiServer spi_server        <- mkSpiServer(
        misc_regs.registers,
        pcie_.registers,
        register_pages(ignition_controllers_));

    mkConnection(spi_phy.decoder_if, spi_decoder.spi_byte);
    mkConnection(spi_decoder.reg_con, spi_server);

    //
    // Interfaces to physical pins
    //
    interface blinky                    = blinky_inst;
    interface misc                      = misc_regs.pins;
    interface pcie                      = pcie_.pins;
    interface SpiPeripheralPins spi     = spi_phy.pins;
    interface Vector ignition_controllers = ignition_controllers_;
endmodule

endpackage: MinibarController