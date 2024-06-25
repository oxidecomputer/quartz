-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- A very simple UART that streams rx'd bytes out an axi streaming port
-- and transmits bytes from an input axi streaming port, no buffering
-- or flow control is implemented here, so a more complex design could
-- wrap this block to provide buffering and flow control

-- Inspired by https://www.bealto.com/fpga-uart_io.html

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.calc_pkg.all;

entity axi_st_uart is
  generic(
    CLK_DIV : natural; -- This is calculated to system clock freqeuncy / (8 x desired baud rate)
    parity: boolean
  );
  port (
    -- Clock and reset
    clk : in std_logic;
    reset : in std_logic;

    -- UART interface
    rx_pin : in std_logic;
    tx_pin : out std_logic;

    -- AXI streaming interface
    rx_data : out std_logic_vector(7 downto 0);
    rx_valid : out std_logic;
    tx_data : in std_logic_vector(7 downto 0);
    tx_valid : in std_logic;
    tx_ready : out std_logic

  );
end entity axi_st_uart;

architecture rtl of axi_st_uart is
  constant SAMPLE_CNTS_MAX : natural := 8;
  constant START_LEVEL : std_logic := '0'; -- Start bit level
  constant SAMPLE_MID_POINT: natural := SAMPLE_CNTS_MAX/2;
  constant IN_STOP_BIT : natural := 9;
  constant PAYLOAD_SIZE : natural := sel(parity, 9, 8);
  type state_t is (IDLE, RUN);
  signal strobe                  : std_logic; -- 1 clk spike at 16x baud rate
  signal strobe_counter          : natural range 0 to 255 := 0;
  signal rx_pin_syncd : std_logic;

  type rx_r_t is record
    state : state_t;
    sample_cnts :std_logic_vector(2 downto 0);
    bit_num: natural range 0 to PAYLOAD_SIZE + 1;
    data: std_logic_vector(PAYLOAD_SIZE - 1 downto 0);
    valid: std_logic;
  end record;
  constant rx_reset : rx_r_t := (state => IDLE, sample_cnts => (others => '0'), bit_num => 0, data => (others => '0'), valid => '0');
  
  type tx_r_t is record
    state : state_t;
    sample_cnts : std_logic_vector(2 downto 0);
    bit_num: natural range 0 to PAYLOAD_SIZE + 1;
    -- added start bit here, so we can just shift the data out
    data: std_logic_vector(PAYLOAD_SIZE downto 0);
    ready: std_logic;
  end record;

  constant tx_reset : tx_r_t := (state => IDLE, sample_cnts => (others => '0'), bit_num => 0, data => (others => '1'), ready => '1');

  signal rx_r, rx_rin : rx_r_t;
  signal tx_r, tx_rin: tx_r_t;

begin

    -- sync the rx pin to the system clock
    meta_sync_inst: entity work.meta_sync
    port map(
       async_input => rx_pin,
       clk => clk,
       sycnd_output => rx_pin_syncd
   ); 


    -- Generate 1 clock strobes at 8x baud rate, free-running,
    -- used by both TX and RX blocks
  strobe_gen: process (clk, reset) is
  begin
    if reset = '1' then
      strobe_counter <= 0;
      strobe <= '0';
    elsif rising_edge(clk) then
      if strobe_counter = CLK_DIV - 1 then
        strobe <= '1';
        strobe_counter <= 0;
      else
        strobe <= '0';
        strobe_counter <= strobe_counter + 1;
      end if;
    end if;
  end process;


  -- RX Block. Assumes catching AXI block is always ready when we are actively
  -- rx'ing data. Next block would have to deal with overrun if it's not ready
  rx_process: process (all) is
    variable v : rx_r_t;
  begin

    v := rx_r;

    -- we don't allow rx backpressure so this just fires when the byte is rx'd
    v.valid := '0';  
    case rx_r.state is
      when IDLE =>
        -- Look for a start bit, and move to run state
        if rx_pin_syncd = START_LEVEL then
          v.state := RUN;
        end if;

      when RUN =>
        if strobe = '1' then
           -- sample next RX bit (at the approx middle of the bit period)
          if rx_r.sample_cnts = SAMPLE_MID_POINT then
            -- Once we've sampled the full UART frame, move to IDLE
            if rx_r.bit_num = IN_STOP_BIT then
              v.state := IDLE;
              -- This is a bit of a hack, but we're going to set the valid bit
              -- based on the stop bit, which is the last bit in the frame and
              -- should be a '1'. If it's not, we'll drop the frame.
              -- TODO: no partiy check here either
              v.valid := rx_pin_syncd;
            else
              v.data := rx_pin_syncd & rx_r.data(7 downto 1);
              v.bit_num := rx_r.bit_num + 1;
            end if;
          end if;
            v.sample_cnts := rx_r.sample_cnts + 1;
        end if;

    end case;

    rx_rin <= v;
  end process;


  -- TX FSM
  tx_process: process (all) is
    variable v : tx_r_t;
  begin
    v := tx_r;

    case tx_r.state is
        when IDLE =>
          v.ready := '1';
          v.data := (others => '1');
          if tx_valid = '1' then
            v.data := tx_data & '0';  -- data & start
            v.bit_num := PAYLOAD_SIZE + 1;  -- added start bit
            v.sample_cnts := (others => '0');
            v.state := RUN;
            v.ready := '0';
          end if;
          
        when RUN =>
          if strobe = '1' then
            -- wait to the end of the bit period to shift out the next bit
            if tx_r.sample_cnts = SAMPLE_CNTS_MAX - 1 then
              -- If we're done, go back to idle
              if tx_r.bit_num = 0 then
                v.ready := '1';
                v.data := (others => '1');
                v.state := IDLE;
              else
                v.data := '1' & tx_r.data(8 downto 1);
                v.bit_num := tx_r.bit_num - 1;
              end if;
            end if;
            v.sample_cnts := tx_r.sample_cnts + 1;
          end if;
          
        end case;
        tx_rin <= v;
  end process;


  -- Register block
  process (clk, reset) is
  begin
    if reset = '1' then
      rx_r <= rx_reset;
      tx_r <= tx_reset;
    elsif rising_edge(clk) then
      rx_r <= rx_rin;
      tx_r <= tx_rin;
    end if;
  end process;

  -- assign the inputs/outputs
  rx_data <= rx_r.data;
  rx_valid <= rx_r.valid;
  tx_ready <= tx_r.ready;
  tx_pin <= tx_r.data(0);

end rtl;