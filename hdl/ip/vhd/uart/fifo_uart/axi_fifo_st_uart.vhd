-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.calc_pkg.all;

entity axi_fifo_st_uart is
  generic(
    CLKS_PER_BIT : natural;
    parity: boolean;
    use_hw_handshake: boolean;
    fifo_depth: natural range 16 to 4 * 1024 * 1024;
    full_threshold: natural range 16 to fifo_depth
  );
  port (
    -- Clock and reset
    clk : in std_logic;
    reset : in std_logic;

    -- UART interface
    -- We have a couple of special cases here to deal with various power states and muxes.
    -- We have a case where we'd like to disallow rx of data *and* deassert rts to indicate this.
    --  Example: SP <-> SP5 console UART, we should not be ready to RX data until in the A0 domain for example.
    -- We also have a case where we want to drop rx data silently, but not deassert rts.
    --  Example: SP <-> SP5 console UART, but UART is muxed away from the SP and to a debug header.
    --  In this case, we don't want to pool data in the FIFO from the SP or the SP5, but we also don't 
    --  want to backpressure the SP here.
    drop_silently : in std_logic := '0'; -- If set, the UART will drop rx data but not deassert rts
    allow_rx : in std_logic := '1'; -- Some configurations may want to not rx data until ready
    rx_pin : in std_logic;
    tx_pin : out std_logic;
    rts_pin : out std_logic;
    cts_pin : in std_logic;

    -- Sideband signals
    uart_to_axi_fifo_usedwds : out std_logic_vector(log2ceil(fifo_depth) downto 0);
    axi_to_uart_fifo_usedwds : out std_logic_vector(log2ceil(fifo_depth) downto 0);
    uart_rts_pin_copy : out std_logic; -- copy of the rts pin, for debug purposes
    uart_cts_pin_copy : out std_logic; -- copy of the cts pin, for debug purposes

    -- AXI streaming interface
    axi_clk : in std_logic;
    axi_reset : in std_logic;
    rx_ready : in std_logic;
    rx_data : out std_logic_vector(7 downto 0);
    rx_valid : out std_logic;
    tx_data : in std_logic_vector(7 downto 0);
    tx_valid : in std_logic;
    tx_ready : out std_logic

  );
end entity axi_fifo_st_uart;

architecture rtl of axi_fifo_st_uart is
  constant cts_ok : std_logic := '0';
  signal pre_fifo_rx_data : std_logic_vector(7 downto 0);
  signal tx_fifo_rdata : std_logic_vector(7 downto 0);
  signal pre_fifo_rx_valid : std_logic;
  signal tx_fifo_rempty : std_logic;
  signal rx_wusedwds : std_logic_vector(log2ceil(fifo_depth) downto 0);
  signal uart_tx_ready : std_logic;
  signal uart_tx_valid : std_logic;
  signal cts_pin_syncd : std_logic;
  signal tx_fifo_wfull : std_logic;
  signal rx_fifo_rempty : std_logic;

begin

 -- sync the cts pin to the system clock
 -- rx pin is sync'd in the uart sub block
 meta_sync_inst: entity work.meta_sync
 port map(
    async_input => cts_pin,
    clk => clk,
    sycnd_output => cts_pin_syncd
);
uart_cts_pin_copy <= cts_pin_syncd;

  -- Actual UART serdes block
  axi_st_uart_inst: entity work.axi_st_uart
   generic map(
      CLKS_PER_BIT => CLKS_PER_BIT,
      parity => parity
  )
   port map(
      clk => clk,
      reset => reset,
      rx_pin => rx_pin,
      tx_pin => tx_pin,
      allowed_to_sample => allow_rx and (not drop_silently),
      rx_data => pre_fifo_rx_data,
      rx_valid => pre_fifo_rx_valid,
      tx_data => tx_fifo_rdata,
      tx_valid => uart_tx_valid,
      tx_ready => uart_tx_ready
  );

  -- As an "RX" FIFO, writes come from the UART block
  -- in the UART's clock domain. Reads go out the main interface
  -- in the "AXI" clock domain.
  rx_fifo: entity work.dcfifo_xpm
   generic map(
      fifo_write_depth => fifo_depth,
      data_width => 8,
      showahead_mode => true
  )
   port map(
      wclk => clk,
      reset => reset,
      write_en => pre_fifo_rx_valid,
      wdata => pre_fifo_rx_data,
      wfull => open,
      wusedwds => rx_wusedwds,
      rclk => axi_clk,
      rdata => rx_data,
      rdreq => rx_valid and rx_ready,
      rempty => rx_fifo_rempty,
      rusedwds => open
  );
  uart_to_axi_fifo_usedwds <= std_logic_vector(rx_wusedwds);
  uart_rts_pin_copy <= rts_pin;
  rx_valid <= not rx_fifo_rempty;
  -- hw handshake, de-assert when we run low on rx fifo space or when we're not allowing rx
  rts_pin <= '0' when (rx_wusedwds < full_threshold) and allow_rx = '1' else '1';
  -- hw handshake
  uart_tx_valid <= not tx_fifo_rempty when (cts_pin_syncd = cts_ok and use_hw_handshake) else 
                     not tx_fifo_rempty when (not use_hw_handshake) else 
                    '0';

  -- As an "TX" FIFO, writes come from AXI interface in the axi domain
  -- Reads go to the UART block in its clock domain
  tx_fifo: entity work.dcfifo_xpm
   generic map(
      fifo_write_depth => fifo_depth,
      data_width => 8,
      showahead_mode => true
  )
   port map(
      wclk => axi_clk,
      reset => axi_reset,
      write_en => tx_valid and tx_ready,
      wdata => tx_data,
      wfull => tx_fifo_wfull,
      wusedwds => open,
      rclk => clk,
      rdata => tx_fifo_rdata,
      rdreq => uart_tx_valid and uart_tx_ready,
      rempty => tx_fifo_rempty,
      rusedwds => axi_to_uart_fifo_usedwds
  );

  tx_ready <= not tx_fifo_wfull;

end rtl;
