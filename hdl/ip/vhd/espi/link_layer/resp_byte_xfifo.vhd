-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

-- A tiny gray-pointer asynchronous FIFO carrying response bytes from the
-- 200MHz bookkeeper into the eSPI SCLK domain.
--
-- Why not dcfifo_xpm: the XPM async FIFO requires several cycles of *both*
-- clocks to complete a reset, and SCLK only exists while a transaction is in
-- flight. A reset issued between transactions would never retire. This block
-- instead takes an asynchronous `clear` (chip select deasserted), which is the
-- natural per-transaction boundary and needs no clock at all.
--
-- Depth is intentionally small. It exists to decouple the byte-rate handoff
-- from the crossing latency, not to buffer a whole packet -- the packet
-- buffering already happens in the 125MHz/200MHz FIFOs upstream. The eSPI
-- WAIT_STATE bytes at the head of every response give the write side a head
-- start to fill this before real data is needed.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity resp_byte_xfifo is
    generic (
        --! log2 of the entry count. 2 => 4 entries.
        depth_log2 : natural := 2
    );
    port (
        --! Asynchronous clear for both domains. Held for many cycles of both
        --! clocks between transactions, so both sides settle before use.
        clear  : in    std_logic;

        -- Write side
        wclk   : in    std_logic;
        wdata  : in    std_logic_vector(7 downto 0);
        wren   : in    std_logic;
        wfull  : out   std_logic;

        -- Read side, showahead: `rdata` is valid whenever `rempty` is low.
        rclk   : in    std_logic;
        rdata  : out   std_logic_vector(7 downto 0);
        rdack  : in    std_logic;
        rempty : out   std_logic
    );
end entity;

architecture rtl of resp_byte_xfifo is

    constant entries : natural := 2 ** depth_log2;

    type mem_t is array (0 to entries - 1) of std_logic_vector(7 downto 0);

    signal mem : mem_t;

    -- Pointers carry one extra bit above the address so that full and empty
    -- are distinguishable.
    subtype ptr_t is std_logic_vector(depth_log2 downto 0);

    signal wptr_bin       : ptr_t;
    signal wptr_gray      : ptr_t;
    signal rptr_bin       : ptr_t;
    signal rptr_gray      : ptr_t;
    -- Opposite-domain pointers, gray coded so at most one bit is in flight.
    signal rptr_gray_sync : ptr_t;
    signal rptr_gray_meta : ptr_t;
    signal wptr_gray_sync : ptr_t;
    signal wptr_gray_meta : ptr_t;

    signal full_int  : std_logic;
    signal empty_int : std_logic;

    -- Xilinx synth attributes, matching the convention in
    -- //hdl/ip/vhd/synchronizers: we want real flops, not SRLs, on the
    -- synchronizer chains.
    attribute shreg_extract : string;
    attribute async_reg     : string;
    attribute shreg_extract of rptr_gray_meta : signal is "no";
    attribute shreg_extract of rptr_gray_sync : signal is "no";
    attribute shreg_extract of wptr_gray_meta : signal is "no";
    attribute shreg_extract of wptr_gray_sync : signal is "no";
    attribute async_reg of rptr_gray_meta : signal is "TRUE";
    attribute async_reg of rptr_gray_sync : signal is "TRUE";
    attribute async_reg of wptr_gray_meta : signal is "TRUE";
    attribute async_reg of wptr_gray_sync : signal is "TRUE";

    function bin2gray (b : ptr_t) return ptr_t is
    begin
        return b xor shift_right(b, 1);
    end function;

begin

    wfull  <= full_int;
    rempty <= empty_int;

    -- Showahead read port. 4 entries of distributed RAM.
    rdata <= mem(to_integer(rptr_bin(depth_log2 - 1 downto 0)));

    -- Empty when the two pointers agree exactly.
    empty_int <= '1' when rptr_gray = wptr_gray_sync else '0';

    -- Full when the write pointer has caught the read pointer with the wrap
    -- bit inverted. In gray code that means the top two bits differ and the
    -- rest match.
    full_int <= '1' when wptr_gray(depth_log2) /= rptr_gray_sync(depth_log2) and
                         wptr_gray(depth_log2 - 1) /= rptr_gray_sync(depth_log2 - 1) and
                         wptr_gray(depth_log2 - 2 downto 0) = rptr_gray_sync(depth_log2 - 2 downto 0)
                    else '0';

    write_side: process(wclk, clear)
    begin
        if clear = '1' then
            wptr_bin  <= (others => '0');
            wptr_gray <= (others => '0');
        elsif rising_edge(wclk) then
            if wren = '1' and full_int = '0' then
                mem(to_integer(wptr_bin(depth_log2 - 1 downto 0))) <= wdata;
                wptr_bin  <= wptr_bin + 1;
                wptr_gray <= bin2gray(wptr_bin + 1);
            end if;
        end if;
    end process;

    read_side: process(rclk, clear)
    begin
        if clear = '1' then
            rptr_bin  <= (others => '0');
            rptr_gray <= (others => '0');
        elsif rising_edge(rclk) then
            if rdack = '1' and empty_int = '0' then
                rptr_bin  <= rptr_bin + 1;
                rptr_gray <= bin2gray(rptr_bin + 1);
            end if;
        end if;
    end process;

    -- Pointer synchronizers. Gray coding means a stale sample is always a
    -- valid earlier pointer value, so full/empty stay conservative.
    sync_rptr_into_wclk: process(wclk, clear)
    begin
        if clear = '1' then
            rptr_gray_meta <= (others => '0');
            rptr_gray_sync <= (others => '0');
        elsif rising_edge(wclk) then
            rptr_gray_meta <= rptr_gray;
            rptr_gray_sync <= rptr_gray_meta;
        end if;
    end process;

    sync_wptr_into_rclk: process(rclk, clear)
    begin
        if clear = '1' then
            wptr_gray_meta <= (others => '0');
            wptr_gray_sync <= (others => '0');
        elsif rising_edge(rclk) then
            wptr_gray_meta <= wptr_gray;
            wptr_gray_sync <= wptr_gray_meta;
        end if;
    end process;

end rtl;
