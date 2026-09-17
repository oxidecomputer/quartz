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
use work.spi_nor_target_vc_pkg.all;

-- Integration test: the hashing engine fetching through the real spi_nor_top,
-- the real QSPI link, and a modelled flash part.
--
-- The part is filled with pattern_byte(addr), which is a bijection over any
-- aligned 256 byte run, so the digest depends on exactly which addresses were
-- fetched. A chunk boundary that re-reads or skips a range changes the digest
-- rather than going unnoticed, which is the whole reason for testing at this
-- level rather than trusting hash_engine_tb's behavioural responder.
entity hash_spi_nor_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of hash_spi_nor_tb is

    constant START_CMD : std_logic_vector(31 downto 0) :=
        pack(control_type'(abort => '0', start => '1'));
    constant CFG_QSPI : std_logic_vector(31 downto 0) :=
        pack(config_type'(source => HOST_QSPI));
    constant CFG_AUX : std_logic_vector(31 downto 0) :=
        pack(config_type'(source => AUX_QSPI));

begin

    th: entity work.hash_spi_nor_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;

        constant flash_actor : actor_t := find("spi_nor_target0");
        -- The auxiliary flash is never filled, so it reads as erased 0xFF
        -- everywhere. That is what tells a hash of it apart from the same
        -- range on the host flash.
        constant aux_actor : actor_t := find("spi_nor_target1");

        variable status : std_logic_vector(31 downto 0);
        variable rdata  : std_logic_vector(31 downto 0);

        -- What the part holds at a given address. Outside the modelled window
        -- the VC returns erased data.
        impure function flash_content (
            addr : natural
        ) return std_logic_vector is
        begin
            if addr < flash_window_bytes then
                return pattern_byte(addr);
            end if;

            return x"FF";
        end function;

        -- The message the engine should end up hashing: the 0xFF run, then the
        -- flash from base_addr on. On the aux flash every byte is erased.
        impure function expected_msg (
            prepend   : natural;
            nbytes    : natural;
            base_addr : natural;
            aux       : boolean := false
        ) return queue_t is
            variable q : queue_t := new_queue;
        begin
            for i in 1 to prepend loop
                push_byte(q, 16#FF#);
            end loop;

            for i in 0 to nbytes - 1 loop
                if aux then
                    push_byte(q, 16#FF#);
                else
                    push_byte(q, to_integer(unsigned(flash_content(base_addr + i))));
                end if;
            end loop;

            return q;
        end function;

        procedure run_hash (
            prepend   : natural;
            nbytes    : natural;
            base_addr : natural;
            name      : string;
            aux       : boolean := false
        ) is
            variable e : digest_t;
            variable s : std_logic_vector(31 downto 0);
            variable d : std_logic_vector(255 downto 0);
        begin
            e := sha3_256_digest(expected_msg(prepend, nbytes, base_addr, aux));

            if aux then
                write_reg(net, CONFIG_OFFSET, CFG_AUX);
            else
                write_reg(net, CONFIG_OFFSET, CFG_QSPI);
            end if;
            write_reg(net, PREPEND_OFFSET, To_StdLogicVector(prepend, 32));
            write_reg(net, LENGTH_OFFSET, To_StdLogicVector(prepend + nbytes, 32));
            write_reg(net, FLASH_ADDR_OFFSET, To_StdLogicVector(base_addr, 32));
            write_reg(net, CONTROL_OFFSET, START_CMD);

            wait_hash_done(net, s);
            read_digest(net, d);

            check_equal(d, std_logic_vector(e), name);
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;

        -- Give the part known contents before anything reads it.
        fill_pattern(net, flash_actor);

        while test_suite loop
            if run("single_chunk") then
                run_hash(0, 64, 16#1000#, "64 bytes, inside one chunk");

            elsif run("exact_chunk") then
                -- Exactly one full chunk, the boundary the transaction manager
                -- is most likely to get wrong.
                run_hash(0, 256, 16#1000#, "256 bytes, exactly one chunk");

            elsif run("chunk_boundary") then
                -- One byte either side of the boundary, so an off-by-one in the
                -- chunking arithmetic cannot hide.
                run_hash(0, 255, 16#1000#, "255 bytes");
                run_hash(0, 257, 16#2000#, "257 bytes, second chunk is one byte");

            elsif run("multi_chunk") then
                run_hash(0, 600, 16#1000#, "600 bytes, three chunks");
                run_hash(0, 5000, 16#4000#, "5000 bytes, twenty chunks");

            elsif run("unaligned_base") then
                -- A base that is not a chunk multiple, so every chunk after the
                -- first starts mid-pattern.
                run_hash(0, 700, 16#1234#, "700 bytes from an unaligned base");

            elsif run("sector_bypass") then
                -- The configuration tools/hash_engine_flash_test.py drives on
                -- hardware: the first sector is fed as 0xFF and the flash is read
                -- from one sector in, so the message is the image with its first
                -- sector blanked.
                run_hash(16#1000#, 16#3000#, 16#1000#,
                         "sector bypass: 0x1000 of 0xFF then flash from 0x1000");

            elsif run("prepend_plus_flash") then
                run_hash(16, 300, 16#2000#, "16 prepended bytes then 300 fetched");

            elsif run("progress_and_busy") then
                write_reg(net, CONFIG_OFFSET, CFG_QSPI);
                write_reg(net, PREPEND_OFFSET, To_StdLogicVector(0, 32));
                write_reg(net, LENGTH_OFFSET, To_StdLogicVector(600, 32));
                write_reg(net, FLASH_ADDR_OFFSET, To_StdLogicVector(16#1000#, 32));
                write_reg(net, CONTROL_OFFSET, START_CMD);

                read_reg(net, STATUS_OFFSET, status);
                check_equal((status and STATUS_BUSY_MASK) /= (status'range => '0'), true,
                            "should be busy once a fetch is under way");

                wait_hash_done(net, status);
                read_reg(net, PROGRESS_OFFSET, rdata);
                check_equal(to_integer(unsigned(rdata)), 600, "all 600 bytes accounted for");

            elsif run("back_to_back") then
                -- The second run is the one that catches a channel left out of
                -- step by the first, e.g. bytes over-fetched and still queued.
                run_hash(0, 128, 16#1000#, "first fetch");
                run_hash(0, 300, 16#3000#, "second fetch, crossing a chunk boundary");
                run_hash(0, 64, 16#5000#, "third fetch");

            elsif run("aux_flash_source") then
                -- Same range on the other flash. The aux part is erased, so a
                -- fetch that quietly went to the host flash would come back
                -- with the pattern and fail the digest.
                run_hash(0, 600, 16#1000#, "600 bytes from the aux flash", aux => true);

            elsif run("host_after_aux") then
                -- The selection is latched per run; make sure it releases the
                -- aux flash and the host flash's channel is still in step after
                -- a run that never touched it.
                run_hash(0, 300, 16#2000#, "aux first", aux => true);
                run_hash(0, 300, 16#2000#, "then host");
                run_hash(0, 700, 16#1234#, "then aux again, unaligned", aux => true);
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 50 ms);

end tb;
