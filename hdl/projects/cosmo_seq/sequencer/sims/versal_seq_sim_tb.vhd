-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.sequencer_regs_pkg.all;
use work.sequencer_io_pkg.all;
use work.sp5_seq_sim_pkg.all;
use work.rail_model_msg_pkg.all;
use work.versal_model_msg_pkg;

entity versal_seq_sim_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of versal_seq_sim_tb is
begin

    th: entity work.sp5_seq_sim_th generic map (NIC_KIND => NIC_VERSAL);

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias versal_held_in_reset is << signal th.versal_held_in_reset : std_logic >>;
        alias versal_pcie_pins is << signal th.versal_pcie_pins : versal_pcie_t >>;
        alias sp5_versal_cha_perst_l is << signal th.sp5_nic_perst_l : std_logic >>;
        alias sp5_versal_chb_perst_l is << signal th.sp5_nic_chb_perst_l : std_logic >>;
        alias flash_owned_by_seq is << signal th.flash_owned_by_seq : std_logic >>;
        alias hash_req is << signal th.hash_req : std_logic >>;
        alias hash_model_fail is << signal th.hash_model_fail : boolean >>;
        alias hash_requests is << signal th.hash_requests : natural >>;
        alias versal_boot_pins is << signal th.versal_boot_pins : versal_boot_t >>;
        constant versal_actor : actor_t := find("versal_model");
        variable read_data : std_logic_vector(31 downto 0);
        variable versal_state : nic_api_status_nic_sm;
        variable rails_pg : rails_type;
        variable readbacks : versal_readbacks_type;
        variable status : status_type;
        variable version : board_version_type;
    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("normal_power_up") then
                power_up_to_nic_done(net);

                -- Every rail should read back good once we are up.
                read_bus(net, bus_handle,
                         To_StdLogicVector(RAIL_PGS_OFFSET, bus_handle.p_address_length),
                         read_data);
                rails_pg := unpack(read_data);
                check_equal(rails_pg.versal_v0p8_vccint, '1',
                            "Expected the Versal VCCINT rail to read power good");
                check_equal(rails_pg.versal_v3p3, '1',
                            "Expected the Versal 3V3 rail to read power good");

                -- and the status register should agree.
                read_bus(net, bus_handle,
                         To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                status := unpack(read_data);
                check_equal(status.nicpwrok, '1',
                            "Expected versalpwrok in the status register");
                check_equal(status.nicdone, '1',
                            "Expected versaldone in the status register");

            elsif run("boot_mode_is_strapped") then
                -- The default boot mode is QSPI32; check it reaches the pins.
                power_up_to_nic_done(net);
                read_bus(net, bus_handle,
                         To_StdLogicVector(VERSAL_READBACKS_OFFSET, bus_handle.p_address_length),
                         read_data);
                readbacks := unpack(read_data);
                check_equal(readbacks.mode, std_logic_vector'(x"2"),
                            "Expected MODE[3:0] to be strapped to QSPI32");
                check_equal(readbacks.mode_buffer_en_l, '0',
                            "Expected the MODE buffer to be enabled");

            elsif run("pcie_resets_follow_their_slots") then
                -- Neither channel leaves reset before the Versal is booted,
                -- and afterwards each follows only its own slot's power
                -- enable from the SP5 hotplug controller.
                check_equal(versal_pcie_pins.cha.perst_l, '0',
                            "Expected channel A PERST asserted before boot");
                check_equal(versal_pcie_pins.chb.perst_l, '0',
                            "Expected channel B PERST asserted before boot");
                power_up_to_nic_done(net);
                wait for 100 ns;
                check_equal(versal_pcie_pins.cha.perst_l, '1',
                            "Expected channel A PERST released once booted");
                check_equal(versal_pcie_pins.chb.perst_l, '1',
                            "Expected channel B PERST released once booted");

                sp5_versal_chb_perst_l <= '0';
                wait for 100 ns;
                check_equal(versal_pcie_pins.cha.perst_l, '1',
                            "Expected channel A PERST unaffected by slot B");
                check_equal(versal_pcie_pins.chb.perst_l, '0',
                            "Expected channel B PERST to follow slot B");
                read_bus(net, bus_handle,
                         To_StdLogicVector(VERSAL_READBACKS_OFFSET, bus_handle.p_address_length),
                         read_data);
                readbacks := unpack(read_data);
                check_equal(readbacks.sp5_cha_perst_l, '1', "Expected slot A readback high");
                check_equal(readbacks.sp5_chb_perst_l, '0', "Expected slot B readback low");
                check_equal(readbacks.chb_perst_l, '0', "Expected channel B PERST readback low");

                sp5_versal_chb_perst_l <= '1';
                sp5_versal_cha_perst_l <= '0';
                wait for 100 ns;
                check_equal(versal_pcie_pins.cha.perst_l, '0',
                            "Expected channel A PERST to follow slot A");
                check_equal(versal_pcie_pins.chb.perst_l, '1',
                            "Expected channel B PERST unaffected by slot A");
                sp5_versal_cha_perst_l <= '1';

            elsif run("flash_mux_interlock") then
                -- The SP may only take the boot flash while POR_B is asserted;
                -- after boot the sequencer holds it for the SP5 instead.
                check_equal(versal_held_in_reset, '1',
                            "Expected the Versal to be held in reset before power up");
                check_equal(flash_owned_by_seq, '0',
                            "Expected no sequencer claim on the flash before power up");
                power_up_to_nic_done(net);
                check_equal(versal_held_in_reset, '0',
                            "Expected the SP's request to be denied once the Versal has booted");
                check_equal(flash_owned_by_seq, '1',
                            "Expected the sequencer to hold the flash for the SP5 after boot");

            elsif run("image_is_measured_before_boot") then
                -- The sequencer asks the hash engine for a measurement with
                -- the rails up, POR_B still held and the flash on the FPGA
                -- side, and only releases POR_B once it has an answer.
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                wait until hash_req = '1' for 50 ms;
                check_equal(hash_req, '1', "Expected a measurement request");
                check_equal(versal_boot_pins.por_b, '0', "Expected POR_B held during the measurement");
                check_equal(flash_owned_by_seq, '1', "Expected the flash on the FPGA side during the measurement");
                read_bus(net, bus_handle,
                         To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                versal_state := encode(read_data(7 downto 0));
                check_equal(versal_state = MEASURING, true, "Expected the MEASURING api state");
                wait until hash_req = '0';
                -- POR_B releases only after the flash has gone back to the Versal
                wait until versal_boot_pins.por_b = '1' for 50 ms;
                check_equal(versal_boot_pins.por_b, '1', "Expected POR_B released after the measurement");
                check_equal(flash_owned_by_seq, '0', "Expected the flash back with the Versal for boot");
                poll_for_nic_state(net, DONE);
                check_equal(flash_owned_by_seq, '1', "Expected the flash back on the FPGA side after boot");
                read_bus(net, bus_handle,
                         To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                status := unpack(read_data);
                check_equal(status.nic_hash_done, '1', "Expected versal_hash_done");
                check_equal(status.nic_hash_err, '0', "Expected no versal_hash_err");
                check_equal(hash_requests, 1, "Expected exactly one measurement");

            elsif run("failed_measurement_is_recorded_and_boot_continues") then
                hash_model_fail <= true;
                power_up_to_nic_done(net);
                read_bus(net, bus_handle,
                         To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                status := unpack(read_data);
                check_equal(status.nic_hash_done, '0', "Expected no versal_hash_done");
                check_equal(status.nic_hash_err, '1', "Expected versal_hash_err");
                read_bus(net, bus_handle,
                         To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length),
                         read_data);
                check_equal((read_data and IFR_NIC_HASH_ERR_MASK) /= (read_data'range => '0'), true,
                            "Expected the versal_hash_err interrupt flag");

            elsif run("measurement_can_be_skipped") then
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_MODE_MASK and x"00000002");
                power_up_to_nic_done(net);
                check_equal(hash_requests, 0, "Expected no measurement request");
                read_bus(net, bus_handle,
                         To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                status := unpack(read_data);
                check_equal(status.nic_hash_done, '0', "Expected no versal_hash_done");
                check_equal(status.nic_hash_err, '0', "Expected no versal_hash_err");

            elsif run("boot_timeout_does_not_drop_power") then
                versal_model_msg_pkg.fail_boot(net, versal_actor);
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                poll_for_seq_state(net, DONE);
                poll_for_nic_state(net, BOOTING);
                wait for 500 us;

                -- A boot that never completes must not look like a power fault.
                read_bus(net, bus_handle,
                         To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                versal_state := encode(read_data(7 downto 0));
                check_equal(versal_state = BOOTING, true,
                            "Expected the Versal sequencer to stay in BOOTING");
                read_bus(net, bus_handle,
                         To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
                check_equal((read_data and IFR_NICMAPO_MASK) = x"00000000", true,
                            "A failed boot must not raise a Versal MAPO");
                versal_model_msg_pkg.allow_boot(net, versal_actor);

            elsif run("error_out_raises_an_irq") then
                power_up_to_nic_done(net);
                versal_model_msg_pkg.assert_error_out(net, versal_actor);
                wait for 100 us;
                read_bus(net, bus_handle,
                         To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
                check_equal((read_data and IFR_VERSAL_ERROR_OUT_MASK) /= x"00000000", true,
                            "Expected ERROR_OUT to set its interrupt flag");
                versal_model_msg_pkg.clear_error_out(net, versal_actor);

            elsif run("board_version_readback") then
                read_bus(net, bus_handle,
                         To_StdLogicVector(BOARD_VERSION_OFFSET, bus_handle.p_address_length),
                         read_data);
                version := unpack(read_data);
                check_equal(version.version_id, std_logic_vector'("01"),
                            "Expected the board version straps to read back");

            elsif run("mapo_fault_v1p1_sp5") then
                test_mapo_fault_injection(net, find("grpb_v1p1_sp5"), "v1p1_sp5");
            elsif run("mapo_fault_vddcr_soc") then
                test_mapo_fault_injection(net, find("grpc_vddcr_soc"), "vddcr_soc");

            elsif run("versal_mapo_fault_v0p8_vccint") then
                test_versal_rail_mapo_fault_injection(net, find("versal_v0p8_vccint"), "v0p8_vccint");
            elsif run("versal_mapo_fault_v0p88") then
                test_versal_rail_mapo_fault_injection(net, find("versal_v0p88"), "v0p88");
            elsif run("versal_mapo_fault_v1p1") then
                test_versal_rail_mapo_fault_injection(net, find("versal_v1p1"), "v1p1");
            elsif run("versal_mapo_fault_v1p4") then
                test_versal_rail_mapo_fault_injection(net, find("versal_v1p4"), "v1p4");
            elsif run("versal_mapo_fault_v1p5") then
                test_versal_rail_mapo_fault_injection(net, find("versal_v1p5"), "v1p5");
            elsif run("versal_mapo_fault_v1p5_avccaux") then
                test_versal_rail_mapo_fault_injection(net, find("versal_v1p5_avccaux"), "v1p5_avccaux");
            elsif run("versal_mapo_fault_v1p8") then
                test_versal_rail_mapo_fault_injection(net, find("versal_v1p8"), "v1p8");
            elsif run("versal_mapo_fault_v3p3") then
                test_versal_rail_mapo_fault_injection(net, find("versal_v3p3"), "v3p3");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 20 ms);
end tb;
