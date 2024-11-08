-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity synchronizers_th is
end entity;

architecture th of synchronizers_th is

    signal clk_a   : std_logic := '0';
    signal reset_a : std_logic := '1';

    signal clk_b   : std_logic := '0';
    signal reset_b : std_logic := '1';

    signal bacd1_write         : std_logic                    := '0';
    signal bacd1_launch_bus    : std_logic_vector(7 downto 0) := (others => '0');
    signal bacd1_write_allowed : std_logic;
    signal bacd1_datavalid     : std_logic;
    signal bacd1_latch_bus     : std_logic_vector(7 downto 0);

    signal tacd_latch_out : std_logic;

    signal sim_gpio_out : std_logic;

begin

    -- set up 2 fastish, un-related clocks for the sim
    -- environment and release reset after a bit of time
    clk_a   <= not clk_a after 4 ns;
    reset_a <= '0' after 200 ns;

    clk_b   <= not clk_b after 5 ns;
    reset_b <= '0' after 220 ns;

    -- Bus across clock domains
    dut_bacd_inst: entity work.bacd
        generic
    map (
            always_valid_in_b => false
        )
        port map (
            reset_launch    => reset_a,
            clk_launch      => clk_a,
            write_launch    => bacd1_write,
            bus_launch      => bacd1_launch_bus,
            write_allowed   => bacd1_write_allowed,
            reset_latch     => reset_b,
            clk_latch       => clk_b,
            datavalid_latch => bacd1_datavalid,
            bus_latch       => bacd1_latch_bus
        );

    sim_gpio_inst: entity work.sim_gpio
        generic map (
            out_num_bits => 1,
            in_num_bits  => 1,
            actor_name   => "tacd_stim"
        )
        port map (
            clk => clk_a,
            -- note that this is *technically* a cdc issue
            -- but this is in simulation and we're messing with
            -- this *slowly* in the testbench so it works fine here
            -- and saves another sim_gpio instance connected to clk_b
            gpio_in(0)  => tacd_latch_out,
            gpio_out(0) => sim_gpio_out
        );

    tacd_inst: entity work.tacd
        port
    map (
            clk_launch      => clk_a,
            reset_launch   => reset_a,
            pulse_in_launch => sim_gpio_out,
            clk_latch       => clk_b,
            reset_latch     => reset_b,
            pulse_out_latch => tacd_latch_out
        );

end th;
