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

use work.hash_engine_regs_pkg.all;
use work.hash_engine_sim_pkg.all;
use work.keccak_pkg.all;
use work.sha3_sim_pkg.all;

-- Tests the hashing engine through its register interface.
--
-- Every expected digest is computed with sha3_sim_pkg's software sponge over a
-- queue built to match what the engine should have hashed, so nothing here is a
-- transcribed constant. The SHA3 core itself is not under test: keccak_pkg_tb
-- anchors that against published vectors.
entity hash_engine_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of hash_engine_tb is

    constant START_CMD : std_logic_vector(31 downto 0) :=
        pack(control_type'(abort => '0', start => '1'));
    constant ABORT_CMD : std_logic_vector(31 downto 0) :=
        pack(control_type'(abort => '1', start => '0'));
    constant CFG_LOCAL : std_logic_vector(31 downto 0) :=
        pack(config_type'(source => LOCAL_REG));
    constant CFG_QSPI : std_logic_vector(31 downto 0) :=
        pack(config_type'(source => HOST_QSPI));

begin

    th: entity work.hash_engine_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;

        variable status   : std_logic_vector(31 downto 0);
        variable rdata    : std_logic_vector(31 downto 0);
        variable dig      : std_logic_vector(255 downto 0);
        variable expected : digest_t;
        variable msg      : queue_t;

        -- A byte of software supplied test data. Arbitrary, but a function of the
        -- index so a misordered feed shows up as a wrong digest.
        impure function sw_byte (
            i : natural
        ) return natural is
        begin
            return (i * 37 + 11) mod 256;
        end function;

        -- Build what the engine should end up hashing: the 0xFF run, then either
        -- software bytes or flash contents.
        impure function expected_msg (
            prepend    : natural;
            nbytes     : natural;
            from_flash : boolean;
            base_addr  : natural
        ) return queue_t is
            variable q : queue_t := new_queue;
        begin
            for i in 1 to prepend loop
                push_byte(q, 16#FF#);
            end loop;

            for i in 0 to nbytes - 1 loop
                if from_flash then
                    push_byte(q, to_integer(unsigned(flash_byte(base_addr + i))));
                else
                    push_byte(q, sw_byte(i));
                end if;
            end loop;

            return q;
        end function;

        procedure configure (
            source     : std_logic_vector(31 downto 0);
            prepend    : natural;
            total_len  : natural;
            base_addr  : natural
        ) is
        begin
            write_reg(net, CONFIG_OFFSET, source);
            write_reg(net, PREPEND_OFFSET, To_StdLogicVector(prepend, 32));
            write_reg(net, LENGTH_OFFSET, To_StdLogicVector(total_len, 32));
            write_reg(net, FLASH_ADDR_OFFSET, To_StdLogicVector(base_addr, 32));
        end procedure;

        -- Push nbytes of software data, four at a time, respecting wfifo_full.
        -- Trailing bytes of the final word are filled with 0xAA: LENGTH decides
        -- where the message ends, so they must not reach the hash.
        procedure feed_sw (
            nbytes : natural
        ) is
            variable word  : std_logic_vector(31 downto 0);
            variable full  : std_logic_vector(31 downto 0);
            variable idx   : natural := 0;
        begin
            while idx < nbytes loop
                loop
                    read_reg(net, STATUS_OFFSET, full);
                    exit when (full and STATUS_WFIFO_FULL_MASK) = (full'range => '0');
                end loop;

                for b in 0 to 3 loop
                    if idx + b < nbytes then
                        word(8 * b + 7 downto 8 * b) := To_StdLogicVector(sw_byte(idx + b), 8);
                    else
                        word(8 * b + 7 downto 8 * b) := x"AA";
                    end if;
                end loop;

                write_reg(net, WDATA_OFFSET, word);
                idx := idx + 4;
            end loop;
        end procedure;

        -- Run a complete software fed hash and check the digest.
        procedure run_local (
            prepend : natural;
            nbytes  : natural;
            name    : string
        ) is
            variable q : queue_t;
            variable e : digest_t;
            variable d : std_logic_vector(255 downto 0);
            variable s : std_logic_vector(31 downto 0);
        begin
            q := expected_msg(prepend, nbytes, false, 0);
            e := sha3_256_digest(q);

            configure(CFG_LOCAL, prepend, prepend + nbytes, 0);
            write_reg(net, CONTROL_OFFSET, START_CMD);
            feed_sw(nbytes);
            wait_hash_done(net, s);
            read_digest(net, d);

            check_equal(d, std_logic_vector(e), name);
        end procedure;

        -- Run a complete flash fed hash and check the digest.
        procedure run_flash (
            prepend   : natural;
            nbytes    : natural;
            base_addr : natural;
            name      : string
        ) is
            variable q : queue_t;
            variable e : digest_t;
            variable d : std_logic_vector(255 downto 0);
            variable s : std_logic_vector(31 downto 0);
        begin
            q := expected_msg(prepend, nbytes, true, base_addr);
            e := sha3_256_digest(q);

            configure(CFG_QSPI, prepend, prepend + nbytes, base_addr);
            write_reg(net, CONTROL_OFFSET, START_CMD);
            wait_hash_done(net, s);
            read_digest(net, d);

            check_equal(d, std_logic_vector(e), name);
        end procedure;

        -- Drive a literal message through the manual path and check it against a
        -- published digest, rather than against the software sponge. This is the
        -- one place the engine is measured against the standard instead of
        -- against our own model of it.
        procedure run_vector (
            msg          : string;
            expected_hex : string;
            name         : string
        ) is
            variable word : std_logic_vector(31 downto 0);
            variable full : std_logic_vector(31 downto 0);
            variable idx  : natural := 0;
            variable d    : std_logic_vector(255 downto 0);
            variable s    : std_logic_vector(31 downto 0);
        begin
            configure(CFG_LOCAL, 0, msg'length, 0);
            write_reg(net, CONTROL_OFFSET, START_CMD);

            while idx < msg'length loop
                loop
                    read_reg(net, STATUS_OFFSET, full);
                    exit when (full and STATUS_WFIFO_FULL_MASK) = (full'range => '0');
                end loop;

                for b in 0 to 3 loop
                    if idx + b < msg'length then
                        word(8 * b + 7 downto 8 * b) :=
                            To_StdLogicVector(character'pos(msg(msg'low + idx + b)), 8);
                    else
                        word(8 * b + 7 downto 8 * b) := x"AA";
                    end if;
                end loop;

                write_reg(net, WDATA_OFFSET, word);
                idx := idx + 4;
            end loop;

            wait_hash_done(net, s);
            read_digest(net, d);

            check_equal(d, std_logic_vector(hex_digest(expected_hex)), name);
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("register_readback") then
                -- Every configuration register holds what was written, and the
                -- self clearing control bits read back as zero.
                write_reg(net, CONFIG_OFFSET, CFG_QSPI);
                write_reg(net, PREPEND_OFFSET, x"0000_1234");
                write_reg(net, FLASH_ADDR_OFFSET, x"DEAD_BEEF");
                write_reg(net, LENGTH_OFFSET, x"0000_ABCD");

                read_reg(net, CONFIG_OFFSET, rdata);
                check_equal(rdata, CFG_QSPI, "CONFIG readback");
                read_reg(net, PREPEND_OFFSET, rdata);
                check_equal(rdata, std_logic_vector'(x"0000_1234"), "PREPEND readback");
                read_reg(net, FLASH_ADDR_OFFSET, rdata);
                check_equal(rdata, std_logic_vector'(x"DEAD_BEEF"), "FLASH_ADDR readback");
                read_reg(net, LENGTH_OFFSET, rdata);
                check_equal(rdata, std_logic_vector'(x"0000_ABCD"), "LENGTH readback");

                read_reg(net, CONTROL_OFFSET, rdata);
                check_equal(rdata, std_logic_vector'(x"0000_0000"),
                            "CONTROL bits are self clearing so must read zero");

            elsif run("nist_vectors") then
                -- The published SHA3-256 vectors, from
                -- https://di-mgt.com.au/sha_testvectors.html, driven through the
                -- same LOCAL_REG path tools/hash_engine_vectors_test.py uses on
                -- hardware, so the expectations that script checks are known good
                -- against the RTL before anyone plugs a board in.
                --
                -- The empty message is in that set too but cannot be expressed on
                -- an AXI stream; reject_zero_length covers what the engine does
                -- with it instead. The million byte and 1 GB vectors are left to
                -- the hardware script.
                run_vector("abc",
                           "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532",
                           "vector: abc");

                run_vector("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                           "41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376",
                           "vector: 448 bit");

                run_vector("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn" &
                           "hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
                           "916f6061fe879741ca6469b43971dfdb28b1a32dc36cb3254e812be27aad1d18",
                           "vector: 896 bit");

            elsif run("local_reg_source") then
                run_local(0, 64, "sha3 of 64 software fed bytes");

            elsif run("local_reg_ragged") then
                -- Not a multiple of four, so the last word carries filler that
                -- must be ignored.
                run_local(0, 61, "sha3 of 61 software fed bytes");
                run_local(0, 1, "sha3 of a single software fed byte");

            elsif run("local_crosses_rate_block") then
                -- 136 bytes is the sponge rate, so these straddle the block
                -- boundary and force the padding corner cases in the core.
                run_local(0, 135, "135 bytes");
                run_local(0, 136, "136 bytes");
                run_local(0, 137, "137 bytes");

            elsif run("prepend_only") then
                run_local(200, 0, "200 prepended 0xFF bytes and no source data");

            elsif run("prepend_plus_local") then
                run_local(16, 48, "16 prepended bytes then 48 software bytes");

            elsif run("flash_source") then
                run_flash(0, 100, 16#1000#, "sha3 of 100 flash bytes");

            elsif run("prepend_plus_flash") then
                -- The intended use: a fixed 0xFF header then a flash range.
                run_flash(32, 200, 16#2040#, "32 prepended bytes then 200 flash bytes");

            elsif run("flash_multi_chunk") then
                -- Past 256 bytes the backend has to split the read, and past 4096
                -- it exceeds anything the eSPI flash path could express, which is
                -- why this client carries a 32 bit length.
                run_flash(0, 300, 16#4000#, "300 flash bytes, two chunks");
                run_flash(8, 5000, 16#8000#, "5000 flash bytes, twenty chunks");

            elsif run("progress_advances") then
                configure(CFG_QSPI, 0, 2000, 16#1000#);
                write_reg(net, CONTROL_OFFSET, START_CMD);

                -- Catch it mid flight: busy set and progress somewhere sensible.
                wait for 40 us;
                read_reg(net, STATUS_OFFSET, status);
                check_equal((status and STATUS_BUSY_MASK) /= (status'range => '0'), true,
                            "should still be busy part way through 2000 bytes");
                read_reg(net, PROGRESS_OFFSET, rdata);
                check_equal(to_integer(unsigned(rdata)) > 0, true, "progress should have advanced");
                check_equal(to_integer(unsigned(rdata)) < 2000, true, "progress should not be complete");

                wait_hash_done(net, status);
                read_reg(net, PROGRESS_OFFSET, rdata);
                check_equal(to_integer(unsigned(rdata)), 2000, "progress should end at the length");

            elsif run("reject_zero_length") then
                configure(CFG_LOCAL, 0, 0, 0);
                write_reg(net, CONTROL_OFFSET, START_CMD);
                wait for 2 us;

                read_reg(net, STATUS_OFFSET, status);
                check_equal((status and STATUS_CFG_ERR_MASK) /= (status'range => '0'), true,
                            "zero length should set cfg_err");
                check_equal((status and STATUS_BUSY_MASK) = (status'range => '0'), true,
                            "zero length should never go busy");

                -- and the engine still works afterwards
                run_local(0, 32, "hash after a rejected start");

            elsif run("reject_prepend_gt_length") then
                configure(CFG_LOCAL, 100, 50, 0);
                write_reg(net, CONTROL_OFFSET, START_CMD);
                wait for 2 us;

                read_reg(net, STATUS_OFFSET, status);
                check_equal((status and STATUS_CFG_ERR_MASK) /= (status'range => '0'), true,
                            "prepend longer than the message should set cfg_err");
                check_equal((status and STATUS_BUSY_MASK) = (status'range => '0'), true,
                            "should never go busy");

            elsif run("abort_midway") then
                -- Abandon a flash read part way through. The engine has to swallow
                -- the bytes the backend still owes before it can be reused, so busy
                -- stays set until the channel is resynchronised.
                configure(CFG_QSPI, 0, 3000, 16#1000#);
                write_reg(net, CONTROL_OFFSET, START_CMD);
                wait for 30 us;

                write_reg(net, CONTROL_OFFSET, ABORT_CMD);
                wait_not_busy(net, status);
                check_equal((status and STATUS_ABORTED_MASK) /= (status'range => '0'), true,
                            "abort should set aborted");
                check_equal((status and STATUS_DONE_MASK) = (status'range => '0'), true,
                            "abort should not report done");

                -- The real check: a stale byte left in the channel would corrupt
                -- this digest.
                run_flash(0, 128, 16#6000#, "flash hash after an abort");

            elsif run("restart_midway") then
                -- Restarting mid flight must discard the partial message and the
                -- tail of the outstanding flash read.
                configure(CFG_QSPI, 0, 3000, 16#1000#);
                write_reg(net, CONTROL_OFFSET, START_CMD);
                wait for 30 us;

                run_flash(0, 150, 16#7000#, "flash hash restarted over a running one");

            elsif run("back_to_back") then
                run_local(0, 40, "first message");
                run_flash(4, 80, 16#3000#, "second message, flash sourced");
                run_local(8, 40, "third message, back to software");

            elsif run("wfifo_full_backpressure") then
                -- Fill the software FIFO with the engine idle, so nothing drains
                -- it. Starting a hash first would not work: the core consumes a
                -- byte per clock, far faster than the bus can deliver four, so the
                -- FIFO would never back up.
                -- 64 words is the FIFO depth, so this must fill.
                for i in 0 to 79 loop
                    write_reg(net, WDATA_OFFSET, To_StdLogicVector(i, 32));
                end loop;

                read_reg(net, STATUS_OFFSET, status);
                check_equal((status and STATUS_WFIFO_FULL_MASK) /= (status'range => '0'), true,
                            "software FIFO should report full after overfilling it");

                -- Leave the FIFO dirty on purpose: the next run's end of run flush
                -- is what cleans it, and back_to_back covers that.
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 50 ms);

end tb;
