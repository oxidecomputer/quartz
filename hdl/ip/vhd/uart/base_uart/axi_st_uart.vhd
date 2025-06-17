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
    CLKS_PER_BIT : natural := 8; -- This is calculated to system clock frequency / desired baud rate
    parity: boolean
  );
  port (
    -- Clock and reset
    clk : in std_logic;
    reset : in std_logic;

    -- UART interface
    rx_pin : in std_logic;
    tx_pin : out std_logic;

    -- Sideband control signals
    allowed_to_sample : in std_logic := '1'; -- Some configurations may want to not rx data until ready

    -- AXI streaming interface
    rx_data : out std_logic_vector(7 downto 0);
    rx_valid : out std_logic;
    tx_data : in std_logic_vector(7 downto 0);
    tx_valid : in std_logic;
    tx_ready : out std_logic

  );
end entity axi_st_uart;

architecture rtl of axi_st_uart is
  constant START_LEVEL : std_logic := '0'; -- Start bit level
  constant IN_STOP_BIT : natural := 9;
  constant PAYLOAD_SIZE : natural := sel(parity, 9, 8);
  constant MID_SAMPLE_CNT : natural := to_integer(shift_right(to_unsigned(CLKS_PER_BIT, 8),2));
  type state_t is (IDLE, RUN);
  signal tx_strobe                  : std_logic;
  signal tx_strobe_counter          : natural range 0 to 255 := 0;
  signal rx_strobe                  : std_logic;
  signal rx_strobe_counter          : natural range 0 to 255 := 0;
  signal rx_pin_syncd : std_logic;

  type rx_r_t is record
    state : state_t;
    bit_num: natural range 0 to PAYLOAD_SIZE + 1;
    data: std_logic_vector(PAYLOAD_SIZE - 1 downto 0);
    valid: std_logic;
  end record;
  constant rx_reset : rx_r_t := (state => IDLE, bit_num => 0, data => (others => '0'), valid => '0');
  
  type tx_r_t is record
    state : state_t;
    bit_num: natural range 0 to PAYLOAD_SIZE + 1;
    -- added start bit here, so we can just shift the data out
    data: std_logic_vector(PAYLOAD_SIZE downto 0);
    ready: std_logic;
  end record;

  constant tx_reset : tx_r_t := (state => IDLE, bit_num => 0, data => (others => '1'), ready => '1');

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


    -- Generate a strobe at bit rate, used by TX block
  tx_strobe_gen: process (clk, reset) is
  begin
    if reset = '1' then
      tx_strobe_counter <= 0;
      tx_strobe <= '0';
    elsif rising_edge(clk) then
      tx_strobe_counter <= 0;
      tx_strobe <= '0';
      if tx_r.state = RUN then
        if tx_strobe_counter < CLKS_PER_BIT then
          tx_strobe_counter <= tx_strobe_counter + 1;
        else
          tx_strobe <= '1';
          tx_strobe_counter <= 0;
        end if;
      end if;
    end if;
  end process;

  rx_sample_strobe_gen: process (clk, reset)
  begin
    if reset = '1' then
      rx_strobe_counter <= 0;
      rx_strobe <= '0';
    elsif rising_edge(clk) then
      rx_strobe <= '0';
      rx_strobe_counter <= 0;
      if rx_r.state = RUN then
        if rx_strobe_counter < CLKS_PER_BIT then
          rx_strobe_counter <= rx_strobe_counter + 1;
        else
          rx_strobe_counter <= 0;
        end if;
        if rx_strobe_counter = MID_SAMPLE_CNT then
          rx_strobe <= '1';
        end if;
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
        -- We allow external logic to disable our sampling of the rx pin after
        -- synchronization. This will allow logic to disable our sampling and the
        -- rx state machine will stay in IDLE until allowed to sample again, preventing
        -- us from sampling noise or other things when it doesn't make sense in a given
        -- hardware configuration.
        if rx_pin_syncd = START_LEVEL and allowed_to_sample = '1' then
          v.bit_num := 0;
          v.state := RUN;
        end if;

      when RUN =>
        if rx_strobe = '1' then
           -- sample next RX bit (at the approx middle of the bit period)
            -- Once we've sampled the full UART frame, move to IDLE
            if rx_r.bit_num = IN_STOP_BIT then
              v.state := IDLE;
              -- This is a bit of a hack, but we're going to set the valid bit
              -- based on the stop bit, which is the last bit in the frame and
              -- should be a '1'. If it's not, we'll drop the frame.
              -- TODO: no parity check here either
              v.valid := rx_pin_syncd;
            else
              v.data := rx_pin_syncd & rx_r.data(7 downto 1);
              v.bit_num := rx_r.bit_num + 1;
            end if;
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
          if tx_valid = '1' and tx_r.ready = '1' then
            v.data := tx_data & '0';  -- data & start
            v.bit_num := PAYLOAD_SIZE + 1;  -- added start bit
            v.state := RUN;
            v.ready := '0';
          end if;
          
        when RUN =>
          if tx_strobe = '1' then
            -- wait to the end of the bit period to shift out the next bit
              if tx_r.bit_num = 0 then
                v.ready := '1';
                v.data := (others => '1');
                v.state := IDLE;
              else
                v.data := '1' & tx_r.data(8 downto 1);
                v.bit_num := tx_r.bit_num - 1;
              end if;
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