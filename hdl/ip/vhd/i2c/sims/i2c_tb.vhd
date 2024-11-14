-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright  Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.i2c_cmd_vc_pkg.all;
use work.i2c_peripheral_pkg.all;
use work.basic_stream_pkg.all;

entity i2c_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of i2c_tb is
    constant I2C_MEM        : memory_t          := new_memory;
    constant TX_DATA_SOURCE : basic_source_t    := new_basic_source(8);
    constant RX_DATA_SINK   : basic_sink_t      := new_basic_sink(8);
    constant I2C_PERIPHERAL : i2c_peripheral_t  := new_i2c_peripheral_vc("I2C_PERIPH", I2C_MEM);
    constant I2C_CMD        : i2c_cmd_vc_t      := new_i2c_cmd_vc;
begin

    th: entity work.i2c_th
        generic map (
            tx_source       => TX_DATA_SOURCE,
            rx_sink         => RX_DATA_SINK,
            i2c_peripheral  => I2C_PERIPHERAL,
            i2c_cmd_vc      => I2C_CMD
        );

    bench: process
        alias reset is << signal th.reset : std_logic >>;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("") then
                null;
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;