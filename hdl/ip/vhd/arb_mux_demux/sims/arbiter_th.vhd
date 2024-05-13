-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
use work.arbiter_pkg.arbiter_mode;

entity arbiter_th is
end entity;

architecture th of arbiter_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal rr_requests : std_logic_vector(2 downto 0);
    signal rr_grants   : std_logic_vector(rr_requests'range);

    signal pri_requests : std_logic_vector(2 downto 0);
    signal pri_grants   : std_logic_vector(rr_requests'range);

begin

    -- set up a fastish, clock for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    rr_arb_dut: entity work.arbiter
        generic map(
            mode => ROUND_ROBIN
        )
        port map(
            clk      => clk,
            reset    => reset,
            requests => rr_requests,
            grants   => rr_grants
        );

    rr_arb_stim: entity work.sim_gpio
        generic map(
            out_num_bits => 3,
            in_num_bits  => 3,
            actor_name   => "rr_arb_ctrl"
        )
        port map(
            clk      => clk,
            gpio_in  => rr_grants,
            gpio_out => rr_requests
        );

    pri_arb_dut: entity work.arbiter
        generic map(
            mode => PRIORITY
        )
        port map(
            clk      => clk,
            reset    => reset,
            requests => pri_requests,
            grants   => pri_grants
        );

    pri_arb_stim: entity work.sim_gpio
        generic map(
            out_num_bits => 3,
            in_num_bits  => 3,
            actor_name   => "pri_arb_ctrl"
        )
        port map(
            clk      => clk,
            gpio_in  => pri_grants,
            gpio_out => pri_requests
        );

end th;
