-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.i2c_ctrl_vc_pkg.all;

entity i2c_target_phy_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of i2c_target_phy_tb is

begin

    th: entity work.i2c_target_phy_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        variable tx_queue        : queue_t               := new_queue;
        variable ack_queue     : queue_t               := new_queue;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            -- this is a super-basic test that is basically made for visual verification
            -- of the i2c_target_phy module and the simulated controller we built.
            -- much more exhaustive testing will be done test benches for the 
            -- in the consumers of this module
            -- I used this to boot-strap basic functionality, more could be done here if we
            -- want or need to do more
            if run("test_dummy_i2c_write") then
                push_byte(tx_queue, to_integer(std_logic_vector'(8x"55")));
                i2c_write_txn(net, 7x"55", tx_queue, ack_queue);
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;