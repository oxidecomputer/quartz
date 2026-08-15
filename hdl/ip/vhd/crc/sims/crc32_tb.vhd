-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.crc_sim_pkg.all;

entity crc32_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of crc32_tb is
begin

    th: entity work.crc32_th;

    bench: process
        alias clk     is << signal th.clk     : std_logic >>;
        alias reset   is << signal th.reset   : std_logic >>;
        alias data_in is << signal th.data_in : std_logic_vector(7 downto 0) >>;
        alias enable  is << signal th.enable  : std_logic >>;
        alias clear   is << signal th.clear   : std_logic >>;
        alias crc_out is << signal th.crc_out : std_logic_vector(31 downto 0) >>;

        -- "123456789", the standard CRC check-value input
        constant CHECK_STRING : string := "123456789";
        -- CRC-32/ISO-HDLC ("Ethernet") check value for "123456789"
        constant CHECK_VALUE : std_logic_vector(31 downto 0) := X"CBF43926";

        variable frame : queue_t := new_queue;
        variable fcs   : std_logic_vector(31 downto 0);

        -- fixed but non-trivial byte pattern; no need for real randomness
        function pat(i : natural) return natural is
        begin
            return (i * 37 + 11) mod 256;
        end function;

        procedure feed_byte(constant b : std_logic_vector(7 downto 0)) is
        begin
            data_in <= b;
            enable  <= '1';
            wait until rising_edge(clk);
            enable <= '0';
            -- let crc_out settle past the edge so callers can check it
            wait for 1 ns;
        end procedure;

        procedure do_clear is
        begin
            clear <= '1';
            wait until rising_edge(clk);
            clear <= '0';
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 50 ns;
        wait until rising_edge(clk);

        while test_suite loop
            if run("check_value") then
                -- the complemented register is the standard CRC result
                for i in CHECK_STRING'range loop
                    feed_byte(std_logic_vector(to_unsigned(character'pos(CHECK_STRING(i)), 8)));
                end loop;
                check_equal(not crc_out, CHECK_VALUE, "CRC32 of '123456789'");

            elsif run("matches_sim_reference") then
                do_clear;
                frame := new_queue;
                for i in 0 to 63 loop
                    push_byte(frame, pat(i));
                end loop;
                fcs := crc32_ethernet(frame);
                for i in 0 to 63 loop
                    feed_byte(std_logic_vector(to_unsigned(pop_byte(frame), 8)));
                end loop;
                check_equal(not crc_out, fcs, "hardware CRC vs sim reference");

            elsif run("good_fcs_leaves_residue") then
                do_clear;
                frame := new_queue;
                for i in 0 to 99 loop
                    push_byte(frame, pat(i));
                end loop;
                fcs := crc32_ethernet(frame);
                for i in 0 to 99 loop
                    feed_byte(std_logic_vector(to_unsigned(pop_byte(frame), 8)));
                end loop;
                -- FCS goes over the wire low byte first
                for i in 0 to 3 loop
                    feed_byte(fcs(8 * i + 7 downto 8 * i));
                end loop;
                check_equal(crc_out, ETH_CRC32_RESIDUE, "register residue after good frame+FCS");

            elsif run("bad_fcs_breaks_residue") then
                do_clear;
                frame := new_queue;
                for i in 0 to 99 loop
                    push_byte(frame, pat(3 * i + 1));
                end loop;
                fcs := crc32_ethernet(frame, gen_invalid_crc => true);
                for i in 0 to 99 loop
                    feed_byte(std_logic_vector(to_unsigned(pop_byte(frame), 8)));
                end loop;
                for i in 0 to 3 loop
                    feed_byte(fcs(8 * i + 7 downto 8 * i));
                end loop;
                check_true(crc_out /= ETH_CRC32_RESIDUE, "corrupt FCS must not leave the residue");
            end if;
        end loop;

        wait for 100 ns;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);
end tb;
