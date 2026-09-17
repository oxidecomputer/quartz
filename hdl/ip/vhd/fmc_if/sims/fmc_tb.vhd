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
use work.stm32h7_fmc_sim_pkg.all;
use work.stm32h7_fmc_model_pkg.all;
use work.fmc_tb_pkg.all;

entity fmc_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of fmc_tb is

begin

    th: entity work.fmc_th;

    bench: process
        -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
        -- So this sim only works in other simulators, like nvc
        alias reset is << signal th.reset : std_logic >>;
        alias fmc_half_period is << signal th.fmc_half_period : time >>;
        alias timeout_count is << signal th.timeout_count : std_logic_vector(7 downto 0) >>;
        alias ne_pins is << signal th.ne : std_logic_vector(3 downto 0) >>;
        alias nwait_pin is << signal th.nwait : std_logic >>;
        alias contention_count is << signal th.contention_count : std_logic_vector(7 downto 0) >>;

        variable address       : std_logic_vector(25 downto 0) := (others => '0');
        variable data          : std_logic_vector(31 downto 0) := (others => '0');
        variable expected_data : std_logic_vector(31 downto 0) := (others => '0');
        variable buf           : buffer_t;
        variable buf2          : buffer_t;
        variable rand_state    : unsigned(31 downto 0) := x"1234_5678";
        variable addr_nat      : natural;

        -- deterministic LCG so the soak needs no external randomization
        -- packages and reproduces exactly
        impure function rand32 return unsigned is
        begin
            rand_state := resize(rand_state * 1664525, 32) + 1013904223;
            return rand_state;
        end;

        -- backing pattern for pre-filled read memory
        function rd_pattern (
            addr : natural
        ) return std_logic_vector is
        begin
            return std_logic_vector(resize(to_unsigned(addr, 32) * 1664525, 32) xor x"A5A5_A5A5");
        end;

        function to_addr (
            addr : natural
        ) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(addr, 26));
        end;

        procedure basic_write_read_pair is
        begin
            buf  := allocate(wmemory, 4096);
            buf2 := allocate(rmemory, 4096);
            data := X"DEAD_BEEF";
            set_expected_word(wmemory, 16#40#, data);
            fmc_write32(net, to_addr(16#40#), data);
            expected_data := X"CAFE_F00D";
            write_word(rmemory, 16#80#, expected_data);
            fmc_read32(net, to_addr(16#80#), data);
            check_equal(data, expected_data, "Read data did not match expected");
            wait for 2 us; -- let the posted write land before checking memory
            check_expected_was_written(buf);
        end;

        procedure soak (
            constant num_ops : natural
        ) is
            constant rd_words   : natural := 1024;
            constant wr_base    : natural := 16#10000#;
            variable wr_index   : natural := 0;
            variable do_read    : boolean;
            variable r          : unsigned(31 downto 0);
        begin
            buf  := allocate(wmemory, 16#20000#);
            buf2 := allocate(rmemory, 4 * rd_words);
            for i in 0 to rd_words - 1 loop
                write_word(rmemory, i * 4, rd_pattern(i * 4));
            end loop;
            for i in 1 to num_ops loop
                -- occasionally change the inter-transaction gap
                r := rand32;
                if r(2 downto 0) = "000" then
                    fmc_set_txn_gap(net, sp_bus_handle, to_integer(r(5 downto 3)));
                end if;
                r       := rand32;
                do_read := r(0) = '1';
                if do_read then
                    addr_nat := to_integer(r(11 downto 2)) * 4;
                    fmc_read32(net, to_addr(addr_nat), data);
                    check_equal(data, rd_pattern(addr_nat),
                                "soak read mismatch at addr " & to_string(addr_nat));
                else
                    -- distinct write addresses so in-flight writes can never
                    -- race a later expectation on the same word
                    addr_nat := wr_base + wr_index * 4;
                    wr_index := wr_index + 1;
                    data     := std_logic_vector(rand32);
                    set_expected_word(wmemory, addr_nat, data);
                    fmc_write32_nb(net, to_addr(addr_nat), data);
                end if;
            end loop;
            fmc_set_txn_gap(net, sp_bus_handle, 0);
            fmc_wait_idle(net);
            wait for 2 us;
            check_expected_was_written(buf);
        end;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        show_all(rd_logger, display_handler);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("basic_fmc_write_test") then
                data := X"DEADBEEF";
                -- Set up the buffer used by the AXI write target
                buf := allocate(wmemory, 4 * 2, alignment => 32);
                -- Only going to allow writes, and set the expected data
                -- using the simulation interface
                set_permissions(wmemory, to_integer(address), write_only);
                set_expected_word(wmemory, to_integer(address), data);
                -- Do the FMC -> AXI write transaction
                fmc_write32(net, address, data);
                wait for 2 us; -- posted write crosses the CDC behind us
                check_expected_was_written(buf);
                -- Do a second transaction
                data := X"ADEADBAD";
                set_expected_word(wmemory, to_integer(address), data);
                fmc_write32(net, address, data);
                wait for 2 us;
                check_expected_was_written(buf);
            elsif run("basic_fmc_read_test") then
                buf := allocate(rmemory, 4 * 2, alignment => 32);
                -- Use the simulation interface to set the data we're going to read back
                expected_data := X"DEADBEEF";
                write_word(rmemory, base_address(buf), expected_data);
                -- TB will fault if DUT tries to write to this memory
                set_permissions(rmemory, base_address(buf), read_only);
                -- Read back written word via sim interface and check it matches
                data := read_word(rmemory, base_address(buf), 4);
                check_equal(data, expected_data, "Sim I/F Read data did not match exptected");
                -- Now do the FMC transaction, and check that returned data matches
                fmc_read32(net, address, data);
                check_equal(data, expected_data, "Read data did not match exptected");
                -- Do a second transaction back-to-back
                expected_data := X"ADEADBAD";
                write_word(rmemory, base_address(buf), expected_data);
                fmc_read32(net, address, data);
                check_equal(data, expected_data, "2nd read data did not match exptected");
            elsif run("basic_fmc_read_after_write") then
                data := X"DEADBEEF";
                -- Set up the buffer used by the AXI write target
                buf := allocate(wmemory, 4 * 2, alignment => 32);
                buf2 := allocate(rmemory, 4 * 2, alignment => 32);
                -- Only going to allow writes, and set the expected data
                -- using the simulation interface
                set_permissions(wmemory, to_integer(address), write_only);
                set_expected_word(wmemory, to_integer(address), data);
                -- Do the FMC -> AXI write transaction
                fmc_write32(net, address, data);
                -- the posted write must land before its expectation is
                -- replaced with the second value
                wait for 2 us;
                -- Do a second transaction
                expected_data := X"ADEADBAD";
                set_expected_word(wmemory, to_integer(address), expected_data);
                fmc_write32(net, address, expected_data);

                write_word(rmemory, base_address(buf2), expected_data);
                set_permissions(rmemory, base_address(buf2), read_only);
                -- The read orders behind both writes in the transaction FIFO,
                -- so it also acts as the write-completion flush
                fmc_read32(net, address, data);
                check_equal(data, expected_data, "Read data did not match exptected");
                check_expected_was_written(buf);
            elsif run("varied_address_write_read") then
                -- walk a one over the address bits; 512 KB keeps the VUnit
                -- memory model inside nvc's heap while still covering the
                -- non-muxed a(18:16) upper-address path
                buf  := allocate(wmemory, 2 ** 19);
                buf2 := allocate(rmemory, 2 ** 19);
                for bit in 2 to 18 loop
                    addr_nat := 2 ** bit;
                    data     := rd_pattern(addr_nat);
                    set_expected_word(wmemory, addr_nat, data);
                    fmc_write32_nb(net, to_addr(addr_nat), data);
                    write_word(rmemory, addr_nat, not data);
                    fmc_read32(net, to_addr(addr_nat), expected_data);
                    check_equal(expected_data, not data,
                                "read mismatch at address bit " & to_string(bit));
                end loop;
                wait for 2 us;
                check_expected_was_written(buf);
            elsif run("back_to_back_writes") then
                -- more writes than the transaction FIFO holds, with a slowed
                -- AXI responder, so the dispatch-stall backpressure engages
                buf := allocate(wmemory, 4096);
                set_response_latency(net, axi_write_target, 500 ns);
                for i in 0 to 31 loop
                    data := std_logic_vector(rand32);
                    set_expected_word(wmemory, i * 4, data);
                    fmc_write32_nb(net, to_addr(i * 4), data);
                end loop;
                fmc_wait_idle(net);
                wait for 25 us;
                check_expected_was_written(buf);
                check_equal(unsigned(timeout_count), 0,
                            "backpressure must stall, not time out, at this latency");
            elsif run("back_to_back_reads") then
                buf := allocate(rmemory, 4096);
                for i in 0 to 31 loop
                    write_word(rmemory, i * 4, rd_pattern(i * 4));
                end loop;
                for i in 0 to 31 loop
                    fmc_read32(net, to_addr(i * 4), data);
                    check_equal(data, rd_pattern(i * 4),
                                "b2b read mismatch at word " & to_string(i));
                end loop;
            elsif run("slow_read_responder") then
                -- long AXI read latency, but below the wait timeout: the SP
                -- just stalls and then gets correct data
                buf := allocate(rmemory, 64);
                expected_data := X"0BAD_CAFE";
                write_word(rmemory, 16, expected_data);
                set_response_latency(net, axi_read_target, 2 us);
                fmc_read32(net, to_addr(16), data);
                check_equal(data, expected_data, "slow read returned wrong data");
                check_equal(unsigned(timeout_count), 0, "no timeout expected");
            elsif run("read_timeout_recovery") then
                -- AXI read latency far beyond the wait timeout: the SP gets
                -- poison instead of a hung bus, and the stale response is
                -- discarded before the next read
                buf := allocate(rmemory, 64);
                write_word(rmemory, 0, X"1111_2222");
                write_word(rmemory, 4, X"3333_4444");
                set_response_latency(net, axi_read_target, 50 us);
                fmc_read32(net, to_addr(0), data);
                check_equal(data, std_logic_vector'(X"FFFF_FFFF"),
                            "timed-out read must return poison");
                check_equal(unsigned(timeout_count), 1, "expected one timeout");
                -- let the stale response land and drain
                wait for 60 us;
                set_response_latency(net, axi_read_target, 0 ns);
                fmc_read32(net, to_addr(4), data);
                check_equal(data, std_logic_vector'(X"3333_4444"),
                            "post-timeout read must return fresh data");
                check_equal(unsigned(timeout_count), 1, "no further timeouts expected");
            elsif run("write_backpressure_timeout") then
                -- wedge the write responder so the FIFOs fill and dispatch
                -- stalls past the timeout: the overflowing writes are
                -- swallowed rather than hanging the SP
                buf := allocate(wmemory, 4096);
                set_response_latency(net, axi_write_target, 20 us);
                for i in 0 to 15 loop
                    data := std_logic_vector(rand32);
                    set_expected_word(wmemory, i * 4, data);
                    fmc_write32_nb(net, to_addr(i * 4), data);
                end loop;
                -- these overflow the queue; some will be swallowed by the
                -- timeout, so no expectations are set on them
                for i in 16 to 19 loop
                    data := std_logic_vector(rand32);
                    fmc_write32_nb(net, to_addr(i * 4), data);
                end loop;
                fmc_wait_idle(net);
                check_true(unsigned(timeout_count) > 0,
                           "expected at least one swallowed write");
                set_response_latency(net, axi_write_target, 0 ns);
                wait for 500 us; -- drain the wedged queue
                check_expected_was_written(buf);
                -- interface must still be alive
                data := X"600D_600D";
                set_expected_word(wmemory, 16#100#, data);
                fmc_write32(net, to_addr(16#100#), data);
                wait for 2 us;
                check_expected_was_written(buf);
            elsif run("cs_abort_read_recovery") then
                buf := allocate(rmemory, 64);
                write_word(rmemory, 0, X"AAAA_BBBB");
                write_word(rmemory, 4, X"CCCC_DDDD");
                -- abort right after the address phase: the read is already in
                -- flight and its data must be silently discarded
                fmc_abort_next(net, sp_bus_handle, 0);
                fmc_read32(net, to_addr(0), data); -- returned data is undefined
                fmc_read32(net, to_addr(4), data);
                check_equal(data, std_logic_vector'(X"CCCC_DDDD"),
                            "read after phase-0 abort must be clean");
                -- abort after one beat: the DUT finishes the word on its own
                fmc_abort_next(net, sp_bus_handle, 1);
                fmc_read32(net, to_addr(0), data); -- returned data is undefined
                fmc_read32(net, to_addr(4), data);
                check_equal(data, std_logic_vector'(X"CCCC_DDDD"),
                            "read after one-beat abort must be clean");
                check_equal(unsigned(timeout_count), 0, "aborts are not timeouts");
            elsif run("cs_abort_write_recovery") then
                buf := allocate(wmemory, 64);
                -- aborted writes complete with zero filler on the AXI side by
                -- design; no expectations on them
                data := X"1234_5678";
                fmc_abort_next(net, sp_bus_handle, 0);
                fmc_write32(net, to_addr(0), data);
                fmc_abort_next(net, sp_bus_handle, 1);
                fmc_write32(net, to_addr(4), data);
                -- interface must still work
                data := X"8765_4321";
                set_expected_word(wmemory, 8, data);
                fmc_write32(net, to_addr(8), data);
                wait for 2 us;
                check_expected_was_written(buf);
                check_equal(unsigned(timeout_count), 0, "aborts are not timeouts");
            elsif run("reset_between_transactions") then
                buf  := allocate(wmemory, 64);
                buf2 := allocate(rmemory, 64);
                data := X"BEF0_4E00";
                set_expected_word(wmemory, 0, data);
                fmc_write32(net, to_addr(0), data);
                wait for 2 us;
                check_expected_was_written(buf);
                -- yank chip_reset between transactions and confirm the
                -- interface comes back
                reset <= force '1';
                wait for 300 ns;
                reset <= release;
                wait for 500 ns;
                data := X"5EC0_4D00";
                set_expected_word(wmemory, 4, data);
                fmc_write32(net, to_addr(4), data);
                write_word(rmemory, 8, X"1357_2468");
                fmc_read32(net, to_addr(8), data);
                check_equal(data, std_logic_vector'(X"1357_2468"),
                            "read after reset must work");
                wait for 2 us;
                check_expected_was_written(buf);
            elsif run("missed_start_timeout") then
                -- Pin chip select with no address latch, emulating the FSM
                -- having miscaptured a transaction start: the SP would be
                -- stalled on its bus, and only the idle timeout can free it.
                ne_pins <= force "1110";
                wait until nwait_pin = '1' for 30 us;
                check_equal(nwait_pin, '1',
                            "wait must release after a missed-start timeout");
                wait for 100 ns; -- let the counter output settle
                check_equal(unsigned(timeout_count), 1, "expected one timeout");
                ne_pins <= release;
                wait for 2 us;
                -- interface must still be alive
                buf  := allocate(wmemory, 64);
                buf2 := allocate(rmemory, 64);
                data := X"0DDB_A115";
                set_expected_word(wmemory, 0, data);
                fmc_write32(net, to_addr(0), data);
                write_word(rmemory, 4, X"BEA7_ED00");
                fmc_read32(net, to_addr(4), data);
                check_equal(data, std_logic_vector'(X"BEA7_ED00"),
                            "read after missed-start recovery must work");
                wait for 2 us;
                check_expected_was_written(buf);
                check_equal(unsigned(timeout_count), 1,
                            "no further timeouts expected");
            elsif run("random_soak") then
                soak(60);
            elsif run("basic_write_read_66mhz") then
                fmc_half_period <= force 7.5 ns;
                wait for 100 ns;
                basic_write_read_pair;
            elsif run("basic_write_read_100mhz") then
                fmc_half_period <= force 5 ns;
                wait for 100 ns;
                basic_write_read_pair;
            elsif run("back_to_back_100mhz") then
                fmc_half_period <= force 5 ns;
                wait for 100 ns;
                buf  := allocate(wmemory, 4096);
                buf2 := allocate(rmemory, 4096);
                for i in 0 to 31 loop
                    data := std_logic_vector(rand32);
                    set_expected_word(wmemory, i * 4, data);
                    fmc_write32_nb(net, to_addr(i * 4), data);
                end loop;
                for i in 0 to 15 loop
                    write_word(rmemory, i * 4, rd_pattern(i * 4));
                    fmc_read32(net, to_addr(i * 4), data);
                    check_equal(data, rd_pattern(i * 4),
                                "100mhz b2b read mismatch at word " & to_string(i));
                end loop;
                fmc_wait_idle(net);
                wait for 2 us;
                check_expected_was_written(buf);
            elsif run("random_soak_66mhz") then
                fmc_half_period <= force 7.5 ns;
                wait for 100 ns;
                soak(60);
            elsif run("random_soak_100mhz") then
                fmc_half_period <= force 5 ns;
                wait for 100 ns;
                soak(60);
            end if;
        end loop;
        -- every test finishes with a quiet bus and zero observed contention
        check_equal(unsigned(contention_count), 0,
                    "DUT contention counter must be zero");
        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 5 ms);

end tb;
