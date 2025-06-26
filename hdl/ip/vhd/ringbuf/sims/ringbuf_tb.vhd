-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;

use work.calc_pkg.log2ceil;

entity ringbuf_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of ringbuf_tb is
    constant CLK_PER : time := 4 ns;
    constant GEN_WIDTH : integer := 3;
    constant DATA_WIDTH : integer := 8;
    constant NUM_ENTRIES : integer := 16;
    constant ENTRY_SIZE : integer := GEN_WIDTH + DATA_WIDTH;

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';

    signal wdata    : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal wvalid   : std_logic := '0';
    signal raddr    : std_logic_vector(log2ceil(NUM_ENTRIES) - 1 downto 0) := (others => '0');
    signal rdata    : std_logic_vector(ENTRY_SIZE - 1 downto 0) := (others => '0');
begin

    clk   <= not clk after CLK_PER / 2;
    reset <= '0' after 200 ns;

    ringbuf_inst: entity work.ringbuf
        generic map(
            GEN_WIDTH => GEN_WIDTH,
            DATA_WIDTH => DATA_WIDTH,
            NUM_ENTRIES => NUM_ENTRIES,
            REG_OUTPUT => FALSE
        )
        port map(
            clk     => clk,
            reset   => reset,
            wdata   => wdata,
            wvalid  => wvalid,
            raddr   => raddr,
            rdata   => rdata
        );

    bench: process
        variable exp_gen  : std_logic_vector(ENTRY_SIZE - DATA_WIDTH - 1 downto 0) := (others => '0');
        variable exp_data : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    begin
        -- Always the first thing in the process, set up things for the VUnit test runner
        test_runner_setup(runner, runner_cfg);
        -- Reach into the test harness, which generates and de-asserts reset and hold the
        -- test cases off until we're out of reset. This runs for every test case
        wait until reset = '0';

        while test_suite loop
            if run("test_single_entry") then
                wdata   <= x"a5";
                wvalid  <= '1';
                wait for CLK_PER; -- one cycle to write
                check_equal(rdata, exp_gen & wdata, "Expected written data to match read data");
            elsif run("test_full_ringbuf") then
                wvalid  <= '1';
                for i in 0 to NUM_ENTRIES - 1 loop
                    wdata <= std_logic_vector(to_unsigned(i, wdata'length));
                    wait for CLK_PER;
                end loop;

                wvalid  <= '0';
                for i in 0 to NUM_ENTRIES - 1 loop
                    exp_data    := std_logic_vector(to_unsigned(i, exp_data'length));
                    raddr       <= std_logic_vector(to_unsigned(i, raddr'length));
                    wait for CLK_PER;
                    check_equal(rdata, exp_gen & exp_data, "Expected written data to match read data");
                end loop;
            elsif run("test_generation_counter") then
                wvalid  <= '1';
                for i in 0 to NUM_ENTRIES loop
                    wdata <= std_logic_vector(to_unsigned(i, wdata'length));
                    wait for CLK_PER;
                end loop;

                wvalid  <= '0';
                for i in 0 to NUM_ENTRIES - 1 loop
                    if i = 0 then
                        exp_gen := std_logic_vector(to_unsigned(1, exp_gen'length));
                        exp_data := std_logic_vector(to_unsigned(NUM_ENTRIES, exp_data'length));
                    else
                        exp_gen := std_logic_vector(to_unsigned(0, exp_gen'length));
                        exp_data := std_logic_vector(to_unsigned(i, exp_data'length));
                    end if;

                    raddr    <= std_logic_vector(to_unsigned(i, raddr'length));
                    wait for CLK_PER;
                    check_equal(rdata, exp_gen & exp_data, "Expected written data to match read data");
                end loop;
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

end tb;