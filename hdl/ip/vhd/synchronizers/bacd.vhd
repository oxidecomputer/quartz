-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL 
-- plugin: https://terostechnology.github.io/terosHDLdoc/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! This is a module that synchronizes a bus (multiple bits) between
--! two clock domains. This is implemented in flipflops only, and
--! is intended for "infrequent" (with respect to both clock frequencies)
--! data changes, where we don't want to use a FIFO. Note that for data
--! that does change frequently w.r.t. the clocks, a FIFO is probably the
--! right answer.
--! The initialism bacd stands for bus-across-clock-domains.
--! The logic consuming the `bus_b` output can make no assumptions about
--! the validity of the `bus_b`
--! This is a handshake synchronizer, using pacd for the handshakes.
--! Note that if you don't particularly care about issuing writes at a
--! specific time (ie bus_a is *always* valid), you can pin `write_a`
--! high (resulting in data propagation whenever possible and ignored
--! during busy cycles), or 
--! connect `write_allowed` to `write_a` which will transit data across
--! as fast as the handshakes allow.
entity bacd is
  generic
  (
    --! If true, adds another set of `clk_b` registers for the bus so that
    --! the bus_b value is always valid at the cost of another set of `bus_b`
    --! registers.
    ALWAYS_VALID_IN_B : boolean := false
  );
  port
  (
    -- Launch (sending) Domain
    reset_launch  : in std_logic;
    clk_launch    : in std_logic;
    write_launch  : in std_logic;
    bus_launch    : in std_logic_vector;
    write_allowed : out std_logic;
    -- Latch (recieving) Domain
    reset_latch     : in std_logic;
    clk_latch       : in std_logic;
    datavalid_latch : out std_logic;
    bus_latch       : out std_logic_vector
  );
end entity;

architecture rtl of bacd is
  signal handshake_from_launch  : std_logic;
  signal bus_launch_reg         : std_logic_vector(bus_launch'range);
  signal write_a_in_last        : std_logic;
  signal handshake_from_latch   : std_logic;
  signal bus_latch_reg_internal : std_logic_vector(bus_launch'range) := (others => '0');
  signal write_a_in_masked      : std_logic;
  signal write_in_progress      : std_logic;

begin
  -- Block/mask writes when one handshake is in progress
  write_a_in_masked <= write_launch and (not write_in_progress);
  -- Provide user visibility to when writes can be accepted
  write_allowed <= not write_in_progress;

  -- Send a handshake over to the b domain when we latch the bus_a
  -- in the a domain.
  handshake_a_to_b : entity work.tacd(rtl)
    port map
    (
      clk_launch      => clk_launch,
      pulse_in_launch => write_a_in_masked,
      clk_latch       => clk_latch,
      pulse_out_latch => handshake_from_launch);
  -- Reverse handshake back to a domain when we've latched the 
  -- bus in the b domain
  reverse_handshake_b_to_a : entity work.tacd
    port
    map(
    clk_launch      => clk_latch,
    pulse_in_launch => handshake_from_launch,
    clk_latch       => clk_launch,
    pulse_out_latch => handshake_from_latch);

  --! `clk_a` domain flops where we latch the new data when requested
  --! and start the handshake across
  regs_in_a : process (clk_launch, reset_launch)
  begin
    if rising_edge(clk_launch) then
      write_a_in_last <= write_a_in_masked;
      -- On a rising edge of the write signal, latch the 
      -- bus in the `clk_a` domain, so long as we're not in the
      -- middle of a previous transaction, in which case we ignore
      -- the write edge.
      if write_a_in_last = '0' and write_a_in_masked = '1' then
        bus_launch_reg    <= bus_launch;
        write_in_progress <= '1';
        --Once we get the handshake back, clear write_in_progress
      elsif handshake_from_latch = '1' then
        write_in_progress <= '0';
      end if;

      -- sync reset
      if reset_launch = '1' then
        write_in_progress <= '0';
        bus_launch_reg    <= (others => '0');
        write_a_in_last   <= '0';
      end if;

    end if;
  end process;

  -- Register 
  regs_b : process (clk_latch, reset_latch)
  begin
    if rising_edge(clk_latch) then
      bus_latch_reg_internal <= bus_launch_reg;
    end if;
  end process;
  extra_reg_gen : if ALWAYS_VALID_IN_B generate
    extra_regs_b : process (clk_latch, reset_latch)
    begin
      if rising_edge(clk_latch) then
        if handshake_from_launch = '1' then
          bus_latch       <= bus_latch_reg_internal;
          datavalid_latch <= '1';
        end if;

        --sync reset, don't care about bus_b here
        if reset_latch = '1' then
          datavalid_latch <= '0';
        end if;
      end if;
    end process;

  else
    generate
      -- Pass through without extra register stages. This means
      -- the bus is really only guaranteed valid for the cycle
      -- where datavalid_latch is also asserted and must be
      -- captured by downstream logic at this time.
      bus_latch       <= bus_latch_reg_internal;
      datavalid_latch <= handshake_from_launch;
    end generate;
  end rtl;