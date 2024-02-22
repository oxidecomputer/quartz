-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity th_synchronizers is
end entity;

architecture th of th_synchronizers is
  signal clk_a   : std_logic := '0';
  signal reset_a : std_logic := '1';

  signal clk_b   : std_logic := '0';
  signal reset_b : std_logic := '1';

  signal bacd1_write : std_logic := '0';
  signal bacd1_launch_bus : std_logic_vector(7 downto 0) := (others => '0');
  signal bacd1_write_allowed : std_logic;
  signal bacd1_datavalid : std_logic;
  signal bacd1_latch_bus : std_logic_vector(7 downto 0);
begin

  -- set up 2 fastish, un-related clocks for the sim
  -- environment and release reset after a bit of time
  clk_a   <= not clk_a after 4 ns;
  reset_a <= '0' after 200 ns;

  clk_b   <= not clk_b after 5 ns;
  reset_b <= '0' after 220 ns;

  -- Instantiate the DUTs here

  -- Bus across clock domains
  bacd_inst : entity work.bacd
    generic
    map (
    ALWAYS_VALID_IN_B => false
    )
    port map
    (
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

  -- bacd2_inst : entity work.bacd
  --   generic
  --   map (
  --   ALWAYS_VALID_IN_B => true
  --   )
  --   port
  --   map (
  --   reset_launch    => reset_launch,
  --   clk_launch      => clk_launch,
  --   write_launch    => write_launch,
  --   bus_launch      => bus_launch,
  --   write_allowed   => write_allowed,
  --   reset_latch     => reset_latch,
  --   clk_latch       => clk_latch,
  --   datavalid_latch => datavalid_latch,
  --   bus_latch       => bus_latch
  --   );

  -- -- reset bridge
  -- async_reset_bridge_inst : entity work.async_reset_bridge
  --   generic
  --   map (
  --   ASYNC_RESET_ACTIVE_LEVEL => ASYNC_RESET_ACTIVE_LEVEL
  --   )
  --   port
  --   map (
  --   clk         => clk_b,
  --   reset_async => reset_async,
  --   reset_sync  => reset_sync
  --   );

  -- -- basic meta filter
  -- meta_sync_inst : entity work.meta_sync
  --   generic
  --   map (
  --   STAGES => 2
  --   )
  --   port
  --   map (
  --   async_input  => async_input,
  --   clk          => clk_b,
  --   sycnd_output => sycnd_output
  --   );

  -- tacd_inst : entity work.tacd
  --   port
  --   map (
  --   clk_launch      => clk_launch,
  --   pulse_in_launch => pulse_in_launch,
  --   clk_latch       => clk_latch,
  --   pulse_out_latch => pulse_out_latch
  --   );

end architecture;