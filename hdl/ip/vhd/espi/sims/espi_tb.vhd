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
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.qspi_vc_pkg.all;
use work.espi_controller_vc_pkg.all;
use work.espi_base_types_pkg.all;
use work.espi_spec_regs_pkg.all;
use work.espi_dbg_vc_pkg.all;
use work.espi_tb_pkg.all;

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
        variable my_queue        : queue_t               := new_queue;
        variable cmd             : cmd_t;
        variable response        : resp_t := (queue => new_queue, num_bytes => 0, response_code => (others => '0'), status => (others => '0'), crc_ok => false);
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        
        -- shared variable in _tb_pkg
        rnd.InitSeed(rnd'instance_name);

        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until sim_reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("qspi_status_check") then
                get_status(net, response_code, status, crc_ok);
                check(crc_ok, "CRC Check failed");
                -- Expect the reset value of status here
                expected_status := pack(status_t'(rec_reset));
                check_equal(status, expected_status, "Status did not match reset value");
            elsif run("dbg_status_check") then
                enable_debug_mode(net);
                dbg_send_get_status_cmd(net);
                dbg_wait_for_done(net);
                dbg_get_response(net, 4, response);
                check(response.crc_ok, "CRC Check failed");
                expected_status := pack(status_t'(rec_reset));
                check_equal(response.status, expected_status, "Status did not match reset value");

                -- Do it a 2nd time
                dbg_send_get_status_cmd(net);
                dbg_wait_for_done(net);
                dbg_get_response(net, 4, response);
                check(response.crc_ok, "CRC Check failed");
                expected_status := pack(status_t'(rec_reset));
                check_equal(response.status, expected_status, "Status did not match reset value");
            elsif run("crc_enforcement") then
                enable_debug_mode(net);
                --Enable CRC enforcement
                cmd := build_set_config_cmd(GENERAL_CAPABILITIES_OFFSET, GENERAL_CAPABILITIES_CRC_EN_MASK);
                dbg_send_cmd(net, cmd);
                dbg_wait_for_done(net);
                dbg_get_response(net, 4, response);
                check(response.crc_ok, "CRC Check failed");
                expected_status := pack(status_t'(rec_reset));
                check_equal(response.status, expected_status, "Status did not match reset value");
                exp_data_32 := (others => '0');
                -- Should have an empty response queue
                read_bus(net, bus_handle, To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, exp_data_32, "Response queue not empty before bad crc command");

                -- Issue a command with a bad CRC
                dbg_send_get_status_cmd(net, bad_crc => true);
                dbg_wait_for_done(net);
                wait for 1 us;
                -- Expect no responses
                read_bus(net, bus_handle, To_StdLogicVector(FIFO_STATUS_OFFSET, bus_handle.p_address_length), data_32);
                exp_data_32 := (others => '0');
                check_equal(data_32, exp_data_32, "Expected no response to bad CRC command");

                -- dbg_get_response(net, 4, response);
                -- check(response.crc_ok, "CRC Check failed");
                -- expected_status := pack(status_t'(rec_reset));
                -- check_equal(response.status, expected_status, "Status did not match reset value");

                -- -- Do it a 2nd time
                -- dbg_send_get_status_cmd(net);
                -- dbg_wait_for_done(net);
                -- dbg_get_response(net, 4, response);
                -- check(response.crc_ok, "CRC Check failed");
                -- expected_status := pack(status_t'(rec_reset));
                -- check_equal(response.status, expected_status, "Status did not match reset value");
            elsif run("get_config") then
                get_config(net, GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
                check(crc_ok, "CRC Check failed");
                -- Expect matching data here
                exp_data_32 := pack(general_capabilities_type'(rec_reset));
                -- Expect the reset value of gen-cap here
                check_equal(data_32, exp_data_32, "General Capabilities did not match reset value");
                -- Expect the reset value of status here
                expected_status := pack(status_t'(rec_reset));
                check_equal(status, expected_status, "Status did not match reset value");
            elsif run("set_config") then
                get_config(net, GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
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
                set_config(net, GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
                exp_data_32 := data_32;
                wait for 100 ns;
                get_config(net, GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
                check(crc_ok, "CRC Check failed");
                -- Expect the reset value of gen-cap here
                check_equal(data_32, exp_data_32, "General Capabilities did not match expected value");
            elsif run("check_alert_works") then
                -- Enable the flash channel
                flash_cap_reg.flash_channel_enable := '1';
                set_config(net, CH3_CAPABILITIES_OFFSET, pack(flash_cap_reg), response_code, status,  crc_ok);

                -- Put a non-posted read request into the flash channel
                -- We expect something to happen here and the alert get set when the completion
                -- status is written back, so we check the crc here and then wait for the alert
                put_flash_read(net, X"00000000", 32, response_code, status,  crc_ok);
            --  check(crc_ok, "CRC Check failed");
            --  wait_for_alert;
            --  get_any_pending_alert(pending_alert);
            --  check(pending_alert, "Expected an alert to be pending");
            --  get_status(response_code, status,  crc_ok);
            --  check(pending_alert = false, "After get status, expected no alert to be pending");
            elsif run("read_flash") then
                -- Enable the flash channel
                flash_cap_reg.flash_channel_enable := '1';
                set_config(net, CH3_CAPABILITIES_OFFSET, pack(flash_cap_reg), response_code, status,  crc_ok);
                -- Put a non-posted read request into the flash channel
                -- We expect something to happen here and the alert get set when the completion
                -- status is written back, so we check the crc here and then wait for the alert
                put_flash_read(net, X"00000000", 32, response_code, status,  crc_ok);
                check(crc_ok, "CRC Check failed");
                wait_for_alert(net);

                get_flash_c(net, 32, my_queue, response_code, status,  crc_ok);
                -- TODO: the data's not coming back right.
                for i in 0 to 31 loop
                    report "Flash Byte: " & to_hstring(to_unsigned(pop_byte(my_queue), 8));
                end loop;

                -- would normally wait for the completion alert now
                wait for 300 us;
            elsif run("dbg_uart") then
                enable_debug_mode(net);
                -- Send UART data which will then be looped back and rx'd
                my_queue := build_rand_byte_queue(32);
                dbg_send_uart_data_cmd(net, my_queue);
                dbg_wait_for_done(net);
                -- 4 junk bytes at the top of the response for the accept of the command
                dbg_pop_resp_fifo(net, 1);  -- 32bit read = 4 bytes
                wait for 100 us; -- let uart data propagate
                dbg_wait_for_alert(net);
                -- technically we'd get status here, and if we supported completions we'd return it here
                -- response size is going to be 4 bytes for response_code/status/crc
                -- plus the payload which is 32 bytes + 4 header bytes
                -- bringing total to 40 bytes
                dbg_get_uart_data_cmd(net);
                dbg_wait_for_done(net);
                dbg_get_response(net, 40 , response);
                check(response.crc_ok, "CRC Check failed");
            end if;
        end loop;
        wait for 10 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 1 ms);

end tb;
