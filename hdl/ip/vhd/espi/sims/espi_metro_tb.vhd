-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- The same harness as espi_tb, built as a metro. Which board the target
-- reports is a generic, so it takes a second elaboration to see the other
-- value; anything that does not depend on the board belongs in espi_tb.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.espi_controller_vc_pkg.all;
use work.espi_platform_regs_pkg.all;

entity espi_metro_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of espi_metro_tb is
begin

    th: entity work.espi_th generic map (BOARD => METRO);

    bench: process
        alias    sim_reset     is <<signal th.reset : std_logic>>;
        alias    clk           is <<signal th.clk : std_logic>>;
        alias    nic_hash_digest is <<signal th.nic_hash_digest : std_logic_vector(255 downto 0)>>;
        alias    nic_hash_done is <<signal th.nic_hash_done : std_logic>>;
        alias    nic_hash_busy is <<signal th.nic_hash_busy : std_logic>>;
        alias    rehash_count  is <<signal th.rehash_count : natural>>;
        alias    done_clear_count is <<signal th.done_clear_count : natural>>;
        variable status        : std_logic_vector(15 downto 0);
        variable response_code : std_logic_vector(7 downto 0);
        variable data_32       : std_logic_vector(31 downto 0);
        variable crc_ok        : boolean;
        variable rehash_pulses : natural;
        variable clear_pulses  : natural;

        -- How many single-cycle strobes a SET_CONFIGURATION produces
        procedure set_hash_ctrl(constant value : std_logic_vector(31 downto 0)) is
            variable rehash_before : natural := rehash_count;
            variable clear_before : natural := done_clear_count;
        begin
            set_config(net, NIC_HASH_CTRL_OFFSET, value, response_code, status, crc_ok);
            check(crc_ok, "Set Config CRC Check failed");
            wait for 1 us;
            rehash_pulses := rehash_count - rehash_before;
            clear_pulses := done_clear_count - clear_before;
        end procedure;
    begin
        test_runner_setup(runner, runner_cfg);
        wait until sim_reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("board_id_reads_metro") then
                get_config(net, BOARD_ID_OFFSET, data_32, response_code, status, crc_ok);
                check(crc_ok, "CRC Check failed");
                check_equal(data_32, std_logic_vector'(x"00000001"), "Expected board_id to read as metro");

            elsif run("nic_hash_reads_zero_until_done") then
                -- Nothing to show before a measurement is done, then the
                -- digest a word at a time, least significant word first
                get_config(net, NIC_HASH_CTRL_OFFSET, data_32, response_code, status, crc_ok);
                check(crc_ok, "CRC Check failed");
                check_equal(data_32, std_logic_vector'(x"00000000"), "Expected nic_hash_ctrl clear");
                for w in 0 to 7 loop
                    get_config(net, NIC_HASH0_OFFSET + 4 * w, data_32, response_code, status, crc_ok);
                    check(crc_ok, "CRC Check failed");
                    check_equal(data_32, std_logic_vector'(x"00000000"),
                                "Expected nic_hash" & integer'image(w) & " to read zero before done");
                end loop;
                nic_hash_done <= '1';
                wait for 100 ns;
                get_config(net, NIC_HASH_CTRL_OFFSET, data_32, response_code, status, crc_ok);
                check(crc_ok, "CRC Check failed");
                check_equal(data_32, NIC_HASH_CTRL_DONE_MASK, "Expected done in nic_hash_ctrl");
                for w in 0 to 7 loop
                    get_config(net, NIC_HASH0_OFFSET + 4 * w, data_32, response_code, status, crc_ok);
                    check(crc_ok, "CRC Check failed");
                    check_equal(data_32, nic_hash_digest(32 * w + 31 downto 32 * w),
                                "Expected nic_hash" & integer'image(w) & " to read its digest word");
                end loop;
                nic_hash_busy <= '1';
                wait for 100 ns;
                get_config(net, NIC_HASH_CTRL_OFFSET, data_32, response_code, status, crc_ok);
                check(crc_ok, "CRC Check failed");
                check_equal(data_32, NIC_HASH_CTRL_DONE_MASK or NIC_HASH_CTRL_REHASH_MASK,
                            "Expected rehash shown while the measurement is busy");
                nic_hash_busy <= '0';
                nic_hash_done <= '0';

            elsif run("nic_hash_rehash_write_strobes") then
                set_hash_ctrl(NIC_HASH_CTRL_REHASH_MASK);
                check_equal(rehash_pulses, 1, "Expected one rehash strobe");
                check_equal(clear_pulses, 0, "Expected no done_clear strobe");

            elsif run("nic_hash_done_clear_write_strobes") then
                set_hash_ctrl(NIC_HASH_CTRL_DONE_MASK);
                check_equal(clear_pulses, 1, "Expected one done_clear strobe");
                check_equal(rehash_pulses, 0, "Expected no rehash strobe");
                -- writing zeros does nothing
                set_hash_ctrl(x"00000000");
                check_equal(clear_pulses, 0, "Expected no done_clear strobe from a zero write");
                check_equal(rehash_pulses, 0, "Expected no rehash strobe from a zero write");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);
end tb;
