-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.calc_pkg.all;

entity aligner_10bk28_5 is
    generic(
        MIN_PATTERNS_TO_LOCK : positive;
        MAX_SYMBOLS_BEFORE_SLIP : positive
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        data_in     : in  std_logic_vector(9 downto 0);
        data_in_valid : in  std_logic;
        data_in_align_ready : out std_logic;

        downstream_ready : in std_logic;
        downstream_valid : out std_logic;
    
        -- control interface
        realign     : in  std_logic;
        bit_slip    : out  std_logic;
        is_locked   : out  std_logic
    );
end entity;

architecture rtl of aligner_10bk28_5 is
    constant K28_5n : std_logic_vector(9 downto 0) := "1010000011"; --jh..ba
    constant K28_5p : std_logic_vector(9 downto 0) := not K28_5n; -- k28.5 is polarity symmetric
    constant ALIGN_CNTS_SIZE : integer := num_bits_needed(MIN_PATTERNS_TO_LOCK) + 1;
    constant SYMBOL_CNTS_SIZE : integer := num_bits_needed(MAX_SYMBOLS_BEFORE_SLIP) + 1;
    type state_type is (LOCKING, LOCKED, SLIP);
    signal state : state_type;
    signal align_cnts : std_logic_vector(ALIGN_CNTS_SIZE - 1 downto 0);
    signal symbol_cnts : std_logic_vector(SYMBOL_CNTS_SIZE - 1 downto 0);

begin

    -- Want to consume the data when we're  un-algined and pass it 
    -- downstream when we're aligned.
    data_in_align_ready <= '1' when state /= LOCKED else 
                           downstream_ready;
    downstream_valid <= '0' when state /= LOCKED else data_in_valid;                   


    bit_slip <= '1' when state = SLIP else '0';
    is_locked <= '1' when state = LOCKED else '0';
    process(clk, reset)
    begin
        if reset then
            state <= LOCKING;
            align_cnts <= (others => '0');
            symbol_cnts <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                when LOCKING =>
                    -- In this state, align-cnts going up is good, it means that
                    -- we are seeing the alignment pattern before we expire the
                    -- MAX SYMBOLS BEFORE SLIP

                    -- Data is valid right now
                    if data_in_valid = '1' and data_in_align_ready = '1' then
                        
                        if ((data_in = K28_5n) or (data_in = K28_5p)) and align_cnts < MIN_PATTERNS_TO_LOCK then
                            -- Found alignment pattern count it, 0 the symbole counter and continue
                            align_cnts <= align_cnts + 1;
                            symbol_cnts <= (others => '0');
                        else
                            -- Not what we're looking for run the symbol counter
                            symbol_cnts <= symbol_cnts + 1;
                        end if;

                    end if;
                    if align_cnts = MIN_PATTERNS_TO_LOCK then
                        state <= LOCKED;
                        align_cnts <= (others => '0');
                    elsif symbol_cnts >= MAX_SYMBOLS_BEFORE_SLIP then
                        state <= SLIP;
                    end if;

                when LOCKED =>
                    -- In this state, the align cnts going up is bad, it means that
                    -- we've crossed the MAX SYMBOLS BEFORE SLIP. We provide a 3x
                    -- hysteresis here before falling out of lock.
                    if realign = '1' then
                        state <= LOCKING;
                        align_cnts <= (others => '0');
                        symbol_cnts <= (others => '0');
                    elsif data_in_valid = '1' and data_in_align_ready = '1' then
                        if (data_in = K28_5n) or (data_in = K28_5p) then
                            -- Found alignment pattern again. reset the counters
                            align_cnts <=(others => '0');
                            symbol_cnts <= (others => '0');
                        else
                            if symbol_cnts >= MAX_SYMBOLS_BEFORE_SLIP then
                                align_cnts <= align_cnts + 1;
                                symbol_cnts <= (others => '0');
                            else
                                symbol_cnts <= symbol_cnts + 1;
                            end if;
                        end if;
                        if align_cnts >= MIN_PATTERNS_TO_LOCK then
                            state <= SLIP;
                            align_cnts <= (others => '0');
                            symbol_cnts <= (others => '0');
                        end if;
                    end if;

                when SLIP =>
                    -- Slipping now. 0 everything and start afresh
                    align_cnts <= (others => '0');
                    symbol_cnts <= (others => '0');
                    state <= LOCKING;

            end case;
        end if;
    end process;

end rtl;