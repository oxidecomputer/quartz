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

use work.spd_proxy_tb_pkg.all;
use work.i2c_ctrl_vc_pkg.all;
use work.i2c_target_vc_pkg.all;
use work.spd_proxy_regs_pkg.all;


entity spd_proxy_top_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of spd_proxy_top_tb is

begin

    th: entity work.spd_proxy_top_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        variable cmd : spd_cmd_type;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("sp_spd_short_read") then
                -- We want to use the new SPD interface via axi to issue
                -- a simple read to the DIMM as a starting point.
                -- Set up the buffer in the DIMM with a response
                write_word(memory(I2C_DIMM1_TGT_VC), 0, X"AA");
                write_word(memory(I2C_DIMM1_TGT_VC), 1, X"BB");
                write_word(memory(I2C_DIMM1_TGT_VC), 2, X"CC");
                -- Set up i2c command and issue it
                -- 3 byte read from spd and addr 0
                cmd :=(
                    op => "00", -- READ
                    bus_addr => address(I2C_DIMM1_TGT_VC),
                    reg_addr => X"00",
                    len => X"03"
                );
                write_bus(net, bus_handle, To_StdLogicVector(SPD_CMD_OFFSET, bus_handle.p_address_length), pack(cmd));
                wait for 60 us;
                -- Wait for the response
                -- check the response.
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