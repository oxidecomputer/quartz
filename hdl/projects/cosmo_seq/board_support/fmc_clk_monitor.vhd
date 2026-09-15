-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Supervises the MMCM that sits on the SP's continuous FMC clock.
--
-- The SP's clock stops whenever the SP resets or reconfigures, and an
-- MMCME2 whose input clock went away is not guaranteed to relock on its
-- own when the clock returns -- AMD's guidance is to assert its reset
-- across a clock interruption. This block watches the raw clock pin as
-- ordinary data in the always-running 125 MHz domain and holds the MMCM
-- in reset while the clock is absent, releasing it (and letting it
-- relock) once the clock is back. While the MMCM is unlocked the FMC
-- domain has no clock and reset_fmc is held asserted (see reset_sync),
-- so the wait line sits asserted and the SP's first post-reset access
-- simply stalls until lock -- nothing needs to sequence against this.
--
-- The transition count is aliased (a 100 MHz toggle sampled at 125 MHz)
-- so it is a presence detector, not a frequency measurement: an absent
-- clock counts zero transitions, any live SP rate counts hundreds per
-- window. Frequency changes (the CLKDIV flip) drop the MMCM's own LOCKED
-- while the clock keeps toggling; the relock timer covers that case by
-- pulsing reset if LOCKED stays low too long with a clock present.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fmc_clk_monitor is
    generic (
        -- observation window, in clk cycles (256 @ 125 MHz ~= 2 us)
        window_cycles : positive := 256;
        -- fewer transitions than this in a window means "clock absent"
        min_transitions : positive := 16;
        -- windows of LOCKED low with a live clock before a relock retry
        -- (128 windows ~= 260 us, comfortably past the ~100 us max lock time)
        relock_windows : positive := 128;
        -- windows of live clock required before releasing mmcm_reset
        settle_windows : positive := 4
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;
        -- the FMC clock pin, sampled as data
        fmc_clk_raw : in std_logic;
        -- LOCKED from the MMCM, async
        mmcm_locked : in std_logic;
        mmcm_reset : out std_logic
    );
end entity;

architecture rtl of fmc_clk_monitor is

    signal raw_meta   : std_logic_vector(1 downto 0);
    signal raw_prev   : std_logic;
    signal locked_meta : std_logic_vector(1 downto 0);

    signal window_cntr     : natural range 0 to window_cycles - 1;
    signal transition_cntr : natural range 0 to window_cycles;
    signal clk_present     : boolean;

    signal settle_cntr : natural range 0 to settle_windows;
    signal unlock_cntr : natural range 0 to relock_windows;

begin

    monitor: process(clk, reset)
    begin
        if reset then
            raw_meta        <= (others => '0');
            raw_prev        <= '0';
            locked_meta     <= (others => '0');
            window_cntr     <= 0;
            transition_cntr <= 0;
            clk_present     <= false;
            settle_cntr     <= 0;
            unlock_cntr     <= 0;
            mmcm_reset      <= '1';
        elsif rising_edge(clk) then
            raw_meta    <= raw_meta(0) & fmc_clk_raw;
            raw_prev    <= raw_meta(1);
            locked_meta <= locked_meta(0) & mmcm_locked;

            if window_cntr = window_cycles - 1 then
                window_cntr     <= 0;
                clk_present     <= transition_cntr >= min_transitions;
                transition_cntr <= 0;

                if transition_cntr < min_transitions then
                    -- clock gone: hold the MMCM in reset and start over
                    mmcm_reset  <= '1';
                    settle_cntr <= 0;
                    unlock_cntr <= 0;
                elsif settle_cntr /= settle_windows then
                    -- clock is back; give it a few clean windows before
                    -- releasing the MMCM
                    settle_cntr <= settle_cntr + 1;
                    unlock_cntr <= 0;
                elsif mmcm_reset = '1' then
                    mmcm_reset <= '0';
                elsif locked_meta(1) = '0' then
                    -- clock alive but no lock (e.g. the input frequency
                    -- changed): retry after a generous wait
                    if unlock_cntr = relock_windows then
                        mmcm_reset  <= '1';
                        settle_cntr <= 0;
                        unlock_cntr <= 0;
                    else
                        unlock_cntr <= unlock_cntr + 1;
                    end if;
                else
                    unlock_cntr <= 0;
                end if;
            else
                window_cntr <= window_cntr + 1;
                if (raw_meta(1) xor raw_prev) = '1'
                    and transition_cntr /= window_cycles then
                    transition_cntr <= transition_cntr + 1;
                end if;
            end if;
        end if;
    end process;

end architecture;
