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
use work.sp5_power_pkg.all;
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
    constant NUM_GROUPS : integer := 7;
    -- The harness runs a millisecond as 100 counts of its 8 ns clock
    constant SIM_MS : time := 100 * 8 ns;
    constant GROUP_DELAY : time := 4 * SIM_MS;
    subtype groups_t is std_logic_vector(1 to NUM_GROUPS);

    -- The Versal power sequence as the pins see it, one bit per group. A
    -- group counts as enabled as soon as any of its enables is up, and as
    -- good only once all of its power goods are.
    function group_enables(rails : versal_power_t) return groups_t is
    begin
        return (
            1 => rails.v3p3.enable or rails.v1p8.enable,
            2 => rails.v0p88.enable,
            3 => rails.v0p8_vccint.enable,
            4 => rails.v1p5.enable,
            5 => rails.v1p1.enable,
            6 => rails.v1p5_avccaux.enable,
            7 => rails.v1p4.enable
        );
    end function;

    -- On the way down, only the groups below the one just disabled are on
    function on_below(other : integer; grp : integer) return std_logic is
    begin
        if other < grp then
            return '1';
        end if;
        return '0';
    end function;

    function group_pgs(rails : versal_power_t) return groups_t is
    begin
        return (
            1 => rails.v3p3.pg and rails.v1p8.pg,
            2 => rails.v0p88.pg,
            3 => rails.v0p8_vccint.pg,
            4 => rails.v1p5.pg,
            5 => rails.v0p92_avcc.pg,
            6 => rails.v1p5_avccaux.pg,
            7 => rails.v1p2_avtt.pg
        );
    end function;
begin

    th: entity work.sp5_seq_sim_th generic map (NIC_KIND => NIC_VERSAL);

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias versal_held_in_reset is << signal th.versal_held_in_reset : std_logic >>;
        alias versal_pcie_pins is << signal th.versal_pcie_pins : versal_pcie_t >>;
        alias sp5_versal_cha_perst_l is << signal th.sp5_nic_perst_l : std_logic >>;
        alias sp5_versal_chb_perst_l is << signal th.sp5_nic_chb_perst_l : std_logic >>;
        alias flash_owned_by_seq is << signal th.flash_owned_by_seq : std_logic >>;
        alias nic_rails_up is << signal th.nic_rails_up : std_logic >>;
        alias sp5_nic_prsnt_l is << signal th.sp5_nic_prsnt_l : std_logic >>;
        alias sp5_nic_chb_prsnt_l is << signal th.sp5_nic_chb_prsnt_l : std_logic >>;
        alias hash_req is << signal th.hash_req : std_logic >>;
        alias hash_model_time is << signal th.hash_model_time : time >>;
        alias hash_model_fail is << signal th.hash_model_fail : boolean >>;
        alias hash_requests is << signal th.hash_requests : natural >>;
        alias versal_boot_pins is << signal th.versal_boot_pins : versal_boot_t >>;
        alias versal_rails_pins is << signal th.versal_rails_pins : versal_power_t >>;
        constant versal_actor : actor_t := find("versal_model");
        variable read_data : std_logic_vector(31 downto 0);
        variable versal_state : nic_api_status_nic_sm;
        variable rails_pg : rails_type;
        variable readbacks : versal_readbacks_type;
        variable status : status_type;
        variable hash_status : nic_hash_status_type;
        variable version : board_version_type;
        variable last_event : time;
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
                -- and so should the T6 rails this board does not have, so
                -- that a bad rail stands out as the only zero.
                check_equal(rails_pg.v1p5_nic_a0hp, '1',
                            "Expected an absent T6 rail to read power good");
                check_equal(rails_pg.v0p96_nic_vdd_a0hp, '1',
                            "Expected an absent T6 rail to read power good");

                -- and the status register should agree.
                read_bus(net, bus_handle,
                         To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                status := unpack(read_data);
                check_equal(status.nicpwrok, '1',
                            "Expected versalpwrok in the status register");
                check_equal(status.nicdone, '1',
                            "Expected versaldone in the status register");

            elsif run("rails_come_up_in_group_order") then
                check_equal(group_enables(versal_rails_pins), groups_t'(others => '0'),
                            "Expected no Versal rail enabled before power up");
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                for grp in 1 to NUM_GROUPS loop
                    wait until group_enables(versal_rails_pins)(grp) = '1' for 10 ms;
                    check_equal(group_enables(versal_rails_pins)(grp), '1',
                                "Expected group " & to_string(grp) & " to be enabled");
                    if grp > 1 then
                        check(now - last_event >= GROUP_DELAY,
                              "Expected group " & to_string(grp) & " no sooner than " &
                              to_string(GROUP_DELAY) & " after the group before it was good, got " &
                              to_string(now - last_event));
                    end if;
                    if group_pgs(versal_rails_pins)(grp) /= '1' then
                        wait until group_pgs(versal_rails_pins)(grp) = '1' for 10 ms;
                    end if;
                    last_event := now;
                    check_equal(versal_rails_pins.v3p3.enable, versal_rails_pins.v1p8.enable,
                                "Expected the group 1 rails to be enabled together");
                    for other in 1 to NUM_GROUPS loop
                        if other < grp then
                            check_equal(group_pgs(versal_rails_pins)(other), '1',
                                        "Expected group " & to_string(other) &
                                        " good before group " & to_string(grp) & " is enabled");
                        elsif other > grp then
                            check_equal(group_enables(versal_rails_pins)(other), '0',
                                        "Expected group " & to_string(other) &
                                        " off when group " & to_string(grp) & " is enabled");
                        end if;
                    end loop;
                end loop;
                check_equal(versal_boot_pins.por_b, '0',
                            "Expected POR_B held while the rails come up");
                poll_for_nic_state(net, DONE);

            elsif run("rails_go_down_in_reverse_group_order") then
                power_up_to_nic_done(net);
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          x"00000000");
                for grp in NUM_GROUPS downto 1 loop
                    wait until group_enables(versal_rails_pins)(grp) = '0' for 10 ms;
                    check_equal(group_enables(versal_rails_pins)(grp), '0',
                                "Expected group " & to_string(grp) & " to be disabled");
                    check_equal(versal_boot_pins.por_b, '0',
                                "Expected POR_B asserted before group " & to_string(grp) & " goes");
                    if grp < NUM_GROUPS then
                        check(now - last_event >= GROUP_DELAY,
                              "Expected group " & to_string(grp) & " no sooner than " &
                              to_string(GROUP_DELAY) & " after the group above it, got " &
                              to_string(now - last_event));
                    end if;
                    last_event := now;
                    for other in 1 to NUM_GROUPS loop
                        check_equal(group_enables(versal_rails_pins)(other),
                                    on_below(other, grp),
                                    "Group " & to_string(other) & " enable when group " &
                                    to_string(grp) & " is disabled");
                    end loop;
                    check_equal(versal_rails_pins.hsc_12v.enable, '1',
                                "Expected the hotswap to outlast group " & to_string(grp));
                end loop;
                wait until versal_rails_pins.hsc_12v.enable = '0' for 10 ms;
                check_equal(versal_rails_pins.hsc_12v.enable, '0',
                            "Expected the hotswap to be disabled last");
                check(now - last_event >= GROUP_DELAY,
                      "Expected the hotswap no sooner than " & to_string(GROUP_DELAY) &
                      " after group 1, got " & to_string(now - last_event));
                poll_for_nic_state(net, IDLE);

            elsif run("fault_takes_rails_down_in_reverse_group_order") then
                power_up_to_nic_done(net);
                disable_power_good(net, find("versal_v0p8_vccint"));
                for grp in NUM_GROUPS downto 1 loop
                    wait until group_enables(versal_rails_pins)(grp) = '0' for 10 ms;
                    check_equal(group_enables(versal_rails_pins)(grp), '0',
                                "Expected group " & to_string(grp) & " to be disabled");
                    check_equal(versal_boot_pins.por_b, '0',
                                "Expected POR_B asserted before group " & to_string(grp) & " goes");
                    for other in 1 to NUM_GROUPS loop
                        check_equal(group_enables(versal_rails_pins)(other),
                                    on_below(other, grp),
                                    "Group " & to_string(other) & " enable when group " &
                                    to_string(grp) & " is disabled");
                    end loop;
                end loop;
                enable_power_good(net, find("versal_v0p8_vccint"));
                poll_for_nic_state(net, IDLE);

            elsif run("a0hp_inhibit_holds_nic_off") then
                test_a0hp_inhibit_holds_nic_off(net);
            elsif run("a0hp_inhibit_powers_nic_down") then
                test_a0hp_inhibit_powers_nic_down(net);
            elsif run("a0hp_inhibit_masks_perst_restart_cha") then
                test_a0hp_inhibit_masks_perst_restart(net, sp5_versal_cha_perst_l);
            elsif run("a0hp_inhibit_masks_perst_restart_chb") then
                test_a0hp_inhibit_masks_perst_restart(net, sp5_versal_chb_perst_l);

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

            elsif run("presence_waits_for_done") then
                -- The model's presence pins are asserted from the start; the
                -- hotplug slots must not see them until the Versal has booted.
                check_equal(sp5_nic_prsnt_l, '1', "Expected channel A absent before power up");
                check_equal(sp5_nic_chb_prsnt_l, '1', "Expected channel B absent before power up");
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                wait until versal_boot_pins.por_b = '1' for 50 ms;
                check_equal(versal_boot_pins.por_b, '1', "Expected POR_B released");
                check_equal(sp5_nic_prsnt_l, '1', "Expected channel A absent while booting");
                check_equal(sp5_nic_chb_prsnt_l, '1', "Expected channel B absent while booting");
                poll_for_nic_state(net, DONE);
                check_equal(sp5_nic_prsnt_l, '0', "Expected channel A present once DONE");
                check_equal(sp5_nic_chb_prsnt_l, '0', "Expected channel B present once DONE");

                -- each channel follows its own pin
                versal_pcie_pins.chb.prsnt_l <= '1';
                wait for 1 us;
                check_equal(sp5_nic_prsnt_l, '0', "Expected channel A unaffected by channel B's pin");
                check_equal(sp5_nic_chb_prsnt_l, '1', "Expected channel B absent with its pin high");
                versal_pcie_pins.chb.prsnt_l <= '0';
                wait for 1 us;
                check_equal(sp5_nic_chb_prsnt_l, '0', "Expected channel B present again");

                -- and both go away with the NIC
                disable_power_good(net, find("versal_v1p8"));
                wait for 100 us;
                check_equal(sp5_nic_prsnt_l, '1', "Expected channel A absent after a fault");
                check_equal(sp5_nic_chb_prsnt_l, '1', "Expected channel B absent after a fault");
                enable_power_good(net, find("versal_v1p8"));

            elsif run("rails_up_follows_the_nic_rails") then
                -- Low while the rails are down, high once they have all
                -- sequenced, and low again the moment a fault takes them down.
                check_equal(nic_rails_up, '0', "Expected rails_up low before power up");
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                poll_for_seq_state(net, DONE);
                wait until nic_rails_up = '1' for 50 ms;
                check_equal(nic_rails_up, '1', "Expected rails_up once the rails have sequenced");
                poll_for_nic_state(net, DONE);
                check_equal(nic_rails_up, '1', "Expected rails_up to hold through boot");
                disable_power_good(net, find("versal_v1p8"));
                wait for 100 us;
                check_equal(nic_rails_up, '0', "Expected rails_up low after a rail fault");
                enable_power_good(net, find("versal_v1p8"));

            elsif run("early_group_fault_during_power_up") then
                -- A group is held to account from the moment the sequence
                -- moves on from it, not only once the whole tree is up.
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                wait until versal_rails_pins.v1p5.enable = '1' for 50 ms;
                check_equal(versal_rails_pins.v1p5.enable, '1',
                            "Expected group 4 to be enabled");
                disable_power_good(net, find("versal_v3p3"));
                wait for 100 us;
                read_bus(net, bus_handle,
                         To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
                check_equal((read_data and IFR_NICMAPO_MASK) /= x"00000000", true,
                            "Expected a MAPO for a group 1 rail lost while group 4 came up");
                check_equal(group_enables(versal_rails_pins), groups_t'(others => '0'),
                            "Expected every group taken back down");
                enable_power_good(net, find("versal_v3p3"));

            elsif run("late_group_fault_during_power_up") then
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                wait until versal_rails_pins.v1p4.enable = '1' for 50 ms;
                check_equal(versal_rails_pins.v1p4.enable, '1',
                            "Expected group 7 to be enabled");
                disable_power_good(net, find("versal_v1p5_avccaux"));
                wait for 100 us;
                read_bus(net, bus_handle,
                         To_StdLogicVector(IFR_OFFSET, bus_handle.p_address_length), read_data);
                check_equal((read_data and IFR_NICMAPO_MASK) /= x"00000000", true,
                            "Expected a MAPO for a group 6 rail lost while group 7 came up");
                check_equal(nic_rails_up, '0',
                            "Expected rails_up never to have been reached");
                check_equal(group_enables(versal_rails_pins), groups_t'(others => '0'),
                            "Expected every group taken back down");
                enable_power_good(net, find("versal_v1p5_avccaux"));

            elsif run("power_down_leaves_the_pins_as_found") then
                -- Everything driven into the NIC domain goes back to its
                -- reset value on the way down, the latched boot mode included.
                power_up_to_nic_done(net);
                check_equal(versal_boot_pins.mode, std_logic_vector'("0010"),
                            "Expected the QSPI32 straps while booted");
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          x"00000000");
                poll_for_nic_state(net, IDLE);
                wait for 1 us;
                check_equal(versal_boot_pins.mode, std_logic_vector'("0000"),
                            "Expected the mode straps cleared after power down");
                check_equal(versal_boot_pins.por_b, '0', "Expected POR_B asserted after power down");
                check_equal(versal_boot_pins.mode_buffer_en_l, '1',
                            "Expected the mode buffer disabled after power down");
                check_equal(versal_boot_pins.err_done_buff_en, '0',
                            "Expected the DONE/ERROR_OUT buffer disabled after power down");
                check_equal(versal_pcie_pins.cha.perst_l, '0', "Expected channel A PERST asserted");
                check_equal(versal_pcie_pins.chb.perst_l, '0', "Expected channel B PERST asserted");
                check_equal(versal_pcie_pins.cha.clk_buff_oe_l, '1', "Expected channel A clock buffer off");
                check_equal(versal_pcie_pins.chb.clk_buff_oe_l, '1', "Expected channel B clock buffer off");
                check_equal(group_enables(versal_rails_pins), groups_t'(others => '0'),
                            "Expected every rail enable low");
                check_equal(versal_rails_pins.hsc_12v.enable, '0', "Expected the hotswap enable low");
                check_equal(nic_rails_up, '0', "Expected rails_up low");
                check_equal(flash_owned_by_seq, '0', "Expected no claim on the flash");

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

            elsif run("image_is_measured_alongside_power_up") then
                -- The measurement sets off with the power sequence and runs
                -- while the rails are still coming up.
                -- the measurement is off by default
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_HASH_IMAGE_MASK or x"00000002");
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                wait until hash_req = '1' for 50 ms;
                check_equal(hash_req, '1', "Expected a measurement request");
                -- the flash claim is a few deltas behind the request
                wait for 1 ns;
                check_equal(versal_rails_pins.v3p3.enable, '0',
                            "Expected the measurement to start ahead of the rails");
                check_equal(versal_boot_pins.por_b, '0', "Expected POR_B held during the measurement");
                check_equal(flash_owned_by_seq, '1', "Expected the flash on the FPGA side during the measurement");
                wait until hash_req = '0';
                wait until versal_boot_pins.por_b = '1' for 50 ms;
                check_equal(versal_boot_pins.por_b, '1', "Expected POR_B released with the rails up");
                check_equal(nic_rails_up, '1', "Expected the rails up at POR_B release");
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
                read_bus(net, bus_handle,
                         To_StdLogicVector(NIC_HASH_STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                hash_status := unpack(read_data);
                check_equal(hash_status.hash_sm = IDLE, true, "Expected the hash state machine idle");
                check_equal(hash_status.done, '1', "Expected done in the hash status");
                check_equal(hash_status.err, '0', "Expected no err in the hash status");
                check_equal(hash_status.abandoned, '0', "Expected no abandoned in the hash status");
                check_equal(hash_status.sw_started, '0', "Expected a sequencer-started measurement");

            elsif run("por_b_waits_for_a_long_measurement") then
                -- Longer than the rails take, so the power sequence gets to
                -- its checkpoint first and has to wait there.
                -- the measurement is off by default
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_HASH_IMAGE_MASK or x"00000002");
                hash_model_time <= 400 us;
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                wait until hash_req = '1' for 50 ms;
                wait for 250 us;
                check_equal(nic_rails_up, '1', "Expected the rails up while the measurement runs on");
                check_equal(versal_boot_pins.por_b, '0', "Expected POR_B held for the measurement");
                read_bus(net, bus_handle,
                         To_StdLogicVector(NIC_API_STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                versal_state := encode(read_data(7 downto 0));
                check_equal(versal_state = MEASURING, true, "Expected the MEASURING api state");
                read_bus(net, bus_handle,
                         To_StdLogicVector(NIC_HASH_STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                hash_status := unpack(read_data);
                check_equal(hash_status.hash_sm = RUNNING, true, "Expected the hash state machine running");
                wait until versal_boot_pins.por_b = '1' for 50 ms;
                check_equal(versal_boot_pins.por_b, '1', "Expected POR_B released after the measurement");
                check_equal(hash_req, '0', "Expected the measurement over before POR_B released");
                poll_for_nic_state(net, DONE);

            elsif run("measurement_can_be_ignored") then
                -- the measurement is off by default
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_HASH_IMAGE_MASK or x"00000002");
                hash_model_time <= 400 us;
                write_bus(net, bus_handle,
                          To_StdLogicVector(DEBUG_ENABLES_OFFSET, bus_handle.p_address_length),
                          DEBUG_ENABLES_IGNORE_NIC_HASH_MASK);
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                wait until versal_boot_pins.por_b = '1' for 50 ms;
                check_equal(versal_boot_pins.por_b, '1', "Expected POR_B released");
                check_equal(hash_req, '1', "Expected the measurement still in flight");
                check_equal(nic_rails_up, '1', "Expected the rails up at POR_B release");
                check_equal(flash_owned_by_seq, '0', "Expected the flash with the Versal for boot");
                wait until hash_req = '0' for 50 ms;
                wait for 10 us;
                read_bus(net, bus_handle,
                         To_StdLogicVector(NIC_HASH_STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                hash_status := unpack(read_data);
                check_equal(hash_status.abandoned, '1', "Expected the measurement recorded as abandoned");
                check_equal(hash_status.done, '0', "Expected no done for an abandoned measurement");
                check_equal(hash_status.err, '1', "Expected err for an abandoned measurement");

            elsif run("software_can_start_a_measurement") then
                -- With the NIC down: the flash does not need its rails
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_HASH_START_MASK or x"00000012");
                wait until hash_req = '1' for 1 ms;
                check_equal(hash_req, '1', "Expected a measurement request");
                -- the flash claim is a few deltas behind the request
                wait for 1 ns;
                check_equal(flash_owned_by_seq, '1', "Expected the flash on the FPGA side");
                check_equal(group_enables(versal_rails_pins), groups_t'(others => '0'),
                            "Expected no rail enabled by a measurement");
                wait until hash_req = '0' for 1 ms;
                wait for 10 us;
                check_equal(flash_owned_by_seq, '0', "Expected the flash let go of");
                read_bus(net, bus_handle,
                         To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                         read_data);
                check_equal(read_data, std_logic_vector'(x"00000012"), "Expected hash_start to clear itself");
                read_bus(net, bus_handle,
                         To_StdLogicVector(NIC_HASH_STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                hash_status := unpack(read_data);
                check_equal(hash_status.done, '1', "Expected done in the hash status");
                check_equal(hash_status.sw_started, '1', "Expected a software-started measurement");
                check_equal(hash_requests, 1, "Expected exactly one measurement");

            elsif run("software_start_refused_once_booted") then
                -- the measurement is off by default
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_HASH_IMAGE_MASK or x"00000002");
                power_up_to_nic_done(net);
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_HASH_START_MASK or x"00000012");
                wait for 100 us;
                check_equal(hash_requests, 1, "Expected only the power-up measurement");
                read_bus(net, bus_handle,
                         To_StdLogicVector(NIC_HASH_STATUS_OFFSET, bus_handle.p_address_length),
                         read_data);
                hash_status := unpack(read_data);
                check_equal(hash_status.refused, '1', "Expected the start recorded as refused");
                check_equal(hash_status.done, '1', "Expected the power-up measurement left standing");

            elsif run("por_b_needs_the_rails") then
                -- Even by override, and whatever the measurement is doing
                -- the measurement is off by default
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_HASH_IMAGE_MASK or x"00000002");
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_OVERRIDES_OFFSET, bus_handle.p_address_length),
                          VERSAL_OVERRIDES_POR_B_MASK or VERSAL_OVERRIDES_MODE_BUFFER_EN_L_MASK);
                write_bus(net, bus_handle,
                          To_StdLogicVector(DEBUG_ENABLES_OFFSET, bus_handle.p_address_length),
                          DEBUG_ENABLES_NIC_OVERRIDE_MASK);
                wait for 100 us;
                check_equal(versal_boot_pins.por_b, '0', "Expected POR_B held with the rails down");
                hash_model_time <= 400 us;
                write_bus(net, bus_handle,
                          To_StdLogicVector(POWER_CTRL_OFFSET, bus_handle.p_address_length),
                          POWER_CTRL_A0_EN_MASK);
                wait until versal_boot_pins.por_b = '1' for 50 ms;
                check_equal(versal_boot_pins.por_b, '1', "Expected the override to release POR_B");
                check_equal(nic_rails_up, '1', "Expected the rails up at POR_B release");
                check_equal(hash_req, '1', "Expected the measurement still in flight");
                disable_power_good(net, find("versal_v0p88"));
                wait for 1 us;
                check_equal(versal_boot_pins.por_b, '0', "Expected POR_B asserted on losing a rail");
                enable_power_good(net, find("versal_v0p88"));
                wait until hash_req = '0' for 50 ms;

            elsif run("failed_measurement_is_recorded_and_boot_continues") then
                -- the measurement is off by default
                write_bus(net, bus_handle,
                          To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                          VERSAL_BOOT_CTRL_HASH_IMAGE_MASK or x"00000002");
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

            elsif run("measurement_is_off_by_default") then
                read_bus(net, bus_handle,
                         To_StdLogicVector(VERSAL_BOOT_CTRL_OFFSET, bus_handle.p_address_length),
                         read_data);
                check_equal(read_data, std_logic_vector'(x"00000002"),
                            "Expected QSPI32 and no measurement out of reset");
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
