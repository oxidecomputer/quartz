-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

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
use work.espi_regs_pkg;
use work.espi_dbg_vc_pkg.all;
use work.espi_tb_pkg.all;
use work.sp5_post_code_pkg.all;

entity espi_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of espi_tb is

    -- One entry per link configuration exercised by the sweeps below. The
    -- target and the controller VC have to be told separately: the target via
    -- SET_CONFIGURATION, the VC through its own API. `qspi_mode_t` is declared
    -- in both qspi_vc_pkg and espi_base_types_pkg, so it needs qualifying.
    type link_cfg_t is record
        io_mode  : work.qspi_vc_pkg.qspi_mode_t;
        mode_sel : general_capabilities_io_mode_sel;
        freq_sel : general_capabilities_op_freq_select;
        period   : time;
    end record;

    type link_cfg_array_t is array (natural range <>) of link_cfg_t;

    -- Every mode against every frequency the spec defines. 33 and 66MHz are
    -- 30.303ns and 15.152ns respectively; rounded to the nearest ns here,
    -- which errs slightly fast and so is the harsher test.
    constant all_link_cfgs : link_cfg_array_t := (
        (single, SINGLE, TWENTY,      50 ns),
        (single, SINGLE, TWENTYFIVE,  40 ns),
        (single, SINGLE, THIRTYTHREE, 30 ns),
        (single, SINGLE, FIFTY,       20 ns),
        (single, SINGLE, SIXTYSIX,    15 ns),
        (dual,   DUAL,   TWENTY,      50 ns),
        (dual,   DUAL,   TWENTYFIVE,  40 ns),
        (dual,   DUAL,   THIRTYTHREE, 30 ns),
        (dual,   DUAL,   FIFTY,       20 ns),
        (dual,   DUAL,   SIXTYSIX,    15 ns),
        (quad,   QUAD,   TWENTY,      50 ns),
        (quad,   QUAD,   TWENTYFIVE,  40 ns),
        (quad,   QUAD,   THIRTYTHREE, 30 ns),
        (quad,   QUAD,   FIFTY,       20 ns),
        (quad,   QUAD,   SIXTYSIX,    15 ns)
    );

    function cfg_name (constant cfg : link_cfg_t) return string is
    begin
        return general_capabilities_io_mode_sel'image(cfg.mode_sel) & "/" &
               general_capabilities_op_freq_select'image(cfg.freq_sel);
    end function;

    type cfg_results_t is array (all_link_cfgs'range) of boolean;

    -- Report every configuration, then fail once at the end. A sweep that
    -- halted on the first bad configuration would only ever tell us about one
    -- of the fifteen, which is not enough to see where the margin actually
    -- sits. Warnings do not trip VUnit's stop level, so the whole matrix makes
    -- it into the log either way.
    procedure report_sweep (
        constant sweep_name : string;
        constant results    : cfg_results_t
    ) is
        variable n_failed : natural := 0;
    begin
        for i in results'range loop
            if results(i) then
                info(sweep_name & ": pass at " & cfg_name(all_link_cfgs(i)));
            else
                n_failed := n_failed + 1;
                warning(sweep_name & ": FAIL at " & cfg_name(all_link_cfgs(i)));
            end if;
        end loop;
        check_equal(n_failed, 0,
                    sweep_name & ": " & integer'image(n_failed) & " of " &
                    integer'image(results'length) & " configurations failed");
    end procedure;

    -- Move both ends of the link to `cfg`. Order matters: the target latches
    -- the I/O mode at chip select, so the response to the SET_CONFIGURATION
    -- that changes the mode still comes back in the old one. The VC may only
    -- switch after that transaction has completed.
    --
    -- Reports success rather than checking, so a sweep can carry on past a
    -- configuration that does not work. Note the link stays in sync even when
    -- this reports failure: too few wait states corrupts the target's
    -- *response*, not the command, so the register write always lands.
    procedure set_link_cfg (
        signal net   : inout network_t;
        constant cfg : link_cfg_t;
        variable ok  : out boolean
    ) is
        variable vc_actor      : actor_t := find("espi_vc");
        variable gen_cap       : general_capabilities_type;
        variable data          : std_logic_vector(31 downto 0);
        variable response_code : std_logic_vector(7 downto 0);
        variable status        : std_logic_vector(15 downto 0);
        variable crc_ok        : boolean;
        variable all_ok        : boolean := true;
    begin
        get_config(net, GENERAL_CAPABILITIES_OFFSET, data, response_code, status, crc_ok);
        all_ok                 := all_ok and crc_ok;
        gen_cap                := unpack(data);
        gen_cap.io_mode_sel    := cfg.mode_sel;
        gen_cap.op_freq_select := cfg.freq_sel;
        set_config(net, GENERAL_CAPABILITIES_OFFSET, pack(gen_cap), response_code, status, crc_ok);
        all_ok                 := all_ok and crc_ok;

        set_mode(net, vc_actor, cfg.io_mode);
        set_sclk_period(net, vc_actor, cfg.period);
        wait for 1 us;
        ok := all_ok;
    end procedure;

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
        variable status_rec      : status_t;
        variable cmd             : cmd_t;
        variable gen_int         : integer;
        variable payload_size    : integer;
        variable response        : resp_t := (queue => new_queue, num_bytes => 0, response_code => (others => '0'), status => (others => '0'), crc_ok => false);
        variable pcfree_deasserted : boolean;
        variable cfg_ok          : boolean;
        variable transition_ok   : boolean;
        variable sweep_results   : cfg_results_t;
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
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.STATUS_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, exp_data_32, "Response queue not empty before bad crc command");

                -- Issue a command with a bad CRC
                dbg_send_get_status_cmd(net, bad_crc => true);
                dbg_wait_for_done(net);
                wait for 1 us;
                -- Expect no responses
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.FIFO_STATUS_OFFSET, bus_handle.p_address_length), data_32);
                exp_data_32 := (others => '0');
                check_equal(data_32, exp_data_32, "Expected no response to bad CRC command");

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
                -- exp_data_32 := data_32;
                -- wait for 100 ns;
                -- get_config(net, GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status,  crc_ok);
                -- check(crc_ok, "CRC Check failed");
                -- -- Expect the reset value of gen-cap here
                -- check_equal(data_32, exp_data_32, "General Capabilities did not match expected value");
            elsif run("check_alert_works") then
                -- Enable the flash channel
                flash_cap_reg.flash_channel_enable := '1';
                set_config(net, CH3_CAPABILITIES_OFFSET, pack(flash_cap_reg), response_code, status,  crc_ok);

                -- Put a non-posted read request into the flash channel
                -- We expect something to happen here and the alert get set when the completion
                -- status is written back, so we check the crc here and then wait for the alert
                put_flash_read(net, X"00000000", 32, response_code, status,  crc_ok);
                wait_for_alert(net);
            elsif run("read_flash") then
                -- Enable the flash channel
                flash_cap_reg.flash_channel_enable := '1';
                set_config(net, CH3_CAPABILITIES_OFFSET, pack(flash_cap_reg), response_code, status,  crc_ok);
                check(crc_ok, "Set Config CRC Check failed");
                -- Put a non-posted read request into the flash channel
                -- We expect something to happen here and the alert get set when the completion
                -- status is written back, so we check the crc here and then wait for the alert
                -- enqueue n copies of the same np request
                -- gen_int represents number of transactions to queue
                gen_int := 1;
                for i in 0 to gen_int - 1 loop
                    put_flash_read(net, X"03020000", 16, response_code, status,  crc_ok);
                    check(crc_ok, "put_flash read CRC Check failed");
                end loop;
    
                -- deal with the responses
                for i in 0 to gen_int - 1 loop
                    report "Status: " & to_hstring(status);
                    status_rec := unpack(status);
                    -- we may, or may not have a completion ready, if not
                    -- we wait for the alert
                    if status_rec.flash_c_avail = '0' then
                       report "Waiting, iter: " & integer'image(i);
                       wait_for_alert(net);
                    end if;
                    get_flash_c(net, 16, my_queue, response_code, status,  crc_ok);
                    check(crc_ok, "CRC Check failed");
                    -- TODO: the data's not coming back right.
                    for j in 0 to 15 loop
                        report "Flash Byte: " & to_hstring(to_unsigned(pop_byte(my_queue), 8));
                    end loop;
                end loop;

                -- would normally wait for the completion alert now
                wait for 300 us;
            elsif run("oob_no_pec_uart") then
                enable_debug_mode(net);
                 --Enable OOB Channel
                cmd := build_set_config_cmd(CH2_CAPABILITIES_OFFSET, CH2_CAPABILITIES_CHAN_EN_MASK);
                dbg_send_cmd(net, cmd);
                dbg_wait_for_done(net);
                dbg_get_response(net, 4, response);
                check(response.crc_ok, "CRC Check failed");
                exp_data_32 := (others => '0');

                -- Send UART data which will then be looped back and rx'd
                payload_size := rnd.RandInt(1, 61);  -- why 61 you ask? we are limiting total bytes to 64 and there could be 3 bytes of header
                my_queue := build_rand_byte_queue(payload_size);
                dbg_send_uart_oob_no_pec_cmd(net, my_queue);
                dbg_wait_for_done(net);
                -- get the response from the fifo
                dbg_get_response(net, 4 , response);
                check(response.crc_ok, "Send UART CMD resp CRC Check failed");
                dbg_get_response_size(net, gen_int);
                print("PUT resp Payload Size: " & integer'image(payload_size) & ", Response size: " & integer'image(gen_int));
                wait for 10 * payload_size * 350 ns;  -- approx uart time for payload size
                status_rec := unpack(response.status);
                if status_rec.oob_avail /= '1' then
                    dbg_wait_for_alert(net);
                end if;
                -- technically we'd get status here, and if we supported completions we'd return it here
                -- response size is going to be 4 bytes for response_code/status/crc
                -- + 3 standard header bytes
                -- + 3 smbus header bytes
                -- + payload bytes

                dbg_get_uart_oob_no_pec_cmd(net);
                dbg_wait_for_done(net);
                wait for 10 us;
                dbg_get_response_size(net, gen_int);
                print("GET resp Payload Size: " & integer'image(payload_size) & ", Response size: " & integer'image(gen_int * 4));
                dbg_get_response(net, payload_size + 10 , response);
                check(response.crc_ok, "Response UART data resp CRC Check failed");
                compare_uart_loopback(my_queue, response.queue);

            elsif run("qspi_oob_no_pec_uart") then
                -- Send UART data which will then be looped back and rx'd
                payload_size := 21; --rnd.RandInt(1, 61);  -- why 61 you ask? we are limiting total bytes to 64 and there could be 3 bytes of header
                my_queue := build_rand_byte_queue(payload_size);
                put_oob_no_pec(net, my_queue, response_code, status,  crc_ok);
                wait for 1 ms;
            
            elsif run("basic_post_code_check") then
                enable_debug_mode(net);
                -- generate 1 post code, check that it shows up in the register and post code buffer
                exp_data_32 := x"000001de";
                dbg_send_post_code(net, exp_data_32);
                dbg_wait_for_done(net);
                -- verify counts are correct.
                wait for 1 us;
                -- Check *last* post code register
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.LAST_POST_CODE_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, exp_data_32, "Single post code register readback failed");
                -- Check post code buffer entry 0
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_BUFFER_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, exp_data_32, "Post code buffer readback failed");
                -- Check post code count register
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_COUNT_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000001"), "Post code count register readback failed");

                -- issue an espi reset and verify post code count resets
                dbg_espi_reset(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_COUNT_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000000"), "Post code count register did not reset after espi reset");


            elsif run("advanced_post_code_check") then
                -- generate multiple post codes, check that they show up in the register and post code buffer
                -- verify counts are correct.

                enable_debug_mode(net);
                -- generate 1 post code, check that it shows up in the register and post code buffer
                exp_data_32 := x"000001de";
                dbg_send_post_code(net, exp_data_32);
                dbg_wait_for_done(net);
                wait for 1 us;
                -- Check *last* post code register
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.LAST_POST_CODE_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, exp_data_32, "Single post code register readback failed");
                -- Check post code buffer entry 0
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_BUFFER_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, exp_data_32, "Post code buffer readback failed");
                -- Check post code count register
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_COUNT_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000001"), "Post code count register readback failed");

                exp_data_32 := x"000101de";
                dbg_send_post_code(net, exp_data_32);
                dbg_wait_for_done(net);
                -- verify counts are correct.
                wait for 1 us;

                -- Check *last* post code register
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.LAST_POST_CODE_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, exp_data_32, "Single post code register readback failed");
                -- Check post code buffer entry 0
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_BUFFER_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"000001de"), "Post code buffer 0 readback failed");
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_BUFFER_OFFSET + 4, bus_handle.p_address_length), data_32);
                check_equal(data_32, exp_data_32, "Post code buffer 1 readback failed");
                -- Check post code count register
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_COUNT_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000002"), "Post code count register readback failed");

                -- issue an espi reset and verify post code count resets
                dbg_espi_reset(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_COUNT_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000000"), "Post code count register did not reset after espi reset");

            elsif run("post_code_monitor_check") then
                enable_debug_mode(net);
                -- Send each tracked post code in turn, verifying the corresponding
                -- sticky bit accumulates in the monitor register.
                dbg_send_post_code(net, POST_CODE_BL_SUCCESS_C_MAIN);
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000001"), "bl_success_c_main bit should be set");

                dbg_send_post_code(net, POST_CODE_TP_PROC_MEM_AFTER_MEM_DATA_INIT);
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000003"), "tp_proc_mem_after_mem_data_init bit should be set");

                dbg_send_post_code(net, POST_CODE_TP_ABL7_RESUME_INITIALIZATION);
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000007"), "tp_abl7_resume_initialization bit should be set");

                dbg_send_post_code(net, POST_CODE_TP_ABL_MEMORY_DDR_TRAINING_START);
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"0000000f"), "tp_abl_memory_ddr_training_start bit should be set");

                dbg_send_post_code(net, POST_CODE_TP_PROC_CPU_OPTIMIZED_BOOT_START);
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"0000001f"), "tp_proc_cpu_optimized_boot_start bit should be set");

                dbg_send_post_code(net, POST_CODE_TP_ABL4_APOB);
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"0000003f"), "tp_abl4_apob bit should be set");

                dbg_send_post_code(net, POST_CODE_BL_SUCCESS_BIOS_LOAD_COMPLETE);
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"0000007f"), "bl_success_bios_load_complete bit should be set");

                dbg_send_post_code(net, POST_CODE_PHBLHELLO);
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"000000ff"), "phbl_hello bit should be set, all bits should now be set");

                -- A non-matching post code must not change the monitor register.
                dbg_send_post_code(net, x"DEADBEEF");
                dbg_wait_for_done(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"000000ff"), "non-matching post code must not alter monitor register");

                -- espi_reset must clear all monitor bits.
                dbg_espi_reset(net);
                wait for 1 us;
                read_bus(net, bus_handle, To_StdLogicVector(espi_regs_pkg.POST_CODE_MONITOR_OFFSET, bus_handle.p_address_length), data_32);
                check_equal(data_32, std_logic_vector'(x"00000000"), "monitor register must clear on espi reset");

            -- ============================================================
            -- Verify that pc_free correctly deasserts when the RX FIFO
            -- approaches capacity, and reasserts after draining.
            -- Checks:
            --   1. pc_free is TRUE when FIFO is empty
            --   2. pc_free transitions to FALSE during fill (via response status)
            --   3. oob_free_saw_full sticky bit is set
            --   4. pc_free recovers to TRUE after UART loopback drains
            -- ============================================================
            elsif run("tla_pcfree_regression") then
                enable_debug_mode(net);
                -- Enable OOB Channel
                cmd := build_set_config_cmd(CH2_CAPABILITIES_OFFSET, CH2_CAPABILITIES_CHAN_EN_MASK);
                dbg_send_cmd(net, cmd);
                dbg_wait_for_done(net);
                dbg_get_response(net, 4, response);
                check(response.crc_ok, "OOB enable CRC failed");

                -- Verify pc_free is TRUE when FIFO is empty
                read_bus(net, bus_handle,
                         To_StdLogicVector(espi_regs_pkg.LIVE_ESPI_STATUS_OFFSET, bus_handle.p_address_length),
                         data_32);
                check_equal(data_32(0), '1',
                            "pc_free should be TRUE when FIFO is empty");

                -- Fill the RX FIFO by sending PUT_OOB messages in a loop.
                -- Each message carries 61 bytes of payload. The UART loopback
                -- drains at ~15 bytes per PUT cycle, so net fill rate is ~46
                -- bytes per iteration. We need FIFO to reach 4096-64 = 4032.
                -- ~90 PUTs pushes well past the pc_free threshold.
                pcfree_deasserted := false;
                for batch in 0 to 89 loop
                    payload_size := 61;
                    my_queue := new_queue;
                    for i in 0 to payload_size - 1 loop
                        push_byte(my_queue, (batch + i) mod 256);
                    end loop;
                    dbg_send_uart_oob_no_pec_cmd(net, my_queue);
                    dbg_wait_for_done(net);
                    dbg_get_response(net, 4, response);
                    check(response.crc_ok, "PUT batch " & integer'image(batch) & " CRC failed");
                    -- Track pc_free in each PUT response status
                    status_rec := unpack(response.status);
                    if batch = 0 then
                        check_equal(status_rec.pc_free, '1',
                                    "pc_free should be TRUE in first PUT response");
                    end if;
                    if status_rec.pc_free = '0' and not pcfree_deasserted then
                        report "pc_free deasserted at PUT batch " & integer'image(batch);
                        pcfree_deasserted := true;
                    end if;
                end loop;
                check(pcfree_deasserted,
                      "pc_free never deasserted during fill loop");

                wait for 1 us;

                -- Read the RX FIFO used words for diagnostics
                read_bus(net, bus_handle,
                         To_StdLogicVector(espi_regs_pkg.IPCC_HOST_TO_SP_USEDWDS_OFFSET, bus_handle.p_address_length),
                         data_32);
                gen_int := to_integer(unsigned(data_32));
                report "RX FIFO host_to_sp usedwds after 90 PUTs: " & integer'image(gen_int);
                -- FIFO should be past the pc_free threshold (4096-64 = 4032)
                check(gen_int > 4032,
                      "Expected RX FIFO usedwds > 4032, got " & integer'image(gen_int));

                -- Read live eSPI status: verify pc_free and oob_free are FALSE
                read_bus(net, bus_handle,
                         To_StdLogicVector(espi_regs_pkg.LIVE_ESPI_STATUS_OFFSET, bus_handle.p_address_length),
                         data_32);
                report "Live eSPI status after fill: " & to_hstring(data_32);
                -- PC_FREE is bit 0, OOB_FREE is bit 3
                check_equal(data_32(0), '0',
                            "pc_free should be FALSE when FIFO is near-full");
                check_equal(data_32(3), '0',
                            "oob_free should be FALSE when FIFO is near-full");

                -- Check the oob_free_saw_full sticky bit
                read_bus(net, bus_handle,
                         To_StdLogicVector(espi_regs_pkg.OOB_FREE_SAW_FULL_OFFSET, bus_handle.p_address_length),
                         data_32);
                check_equal(data_32(0), '1',
                            "oob_free_saw_full should be set (FIFO was near-full)");

                -- Wait for UART loopback to drain enough bytes for pc_free
                -- to recover. At CLKS_PER_BIT=41 / 125 MHz, one byte takes
                -- ~3.28 us. We need to drain at most 64 bytes (210 us).
                wait for 500 us;
                read_bus(net, bus_handle,
                         To_StdLogicVector(espi_regs_pkg.LIVE_ESPI_STATUS_OFFSET, bus_handle.p_address_length),
                         data_32);
                check_equal(data_32(0), '1',
                            "pc_free should recover to TRUE after UART drains");

            elsif run("put_iowr_short") then
                put_iowr_short4(net, X"0080", X"EE0000A2", response_code, status,  crc_ok);
                dbg_get_response(net, 4 , response);
                check(response.crc_ok, "put iowr resp CRC Check failed");

                get_status(net, response_code, status, crc_ok);
                check(crc_ok, "get status CRC Check failed");

            -- The sweeps below walk every I/O mode against every frequency the
            -- spec defines. A CRC failure is the signal that matters: if the
            -- wait-state count is too small for a configuration, the link layer
            -- pads the response with 0xFF and the CRC stops matching.
            elsif run("mode_freq_sweep_status") then
                -- GET_STATUS is the shortest command there is (opcode plus
                -- CRC), so the sizer has the least time to work out where the
                -- turnaround falls. Quad at 66MHz leaves it two SCLK.
                for i in all_link_cfgs'range loop
                    -- The transition itself runs at the *previous*
                    -- configuration's mode and speed, so its result belongs to
                    -- that configuration, not this one. Score only what follows.
                    set_link_cfg(net, all_link_cfgs(i), transition_ok);
                    cfg_ok := true;
                    for rep in 0 to 1 loop
                        get_status(net, response_code, status, crc_ok);
                        expected_status := pack(status_t'(rec_reset));
                        cfg_ok := cfg_ok and crc_ok and (status = expected_status);
                    end loop;
                    sweep_results(i) := cfg_ok;
                end loop;
                report_sweep("GET_STATUS", sweep_results);

            elsif run("mode_freq_sweep_config") then
                -- Eight bytes out, eight back. Also covers the mode change
                -- itself, since set_link_cfg is a config write.
                for i in all_link_cfgs'range loop
                    -- The transition itself runs at the *previous*
                    -- configuration's mode and speed, so its result belongs to
                    -- that configuration, not this one. Score only what follows.
                    set_link_cfg(net, all_link_cfgs(i), transition_ok);
                    cfg_ok := true;
                    get_config(net, GENERAL_CAPABILITIES_OFFSET, data_32, response_code, status, crc_ok);
                    cfg_ok := cfg_ok and crc_ok
                              and (data_32(27 downto 26) = std_logic_vector(to_unsigned(
                                   general_capabilities_io_mode_sel'pos(all_link_cfgs(i).mode_sel), 2)))
                              and (data_32(22 downto 20) = std_logic_vector(to_unsigned(
                                   general_capabilities_op_freq_select'pos(all_link_cfgs(i).freq_sel), 3)));
                    sweep_results(i) := cfg_ok;
                end loop;
                report_sweep("GET/SET_CONFIGURATION", sweep_results);

            elsif run("mode_freq_sweep_flash_read") then
                -- The long-response path, and so the real test of whether the
                -- wait-state count covers the round trip to the transaction
                -- layer and back at each mode and frequency.
                flash_cap_reg.flash_channel_enable := '1';
                -- Not a halting check: the command lands even when its response
                -- is corrupt, and halting here would cost us the whole matrix.
                set_config(net, CH3_CAPABILITIES_OFFSET, pack(flash_cap_reg), response_code, status, crc_ok);
                if not crc_ok then
                    warning("Flash channel enable response CRC failed");
                end if;
                for i in all_link_cfgs'range loop
                    -- The transition itself runs at the *previous*
                    -- configuration's mode and speed, so its result belongs to
                    -- that configuration, not this one. Score only what follows.
                    set_link_cfg(net, all_link_cfgs(i), transition_ok);
                    cfg_ok := true;
                    put_flash_read(net, X"03020000", 16, response_code, status, crc_ok);
                    cfg_ok     := cfg_ok and crc_ok;
                    status_rec := unpack(status);
                    if status_rec.flash_c_avail = '0' then
                        wait_for_alert(net);
                    end if;
                    get_flash_c(net, 16, my_queue, response_code, status, crc_ok);
                    cfg_ok := cfg_ok and crc_ok;
                    flush(my_queue);
                    sweep_results(i) := cfg_ok;
                end loop;
                report_sweep("FLASH_READ", sweep_results);

            end if;
        end loop;
        wait for 10 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog. The mode/frequency sweeps walk 15
    -- configurations in a single test case, so this is well above what any
    -- individual test needs.
    test_runner_watchdog(runner, 20 ms);

end tb;
