library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.calc_pkg.all;

--! This block wraps a Xilinx XPM macro with Oxide's desired
--! interface for a standard, dual-clock fifo with matching
--! datawidths. This allows us to easily swap in different
--! fifo implementations for different vendors all using
--! the same basic "fifo" interface
entity dcfifo_xpm is
  generic
  (
    --! How many CDC stages (increases flag delays)
    CDC_STAGES : integer range 2 to 8 := 2;
    --! How deep the fifo is in terms of the native
    --! data-width word size. Must be a power of 2
    FIFO_WRITE_DEPTH : integer range 16 to 4*1024*1024;
    --! Width of read and write data interfaces.
    DATA_WIDTH : integer;
    --! Set to true to have FIFO output immediately valid
    --! and rdreq will function as a read ack. This mode
    --! often comes with an fmax penalty but simplifies
    --! use in a lot of cases where fmax isn't pushing 
    --! boundaries
    SHOWAHEAD_MODE : boolean
  );
  port
  (
    --Write interface
    --! Write clock
    wclk : in std_logic;
    --! Reset interface, sync to write clock domain
    reset : in std_logic;
    --! Write enable signal storing `wdata`, sync to write clock domain 
    write_en : in std_logic;
    --! Write data into the fifo, sync to write clock domain
    wdata : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    --! Write full flag, sync to write clock domain
    wfull : out std_logic;
    --! Number of words stored in fifo, sync to write clock domain
    wusedwds : out std_logic_vector(log2ceil(FIFO_WRITE_DEPTH) downto 0);
    -- Read interface
    --! Read clock
    rclk : in std_logic;
    --! Read data output, sync to read clock domain.
    --! In showahead mode, data is valid when available and
    --! rdreq acts as a read ack. Otherwise, data is valid
    --! the clock after the rdreq is sampled high.
    rdata : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    --! Read request/read ack. If `SHOWAHEAD_MODE` is set, this functions
    --! as a read ack, valid data will be present immediately when available.
    rdreq : in std_logic;
    --! Read empty flag, sync to read clock domain
    rempty : out std_logic;
    --! Number of words stored in fifo, sync to read clock domain
    rusedwds : out std_logic_vector(log2ceil(FIFO_WRITE_DEPTH) downto 0)
  );
end entity;

architecture xpm of dcfifo_xpm is
  constant READ_MODE         : string  := sel(SHOWAHEAD_MODE, "fwft", "std");
  constant READ_LATENCY      : integer := sel(SHOWAHEAD_MODE, 0, 1);
  constant PROG_EMPTY_THRESH : integer := sel(SHOWAHEAD_MODE, 3 + 2, 3);
  constant PROG_FULL_THRESH  : integer := sel(SHOWAHEAD_MODE, 3 + 2 + CDC_STAGES, 3 + CDC_STAGES);
begin

  xpm_fifo_async_inst : xpm_fifo_async
  generic
  map (
  CASCADE_HEIGHT      => 0,
  CDC_SYNC_STAGES     => CDC_STAGES,
  DOUT_RESET_VALUE    => "0",
  ECC_MODE            => "no_ecc",
  FIFO_MEMORY_TYPE    => "auto",
  FIFO_WRITE_DEPTH    => FIFO_WRITE_DEPTH,
  FULL_RESET_VALUE    => 0,
  PROG_EMPTY_THRESH   => PROG_EMPTY_THRESH,
  PROG_FULL_THRESH    => PROG_FULL_THRESH,
  RD_DATA_COUNT_WIDTH => log2ceil(FIFO_WRITE_DEPTH) + 1,
  READ_DATA_WIDTH     => DATA_WIDTH,
  READ_MODE           => READ_MODE,
  RELATED_CLOCKS      => 0,
  SIM_ASSERT_CHK      => 0,
  USE_ADV_FEATURES    => "0707",
  WAKEUP_TIME         => 0,
  WRITE_DATA_WIDTH    => DATA_WIDTH,
  WR_DATA_COUNT_WIDTH => log2ceil(FIFO_WRITE_DEPTH) +1
  )
  port map
  (
    -- 1-bit output: Almost Empty : When asserted, this signal indicates that
    -- only one more read can be performed before the FIFO goes to empty.
    almost_empty => open,
    -- 1-bit output: Almost Full: When asserted, this signal indicates that
    -- only one more write can be performed before the FIFO is full.
    almost_full => open,
    -- 1-bit output: Read Data Valid: When asserted, this signal indicates
    -- that valid data is available on the output bus (dout).
    data_valid => open,
    -- 1-bit output: Double Bit Error: Indicates that the ECC decoder
    -- detected a double-bit error and data in the FIFO core is corrupted.
    dbiterr => open,
    -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
    -- when reading the FIFO. 
    dout => rdata,
    -- 1-bit output: Empty Flag: When asserted, this signal indicates that
    -- the FIFO is empty. Read requests are ignored when the FIFO is empty,
    -- initiating a read while empty is not destructive to the FIFO. 
    empty => rempty,
    -- 1-bit output: Full Flag: When asserted, this signal indicates that the
    -- FIFO is full. Write requests are ignored when the FIFO is full,
    -- initiating a write when the FIFO is full is not destructive to the
    -- contents of the FIFO.
    full => wfull,
    -- 1-bit output: Overflow: This signal indicates that a write request
    -- (wren) during the prior clock cycle was rejected, because the FIFO is
    -- full. Overflowing the FIFO is not destructive to the contents of the
    -- FIFO.
    overflow => open,
    -- 1-bit output: Programmable Empty: This signal is asserted when the
    -- number of words in the FIFO is less than or equal to the programmable
    -- empty threshold value. It is de-asserted when the number of words in
    -- the FIFO exceeds the programmable empty threshold value.
    prog_empty => open,
    -- 1-bit output: Programmable Full: This signal is asserted when the
    -- number of words in the FIFO is greater than or equal to the
    -- programmable full threshold value. It is de-asserted when the number
    -- of words in the FIFO is less than the programmable full threshold
    -- value.
    prog_full => open,
     -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates
    -- the number of words read from the FIFO.
    rd_data_count => rusedwds,
    -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO
    -- read domain is currently in a reset state.
    rd_rst_busy => open,
    -- 1-bit output: Single Bit Error: Indicates that the ECC decoder
    -- detected and fixed a single-bit error.
    sbiterr => open,
    -- 1-bit output: Underflow: Indicates that the read request (rd_en)
    -- during the previous clock cycle was rejected because the FIFO is
    -- empty. Under flowing the FIFO is not destructive to the FIFO.
    underflow => open,
    -- 1-bit output: Write Acknowledge: This signal indicates that a write
    -- request (wr_en) during the prior clock cycle is succeeded.
    wr_ack => open,
    -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
    -- the number of words written into the FIFO.
    wr_data_count => wusedwds,
    -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
    -- write domain is currently in a reset state.
    wr_rst_busy => open,
    -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
    -- writing the FIFO.
    din => wdata,
    -- 1-bit input: Double Bit Error Injection: Injects a double bit error if
    -- the ECC feature is used on block RAMs or UltraRAM macros.
    injectdbiterr => '0',
    -- 1-bit input: Single Bit Error Injection: Injects a single bit error if
    -- the ECC feature is used on block RAMs or UltraRAM macros.
    injectsbiterr => '0',
    -- 1-bit input: Read clock: Used for read operation. rd_clk must be a
    -- free running clock.
    rd_clk => rclk,
    -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this
    -- signal causes data (on dout) to be read from the FIFO. Must be held
    -- low when rd_rst_busy is active high.
    rd_en => rdreq,
    -- 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
    -- unstable at the time of applying reset, but reset must be released
    -- only after the clock(s) is/are stable.
    rst => reset,
    -- 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo
    -- block is in power saving mode.
    sleep => '0',
    -- 1-bit input: Write clock: Used for write operation. wr_clk must be a
    -- free running clock.
    wr_clk => wclk,
    -- 1-bit input: Write Enable: If the FIFO is not full, asserting this
    -- signal causes data (on din) to be written to the FIFO. Must be held
    -- active-low when rst or wr_rst_busy is active high.
    wr_en => write_en
  );
end xpm;