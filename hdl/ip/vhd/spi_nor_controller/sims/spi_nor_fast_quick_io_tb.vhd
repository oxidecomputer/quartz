-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- The shipped fast configuration at the *quick* IO corner.
--
-- spi_nor_fast_tb runs the same RTL configuration with the slow-corner FPGA IO
-- delays, which is the corner that decides whether the sample point is late
-- enough. This one runs the fast corner, which decides whether it is early
-- enough: the sample point must land no later than half an sclk period past the
-- point the part stops holding the previous bit (tCLQX), and at the fast corner
-- everything arrives sooner, so that limit tightens.
--
-- Both corners have to pass for rx_sample_taps to be the right choice, and at
-- 62.5MHz the margin at this corner is well under a nanosecond. That is the
-- headline number for anyone considering pushing sclk higher, or deciding
-- whether to fall back to sclk_divisor = 1.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
use work.spi_nor_tb_pkg.all;
use work.spi_nor_pkg.all;
use work.spi_nor_target_vc_pkg.all;

entity spi_nor_fast_quick_io_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of spi_nor_fast_quick_io_tb is

begin

    th: entity work.spi_nor_th
        generic map (
            sclk_divisor   => 0,
            rx_sample_taps => 2,
            -- Fast corner of the delays the XDC bounds
            out_delay => 1.6 ns,
            in_delay  => 0.5 ns
        );

    bench: process
        alias reset is <<signal .spi_nor_fast_quick_io_tb.th.reset : std_logic>>;
        alias cs_n  is <<signal .spi_nor_fast_quick_io_tb.th.cs_n : std_logic>>;
        constant flash : actor_t := find("spi_nor_target");
    begin
        test_runner_setup(runner, runner_cfg);

        wait until reset = '0';
        wait for 500 ns;

        fill_pattern(net, flash);

        while test_suite loop
            if run("read_quad_32addr_dummy") then
                check_flash_read(net, FAST_READ_4BYTE_QUAD_OP, 8, 16#1200#, 64);
            elsif run("read_dual_32addr_dummy") then
                check_flash_read(net, FAST_READ_4BYTE_DUAL_OP, 8, 16#80#, 16);
            elsif run("write_then_read_back") then
                check_program_readback(net, flash, 16#2000#);
            elsif run("back_to_back_reads") then
                check_back_to_back_reads(net, 16#400#, 16#500#, 32);
            elsif run("output_delay_margin") then
                for clqv_ns in 2 to 7 loop
                    info("checking with tCLQV = " & to_string(clqv_ns) & " ns");
                    set_output_valid_delay(net, flash, clqv_ns * 1 ns);
                    check_flash_read(net, FAST_READ_4BYTE_QUAD_OP, 8, 16#1200#, 32);
                end loop;
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

    test_runner_watchdog(runner, 10 ms);

end tb;
