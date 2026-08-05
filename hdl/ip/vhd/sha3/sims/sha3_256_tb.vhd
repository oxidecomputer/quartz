-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.axi_st8_pkg;
use work.basic_stream_pkg.all;
use work.gpio_msg_pkg.all;
use work.keccak_pkg.all;
use work.sha3_sim_pkg.all;

-- Sponge and stream-interface tests for sha3_256.
--
-- The round function is not under test here: keccak_pkg_tb anchors that against
-- published vectors. What these tests cover is everything the sponge wraps
-- around it -- block framing, the three padding cases, byte order, multi-block
-- carry, backpressure, and message-to-message state clearing -- for both
-- buffering configurations at once.
entity sha3_256_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of sha3_256_tb is

    constant CLK_PER_NS : positive := 8;

    -- Deliberately different throttling on the two instances. The single
    -- buffered core sees gaps in valid on top of its own backpressure, and the
    -- double buffered one is driven flat out so no_stall_is_real can measure
    -- that it never pushes back.
    constant SRC_SINGLE : basic_source_t := new_basic_source(8, valid_high_probability => 0.6);
    constant SRC_DOUBLE : basic_source_t := new_basic_source(8, valid_high_probability => 1.0);

    -- Cycles where the source had a byte to give and the core refused it.
    signal stalls_single : natural := 0;
    signal stalls_double : natural := 0;

begin

    th: entity work.sha3_256_th
        generic map (
            CLK_PER_NS => CLK_PER_NS,
            SRC_SINGLE => SRC_SINGLE,
            SRC_DOUBLE => SRC_DOUBLE
        );

    -- Backpressure observer. Counting refused beats rather than sampling ready
    -- directly keeps this meaningful under a throttled source: ready going low
    -- while the source has nothing to send is not a stall.
    stall_count: process
        alias clk is << signal th.clk : std_logic >>;
        alias msg_single is << signal th.msg_single : axi_st8_pkg.axi_st_pkt_t >>;
        alias msg_double is << signal th.msg_double : axi_st8_pkg.axi_st_pkt_t >>;
    begin
        wait until rising_edge(clk);

        if msg_single.valid = '1' and msg_single.ready = '0' then
            stalls_single <= stalls_single + 1;
        end if;

        if msg_double.valid = '1' and msg_double.ready = '0' then
            stalls_double <= stalls_double + 1;
        end if;
    end process;

    bench: process
        alias clk is << signal th.clk : std_logic >>;
        alias reset is << signal th.reset : std_logic >>;
        alias digest_single is << signal th.digest_single : digest_t >>;
        alias digest_double is << signal th.digest_double : digest_t >>;
        alias dv_single is << signal th.dv_single : std_logic >>;
        alias dv_double is << signal th.dv_double : std_logic >>;
        alias busy_single is << signal th.busy_single : std_logic >>;
        alias busy_double is << signal th.busy_double : std_logic >>;

        constant init_actor : actor_t := find("init_gpio");

        variable rnd : RandomPType;

        -- Push a message into both cores and check the digest each produces.
        procedure check_message (
            msg      : queue_t;
            expected : digest_t;
            name     : string
        ) is
            variable q : queue_t := copy(msg);
            variable b : std_logic_vector(7 downto 0);
        begin
            assert not is_empty(q)
                report "check_message: the empty message is not representable on an " &
                       "AXI stream, use the known constant instead"
                severity failure;

            -- Pop first, then ask whether anything is left: that identifies the
            -- final byte without needing a count up front. Note length() on a
            -- VUnit queue counts encoded bytes, not pushed items, so it is not
            -- the byte count.
            while not is_empty(q) loop
                b := To_StdLogicVector(pop_byte(q), 8);
                push_basic_pkt_stream(net, SRC_SINGLE, b, last => is_empty(q));
                push_basic_pkt_stream(net, SRC_DOUBLE, b, last => is_empty(q));
            end loop;

            -- Wait for both cores to claim the message before looking at
            -- digest_valid, otherwise a digest still being held from the
            -- previous message would satisfy the wait below immediately.
            wait until busy_single = '1' and busy_double = '1' and rising_edge(clk);
            wait until dv_single = '1' and dv_double = '1' and rising_edge(clk);

            check_equal(digest_single, expected, name & " [single buffer]");
            check_equal(digest_double, expected, name & " [double buffer]");
        end procedure;

        -- Same, but the expected value comes from the software sponge rather
        -- than a hardcoded digest.
        procedure check_against_model (
            msg  : queue_t;
            name : string
        ) is
        begin
            check_message(msg, sha3_256_digest(msg), name);
        end procedure;

        procedure pulse_init is
            variable data : std_logic_vector(GPIO_MESAGE_DATA_WDITH - 1 downto 0);
        begin
            data    := (others => '0');
            data(0) := '1';
            set_gpio(net, init_actor, data);
            wait for CLK_PER_NS * 4 * 1 ns;
            data(0) := '0';
            set_gpio(net, init_actor, data);
            wait for CLK_PER_NS * 4 * 1 ns;
        end procedure;

        variable msg    : queue_t;
        variable n      : natural;
        variable before : natural;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("kat_abc") then
                check_message(to_queue("abc"),
                              hex_digest("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe2451143" &
                                         "1532"),
                              "sha3-256(""abc"")");

            elsif run("kat_single_byte") then
                check_message(repeat_byte(16#00#, 1),
                              hex_digest("5d53469f20fef4f8eab52b88044ede69c77a6a68a60728609fc4a65ff531" &
                                         "e7d0"),
                              "sha3-256(0x00)");

            elsif run("kat_135_bytes") then
                -- One byte of room left after the message, so 0x06 and 0x80 fuse
                -- into a single 0x86.
                check_message(repeat_byte(16#5A#, 135),
                              hex_digest("12fa8b3d366f54305d82b8eff1dae1df85046ee32ec82d6f6e290f8e9cae" &
                                         "2f90"),
                              "sha3-256(135 x 0x5a), fused 0x86 pad");

            elsif run("kat_136_bytes") then
                -- Exact multiple of the rate, so the spec demands a whole extra
                -- block of padding. Getting this wrong is the classic sponge bug.
                check_message(repeat_byte(16#5A#, 136),
                              hex_digest("89e699b3685be673ff90f26e215dd8140b5364e1f931f27c6000dc184ee0" &
                                         "533c"),
                              "sha3-256(136 x 0x5a), full extra pad block");

            elsif run("kat_137_bytes") then
                check_message(repeat_byte(16#5A#, 137),
                              hex_digest("50bf5cd6f1906058d863c6d02a7b7dd7bed531bdca5dab2b55b135d295cb" &
                                         "72a1"),
                              "sha3-256(137 x 0x5a)");

            elsif run("kat_200_bytes_a3") then
                check_message(repeat_byte(16#A3#, 200),
                              hex_digest("79f38adec5c20307a98ef76e8324afbfd46cfd81b22e3973c65fa1bd9de3" &
                                         "1787"),
                              "sha3-256(200 x 0xa3), NIST 1600-bit vector");

            elsif run("kat_272_bytes") then
                check_message(repeat_byte(16#5A#, 272),
                              hex_digest("2da5e8552b2fd944d850d3f4300fdb3054f7561c867fe6a748320760869f" &
                                         "8bba"),
                              "sha3-256(272 x 0x5a), two blocks plus a pad block");

            elsif run("random_lengths") then
                -- Arbitrary lengths against the software sponge, which is what
                -- covers the block-boundary cases the fixed vectors above miss.
                rnd.InitSeed(rnd'instance_name);

                for i in 0 to 19 loop
                    n   := rnd.RandInt(1, 400);
                    msg := new_queue;

                    for j in 1 to n loop
                        push_byte(msg, rnd.RandInt(0, 255));
                    end loop;

                    check_against_model(msg, "random message of " & natural'image(n) & " bytes");
                end loop;

            elsif run("back_to_back") then
                -- No init between messages. If the sponge state or the buffer
                -- flags were not cleared on completion, the second digest is
                -- wrong.
                check_message(to_queue("abc"),
                              hex_digest("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe2451143" &
                                         "1532"),
                              "first message");
                check_message(repeat_byte(16#A3#, 200),
                              hex_digest("79f38adec5c20307a98ef76e8324afbfd46cfd81b22e3973c65fa1bd9de3" &
                                         "1787"),
                              "second message, no init between");
                check_message(to_queue("abc"),
                              hex_digest("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe2451143" &
                                         "1532"),
                              "third message, crossing a multi-block message");

            elsif run("init_aborts") then
                -- Abandon a message part way through, then check the core hashes
                -- the next one correctly from a clean sponge.
                for i in 1 to 50 loop
                    push_basic_pkt_stream(net, SRC_SINGLE, x"FF", last => false);
                    push_basic_pkt_stream(net, SRC_DOUBLE, x"FF", last => false);
                end loop;

                -- Let every queued beat drain into the cores before aborting, so
                -- no stragglers get counted against the next message.
                wait for CLK_PER_NS * 1000 * 1 ns;
                pulse_init;

                check_equal(dv_single, '0', "init should clear digest_valid [single]");
                check_equal(dv_double, '0', "init should clear digest_valid [double]");
                check_equal(busy_single, '0', "init should clear busy [single]");
                check_equal(busy_double, '0', "init should clear busy [double]");

                check_message(to_queue("abc"),
                              hex_digest("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe2451143" &
                                         "1532"),
                              "message after an aborted one");

            elsif run("no_stall_is_real") then
                -- The double buffered core should never refuse a byte mid-message
                -- because the 25 cycle absorb and permute hides inside the 136
                -- cycles the next block spends arriving. The single buffered core
                -- must refuse bytes, otherwise this check is vacuous and would
                -- pass on a broken observer.
                before := stalls_single;
                check_message(repeat_byte(16#5A#, 500), sha3_256_digest(repeat_byte(16#5A#, 500)),
                              "500 byte message");

                check_equal(stalls_double, 0,
                            "double buffered core stalled the stream mid-message");
                check_true(stalls_single > before,
                           "single buffered core never stalled, so this test proves nothing");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 50 ms);

end tb;
