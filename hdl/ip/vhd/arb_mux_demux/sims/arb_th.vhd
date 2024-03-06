-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity arb_th is
end entity;

architecture th of arb_th is
  signal clk   : std_logic := '0';
  signal reset : std_logic := '1';

  signal requests: std_logic_vector(2 downto 0);
  signal grants: std_logic_vector(requests'range);

begin

    -- set up a fastish, un-related clocka for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    arb_dut: entity work.basic_arbiter
        generic map(
          PRIORITY => false
        )
        port map(
            clk =>  clk,
            reset =>  reset,
            requests => requests,
            grants  => grants
        );
    
    arb_stim: entity work.sim_gpio
        generic map(
            OUT_NUM_BITS => 3,
            IN_NUM_BITS => 3,
            ACTOR_NAME => "arb_ctrl"
        )
        port map(
            clk => clk,
            gpio_in => grants, 
            gpio_out => requests
        );
end th;