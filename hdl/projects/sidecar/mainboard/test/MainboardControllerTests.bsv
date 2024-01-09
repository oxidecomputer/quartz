package MainboardControllerTests;

import Connectable::*;
import DefaultValue::*;
import StmtFSM::*;

import TestUtils::*;

import PowerRail::*;
import SidecarMainboardController::*;
import SidecarMainboardControllerReg::*;


typedef MainboardController#(2) BenchMainboardController;

module mkFrontIOHSCTest (Empty);
    BenchMainboardController controller <- mkBenchMainboardController();
    PowerRailModel#(16) front_io_hsc <- mkPowerRailModel("FRONT_IO", True, 10);

    mkConnection(front_io_hsc.pins, controller.pins.front_io_hsc);

    mkAutoFSM(seq
        assert_false(
            front_io_hsc.state.enabled,
            "expected Front IO HSC disabled");

        // Repeat the power up sequence twice to make sure nothing gets stuck
        // after being disabled.
        repeat(2) seq
            controller.registers.front_io_hsc.enable <= 1;

            await(front_io_hsc.state.enabled);
            await(front_io_hsc.state.good);
            assert_set(
                controller.registers.front_io_hsc.enable,
                "expected enable bit to match power rail state");
            assert_set(
                controller.registers.front_io_hsc.good,
                "expected good bit to match power rail state");
            assert_eq(
                controller.registers.front_io_hsc.state,
                extend(pack(Enabled)),
                "expected state bits to match power rail state");

            controller.registers.front_io_hsc.enable <= 0;

            await(controller.registers.front_io_hsc.state == extend(pack(Disabled)));
            assert_false(
                front_io_hsc.state.enabled,
                "expected Front IO HSC disabled");
        endseq
    endseq);

    mkTestWatchdog(100);
endmodule

module mkBenchMainboardController (BenchMainboardController);
    Parameters parameters = defaultValue;

    (* hide *) BenchMainboardController _c <- mkMainboardController(parameters);
    return _c;
endmodule

endpackage
