-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
use work.qspi_vc_pkg.all;
use work.espi_controller_vc_pkg.all;
use work.espi_base_types_pkg.all;
use work.espi_regs_pkg.all;

entity espi_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of espi_tb is

begin

    th: entity work.espi_th;

    bench: process
        alias    sim_reset       is <<signal th.reset : std_logic>>;
        variable msg_target      : actor_t;
        variable status          : std_logic_vector(15 downto 0);
        variable response_code   : std_logic_vector(7 downto 0);
        variable expected_status : std_logic_vector(15 downto 0);
        variable data_32         : std_logic_vector(31 downto 0);
        variable exp_data_32     : std_logic_vector(31 downto 0);
        variable crc_ok          : boolean;
        variable pending_alert   : boolean;
        variable flash_cap_reg   : ch3_capabilities_type := rec_reset;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);

        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until sim_reset = '0';

        while test_suite loop
            if run("status_check") then
                get_status(response_code, status,  crc_ok);
                check(crc_ok, "CRC Check failed");
                -- Expect the reset value of status here
                expected_status := pack(status_t'(rec_reset));
                check_equal(status, expected_status, "Status did not match reset value");
            elsif run("get_config") then
                get_config(GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
                check(crc_ok, "CRC Check failed");
                -- Expect matching data here
                exp_data_32 := pack(general_capabilities_type'(rec_reset));
                -- Expect the reset value of gen-cap here
                check_equal(data_32, exp_data_32, "General Capabilities did not match reset value");
                -- Expect the reset value of status here
                expected_status := pack(status_t'(rec_reset));
                check_equal(status, expected_status, "Status did not match reset value");
            elsif run("set_config") then
                get_config(GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
                check(crc_ok, "CRC Check failed");
                -- Expect matching data here
                exp_data_32 := pack(general_capabilities_type'(rec_reset));
                -- Expect the reset value of gen-cap here
                check_equal(data_32, exp_data_32, "General Capabilities did not match reset value");
                -- Expect the reset value of status here
                expected_status := pack(status_t'(rec_reset));
                check_equal(status, expected_status, "Status did not match reset value");
                check(data_32(31) = '0', "CRC Checking Enable bit was not 0");
                -- Now set the CRC Checking Enable bit to 1
                data_32(31) := '1'; -- alter state
                wait for 100 ns;
                set_config(GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
                exp_data_32 := data_32;
                wait for 100 ns;
                get_config(GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
                check(crc_ok, "CRC Check failed");
                -- Expect the reset value of gen-cap here
                check_equal(data_32, exp_data_32, "General Capabilities did not match expected value");
            elsif run("check_alert_works") then
                 -- Enable the flash channel
                 flash_cap_reg.flash_channel_enable := '1';
                 set_config(CH3_CAPABILITIES_OFFSET, pack(flash_cap_reg), response_code, status,  crc_ok);
     
                 -- Put a non-posted read request into the flash channel
                 -- We expect something to happen here and the alert get set when the completion
                 -- status is written back, so we check the crc here and then wait for the alert
                put_flash_read(X"00000000", 32, response_code, status,  crc_ok);
                --  check(crc_ok, "CRC Check failed");
                --  wait_for_alert;
                --  get_any_pending_alert(pending_alert);
                --  check(pending_alert, "Expected an alert to be pending");
                --  get_status(response_code, status,  crc_ok);
                --  check(pending_alert = false, "After get status, expected no alert to be pending");
            elsif run("read_flash") then
                -- Enable the flash channel
                flash_cap_reg.flash_channel_enable := '1';
                set_config(CH3_CAPABILITIES_OFFSET, pack(flash_cap_reg), response_code, status,  crc_ok);
                -- Put a non-posted read request into the flash channel
                -- We expect something to happen here and the alert get set when the completion
                -- status is written back, so we check the crc here and then wait for the alert
                put_flash_read(X"00000000", 32, response_code, status,  crc_ok);
                check(crc_ok, "CRC Check failed");
                wait_for_alert;

                -- would normally wait for the completion alert now
                wait for 300 us;
            end if;
        end loop;
        wait for 10 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;
