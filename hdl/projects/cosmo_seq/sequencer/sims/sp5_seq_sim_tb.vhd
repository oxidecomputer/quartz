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

use work.sp5_seq_sim_pkg.all;
use work.sequencer_regs_pkg.all;
use work.rail_model_msg_pkg.all;
use work.nic_model_msg_pkg.all;


entity sp5_seq_sim_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of sp5_seq_sim_tb is

begin

    th: entity work.sp5_seq_sim_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        variable read_data       : std_logic_vector(31 downto 0);
        variable seq_state       : seq_api_status_a0_sm;
        constant grpa_v3p3_actor : actor_t := find("grpa_v3p3_sp5_a1");
        constant nic_actor       : actor_t := find("nic_model");
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("normal_enable") then
                info("Starting normal A0 power sequence");
                write_bus(net, bus_handle, To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length), POWER_CTRL_A0_EN_MASK);

                -- Poll for sequence to complete (wait for DONE state)
                poll_for_seq_state(net, DONE);

                -- Verify we're in DONE state
                read_bus(net, bus_handle, To_StdLogicVector(SEQ_API_STATUS_OFFSET, bus_handle.p_address_length), read_data);
                seq_state := encode(read_data(7 downto 0));
                info("A0 state after power up: " & to_hstring(read_data(7 downto 0)));
                check_equal(seq_state = DONE, true, "Expected sequencer to be in DONE state");
            elsif run("mapo_fault_v3p3_sp5_a1") then
                test_mapo_fault_injection(net, grpa_v3p3_actor, "V3P3_SP5_A1");
            elsif run("mapo_fault_pwr_v1p5_rtc") then
                test_mapo_fault_injection(net, find("grpa_pwr_v1p5_rtc"), "PWR_V1P5_RTC");
            elsif run("mapo_fault_v1p8_sp5_a1") then
                test_mapo_fault_injection(net, find("grpa_v1p8_sp5_a1"), "V1P8_SP5_A1");
            elsif run("mapo_fault_v1p1_sp5") then
                test_mapo_fault_injection(net, find("grpb_v1p1_sp5"), "V1P1_SP5");
            elsif run("mapo_fault_vddio_sp5_a0") then
                test_mapo_fault_injection(net, find("grpc_vddio_sp5_a0"), "VDDIO_SP5_A0");
            elsif run("mapo_fault_vddcr_cpu0") then
                test_mapo_fault_injection(net, find("grpc_vddcr_cpu0"), "VDDCR_CPU0");
            elsif run("mapo_fault_vddcr_cpu1") then
                test_mapo_fault_injection(net, find("grpc_vddcr_cpu1"), "VDDCR_CPU1");
            elsif run("mapo_fault_vddcr_soc") then
                test_mapo_fault_injection(net, find("grpc_vddcr_soc"), "VDDCR_SOC");
            elsif run("nic_mapo_fault_v1p5_nic_a0hp") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_V1P5_NIC_A0HP);
            elsif run("nic_mapo_fault_v1p2_nic_pcie_a0hp") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_V1P2_NIC_PCIE_A0HP);
            elsif run("nic_mapo_fault_v1p2_nic_enet_a0hp") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_V1P2_NIC_ENET_A0HP);
            elsif run("nic_mapo_fault_v3p3_nic_a0hp") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_V3P3_NIC_A0HP);
            elsif run("nic_mapo_fault_v1p1_nic_a0hp") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_V1P1_NIC_A0HP);
            elsif run("nic_mapo_fault_v1p4_nic_a0hp") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_V1P4_NIC_A0HP);
            elsif run("nic_mapo_fault_v0p96_nic_vdd_a0hp") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_V0P96_NIC_VDD_A0HP);
            elsif run("nic_mapo_fault_nic_hsc_12v") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_NIC_HSC_12V);
            elsif run("nic_mapo_fault_nic_hsc_5v") then
                test_nic_rail_mapo_fault_injection(net, nic_actor, RAIL_NIC_HSC_5V);
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;