-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
use work.spi_nor_tb_pkg.all;
use work.spi_nor_pkg.all;
use work.spi_nor_target_vc_pkg.all;

entity spi_nor_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of spi_nor_tb is

begin

    th: entity work.spi_nor_th;

    bench: process
        -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
        -- So this sim only works in other simulators, like nvc
        -- reset_a uses the absolute path form (starting with a '.') and
        -- reset_b uses the relative path form of external naming for example purposes.
        alias reset is <<signal .spi_nor_tb.th.reset : std_logic>>;
        alias cs_n  is <<signal .spi_nor_tb.th.cs_n : std_logic>>;
        constant flash : actor_t := find("spi_nor_target");
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);

        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;

        -- Give the flash model known contents so read paths can be checked
        -- rather than just watched.
        fill_pattern(net, flash);

        while test_suite loop
            if run("instr_only") then
                check_jedec_id(net);
            elsif run("read_quad_32addr_dummy") then
                -- The read path that actually matters: hubris and the eSPI flash
                -- reader both use 4-byte-address quad fast read with 8 dummies.
                check_flash_read(net, FAST_READ_4BYTE_QUAD_OP, 8, 16#1200#, 64);
            elsif run("read_single_32addr") then
                check_flash_read(net, READ_DATA_4BYTE_OP, 0, 16#40#, 16);
            elsif run("read_dual_32addr_dummy") then
                check_flash_read(net, FAST_READ_4BYTE_DUAL_OP, 8, 16#80#, 16);
            elsif run("write_then_read_back") then
                check_program_readback(net, flash, 16#2000#);
            elsif run("back_to_back_reads") then
                check_back_to_back_reads(net, 16#400#, 16#500#, 32);
            elsif run("block_erase") then
                check_block_erase(net, flash, 16#30000#);
            elsif run("quad_page_program") then
                check_quad_page_program(net, flash, 16#5000#);
            elsif run("write_24addr_no_dummy") then
                write_data(net, x"03020100");  -- do do words
                write_data(net, x"07060504");  -- do do words
                write_data_size(net, 8);  -- write out 6 bytes
                write_instr(net, PAGE_PROGRAM_OP);
            elsif run("write_32addr_no_dummy") then
                write_data(net, x"AA55AA55");  -- do do words
                write_data(net, x"55AA55AA");  -- do do words
                write_data_size(net, 6);  -- write out 6 bytes
                write_instr(net, PAGE_PROGRAM_4BYTE_OP);
            elsif run("read_24addr_no_dummy") then
                write_data_size(net, 8);  -- read out 6 bytes
                write_instr(net, READ_DATA_OP);
            elsif run("read_32addr_no_dummy") then
                write_data_size(net, 6);  -- read out 6 bytes
                write_instr(net, READ_DATA_4BYTE_OP);
            elsif run("read_24addr_dummy") then
                write_data_size(net, 1);  -- read out 6 bytes
                write_dummy(net, 3);  -- 8 dummy clocks
                write_instr(net, FAST_READ_4BYTE_OP);
            elsif run("write_32addr_quad") then
                write_data_size(net, 5);  -- write out 5 bytes
                write_data(net, x"03020100");  -- do do words
                write_data(net, x"07060504");  -- do do words
                write_instr(net, QUAD_INPUT_PAGE_PROGRAM_OP);
            elsif run("read_2x_32addr_dummy") then
                write_dummy(net, 8);  -- 8 dummy clocks
                write_data_size(net, 27);  -- read out 27 bytes
                write_instr(net, FAST_READ_4BYTE_QUAD_OP);
                wait for 25 us;
                write_instr(net, FAST_READ_4BYTE_QUAD_OP);
            elsif run("erase_64") then
                write_addr(net, x"aabbccdd");  -- erase the whole chip
                write_instr(net, BLOCK_ERASE_64K_4BYTE_OP);
                wait for 25 us;
            end if;
        end loop;

        wait for 1 us;
        if cs_n = '0' then
            wait until cs_n = '1' for 1 ms;
        end if;

        wait for 1 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;
