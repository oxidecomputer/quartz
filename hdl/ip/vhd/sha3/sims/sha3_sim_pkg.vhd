-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.keccak_pkg.all;

-- Software SHA3-256 for testbench use: a plain byte-at-a-time sponge over a
-- VUnit queue, in the spirit of crc_sim_pkg.
--
-- This shares keccak_round with the DUT, so it cannot catch a bug in the round
-- function itself. It exists to check the sponge around it -- block framing,
-- padding, byte order, multi-block carry -- at arbitrary message lengths, which
-- a fixed set of known-answer tests cannot do. The round function is anchored
-- separately by the KATs in keccak_pkg_tb.
package sha3_sim_pkg is

    impure function sha3_256_digest (
        data : queue_t
    ) return digest_t;

    -- Parse a digest hex string in the conventional order, ie exactly what
    -- sha3sum or hashlib.hexdigest() prints, into this core's bit order. The
    -- leftmost byte of the string lands in bits 7 downto 0.
    --
    -- Worth having rather than writing a VHDL hex literal directly: in a literal
    -- the leftmost digits are the most significant bits, so the constant would
    -- have to be hand byte-reversed, which is 32 chances to make a silent
    -- mistake in a value whose whole job is to be trustworthy.
    function hex_digest (
        s : string
    ) return digest_t;

    -- Convenience constructors for test messages.
    impure function to_queue (
        s : string
    ) return queue_t;

    impure function repeat_byte (
        b : natural;
        n : natural
    ) return queue_t;

end package;

package body sha3_sim_pkg is

    impure function sha3_256_digest (
        data : queue_t
    ) return digest_t is

        -- Copy so we don't consume the caller's queue.
        constant msg_queue : queue_t := copy(data);

        variable st  : state_t      := (others => (others => (others => '0')));
        variable blk : rate_block_t := (others => '0');
        -- Bytes staged in the current block, always < RATE_BYTES on exit from
        -- the absorb loop, which is what lets the padding below be unconditional.
        variable n   : natural      := 0;

    begin
        while not is_empty(msg_queue) loop
            blk(8 * n + 7 downto 8 * n) := To_StdLogicVector(pop_byte(msg_queue), 8);
            n                           := n + 1;

            if n = RATE_BYTES then
                st  := keccak_f1600(absorb_block(st, blk));
                blk := (others => '0');
                n   := 0;
            end if;
        end loop;

        -- pad10*1 with the SHA3 domain separator. Both awkward cases fall out of
        -- writing 0x06 then OR-ing 0x80 into the top byte: when the message ends
        -- one byte short of a block the two land on the same byte and fuse into
        -- 0x86, and when the message length is an exact multiple of the rate we
        -- get a full block of padding, which the spec requires.
        blk(8 * n + 7 downto 8 * n)              := PAD_FIRST;
        blk(RATE_BITS - 1 downto RATE_BITS - 8)  := blk(RATE_BITS - 1 downto RATE_BITS - 8) or PAD_LAST;

        st := keccak_f1600(absorb_block(st, blk));

        return digest_of(st);
    end function;

    function hex_digest (
        s : string
    ) return digest_t is

        variable v : digest_t := (others => '0');
        variable n : natural;

    begin
        assert s'length = DIGEST_BITS / 4
            report "hex_digest: expected " & natural'image(DIGEST_BITS / 4) &
                   " hex digits, got " & natural'image(s'length)
            severity failure;

        for i in 0 to DIGEST_BITS / 8 - 1 loop
            n := 0;

            -- Two digits per byte, most significant nibble first.
            for j in 0 to 1 loop
                case s(s'low + 2 * i + j) is
                    when '0' to '9' => n := n * 16 + (character'pos(s(s'low + 2 * i + j)) - character'pos('0'));
                    when 'a' to 'f' => n := n * 16 + (character'pos(s(s'low + 2 * i + j)) - character'pos('a')) + 10;
                    when 'A' to 'F' => n := n * 16 + (character'pos(s(s'low + 2 * i + j)) - character'pos('A')) + 10;
                    when others     => report "hex_digest: bad hex digit" severity failure;
                end case;
            end loop;

            v(8 * i + 7 downto 8 * i) := To_StdLogicVector(n, 8);
        end loop;

        return v;
    end function;

    impure function to_queue (
        s : string
    ) return queue_t is

        variable q : queue_t := new_queue;

    begin
        for i in s'range loop
            push_byte(q, character'pos(s(i)));
        end loop;

        return q;
    end function;

    impure function repeat_byte (
        b : natural;
        n : natural
    ) return queue_t is

        variable q : queue_t := new_queue;

    begin
        for i in 1 to n loop
            push_byte(q, b);
        end loop;

        return q;
    end function;

end package body;
