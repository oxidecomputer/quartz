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

use work.keccak_pkg.all;
use work.sha3_sim_pkg.all;

-- Unit tests for keccak_pkg, with no RTL involved.
--
-- This is the layer that anchors the round function, the generated rho offsets
-- and the generated round constants against published values. The sponge tests
-- in sha3_256_tb lean on sha3_sim_pkg, which shares keccak_round with the DUT
-- and so cannot detect a wrong rotation offset or a wrong round constant -- both
-- sides would be wrong identically. These known-answer tests can.
entity keccak_pkg_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of keccak_pkg_tb is

    -- Keccak-f[1600] applied to the all-zero state, from the reference
    -- KeccakF-1600-IntermediateValues.txt. Indexed by the flat lane number
    -- k = x + 5y. This is the strongest single check on the permutation: it
    -- exercises every rotation offset and all 24 round constants, and any error
    -- in either avalanches across the whole state.
    type lane_array_t is array (0 to 24) of lane_t;

    constant ZERO_STATE_PERMUTED : lane_array_t := (
        x"F1258F7940E1DDE7", x"84D5CCF933C0478A", x"D598261EA65AA9EE",
        x"BD1547306F80494D", x"8B284E056253D057", x"FF97A42D7F8E6FD4",
        x"90FEE5A0A44647C4", x"8C5BDA0CD6192E76", x"AD30A6F71B19059C",
        x"30935AB7D08FFC64", x"EB5AA93F2317D635", x"A9A6E6260D712103",
        x"81A57C16DBCF555F", x"43B831CD0347C826", x"01F22F1A11A5569F",
        x"05E5635A21D9AE61", x"64BEFEF28CC970F2", x"613670957BC46611",
        x"B87C5A554FD00ECB", x"8C3EE88A1CCF32C8", x"940C7922AE3A2614",
        x"1841F924A2C509E4", x"16F53526E70465C2", x"75F644E97F30A13B",
        x"EAF1FF7B5CECA249"
    );

    -- Canonical rho offsets, indexed [x][y], from FIPS 202 table 2. gen_rho
    -- walks these out of a recurrence instead of storing them, so this checks
    -- the recurrence.
    type rho_check_t is array (0 to 4, 0 to 4) of natural;

    constant RHO_EXPECTED : rho_check_t := (
        --  y=0  y=1  y=2  y=3  y=4
        0 => (0, 36, 3, 41, 18),
        1 => (1, 44, 10, 45, 2),
        2 => (62, 6, 43, 15, 61),
        3 => (28, 55, 25, 21, 56),
        4 => (27, 20, 39, 8, 14)
    );

    -- The only bit positions a round constant is allowed to occupy: 2^j - 1 for
    -- j in 0..6. This invariant is what justifies storing the constants as 7 bits
    -- and scattering them, so it is worth pinning.
    function rc_allowed_mask return lane_t is

        variable v : lane_t := (others => '0');

    begin
        for j in 0 to 6 loop
            v(2 ** j - 1) := '1';
        end loop;

        return v;
    end function;

    constant RC_ALLOWED : lane_t := rc_allowed_mask;

begin

    bench: process
        variable st  : state_t := (others => (others => (others => '0')));
        variable msg : queue_t;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
            if run("rho_offsets_match_fips202") then
                -- gen_rho is elaboration-time, so a failure here is a compile-time
                -- constant being wrong, not a simulation event.
                for x in 0 to 4 loop
                    for y in 0 to 4 loop
                        check_equal(rho_offset(x, y), RHO_EXPECTED(x, y),
                                    "rho offset at x=" & natural'image(x) & " y=" & natural'image(y));
                    end loop;
                end loop;

            elsif run("round_constants") then
                -- First and last round constants, and the invariant that only
                -- bit positions 2^j - 1 are ever set.
                check_equal(rc_lane(RC_BITS(0)),
                            std_logic_vector'(x"0000000000000001"), "RC[0]");
                check_equal(rc_lane(RC_BITS(23)),
                            std_logic_vector'(x"8000000080008008"), "RC[23]");

                for r in 0 to NUM_ROUNDS - 1 loop
                    check_equal(rc_lane(RC_BITS(r)) and not RC_ALLOWED,
                                std_logic_vector'(lane_t'(others => '0')),
                                "RC[" & natural'image(r) & "] has bits outside 2^j-1 positions");
                end loop;

            elsif run("keccak_f1600_zero_state") then
                st := keccak_f1600(st);

                for k in 0 to 24 loop
                    check_equal(st(k mod 5, k / 5), ZERO_STATE_PERMUTED(k),
                                "permuted zero state lane " & natural'image(k));
                end loop;

            elsif run("sponge_known_answers") then
                -- Digests generated with python3 hashlib.sha3_256. These cover the
                -- padding corner cases: 135 bytes fuses 0x06 and 0x80 into a single
                -- 0x86, and 136 bytes forces an entire extra block of padding.
                msg := to_queue("abc");
                check_equal(sha3_256_digest(msg),
                            hex_digest("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"),
                            "sha3-256(""abc"")");

                msg := new_queue;
                check_equal(sha3_256_digest(msg),
                            hex_digest("a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"),
                            "sha3-256(empty)");

                msg := repeat_byte(16#5A#, 135);
                check_equal(sha3_256_digest(msg),
                            hex_digest("12fa8b3d366f54305d82b8eff1dae1df85046ee32ec82d6f6e290f8e9cae2f90"),
                            "sha3-256(135 x 0x5a), fused 0x86 pad");

                msg := repeat_byte(16#5A#, 136);
                check_equal(sha3_256_digest(msg),
                            hex_digest("89e699b3685be673ff90f26e215dd8140b5364e1f931f27c6000dc184ee0533c"),
                            "sha3-256(136 x 0x5a), full extra pad block");

                msg := repeat_byte(16#5A#, 137);
                check_equal(sha3_256_digest(msg),
                            hex_digest("50bf5cd6f1906058d863c6d02a7b7dd7bed531bdca5dab2b55b135d295cb72a1"),
                            "sha3-256(137 x 0x5a)");

                msg := repeat_byte(16#A3#, 200);
                check_equal(sha3_256_digest(msg),
                            hex_digest("79f38adec5c20307a98ef76e8324afbfd46cfd81b22e3973c65fa1bd9de31787"),
                            "sha3-256(200 x 0xa3), NIST 1600-bit vector");

                msg := repeat_byte(16#5A#, 272);
                check_equal(sha3_256_digest(msg),
                            hex_digest("2da5e8552b2fd944d850d3f4300fdb3054f7561c867fe6a748320760869f8bba"),
                            "sha3-256(272 x 0x5a), two full blocks plus pad block");

            elsif run("hex_digest_byte_order") then
                -- The digest hex string's leftmost byte must land in bits 7
                -- downto 0. Getting this backwards would make every other check
                -- in this file wrong in the same direction, so pin it directly.
                check_equal(hex_digest("00112233445566778899aabbccddeeff" &
                                       "00112233445566778899aabbccddee01")(7 downto 0),
                            std_logic_vector'(x"00"), "first hex byte lands in bits 7:0");
                check_equal(hex_digest("00112233445566778899aabbccddeeff" &
                                       "00112233445566778899aabbccddee01")(255 downto 248),
                            std_logic_vector'(x"01"), "last hex byte lands in bits 255:248");
            end if;
        end loop;

        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

end tb;
