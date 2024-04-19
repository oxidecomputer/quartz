-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity memories_th is
end entity;

architecture th of memories_th is
  signal clk_a   : std_logic := '0';
  signal reset_a : std_logic := '1';

  signal clk_b   : std_logic := '0';
  signal reset_b : std_logic := '1';

  signal write_side_control : std_logic_vector(8 downto 0);
  alias write_en : std_logic is write_side_control(8);
  alias write_data : std_logic_vector(7 downto 0) is write_side_control(7 downto 0);

  signal write_side_reads: std_logic_vector(5 downto 0);
  alias wfull : std_logic is write_side_reads(4);
  alias wusedwds: std_logic_vector(4 downto 0) is write_side_reads(4 downto 0);

  signal read_req : std_logic;

  signal read_side_reads: std_logic_vector(13 downto 0);
  alias rdata : std_logic_vector(7 downto 0) is read_side_reads(7 downto 0);
  alias rusedwds : std_logic_vector(4 downto 0) is read_side_reads(12 downto 8);
  alias rempty : std_logic is read_side_reads(13);

  signal dpr_write_side_control : std_logic_vector(12 downto 0);
  alias dpr_write : std_logic is dpr_write_side_control(12);
  alias dpr_waddr : std_logic_vector(3 downto 0) is dpr_write_side_control(11 downto 8);
  alias dpr_wdata : std_logic_vector(7 downto 0) is dpr_write_side_control(7 downto 0);

  signal dpr_raddr : std_logic_vector(3 downto 0);
  signal dpr_rdata : std_logic_vector(7 downto 0);

begin

    -- set up 2 fastish, un-related clocks for the sim
    -- environment and release reset after a bit of time
    clk_a   <= not clk_a after 4 ns;
    reset_a <= '0' after 200 ns;
  
    clk_b   <= not clk_b after 5 ns;
    reset_b <= '0' after 220 ns;

    --------------------------------------------------------------------------------
    -- Dual clock FIFO DUT
    --------------------------------------------------------------------------------
    -- Simple show-ahead fifo for testing
    show_ahead_dcfifo_dut: entity work.dcfifo_xpm
        generic map
        (
          FIFO_WRITE_DEPTH => 16,
          DATA_WIDTH => 8,
          SHOWAHEAD_MODE => true
        )
        port map
        (
          --Write interface
          wclk => clk_a,
          --Reset interface, sync to write clock domain
          reset => reset_a,
          write_en => write_en,
          wdata => write_data,
          wfull => wfull,
          std_logic_vector(wusedwds) => wusedwds,
          -- Read interface
          rclk => clk_b,
          rdata => rdata,
          rdreq => read_req,
          rempty => rempty,
          std_logic_vector(rusedwds) => rusedwds
        );

      write_side_gpios: entity work.sim_gpio
      generic map(
          OUT_NUM_BITS => 9,
          IN_NUM_BITS => 6,
          ACTOR_NAME => "write_side"
      )
      port map(
          clk => clk_a,
          gpio_in => write_side_reads, 
          gpio_out => write_side_control
      );

      read_side_gpios: entity work.sim_gpio
      generic map(
          OUT_NUM_BITS => 1,
          IN_NUM_BITS => 14,
          ACTOR_NAME => "read_side"
      )
      port map(
          clk => clk_b,
          gpio_in => read_side_reads, 
          gpio_out(0) => read_req
      );
      
      --------------------------------------------------------------------------------
      -- Dual Port RAM DUT
      --------------------------------------------------------------------------------
      simple_dpr_dut: entity work.dual_clock_simple_dpr
        generic map(
            DATA_WIDTH => 8,
            NUM_WORDS => 16,
            REG_OUTPUT => false
        )
        port map(
            wclk => clk_a,
            waddr => dpr_waddr,
            wdata =>  dpr_wdata,
            wren => dpr_write,
            rclk  => clk_b,
            raddr => dpr_raddr,
            rdata => dpr_rdata
        );

        dpr_write_side_gpios: entity work.sim_gpio
        generic map(
            OUT_NUM_BITS => 13,
            IN_NUM_BITS => 1,
            ACTOR_NAME => "dpr_write_side"
        )
        port map(
            clk => clk_a,
            gpio_in(0) => '0', 
            gpio_out => dpr_write_side_control
        );
  
        dpr_read_side_gpios: entity work.sim_gpio
        generic map(
            OUT_NUM_BITS => 4,
            IN_NUM_BITS => 8,
            ACTOR_NAME => "dpr_read_side"
        )
        port map(
            clk => clk_b,
            gpio_in => dpr_rdata, 
            gpio_out => dpr_raddr
        );
end th;