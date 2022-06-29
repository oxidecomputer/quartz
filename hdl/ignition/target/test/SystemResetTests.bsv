package SystemResetTests;

import Assert::*;
import StmtFSM::*;

import IgnitionTarget::*;
import TestUtils::*;


(* synthesize *)
module mkSystemResetShortButtonPressTest (Empty);
    // Shorten the duration and cool down to avoid long sim times.
    let reset_button_min_duration = 4;
    let reset_button_cool_down = 2;

    Parameters parameters = default_app_with_button_as_reset;
    parameters.button_behavior =
        tagged ResetButton {
            min_duration: reset_button_min_duration,
            cool_down: reset_button_cool_down};

    IgnitionTargetBench bench <- mkIgnitionTargetBench(parameters, 0);

    mkAutoFSM(
        seq
            dynamicAssert(bench.system_powered_on, "expected system power on");

            // Power off the system and assert the system powered off.
            bench.press_button();
            // Wait for the next tick. Technically we need only a single delay
            // cycle here.
            await(bench.target.tick_1khz);
            action
                dynamicAssert(bench.system_powered_off, "expected system power off");
                bench.reset_ticks_elapsed();
            endaction

            // Almost immediately release the button.
            bench.release_button();

            // Wait for system power on and confirm the minimum reset duration.
            await(bench.system_powered_on);
            dynamicAssert(
                bench.ticks_elapsed == fromInteger(reset_button_min_duration),
                "expected system power off for 4 ticks");
        endseq);

    mkTestWatchdog(25);
endmodule

(* synthesize *)
module mkSystemResetLongButtonPressTest (Empty);
    // Shorten the duration and cool down to avoid long sim times.
    let reset_button_min_duration = 4;
    let reset_button_cool_down = 2;

    Parameters parameters = default_app_with_button_as_reset;
    parameters.button_behavior =
        tagged ResetButton {
            min_duration: reset_button_min_duration,
            cool_down: reset_button_cool_down};

    IgnitionTargetBench bench <- mkIgnitionTargetBench(parameters, 0);

    mkAutoFSM(
        seq
            dynamicAssert(bench.system_powered_on, "expected system power on");

            // Power off the system and assert the system powered off.
            bench.press_button();
            // Wait for the next tick. Technically we need only a single delay
            // cycle here.
            await(bench.target.tick_1khz);
            action
                dynamicAssert(bench.system_powered_off, "expected system power off");
                bench.reset_ticks_elapsed();
            endaction

            // Keep the button pressed until the minimum duration has elapsed.
            await(bench.ticks_elapsed > fromInteger(reset_button_min_duration));
            bench.release_button();

            // Expect the system to be powered on after the next tick.
            await(bench.target.tick_1khz);
            dynamicAssert(bench.system_powered_on, "expected system power on");
        endseq);

    mkTestWatchdog(30);
endmodule

endpackage