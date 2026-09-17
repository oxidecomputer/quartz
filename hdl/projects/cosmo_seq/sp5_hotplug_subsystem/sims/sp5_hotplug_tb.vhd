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

use work.pca9506_regs_pkg.all;
use work.i2c_pca9506ish_sim_pkg.all;

-- Slot-level behaviour of the two NIC hotplug slots, as the SP5 sees them
-- through the emulated PCA9506: bank 2 (the T6 slot cosmo has always had) and
-- bank 4 (the second slot metro adds). The expander itself is covered by
-- i2c_pca9506ish_tb; this is about the wiring from its bits to the slot pins.
entity sp5_hotplug_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of sp5_hotplug_tb is
    constant hp_addr : std_logic_vector(6 downto 0) := b"0100_010";
    -- AMD Mode A: bit 4 of each bank is PWR_EN_L, an output from the SP5.
    constant ALL_INPUTS : std_logic_vector(7 downto 0) := x"FF";
    constant PWR_EN_AS_OUTPUT : std_logic_vector(7 downto 0) := x"EF";
    constant PWR_EN_ASSERTED : std_logic_vector(7 downto 0) := x"00";
    constant PWR_EN_DEASSERTED : std_logic_vector(7 downto 0) := x"10";
begin

    th: entity work.sp5_hotplug_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias t6_power_en is << signal th.t6_power_en : std_logic >>;
        alias t6_perst_l is << signal th.t6_perst_l : std_logic >>;
        alias t6_faulted is << signal th.t6_faulted : std_logic >>;
        alias t6_prsnt_l is << signal th.t6_prsnt_l : std_logic >>;
        alias nic2_power_en is << signal th.nic2_power_en : std_logic >>;
        alias nic2_perst_l is << signal th.nic2_perst_l : std_logic >>;
        alias nic2_faulted is << signal th.nic2_faulted : std_logic >>;
        alias nic2_prsnt_l is << signal th.nic2_prsnt_l : std_logic >>;
        variable ack_status : boolean;
        constant rx_queue : queue_t := new_queue;
        constant ack_queue : queue_t := new_queue;
        variable ip : std_logic_vector(7 downto 0);

        -- Drive a bank's PWR_EN_L through the expander: configure bit 4 as an
        -- output, then write it.
        procedure set_pwr_en(bank : natural; asserted : boolean) is
        begin
            single_write_pca9506_reg(net, hp_addr, I2C_IOC0_OFFSET + bank, PWR_EN_AS_OUTPUT, ack_status);
            if asserted then
                single_write_pca9506_reg(net, hp_addr, I2C_OP0_OFFSET + bank, PWR_EN_ASSERTED, ack_status);
            else
                single_write_pca9506_reg(net, hp_addr, I2C_OP0_OFFSET + bank, PWR_EN_DEASSERTED, ack_status);
            end if;
            wait for 200 ns;
        end procedure;

        procedure read_ip(bank : natural; variable value : out std_logic_vector(7 downto 0)) is
        begin
            read_pca9506_reg(net, hp_addr, I2C_IP0_OFFSET + bank, 1, rx_queue, ack_queue);
            flush(ack_queue);
            value := to_std_logic_vector(pop_byte(rx_queue), 8);
        end procedure;
    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("nic_slot_power_enable_follows_expander") then
                check_equal(t6_power_en, '0', "NIC slot must be off out of reset");
                set_pwr_en(2, true);
                check_equal(t6_power_en, '1', "PWR_EN_L low should enable the NIC slot");
                check_equal(t6_perst_l, '1', "PERST follows the power enable on this slot");
                set_pwr_en(2, false);
                check_equal(t6_power_en, '0', "PWR_EN_L high should disable the NIC slot");
                check_equal(t6_perst_l, '0', "PERST follows the power enable on this slot");

            elsif run("nic2_slot_power_enable_follows_expander") then
                check_equal(nic2_power_en, '0', "second NIC slot must be off out of reset");
                set_pwr_en(4, true);
                check_equal(nic2_power_en, '1', "PWR_EN_L low should enable the second NIC slot");
                check_equal(nic2_perst_l, '1', "PERST follows the power enable on this slot");
                set_pwr_en(4, false);
                check_equal(nic2_power_en, '0', "PWR_EN_L high should disable the second NIC slot");
                check_equal(nic2_perst_l, '0', "PERST follows the power enable on this slot");

            elsif run("nic_slots_are_independent") then
                set_pwr_en(2, true);
                check_equal(nic2_power_en, '0', "enabling bank 2 must not enable bank 4");
                set_pwr_en(4, true);
                check_equal(t6_power_en, '1', "bank 2 stays enabled when bank 4 is enabled");
                set_pwr_en(2, false);
                check_equal(nic2_power_en, '1', "disabling bank 2 must not disable bank 4");

            elsif run("power_enable_ignored_until_bank_is_configured") then
                -- The guard used to look at bank 0's direction bit, so
                -- configuring M.2 A as an output would have let a still-input
                -- bank 2 turn the NIC on. Configure everything *but* bank 2 and
                -- bank 4 as outputs and write their OP bits low: neither NIC
                -- slot may move.
                for bank in 0 to 3 loop
                    if bank /= 2 then
                        single_write_pca9506_reg(net, hp_addr, I2C_IOC0_OFFSET + bank, PWR_EN_AS_OUTPUT, ack_status);
                    end if;
                end loop;
                single_write_pca9506_reg(net, hp_addr, I2C_OP0_OFFSET + 2, PWR_EN_ASSERTED, ack_status);
                single_write_pca9506_reg(net, hp_addr, I2C_OP0_OFFSET + 4, PWR_EN_ASSERTED, ack_status);
                wait for 200 ns;
                check_equal(t6_power_en, '0', "bank 2 still an input: NIC slot must stay off");
                check_equal(nic2_power_en, '0', "bank 4 still an input: second NIC slot must stay off");

            elsif run("nic_slots_report_presence_and_fault") then
                -- Both present, no fault: PRSNT_L low, PWRFLT_L high.
                read_ip(2, ip);
                check_equal(ip(0), '0', "bank 2 PRSNT_L should follow the presence input");
                check_equal(ip(1), '1', "bank 2 PWRFLT_L should be deasserted with no fault");
                read_ip(4, ip);
                check_equal(ip(0), '0', "bank 4 PRSNT_L should follow the presence input");
                check_equal(ip(1), '1', "bank 4 PWRFLT_L should be deasserted with no fault");

                t6_prsnt_l <= '1';
                nic2_faulted <= '1';
                wait for 200 ns;
                read_ip(2, ip);
                check_equal(ip(0), '1', "bank 2 PRSNT_L should deassert when the NIC is absent");
                read_ip(4, ip);
                check_equal(ip(1), '0', "bank 4 PWRFLT_L should assert on a fault");
                t6_prsnt_l <= '0';
                nic2_faulted <= '0';
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);
end tb;
