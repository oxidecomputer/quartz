-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
use work.memories_sim_pkg.all;

entity memories_tb is
    generic (

        runner_cfg : string
    );
end entity;

architecture tb of memories_tb is

begin

    th: entity work.memories_th;

    bench: process
        -- Note: External names are broken in GHDL llvm backends https://github.com/ghdl/ghdl/issues/2610
        -- So this sim only works in other simulators, like nvc
        -- reset_a uses the absolute path form (starting with a '.') and
        -- reset_b uses the relative path form of external naming for example purposes.
        alias reset_a is << signal th.reset_a : std_logic >>;
        alias reset_b is << signal th.reset_b : std_logic >>;

        variable write_data : std_logic_vector(15 downto 0);
        variable read_data  : std_logic_vector(15 downto 0);
        variable dpr_addr   : std_logic_vector(3 downto 0);
        variable wactor      : actor_t := null_actor;
        variable ractor      : actor_t := null_actor;
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);

        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset_b = '0';
        wait for 500 ns;  -- let the resets propagate and clear in the fifo

        while test_suite loop
            if run("basic_dpr_test") then
                wactor := find("dpr_write_side");
                ractor := find("dpr_read_side");
                -- load fifo with data
                write_data := 16x"AAAA";
                dpr_addr   := 4x"0";
                write_dpr(net, dpr_addr, write_data, wactor);
                wait for 1 us;
                read_dpr(net, dpr_addr, read_data, ractor);

                -- check read-side data
                check_equal(read_data, write_data, "Addr0: Mismatch detected");

                write_data := 16x"55";
                dpr_addr   := 4x"1";
                write_dpr(net, dpr_addr, write_data, wactor);
                wait for 1 us;
                read_dpr(net, dpr_addr, read_data, ractor);
                -- check read-side data
                check_equal(read_data, write_data, "Addr1: Mismatch detected");
            elsif run("mixed_width_dpr_test") then
                wactor := find("mixed_dpr_write_side");
                ractor := find("mixed_dpr_read_side");
                -- load an 8bit write-side with 55 at address 0
                write_data := 16x"55";
                dpr_addr   := 4x"0";
                write_dpr(net, dpr_addr, write_data, wactor);
                wait for 1 us;
                -- load an 8bit write-side with AA at address 1
                write_data := 16x"AA";
                dpr_addr   := 4x"1";
                write_dpr(net, dpr_addr, write_data, wactor);
                wait for 1 us;
                -- get 16bit read-side expected AA55 at address 0
                dpr_addr   := 4x"0";
                read_dpr(net, dpr_addr, read_data, ractor);

                -- check read-side data
                check_equal(read_data, std_logic_vector'(16x"AA55"), "Addr0: Mismatch detected");

                
            end if;
        end loop;
        wait for 1 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    -- Example total test timeout dog
    test_runner_watchdog(runner, 10 ms);

end tb;
