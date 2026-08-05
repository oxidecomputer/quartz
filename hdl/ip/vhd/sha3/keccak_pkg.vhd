-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Keccak-f[1600] and the SHA3-256 sponge parameters from FIPS 202.
--
-- Everything here is pure functions and elaboration-time constants so the same
-- code is both the synthesizable next-state logic in sha3_256 and the golden
-- model in the testbench, following the lfsr8_pkg precedent. The two constant
-- tables are *generated* rather than transcribed: 25 rotation offsets and 24
-- 64-bit round constants are a lot of hand-typed hex to get wrong, and the
-- generators are short enough to read.
--
-- The state is the usual 5x5 array of 64-bit lanes indexed [x][y]. Where the
-- sponge needs a flat lane index k (the rate block and the digest both run over
-- lanes in order), the mapping is k = x + 5y, ie x = k mod 5 and y = k / 5.
package keccak_pkg is

    subtype lane_t is std_logic_vector(63 downto 0);

    type state_t is array (0 to 4, 0 to 4) of lane_t;

    constant NUM_ROUNDS : positive := 24;

    -- SHA3-256: capacity 512 bits, so the rate is 1600 - 512 = 1088 bits.
    constant RATE_LANES  : positive := 17;
    constant RATE_BITS   : positive := RATE_LANES * 64;   -- 1088
    constant RATE_BYTES  : positive := RATE_BITS / 8;     -- 136

    -- The digest is 4 lanes, which fits inside one rate block, so SHA3-256
    -- never needs a squeeze permutation.
    constant DIGEST_LANES : positive := 4;
    constant DIGEST_BITS  : positive := DIGEST_LANES * 64;

    subtype rate_block_t is std_logic_vector(RATE_BITS - 1 downto 0);
    subtype digest_t is std_logic_vector(DIGEST_BITS - 1 downto 0);

    -- Domain separation and padding bytes for pad10*1. The 0x06 prefix is
    -- SHA3-specific: SHAKE uses 0x1F and original Keccak uses 0x01.
    constant PAD_FIRST : std_logic_vector(7 downto 0) := X"06";
    constant PAD_LAST  : std_logic_vector(7 downto 0) := X"80";
    constant PAD_ONLY  : std_logic_vector(7 downto 0) := X"86";

    -- Left rotation, towards increasing z. This is the direction Keccak means
    -- everywhere, including theta's rotate-by-one.
    function rotl (
        v : lane_t;
        n : natural
    ) return lane_t;

    -- One round of Keccak-f[1600]: theta, rho, pi, chi, iota.
    function keccak_round (
        a  : state_t;
        rc : lane_t
    ) return state_t;

    -- All 24 rounds. Not used by the RTL, which runs one round per cycle, but
    -- it is what the testbench golden model and the round-function known-answer
    -- test are built on.
    function keccak_f1600 (
        a : state_t
    ) return state_t;

    -- XOR a full rate block into the state. Lane k takes block bytes 8k..8k+7
    -- little-endian, per FIPS 202 B.1, so block byte j lives at bits
    -- 8j+7 downto 8j of blk.
    function absorb_block (
        a   : state_t;
        blk : rate_block_t
    ) return state_t;

    -- The 256-bit digest. Bits 7 downto 0 are hash byte 0, ie the leftmost byte
    -- of the conventional hex string. Keeping this in one place is deliberate:
    -- byte order is the easiest thing to get wrong when integrating a hash.
    function digest_of (
        a : state_t
    ) return digest_t;

    -- Round constants, stored as the 7 bits that can actually be non-zero. In a
    -- round constant only bit positions 2^j - 1 for j in 0..6 are ever set, so
    -- indexing a 24x7 ROM by the round counter and scattering costs a handful of
    -- LUTs where a 24-entry 64-bit ROM would cost a few hundred.
    subtype rc_bits_t is std_logic_vector(6 downto 0);

    type rc_table_t is array (0 to NUM_ROUNDS - 1) of rc_bits_t;

    -- Deferred: the generator lives in the body, so the value cannot be
    -- elaborated here.
    constant RC_BITS : rc_table_t;

    -- Expand a packed round constant back out to a full lane. Pure wiring.
    function rc_lane (
        b : rc_bits_t
    ) return lane_t;

    -- The rho rotation offset for lane (x,y). The table is generated, so this is
    -- exposed to let a testbench check it against the published one.
    function rho_offset (
        x : natural range 0 to 4;
        y : natural range 0 to 4
    ) return natural;

end package;

package body keccak_pkg is

    function rotl (
        v : lane_t;
        n : natural
    ) return lane_t is
    begin
        if n = 0 then
            return v;
        end if;

        return v(63 - n downto 0) & v(63 downto 64 - n);
    end function;

    type rho_table_t is array (0 to 4, 0 to 4) of natural range 0 to 63;

    -- The rho offsets, walked out of the standard recurrence rather than typed
    -- in as a table. Starting from (1,0), the t'th lane visited gets offset
    -- (t+1)(t+2)/2 mod 64, and the walk steps by the same pi permutation used in
    -- the round below. The 24 steps visit every lane except (0,0), whose offset
    -- is zero. This reproduces the canonical table exactly.
    function gen_rho return rho_table_t is

        variable t     : rho_table_t := (others => (others => 0));
        variable x     : natural range 0 to 4;
        variable y     : natural range 0 to 4;
        variable old_x : natural range 0 to 4;

    begin
        x := 1;
        y := 0;

        for i in 0 to 23 loop
            t(x, y) := ((i + 1) * (i + 2) / 2) mod 64;
            old_x   := x;
            x       := y;
            y       := (2 * old_x + 3 * y) mod 5;
        end loop;

        return t;
    end function;

    constant RHO : rho_table_t := gen_rho;

    function rho_offset (
        x : natural range 0 to 4;
        y : natural range 0 to 4
    ) return natural is
    begin
        return RHO(x, y);
    end function;

    -- The round constants come out of a Galois LFSR over x^8 + x^6 + x^5 + x^4 + 1,
    -- seeded with 0x01. Seven steps per round, each contributing one bit. This is
    -- the same polynomial lfsr8_pkg uses for the SerDes scrambler, but it is
    -- pinned here by FIPS 202 rather than shared, so a future change to the
    -- scrambler's polynomial cannot quietly break SHA3.
    function gen_rc return rc_table_t is

        variable t    : rc_table_t;
        variable lfsr : std_logic_vector(7 downto 0);
        variable bits : rc_bits_t;

    begin
        lfsr := X"01";

        for r in 0 to NUM_ROUNDS - 1 loop
            bits := (others => '0');

            for j in 0 to 6 loop
                if lfsr(7) = '1' then
                    lfsr := (lfsr(6 downto 0) & '0') xor X"71";
                else
                    lfsr := lfsr(6 downto 0) & '0';
                end if;
                bits(j) := lfsr(1);
            end loop;

            t(r) := bits;
        end loop;

        return t;
    end function;

    constant RC_BITS : rc_table_t := gen_rc;

    function rc_lane (
        b : rc_bits_t
    ) return lane_t is

        variable v : lane_t := (others => '0');

    begin
        for j in 0 to 6 loop
            v(2 ** j - 1) := b(j);
        end loop;

        return v;
    end function;

    function keccak_round (
        a  : state_t;
        rc : lane_t
    ) return state_t is

        type lane_row_t is array (0 to 4) of lane_t;

        variable c   : lane_row_t;
        variable d   : lane_row_t;
        variable b   : state_t;
        variable res : state_t;

    begin
        -- theta, part one: parity of each column.
        for x in 0 to 4 loop
            c(x) := a(x, 0) xor a(x, 1) xor a(x, 2) xor a(x, 3) xor a(x, 4);
        end loop;

        -- theta, part two: the diffusion term applied to every lane of column x.
        for x in 0 to 4 loop
            d(x) := c((x + 4) mod 5) xor rotl(c((x + 1) mod 5), 1);
        end loop;

        -- rho and pi, with theta's XOR folded in. rho is a constant rotation per
        -- lane and pi is a relabelling, so neither costs any gates: the only
        -- logic here is the XOR with d, and that folds into the chi term below.
        -- Each output bit then depends on exactly six inputs, three state bits
        -- and three d bits, which is one LUT6 per state bit.
        for x in 0 to 4 loop
            for y in 0 to 4 loop
                b(y, (2 * x + 3 * y) mod 5) := rotl(a(x, y) xor d(x), RHO(x, y));
            end loop;
        end loop;

        -- chi, the only non-linear step, acting along rows.
        for x in 0 to 4 loop
            for y in 0 to 4 loop
                res(x, y) := b(x, y) xor ((not b((x + 1) mod 5, y)) and b((x + 2) mod 5, y));
            end loop;
        end loop;

        -- iota, breaking the symmetry that the other four steps preserve.
        res(0, 0) := res(0, 0) xor rc;

        return res;
    end function;

    function keccak_f1600 (
        a : state_t
    ) return state_t is

        variable res : state_t := a;

    begin
        for r in 0 to NUM_ROUNDS - 1 loop
            res := keccak_round(res, rc_lane(RC_BITS(r)));
        end loop;

        return res;
    end function;

    function absorb_block (
        a   : state_t;
        blk : rate_block_t
    ) return state_t is

        variable res : state_t := a;

    begin
        for k in 0 to RATE_LANES - 1 loop
            res(k mod 5, k / 5) := res(k mod 5, k / 5) xor blk(64 * k + 63 downto 64 * k);
        end loop;

        return res;
    end function;

    function digest_of (
        a : state_t
    ) return digest_t is

        variable v : digest_t;

    begin
        for k in 0 to DIGEST_LANES - 1 loop
            v(64 * k + 63 downto 64 * k) := a(k mod 5, k / 5);
        end loop;

        return v;
    end function;

end package body;
