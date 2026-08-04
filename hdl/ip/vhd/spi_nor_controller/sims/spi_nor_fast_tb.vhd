-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- The same checked scenarios as spi_nor_tb, run at the fast configuration the
-- projects actually ship: sclk_divisor 0, so sclk is clk/2 (62.5MHz off the
-- 125MHz system clock) instead of clk/6.
--
-- This is the configuration where every clk edge is also an sclk edge, so there
-- are no spare cycles between sclk edges for phase transitions to settle in.
-- It is a genuinely different timing regime from clk/6, not just a faster one,
-- which is why it gets its own testbench rather than a comment.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
use work.spi_nor_tb_pkg.all;
use work.spi_nor_pkg.all;
use work.spi_nor_target_vc_pkg.all;

entity spi_nor_fast_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of spi_nor_fast_tb is

begin

    th: entity work.spi_nor_th
        generic map (
            sclk_divisor   => 0,
            rx_sample_taps => 2
        );

    bench: process
        alias reset is <<signal .spi_nor_fast_tb.th.reset : std_logic>>;
        alias cs_n  is <<signal .spi_nor_fast_tb.th.cs_n : std_logic>>;
        constant flash : actor_t := find("spi_nor_target");
    begin
        test_runner_setup(runner, runner_cfg);

        wait until reset = '0';
        wait for 500 ns;

        fill_pattern(net, flash);

        while test_suite loop
            if run("jedec_id") then
                check_jedec_id(net);
            elsif run("read_quad_32addr_dummy") then
                check_flash_read(net, FAST_READ_4BYTE_QUAD_OP, 8, 16#1200#, 64);
            elsif run("read_single_32addr") then
                -- Note: on a real W25Q01JV plain READ_DATA is limited to 50MHz,
                -- so this opcode is out of spec at this rate. It is exercised
                -- here for the datapath only; hubris uses the fast reads.
                check_flash_read(net, READ_DATA_4BYTE_OP, 0, 16#40#, 16);
            elsif run("read_dual_32addr_dummy") then
                check_flash_read(net, FAST_READ_4BYTE_DUAL_OP, 8, 16#80#, 16);
            elsif run("write_then_read_back") then
                check_program_readback(net, flash, 16#2000#);
            elsif run("back_to_back_reads") then
                check_back_to_back_reads(net, 16#400#, 16#500#, 32);
            elsif run("output_delay_margin") then
                -- Sweep the part's clock-low-to-output-valid delay across the
                -- datasheet range and well beyond it, and require correct data
                -- throughout.
                --
                -- The harness already models the FPGA's clock-to-pin and
                -- pin-to-flop delays, so this sweeps only the part's own tCLQV,
                -- across and a little beyond its datasheet range. Combined with
                -- the harness delays this covers the whole read round trip that
                -- the XDC allows at the slow corner.
                --
                -- The sample point has to satisfy
                --   round_trip_valid - half_period  <=  S  <=  half_period + round_trip_hold
                -- and note the upper limit comes from tCLQX (output hold), not
                -- tCLQV: sampling too late catches the *next* bit. That upper
                -- limit is the binding one at the fast corner, which is what
                -- spi_nor_fast_quick_io_tb covers.
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
