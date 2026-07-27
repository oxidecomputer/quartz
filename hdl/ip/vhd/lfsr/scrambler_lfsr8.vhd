-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lfsr8_pkg.all;

-- 8-bit additive scrambler built on a Galois LFSR, polynomial
-- x^8 + x^6 + x^5 + x^4 + 1 (taps at bits 6, 5 and 4, with x^8 as the
-- implicit feedback bit).
--
-- We XOR each non-control character with the current register state, then
-- advance the register eight Galois steps, one per data bit, to get the state
-- for the next character. De-scrambling is the identical operation so we use
-- this same entity on both the transmit and receive sides.
--
-- The LFSR free-runs: it advances on every character we see with data_valid
-- asserted, inter-packet filler included, and we don't reset it per packet or
-- per IDLE. The polynomial is primitive so we get the full 255 state period
-- out of it before the sequence repeats.
--
-- data_out is combinational in data_in so scrambling costs the character
-- stream no latency, only the register state is clocked.
entity scrambler_lfsr8 is
    generic (
        -- Cold-start value loaded on either reset. Must be non-zero, see
        -- lfsr8_seed.
        seed : std_logic_vector(7 downto 0) := lfsr8_seed
    );
    port (
        clk : in    std_logic;
        -- Asynchronous, active-high. Restores seed.
        reset : in    std_logic;
        -- Synchronous, active-high. Restores seed. This is the one a link
        -- reset would normally drive.
        sync_reset : in    std_logic;
        -- Load load_data into the register on the next clock. Beats
        -- data_valid, so a character in the same cycle still gets scrambled
        -- with the pre-load state but we throw its advance away.
        load_valid : in    std_logic;
        load_data : in    std_logic_vector(7 downto 0);
        -- Current register state, ie the keystream byte we're applying to
        -- data_in this cycle. Brought out for monitoring.
        lfsr_state : out   std_logic_vector(7 downto 0);
        -- Plaintext byte when scrambling, ciphertext byte when de-scrambling.
        data_in : in    std_logic_vector(7 downto 0);
        -- Assert for every scrambled character to advance the register.
        -- De-assert for control characters, which pass through unscrambled
        -- and leave the register alone.
        data_valid : in    std_logic;
        data_out : out   std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of scrambler_lfsr8 is

begin

    assert seed /= X"00"
        report "scrambler_lfsr8: seed must be non-zero, all-zeros is the LFSR lock-up state"
        severity failure;

    lfsr_reg: process(clk, reset)
    begin
        if reset then
            lfsr_state <= seed;
        elsif rising_edge(clk) then
            if sync_reset then
                lfsr_state <= seed;
            elsif load_valid then
                lfsr_state <= load_data;
            elsif data_valid then
                lfsr_state <= lfsr8_next_char(lfsr_state);
            end if;
        end if;
    end process;

    -- Additive scrambler, so scramble and de-scramble are the same XOR. We
    -- don't gate this with data_valid since whoever consumes it already knows
    -- which characters it marked as scrambled, and gating would just be more
    -- logic.
    data_out <= data_in xor lfsr_state;

end rtl;
