-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;

use work.lfsr8_pkg.all;

entity lfsr_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of lfsr_tb is

    -- The scrambler runs 255 characters before the state repeats.
    constant char_period : natural := 255;

    -- Hand-computed from the spec: seed 0xFF, eight Galois steps per
    -- character, reduction constant 0x71.
    type state_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

    constant expected_states : state_array_t(0 to 7) :=
    (
        X"FF", X"7E", X"CE", X"55", X"2A", X"95", X"33", X"C9"
    );

begin

    th: entity work.lfsr_th;

    bench: process
        -- Note: external names are broken in GHDL llvm backends
        -- https://github.com/ghdl/ghdl/issues/2610 so this sim wants nvc.
        alias clk        is << signal th.clk : std_logic >>;
        alias reset      is << signal th.reset : std_logic >>;
        alias sync_reset is << signal th.sync_reset : std_logic >>;

        alias load_valid is << signal th.load_valid : std_logic >>;
        alias load_data  is << signal th.load_data : std_logic_vector(7 downto 0) >>;

        alias data_valid is << signal th.data_valid : std_logic >>;
        alias plain_data is << signal th.plain_data : std_logic_vector(7 downto 0) >>;

        alias tx_state       is << signal th.tx_state : std_logic_vector(7 downto 0) >>;
        alias rx_state       is << signal th.rx_state : std_logic_vector(7 downto 0) >>;
        alias scrambled_data is << signal th.scrambled_data : std_logic_vector(7 downto 0) >>;
        alias recovered_data is << signal th.recovered_data : std_logic_vector(7 downto 0) >>;

        variable model_state : std_logic_vector(7 downto 0);
        variable held_state  : std_logic_vector(7 downto 0);
        variable payload     : std_logic_vector(7 downto 0);

        -- Present a character and step the reference model alongside the DUT.
        -- We apply on the falling edge and check before the next rising edge
        -- eats it so that the checks see the state that actually got XORed
        -- into this byte. The register hasn't advanced when we return, it does
        -- that on the next rising edge, and we leave data_valid asserted for
        -- the caller to drop.
        procedure send_char (
            byte : std_logic_vector(7 downto 0)
        ) is
        begin
            wait until falling_edge(clk);
            plain_data <= force byte;
            data_valid <= force '1';
            wait for 1 ns;
            check_equal(tx_state, model_state, "Scrambler state diverged from the reference model");
            check_equal(scrambled_data, byte xor model_state, "Scrambled byte is not plaintext xor state");
            check_equal(recovered_data, byte, "De-scrambler did not recover the plaintext");
            model_state := lfsr8_next_char(model_state);
        end procedure;
    begin
        test_runner_setup(runner, runner_cfg);

        -- The harness holds reset for the first 200 ns, well past the first
        -- clock edges, so getting past this wait means the async reset already
        -- did its job.
        wait until reset = '0';
        wait for 100 ns;

        model_state := lfsr8_seed;

        while test_suite loop
            if run("cold_start_seed") then
                check_equal(tx_state, lfsr8_seed, "Scrambler did not come out of reset at the seed");
                check_equal(rx_state, lfsr8_seed, "De-scrambler did not come out of reset at the seed");
            elsif run("state_sequence_matches_spec") then
                -- Check the first few states against the hand-computed values
                -- before we start trusting the model for the long runs.
                for i in expected_states'range loop
                    wait until falling_edge(clk);
                    check_equal(tx_state, expected_states(i), "Unexpected state at character " & to_string(i));
                    plain_data <= force X"00";
                    data_valid <= force '1';
                end loop;
            elsif run("free_running_period") then
                -- Walk a full lap of the sequence, checking the model the
                -- whole way, and make sure we land back on the seed without
                -- repeating early or touching the lock-up state.
                for i in 0 to char_period - 1 loop
                    payload := std_logic_vector(to_unsigned(i mod 256, 8));
                    send_char(payload);
                    check(tx_state /= X"00", "Scrambler reached the all-zero lock-up state");

                    if i > 0 then
                        check(tx_state /= lfsr8_seed, "Sequence repeated before the full 255 character period");
                    end if;
                end loop;

                -- The 255th character's advance lands on the next rising edge.
                wait until falling_edge(clk);
                data_valid <= force '0';
                check_equal(tx_state, lfsr8_seed, "Scrambler did not return to the seed after 255 characters");
            elsif run("holds_when_not_valid") then
                -- Control characters de-assert data_valid and must not
                -- disturb the register.
                send_char(X"A5");
                wait until falling_edge(clk);
                data_valid <= force '0';
                held_state := tx_state;

                for i in 0 to 9 loop
                    wait until falling_edge(clk);
                    check_equal(tx_state, held_state, "State advanced while data_valid was de-asserted");
                end loop;
            elsif run("external_load") then
                send_char(X"5A");
                wait until falling_edge(clk);
                data_valid <= force '0';
                load_data  <= force X"3C";
                load_valid <= force '1';
                wait until falling_edge(clk);
                load_valid <= force '0';
                check_equal(tx_state, std_logic_vector'(X"3C"), "External load did not take");
                check_equal(rx_state, std_logic_vector'(X"3C"), "External load did not reach the de-scrambler");

                -- A load in the same cycle as a character wins and we throw
                -- the character's advance away.
                model_state := X"3C";
                send_char(X"11");
                wait until falling_edge(clk);
                load_data  <= force X"80";
                load_valid <= force '1';
                data_valid <= force '1';
                wait until falling_edge(clk);
                load_valid <= force '0';
                data_valid <= force '0';
                check_equal(tx_state, std_logic_vector'(X"80"), "Load did not take priority over a valid character");
            elsif run("sync_reset_restores_seed") then
                for i in 0 to 4 loop
                    send_char(X"C3");
                end loop;

                check(tx_state /= lfsr8_seed, "State should have moved off the seed by now");
                wait until falling_edge(clk);
                data_valid <= force '0';
                sync_reset <= force '1';
                wait until falling_edge(clk);
                sync_reset <= force '0';
                check_equal(tx_state, lfsr8_seed, "Sync reset did not restore the seed");
            elsif run("async_reset_restores_seed") then
                for i in 0 to 4 loop
                    send_char(X"C3");
                end loop;

                wait until falling_edge(clk);
                data_valid <= force '0';
                check(tx_state /= lfsr8_seed, "State should have moved off the seed by now");

                -- Assert reset well away from a clock edge so we can show the
                -- seed comes back without waiting for one.
                wait for 1 ns;
                reset <= force '1';
                wait for 1 ns;
                check_equal(tx_state, lfsr8_seed, "Async reset did not restore the seed without a clock edge");
                reset <= release;
            end if;
        end loop;

        wait for 1 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

end tb;
