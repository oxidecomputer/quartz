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

use work.crc16_pkg.all;
use work.crc_sim_pkg.all;

-- Pins the CRC8/ATM and CRC-16/CCITT-FALSE implementations, both the RTL
-- registers and the simulation reference functions, to the check vectors in
-- RFD 693 and to the published "123456789" check values.
entity crc_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of crc_tb is

    constant check_string : string := "123456789";

begin

    th: entity work.crc_th;

    bench: process
        -- Note: external names are broken in GHDL llvm backends
        -- https://github.com/ghdl/ghdl/issues/2610 so this sim wants nvc.
        alias clk   is << signal th.clk : std_logic >>;
        alias reset is << signal th.reset : std_logic >>;

        alias crc8_data   is << signal th.crc8_data : std_logic_vector(7 downto 0) >>;
        alias crc8_enable is << signal th.crc8_enable : std_logic >>;
        alias crc8_clear  is << signal th.crc8_clear : std_logic >>;
        alias crc8_out    is << signal th.crc8_out : std_logic_vector(7 downto 0) >>;

        alias crc16_data   is << signal th.crc16_data : std_logic_vector(7 downto 0) >>;
        alias crc16_enable is << signal th.crc16_enable : std_logic >>;
        alias crc16_clear  is << signal th.crc16_clear : std_logic >>;
        alias crc16_out    is << signal th.crc16_out : std_logic_vector(15 downto 0) >>;

        variable q      : queue_t;
        variable crc8   : std_logic_vector(7 downto 0);
        variable crc16  : crc16_t;
        variable model  : crc16_t;

        impure function string_queue (s : string) return queue_t is
            variable ret : queue_t := new_queue;
        begin
            for i in s'range loop
                push_byte(ret, character'pos(s(i)));
            end loop;
            return ret;
        end function;

        impure function counting_queue (len : natural) return queue_t is
            variable ret : queue_t := new_queue;
        begin
            for i in 0 to len - 1 loop
                push_byte(ret, i mod 256);
            end loop;
            return ret;
        end function;

        -- Clock one byte into the CRC8 register. The register updates on the
        -- rising edge after we return, so callers wait a cycle before looking.
        procedure feed_crc8 (
            byte : std_logic_vector(7 downto 0)
        ) is
        begin
            wait until falling_edge(clk);
            crc8_data   <= force byte;
            crc8_enable <= force '1';
            wait until falling_edge(clk);
            crc8_enable <= force '0';
        end procedure;

        procedure feed_crc16 (
            byte : std_logic_vector(7 downto 0)
        ) is
        begin
            wait until falling_edge(clk);
            crc16_data   <= force byte;
            crc16_enable <= force '1';
            wait until falling_edge(clk);
            crc16_enable <= force '0';
        end procedure;

        -- Run a copy of the queue through the RTL register, leaving the
        -- caller's queue intact for the model to consume.
        procedure feed_crc8_queue (
            data : queue_t
        ) is
            constant copied : queue_t := copy(data);
        begin
            while not is_empty(copied) loop
                feed_crc8(To_StdLogicVector(pop_byte(copied), 8));
            end loop;
        end procedure;

        procedure feed_crc16_queue (
            data : queue_t
        ) is
            constant copied : queue_t := copy(data);
        begin
            while not is_empty(copied) loop
                feed_crc16(To_StdLogicVector(pop_byte(copied), 8));
            end loop;
        end procedure;

        procedure clear_crc16 is
        begin
            wait until falling_edge(clk);
            crc16_clear <= force '1';
            wait until falling_edge(clk);
            crc16_clear <= force '0';
        end procedure;

        -- Feed payload then the CRC bytes, high byte first, and return the
        -- register value. This is what the receive side of a link sees.
        impure function model_residue (
            data : queue_t;
            crc : crc16_t
        ) return crc16_t is
            constant copied : queue_t := copy(data);
            variable ret : crc16_t := crc16_init;
        begin
            while not is_empty(copied) loop
                ret := crc16_next(ret, To_StdLogicVector(pop_byte(copied), 8));
            end loop;
            ret := crc16_next(ret, crc(15 downto 8));
            ret := crc16_next(ret, crc(7 downto 0));
            return ret;
        end function;
    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 100 ns;

        while test_suite loop
            if run("crc8_model_vectors") then
                q := string_queue(check_string);
                check_equal(crc8_atm(q), std_logic_vector'(X"F4"), "CRC8/ATM check string");
                q := new_queue;
                push_byte(q, 16#01#);
                push_byte(q, 16#2A#);
                check_equal(crc8_atm(q), std_logic_vector'(X"C3"), "CRC8/ATM over ChannelID=0x01 Seq=0x2A");
                check_equal(crc8_atm(q, gen_invalid_crc => true), std_logic_vector'(not X"C3"), "Invalid CRC flag inverts");
            elsif run("crc8_rtl_vectors") then
                check_equal(crc8_out, std_logic_vector'(X"00"), "CRC8 register did not reset to the seed");
                q := string_queue(check_string);
                feed_crc8_queue(q);
                check_equal(crc8_out, std_logic_vector'(X"F4"), "CRC8 RTL check string");
                wait until falling_edge(clk);
                crc8_clear <= force '1';
                wait until falling_edge(clk);
                crc8_clear <= force '0';
                check_equal(crc8_out, std_logic_vector'(X"00"), "CRC8 clear did not restore the seed");
                feed_crc8(X"01");
                feed_crc8(X"2A");
                check_equal(crc8_out, std_logic_vector'(X"C3"), "CRC8 RTL over header fields");
            elsif run("crc16_model_vectors") then
                q := string_queue(check_string);
                check_equal(crc16_ccitt(q), std_logic_vector'(X"29B1"), "CRC16 check string");
                q := counting_queue(8);
                check_equal(crc16_ccitt(q), std_logic_vector'(X"178D"), "CRC16 over 0x00..0x07");
                -- The RFD's argument for the non-zero seed: runs of zeros of
                -- different lengths must not collide.
                q := counting_queue(0);
                push_byte(q, 0); push_byte(q, 0); push_byte(q, 0); push_byte(q, 0);
                check_equal(crc16_ccitt(q), std_logic_vector'(X"84C0"), "CRC16 over four zero bytes");
                push_byte(q, 0); push_byte(q, 0); push_byte(q, 0); push_byte(q, 0);
                check_equal(crc16_ccitt(q), std_logic_vector'(X"313E"), "CRC16 over eight zero bytes");
                q := string_queue(check_string);
                check_equal(crc16_ccitt(q, gen_invalid_crc => true), std_logic_vector'(not X"29B1"), "Invalid CRC flag inverts");
            elsif run("crc16_rtl_vectors") then
                check_equal(crc16_out, crc16_init, "CRC16 register did not reset to the seed");
                q := string_queue(check_string);
                feed_crc16_queue(q);
                check_equal(crc16_out, std_logic_vector'(X"29B1"), "CRC16 RTL check string");
                clear_crc16;
                check_equal(crc16_out, crc16_init, "CRC16 clear did not restore the seed");
                q := counting_queue(8);
                feed_crc16_queue(q);
                check_equal(crc16_out, std_logic_vector'(X"178D"), "CRC16 RTL over 0x00..0x07");
                -- clear beats enable in the same cycle
                wait until falling_edge(clk);
                crc16_data   <= force X"A5";
                crc16_enable <= force '1';
                crc16_clear  <= force '1';
                wait until falling_edge(clk);
                crc16_enable <= force '0';
                crc16_clear  <= force '0';
                check_equal(crc16_out, crc16_init, "Clear did not take priority over enable");
            elsif run("crc16_residues") then
                -- A receiver runs the CRC over the payload and the two CRC
                -- bytes that follow it. That lands on a constant, which is
                -- how it checks a packet without knowing the length up front.
                for len in 0 to 300 loop
                    q := counting_queue(len);
                    crc16 := crc16_ccitt(q);
                    check_equal(model_residue(q, crc16), crc16_residue_good,
                                "Good residue for payload length " & to_string(len));
                    check_equal(model_residue(q, not crc16), crc16_residue_abort,
                                "Abort residue for payload length " & to_string(len));
                end loop;

                -- Same through the RTL register for a couple of lengths.
                for len in 0 to 3 loop
                    q := counting_queue(len * 5);
                    crc16 := crc16_ccitt(q);
                    clear_crc16;
                    feed_crc16_queue(q);
                    feed_crc16(crc16(15 downto 8));
                    feed_crc16(crc16(7 downto 0));
                    check_equal(crc16_out, crc16_residue_good, "RTL good residue, length " & to_string(len * 5));
                    clear_crc16;
                    feed_crc16_queue(q);
                    feed_crc16(not crc16(15 downto 8));
                    feed_crc16(not crc16(7 downto 0));
                    check_equal(crc16_out, crc16_residue_abort, "RTL abort residue, length " & to_string(len * 5));
                end loop;

                -- And a corrupted packet lands on neither.
                q := counting_queue(16);
                crc16 := crc16_ccitt(q);
                model := crc16_init;
                for i in 0 to 15 loop
                    if i = 7 then
                        model := crc16_next(model, X"07" xor X"10");
                    else
                        model := crc16_next(model, to_std_logic_vector(i, 8));
                    end if;
                end loop;
                model := crc16_next(model, crc16(15 downto 8));
                model := crc16_next(model, crc16(7 downto 0));
                check(model /= crc16_residue_good, "Corrupted payload passed as good");
                check(model /= crc16_residue_abort, "Corrupted payload passed as aborted");
            end if;
        end loop;

        wait for 1 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

end tb;
