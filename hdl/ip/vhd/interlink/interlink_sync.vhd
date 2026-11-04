-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Receive lock state machine. The RFD leaves the lock criteria to the
-- implementor, so this is one reasonable choice: once the aligner has found
-- the comma, read the polarity off the next IDLE, then count good IDLEs to
-- declare lock. Lock is dropped on a run of bad IDLEs, on going too long
-- without any IDLE, or when the aligner lets go.
--
-- Polarity is only ever evaluated while unlocked and is held through a loss
-- of lock, since the wires do not change sides at runtime and keeping the
-- inversion in place makes re-acquisition faster.
entity interlink_sync is
    generic (
        IDLES_TO_LOCK : positive;
        BAD_IDLES_TO_UNLOCK : positive;
        -- Byte cycles without a good IDLE before we give up on the partner.
        IDLE_TIMEOUT : positive
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        -- Drop lock and start over, also realigns the comma aligner.
        link_reset : in std_logic;

        rx_aligned : in std_logic;
        -- One pulse per received character, the timeout is measured in these.
        char_valid : in std_logic;
        -- From the deframer's IDLE parser. pol_inverted is relative to the
        -- correction already being applied: it says the stream still looks
        -- inverted after it.
        idle_good : in std_logic;
        idle_bad : in std_logic;
        pol_valid : in std_logic;
        pol_inverted : in std_logic;
        partner_scramble : in std_logic;

        rx_locked : out std_logic;
        polarity_inverted : out std_logic;
        descramble_enable : out std_logic;
        lock_lost : out std_logic;
        realign : out std_logic
    );
end entity;

architecture rtl of interlink_sync is
    type state_t is (UNLOCKED, POL_HUNT, ACQUIRE, LOCKED);

    type reg_t is record
        state : state_t;
        inverted : std_logic;
        good_cnt : natural range 0 to IDLES_TO_LOCK;
        bad_cnt : natural range 0 to BAD_IDLES_TO_UNLOCK;
        timeout : natural range 0 to IDLE_TIMEOUT;
        lock_lost : std_logic;
    end record;
    constant rec_reset : reg_t := (
        state => UNLOCKED,
        inverted => '0',
        good_cnt => 0,
        bad_cnt => 0,
        timeout => 0,
        lock_lost => '0'
    );

    signal r, rin : reg_t;
begin

    rx_locked <= '1' when r.state = LOCKED else '0';
    polarity_inverted <= r.inverted;
    -- Decoded data depends on the polarity being right, so nothing gets
    -- de-scrambled until we are locked and the partner says it scrambles.
    descramble_enable <= '1' when r.state = LOCKED and partner_scramble = '1' else '0';
    lock_lost <= r.lock_lost;
    realign <= link_reset;

    sm: process(all)
        variable v : reg_t;
    begin
        v := r;
        v.lock_lost := '0';

        case r.state is
            when UNLOCKED =>
                if rx_aligned = '1' and link_reset = '0' then
                    v.state := POL_HUNT;
                end if;

            when POL_HUNT =>
                if pol_valid = '1' then
                    -- relative to the correction already applied
                    v.inverted := r.inverted xor pol_inverted;
                    v.good_cnt := 0;
                    v.state := ACQUIRE;
                end if;

            when ACQUIRE =>
                -- The IDLE that revealed an inversion decoded its seed and
                -- flags the wrong way round and fails its CRC, so a bad IDLE
                -- here is expected and does not restart the count. A good one
                -- can only come through once the inversion is right.
                if pol_valid = '1' and pol_inverted = '1' then
                    v.inverted := not r.inverted;
                    v.good_cnt := 0;
                elsif idle_good = '1' then
                    if r.good_cnt = IDLES_TO_LOCK - 1 then
                        v.state := LOCKED;
                        v.bad_cnt := 0;
                        v.timeout := 0;
                    else
                        v.good_cnt := r.good_cnt + 1;
                    end if;
                end if;

            when LOCKED =>
                if idle_good = '1' then
                    v.bad_cnt := 0;
                    v.timeout := 0;
                elsif idle_bad = '1' then
                    if r.bad_cnt = BAD_IDLES_TO_UNLOCK - 1 then
                        v.state := UNLOCKED;
                        v.lock_lost := '1';
                    else
                        v.bad_cnt := r.bad_cnt + 1;
                    end if;
                elsif char_valid = '1' then
                    if r.timeout = IDLE_TIMEOUT - 1 then
                        v.state := UNLOCKED;
                        v.lock_lost := '1';
                    else
                        v.timeout := r.timeout + 1;
                    end if;
                end if;
        end case;

        if r.state /= UNLOCKED and (rx_aligned = '0' or link_reset = '1') then
            v.state := UNLOCKED;
            if r.state = LOCKED then
                v.lock_lost := '1';
            end if;
        end if;

        rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;
