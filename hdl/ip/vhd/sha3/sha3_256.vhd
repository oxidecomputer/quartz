-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axi_st8_pkg;
use work.calc_pkg.all;
use work.keccak_pkg.all;

-- SHA3-256 (FIPS 202) over a byte-wide AXI stream.
--
-- The permutation runs one full Keccak-f[1600] round per cycle, so the 1600-bit
-- state lives in flops and the whole round is a single layer of combinational
-- logic. rho and pi are pure wiring and theta's XOR folds into chi, so each
-- state bit's next value depends on exactly six inputs -- one LUT6 per bit.
-- Nothing here wants a RAM: the state is read and rewritten in full every cycle.
--
-- Absorb costs 136 cycles per block against the permutation's 24, so the stream
-- is the bottleneck, not the hashing. See DOUBLE_BUFFER for whether those 24
-- cycles show up as backpressure.
--
-- The design is two independent state machines that share nothing but a
-- per-buffer full/final handshake:
--
--   feed FSM     owns msg_if.ready, the byte counter, padding, and fill_idx.
--                It shifts bytes into a 136-byte block register and marks it
--                full when complete.
--   permute FSM  owns the Keccak state, the round counter, and drain_idx. It
--                waits for a full block, XORs it in, runs 24 rounds, and hands
--                the buffer back.
--
-- Splitting them this way is what makes DOUBLE_BUFFER a one-line change rather
-- than a second code path.
entity sha3_256 is
    generic (
        -- false: one block register. ready deasserts for the 25-cycle absorb and
        --        permute, so a long message runs at about 84% of line rate.
        -- true:  two block registers (+1088 FF). Block N+1 absorbs while block N
        --        permutes, so ready never deasserts mid-message and the core
        --        sustains one byte per cycle. The permutation cannot fall behind
        --        because 25 < 136.
        DOUBLE_BUFFER : boolean := false
    );
    port (
        clk   : in    std_logic;
        -- Asynchronous, active-high.
        reset : in    std_logic;

        -- Synchronous, active-high. Zeroes the sponge, abandons any message in
        -- flight and clears digest_valid; the core is held cleared for as long as
        -- it is asserted, so either a pulse or a level works. Not required
        -- between messages, last already ends one cleanly.
        init  : in    std_logic;
        -- High from the first accepted byte until digest_valid asserts.
        busy  : out   std_logic;

        -- Message bytes in natural order, last marks the final byte. Note that
        -- AXI streaming has no zero-beat packet, so the empty message is not
        -- representable here; a consumer needing SHA3-256("") should use the
        -- known constant.
        msg_if : view axi_st8_pkg.axi_st_pkt_sink;

        -- digest(7 downto 0) is hash byte 0, ie the leftmost byte of the
        -- conventional hex string. Held stable until init or the next message
        -- starts.
        digest       : out   digest_t;
        digest_valid : out   std_logic
    );
end entity;

architecture rtl of sha3_256 is

    constant NUM_BUFS : positive := sel(DOUBLE_BUFFER, 2, 1);

    type block_buf_t is array (0 to NUM_BUFS - 1) of rate_block_t;

    subtype buf_idx_t is natural range 0 to NUM_BUFS - 1;
    subtype buf_flags_t is std_logic_vector(NUM_BUFS - 1 downto 0);

    -- Constant-folds to 0 when there is only one buffer, which is what keeps the
    -- single-buffer configuration from paying for the generic.
    function next_idx (
        i : buf_idx_t
    ) return buf_idx_t is
    begin
        return (i + 1) mod NUM_BUFS;
    end function;

    -- FINISHING is where we sit between the final block being handed off and the
    -- digest appearing. Holding ready low there stops a following message from
    -- corrupting the one still being permuted.
    type feed_state_t is (IDLE, ABSORB, PAD, FINISHING);

    type feed_reg_t is record
        state     : feed_state_t;
        buf       : block_buf_t;
        -- Bytes shifted into the current block so far.
        cnt       : natural range 0 to RATE_BYTES - 1;
        fill_idx  : buf_idx_t;
        full      : buf_flags_t;
        final     : buf_flags_t;
        pad_first : std_logic;
        started   : std_logic;
        busy      : std_logic;
    end record;

    constant FEED_REG_RESET : feed_reg_t := (
        state     => IDLE,
        buf       => (others => (others => '0')),
        cnt       => 0,
        fill_idx  => 0,
        full      => (others => '0'),
        final     => (others => '0'),
        pad_first => '0',
        started   => '0',
        busy      => '0'
    );

    type permute_state_t is (WAIT_BLOCK, ABSORB_BLOCK, RUN, HOLD);

    type permute_reg_t is record
        state     : permute_state_t;
        st        : state_t;
        round     : natural range 0 to NUM_ROUNDS - 1;
        drain_idx : buf_idx_t;
        dig       : digest_t;
        dv        : std_logic;
    end record;

    constant PERMUTE_REG_RESET : permute_reg_t := (
        state     => WAIT_BLOCK,
        st        => (others => (others => (others => '0'))),
        round     => 0,
        drain_idx => 0,
        dig       => (others => '0'),
        dv        => '0'
    );

    signal feed_reg, feed_reg_next       : feed_reg_t;
    signal perm_reg, perm_reg_next       : permute_reg_t;

    signal ready_int   : std_logic;
    signal accept_byte : std_logic;

    -- Combinational, not registered. The feed side has to see the release in the
    -- same cycle the last round retires, otherwise it would still be showing the
    -- buffer as full when the permute side next looks at it and, with a single
    -- buffer, the same block would be absorbed twice.
    signal buf_release     : std_logic;
    signal buf_release_idx : buf_idx_t;

begin

    -- The whole difference between the two buffering configurations. With one
    -- buffer this naturally stalls for the absorb and permute; with two it only
    -- stalls if the permute side falls behind, which it cannot.
    ready_int <= '1' when (feed_reg.state = IDLE or feed_reg.state = ABSORB) and
                          feed_reg.full(feed_reg.fill_idx) = '0' else '0';

    msg_if.ready <= ready_int;
    accept_byte  <= ready_int and msg_if.valid;

    buf_release     <= '1' when perm_reg.state = RUN and
                                perm_reg.round = NUM_ROUNDS - 1 else '0';
    buf_release_idx <= perm_reg.drain_idx;

    busy         <= feed_reg.busy;
    digest       <= perm_reg.dig;
    digest_valid <= perm_reg.dv;

    -- Feed side ---------------------------------------------------------------

    feed_next: process(all)

        variable v        : feed_reg_t;
        variable pad_byte : std_logic_vector(7 downto 0);
        variable at_end   : boolean;

    begin
        v := feed_reg;

        v.started := '0';

        -- The permute side is done with a buffer, so take it back. This can never
        -- collide with the set below: we only ever mark a buffer full when it is
        -- currently clear, and only ever clear one that is currently full.
        if buf_release then
            v.full(buf_release_idx)  := '0';
            v.final(buf_release_idx) := '0';
        end if;

        -- Every block is filled by exactly RATE_BYTES shifts, so a byte's final
        -- position is fixed by how many shifts follow it rather than by any
        -- addressing. That is why padding has to shift filler through rather than
        -- writing the last byte directly.
        at_end := feed_reg.cnt = RATE_BYTES - 1;

        case feed_reg.state is

            when IDLE =>
                if accept_byte then
                    v.buf(feed_reg.fill_idx) :=
                        msg_if.data & feed_reg.buf(feed_reg.fill_idx)(RATE_BITS - 1 downto 8);
                    v.started := '1';
                    v.busy    := '1';
                    v.cnt     := 1;
                    v.state   := ABSORB;

                    -- A single-byte message: straight into padding.
                    if msg_if.last then
                        v.pad_first := '1';
                        v.state     := PAD;
                    end if;
                end if;

            when ABSORB =>
                if accept_byte then
                    v.buf(feed_reg.fill_idx) :=
                        msg_if.data & feed_reg.buf(feed_reg.fill_idx)(RATE_BITS - 1 downto 8);

                    if at_end then
                        -- Block complete. Not final even if this was the last
                        -- message byte: the spec still wants a whole block of
                        -- padding after an exact multiple of the rate.
                        v.full(feed_reg.fill_idx) := '1';
                        v.fill_idx                := next_idx(feed_reg.fill_idx);
                        v.cnt                     := 0;
                    else
                        v.cnt := feed_reg.cnt + 1;
                    end if;

                    if msg_if.last then
                        v.pad_first := '1';
                        v.state     := PAD;
                    end if;
                end if;

            when PAD =>
                -- Same stall condition as ABSORB. With a single buffer this is
                -- what makes us wait for an in-flight permutation before starting
                -- the padding block.
                if feed_reg.full(feed_reg.fill_idx) = '0' then
                    if feed_reg.pad_first = '1' and at_end then
                        -- Exactly one byte of room left, so the domain separator
                        -- and the terminator land on the same byte.
                        pad_byte := PAD_ONLY;
                    elsif feed_reg.pad_first = '1' then
                        pad_byte := PAD_FIRST;
                    elsif at_end then
                        pad_byte := PAD_LAST;
                    else
                        pad_byte := (others => '0');
                    end if;

                    v.buf(feed_reg.fill_idx) :=
                        pad_byte & feed_reg.buf(feed_reg.fill_idx)(RATE_BITS - 1 downto 8);
                    v.pad_first := '0';

                    if at_end then
                        v.full(feed_reg.fill_idx)  := '1';
                        v.final(feed_reg.fill_idx) := '1';
                        v.fill_idx                 := next_idx(feed_reg.fill_idx);
                        v.cnt                      := 0;
                        v.state                    := FINISHING;
                    else
                        v.cnt := feed_reg.cnt + 1;
                    end if;
                end if;

            when FINISHING =>
                if perm_reg.dv then
                    v.busy  := '0';
                    v.state := IDLE;
                end if;

        end case;

        if init then
            v := FEED_REG_RESET;
        end if;

        feed_reg_next <= v;
    end process;

    -- Permute side ------------------------------------------------------------

    perm_next: process(all)

        variable v : permute_reg_t;

    begin
        v := perm_reg;

        case perm_reg.state is

            when WAIT_BLOCK =>
                if feed_reg.full(perm_reg.drain_idx) then
                    v.state := ABSORB_BLOCK;
                end if;

            when ABSORB_BLOCK =>
                -- Kept out of round 0 deliberately. Folding the XOR in would add a
                -- logic level to the round's critical path to save a single cycle
                -- out of the 136 the stream already costs.
                v.st    := absorb_block(perm_reg.st, feed_reg.buf(perm_reg.drain_idx));
                v.round := 0;
                v.state := RUN;

            when RUN =>
                v.st := keccak_round(perm_reg.st, rc_lane(RC_BITS(perm_reg.round)));

                if perm_reg.round = NUM_ROUNDS - 1 then
                    -- Advance unconditionally, final block included, so drain_idx
                    -- stays in step with the feed side's fill_idx across a message
                    -- boundary.
                    v.drain_idx := next_idx(perm_reg.drain_idx);

                    if feed_reg.final(perm_reg.drain_idx) then
                        -- v.st is this round's result, so the digest is taken from
                        -- the fully permuted state.
                        v.dig   := digest_of(v.st);
                        v.dv    := '1';
                        v.state := HOLD;
                    else
                        v.state := WAIT_BLOCK;
                    end if;
                else
                    v.round := perm_reg.round + 1;
                end if;

            when HOLD =>
                -- Hold the digest until the next message claims its first byte.
                if feed_reg.started then
                    v.st    := (others => (others => (others => '0')));
                    v.dv    := '0';
                    v.state := WAIT_BLOCK;
                end if;

        end case;

        if init then
            v := PERMUTE_REG_RESET;
        end if;

        perm_reg_next <= v;
    end process;

    -- Registers ---------------------------------------------------------------

    regs: process(clk, reset)
    begin
        if reset then
            feed_reg <= FEED_REG_RESET;
            perm_reg <= PERMUTE_REG_RESET;
        elsif rising_edge(clk) then
            feed_reg <= feed_reg_next;
            perm_reg <= perm_reg_next;
        end if;
    end process;

end rtl;
