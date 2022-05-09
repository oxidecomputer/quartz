// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package QsfpX32Controller;

import Connectable::*;
import DefaultValue::*;
import Vector::*;

import Blinky::*;
import PowerRail::*;
import SPI::*;
import Strobe::*;

import QsfpModulesTop::*;
import QsfpX32ControllerSpiServer::*;
import QsfpX32ControllerTopRegs::*;
import VSC8562::*;

typedef struct {
    Integer system_frequency_hz;
} Parameters;

instance DefaultValue#(Parameters);
    defaultValue = Parameters {system_frequency_hz: 50_000_000};
endinstance

interface QsfpX32Controller;
    interface SpiPeripheralPins spi;
    interface VSC8562::Pins vsc8562;
    interface Vector#(16, QsfpModuleController::Pins) qsfp;
    interface Blinky#(50_000_000) blinky;
    interface QsfpX32ControllerTopRegs::Pins top;
endinterface

module mkQsfpX32Controller #(Parameters parameters) (QsfpX32Controller);
    //
    // Blinky to show sign of life
    //
    Blinky#(50_000_000) blinky_inst <- Blinky::mkBlinky();

    //
    // Useful timers for the rest of the design
    //
    Strobe#(20) tick_1khz   <-
        mkLimitStrobe(1, parameters.system_frequency_hz / 1000, 0);
    mkFreeRunningStrobe(tick_1khz);

    //
    // Registers for interesting top-level signals
    //
    QsfpX32ControllerTopRegs top_regs_inst  <- mkQsfpX32ControllerTopRegs();

    //
    // PHY
    //
    VSC8562 vsc8562_phy     <- mkVSC8562(defaultValue);
    mkConnection(asIfc(tick_1khz), asIfc(vsc8562_phy.tick_1ms));

    //
    // QSFP Ports
    //

    QsfpModulesTop qsfp_top   <- mkQsfpModulesTop(defaultValue);

    //
    // SPI Peripheral
    //

    SpiPeripheralPhy spi_phy    <- mkSpiPeripheralPhy();
    SpiDecodeIF spi_decoder     <- mkSpiRegDecode();
    SpiServer spi_server        <-
        mkSpiServer(vsc8562_phy.registers,
            top_regs_inst.registers,
            qsfp_top.registers);

    mkConnection(spi_phy.decoder_if, spi_decoder.spi_byte);
    mkConnection(spi_decoder.reg_con, spi_server);

    //
    // Interfaces
    //
    interface SpiPeripheralPins spi = spi_phy.pins;
    interface VSC8562::Pins vsc8562 = vsc8562_phy.pins;
    interface qsfp                  = qsfp_top.module_pins;
    interface blinky                = blinky_inst;
    interface QsfpX32ControllerTopRegs::Pins top = top_regs_inst.pins;
endmodule


endpackage: QsfpX32Controller