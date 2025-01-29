-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use vunit_lib.spi_pkg.all;

use work.spi_axi_tb_pkg.all;
use work.spi_axi_pkg.all;


entity spi_axi_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of spi_axi_tb is

begin

    th: entity work.spi_axi_th;

    bench: process
        alias reset is << signal th.reset : std_logic >>;
        alias csn is << signal th.csn : std_logic >>;
        variable buf           : buffer_t;
        variable buf2          : buffer_t;
        variable data          : std_logic_vector(7 downto 0) := (others => '0');
        variable expected_data : std_logic_vector(7 downto 0) := (others => '0');
        variable address       : std_logic_vector(15 downto 0) := (others => '0');
        variable tx_queue      : queue_t := new_queue;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        show_all(wr_logger, display_handler);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';
        wait for 500 ns;  -- let the resets propagate

        while test_suite loop
            if run("single-read") then
                -- set up the "memory to be read with a known value"
                buf := allocate(rmemory, 1 * 64, alignment => 32);
                -- Use the simulation interface to set the data we're going to read back
                expected_data := X"AA";
                write_word(rmemory, 0, expected_data);
                -- TB will fault if DUT tries to write to this memory
                set_permissions(rmemory, 0, read_only);
                -- issue spi read command (data is dummy byte here since this is a)
                spi_send_byte(net, spi_opcode_read, address, (others => '0'), csn);
                -- Read back word rx'd from DUT and check it matches expected.
                -- -- we're going to have 3 dummy bytes here, skip them, keeping the 4th
                for i in 0 to 3 loop
                    pop_stream(net, master_rstream, data);
                end loop;
                check_equal(data, expected_data, "Read data did not match expected");
            elsif run("single-write") then
                -- set up the "memory to be read with a known value"
                buf := allocate(wmemory, 1 * 64, alignment => 32);
                -- Use the simulation interface to set the data we're expected to write
                expected_data := X"AA";
                set_expected_word(wmemory, 0, expected_data);
                -- issue spi write command
                spi_send_byte(net, spi_opcode_write, address, expected_data, csn);
                -- no reach into the ram and see what is there now
                wait for 20 ns;
                check_expected_was_written(buf);
            elsif run("single-bit-set") then
                -- Due to how the axi blocks by vunit work, we need to set up 2 buffers, one for the
                -- read side and one for the write-side
                -- READ SIDE is buf
                -- set up the "memory to be read with a known value"
                buf := allocate(rmemory, 1 * 64, alignment => 32);
                -- WRITE SIDE is buf2
                buf2 := allocate(wmemory, 1 * 64, alignment => 32);
                -- Sick X"AA" into the read buffer, this is going to be our starting point for the bit-set
                -- Use the simulation interface to set the data we're going to read back
                expected_data := X"AA";
                write_word(rmemory, 0, expected_data);
                -- Our Write address now has X"AA" in it.
                data := X"05";
                -- This is the expected write into the write-side after the read-modify-write bit-set operation
                expected_data := expected_data or data;
                set_expected_word(wmemory, 0, expected_data);

                -- issue spi write command for bit set with data bits
                spi_send_byte(net, spi_opcode_bit_set, address, data, csn);

                -- no reach into the ram and see what is there now
                wait for 1 us;
                check_expected_was_written(buf2);
            elsif run("single-bit-clr") then
                -- Due to how the axi blocks by vunit work, we need to set up 2 buffers, one for the
                -- read side and one for the write-side
                -- READ SIDE is buf
                -- set up the "memory to be read with a known value"
                buf := allocate(rmemory, 1 * 64, alignment => 32);
                -- WRITE SIDE is buf2
                buf2 := allocate(wmemory, 1 * 64, alignment => 32);
                -- Sick X"AA" into the read buffer, this is going to be our starting point for the bit-set
                
                -- Use the simulation interface to set the data we're going to read back
                expected_data := X"AA";
                write_word(rmemory, 0, expected_data);
                -- Our Write address now has X"AA" in it.
                data := X"0A";
                -- This is the expected write into the write-side after the read-modify-write bit-set operation
                expected_data := expected_data and (not data);
                set_expected_word(wmemory, 0, expected_data);

                -- issue spi write command for bit set with data bits
                spi_send_byte(net, spi_opcode_bit_clr, address, data, csn);
                -- no reach into the ram and see what is there now
                wait for 20 ns;
                check_expected_was_written(buf2);
            elsif run("multi-read") then
                 -- set up the "memory to be read with a known value"
                 buf := allocate(rmemory, 4 * 32, alignment => 32);
                 -- Use the simulation interface to set the data we're going to read back
                 -- Load up 3 known bytes into the memory
                 expected_data := X"AA";
                 write_word(rmemory, 0, X"ACABAA");
                 -- TB will fault if DUT tries to write to this memory
                 set_permissions(rmemory, 0, read_only);
                 -- issue spi read command for multiple bytes. No early abort
                 for i in 0 to 2 loop
                    push_byte(tx_queue, 0); -- push dummy data for the read
                 end loop;
                 spi_send_stream(net, spi_opcode_read, address, tx_queue, csn);
                 -- Read back word rx'd from DUT and check it matches expected.
                 -- we're going to have 3 dummy bytes here, skip them, keeping the 4th
                 expected_data := X"AA";
                 for i in 0 to 4 loop
                    pop_stream(net, master_rstream, data);
                    -- only check past the dummy data
                    if i > 2 then
                        check_equal(data, expected_data, "Read data did not match expected, iteration " & to_string(i-2));
                        expected_data := expected_data + 1;
                    end if;
                 end loop;
            elsif run("multi-write") then
                -- set up the "memory to be read with a known value"
                buf := allocate(wmemory, 1 * 64, alignment => 32);
                -- Use the simulation interface to set the data we're expected to write
                set_expected_word(wmemory, 0, X"ACABAA");
                -- issue spi write command
                expected_data := X"AA";
                for i in 0 to 2 loop
                    push_byte(tx_queue, to_integer(expected_data)); -- push dummy data for the read
                    expected_data := expected_data + 1;
                 end loop;
                 spi_send_stream(net, spi_opcode_write, address, tx_queue, csn);
                -- no reach into the ram and see what is there now
                wait for 20 ns;
                check_expected_was_written(buf);
            
            elsif run("ok-after-invalid-opcode") then
                    -- set up the "memory to be read with a known value"
                buf := allocate(rmemory, 1 * 64, alignment => 32);
                -- Use the simulation interface to set the data we're going to read back
                expected_data := X"AA";
                write_word(rmemory, 0, expected_data);
                -- TB will fault if DUT tries to write to this memory
                set_permissions(rmemory, 0, read_only);
                -- issue invalid opcode.
                spi_send_byte(net, "1001", address, (others => '0'), csn);
                -- Read back word rx'd from DUT and check it matches expected.
                -- we're going to have 3 dummy bytes here, skip them, keeping the 4th
                for i in 0 to 3 loop
                    pop_stream(net, master_rstream, data);
                end loop;
               wait for 20 ns;-- same thing again with a read this time
               -- issue spi read command (data is dummy byte here since this is a)
               spi_send_byte(net, spi_opcode_read, address, (others => '0'), csn);
               -- Read back word rx'd from DUT and check it matches expected.
               -- we're going to have 3 dummy bytes here, skip them, keeping the 4th
               for i in 0 to 3 loop
                   pop_stream(net, master_rstream, data);
               end loop;
               check_equal(data, expected_data, "Read data did not match expected");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;