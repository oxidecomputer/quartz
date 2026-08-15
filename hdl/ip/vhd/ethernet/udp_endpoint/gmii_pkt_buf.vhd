-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Single-clock packet buffer for the g2r (SGMII -> RGMII) forward path. The
-- PCS RX pushes a replicated octet stream with no backpressure; this block
-- deduplicates it (one entry per logical octet) into a BRAM ring so that
-- g2r_inject_mux can delay forwarded frames while a response frame is being
-- injected, then re-replicate on the way out.
--
-- Frames are stored as {er,data} entries terminated by a marker entry, so a
-- frame can start draining (cut-through) before it has fully arrived: writer
-- and reader consume exactly one entry per byte period on the same clock, so
-- once started a drain can never underrun. If the ring fills mid-frame (a
-- long injection plus sustained input), the rest of the incoming frame is
-- discarded and the stored portion is terminated with an er-flagged marker:
-- the mux propagates the error indication, the far receiver's FCS check
-- rejects the truncation, and the event is counted here. Truncation instead
-- of a write-pointer rewind because a cut-through reader may already be
-- draining the very frame that overflowed.
--
-- The show-ahead read side (head_* valid when head_valid = '1', pop
-- advances) hides the BRAM read latency; avail deliberately lags writes by
-- two cycles so a just-written entry is never popped before the synchronous
-- read pipe has actually fetched it.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;

entity gmii_pkt_buf is
    generic (
        ADDR_BITS : positive := 11    -- ring depth = 2**ADDR_BITS entries
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        speed : in    eth_speed_t;

        -- replicated push-only stream from the PCS RX
        g2r_in : in   gmii_t;

        -- deduplicated show-ahead read side (to g2r_inject_mux)
        head_valid  : out   std_logic;
        head_marker : out   std_logic;   -- entry is an end-of-frame marker
        head_er     : out   std_logic;   -- with head_marker: frame truncated
        head_data   : out   std_logic_vector(7 downto 0);
        pop         : in    std_logic;

        -- a frame was truncated because the ring was full (saturating count)
        drop_count : out   unsigned(7 downto 0)
    );
end entity;

architecture rtl of gmii_pkt_buf is

    constant DEPTH : positive := 2 ** ADDR_BITS;

    -- {marker, er, data}
    type mem_t is array (0 to DEPTH - 1) of std_logic_vector(9 downto 0);
    signal mem : mem_t;

    signal wr_ptr : unsigned(ADDR_BITS downto 0) := (others => '0');
    signal rd_ptr : unsigned(ADDR_BITS downto 0) := (others => '0');

    signal phase    : natural range 0 to 99 := 0;
    signal dv_prev  : std_logic := '0';
    signal dropping : std_logic := '0';
    signal wrote    : std_logic := '0';   -- frame has at least one entry

    signal wr_en   : std_logic;
    signal wr_data : std_logic_vector(9 downto 0);

    -- writes counted into avail two cycles late (BRAM read pipe coverage)
    signal wr_en_d1 : std_logic := '0';
    signal wr_en_d2 : std_logic := '0';
    signal avail    : unsigned(ADDR_BITS downto 0) := (others => '0');

    signal space  : unsigned(ADDR_BITS downto 0);
    signal full   : std_logic;
    signal drops  : unsigned(7 downto 0) := (others => '0');
    signal head   : std_logic_vector(9 downto 0) := (others => '0');
    signal sample : std_logic;

begin

    -- one sample at the start of each replicated octet window; the PCS RX
    -- replication is deterministic from dv rise, so a dv-rise-synced phase
    -- counter deduplicates exactly
    sample <= '1' when g2r_in.dv = '1' and phase = 0 else '0';

    space <= DEPTH - (wr_ptr - rd_ptr);
    -- keep headroom so a terminating marker always fits
    full <= '1' when space < 2 else '0';

    -- On overflow: a frame with stored bytes gets an er-flagged truncation
    -- marker (space for it is guaranteed: data writes stop at space < 2); a
    -- frame that overflows before its first byte is dropped without a trace.
    wr_en <= '1' when (sample = '1' and dropping = '0' and (full = '0' or wrote = '1')) or
                      -- end-of-frame marker for a frame we kept
                      (g2r_in.dv = '0' and dv_prev = '1' and dropping = '0' and wrote = '1') else
             '0';
    -- marker entries carry er = '1' only for a truncated frame
    wr_data <= "11" & X"00" when sample = '1' and full = '1' else
               '0' & g2r_in.er & g2r_in.data when g2r_in.dv = '1' else
               "10" & X"00";

    write_proc: process (clk, reset) is
    begin
        if reset = '1' then
            wr_ptr   <= (others => '0');
            phase    <= 0;
            dv_prev  <= '0';
            dropping <= '0';
            wrote    <= '0';
            drops    <= (others => '0');
        elsif rising_edge(clk) then
            dv_prev <= g2r_in.dv;

            if g2r_in.dv = '1' then
                if phase = speed_cycles_per_byte(speed) - 1 then
                    phase <= 0;
                else
                    phase <= phase + 1;
                end if;
            else
                phase <= 0;
            end if;

            if g2r_in.dv = '1' and dv_prev = '0' then
                wrote <= '0';
            end if;

            if wr_en = '1' then
                mem(to_integer(wr_ptr(ADDR_BITS - 1 downto 0))) <= wr_data;
                wr_ptr <= wr_ptr + 1;
                if sample = '1' and full = '0' then
                    wrote <= '1';
                end if;
            end if;

            if sample = '1' and full = '1' and dropping = '0' then
                -- overflow: marker written above if the frame had bytes;
                -- either way ignore the rest of this frame
                dropping <= '1';
                if drops /= X"FF" then
                    drops <= drops + 1;
                end if;
            end if;

            if g2r_in.dv = '0' and dv_prev = '1' then
                dropping <= '0';
            end if;
        end if;
    end process;

    drop_count <= drops;

    -- show-ahead read: head always reflects mem(rd_ptr); the address mux
    -- lets back-to-back pops stream one entry per cycle at 1000M
    read_proc: process (clk, reset) is
        variable nxt : unsigned(ADDR_BITS downto 0);
    begin
        if reset = '1' then
            rd_ptr   <= (others => '0');
            wr_en_d1 <= '0';
            wr_en_d2 <= '0';
            avail    <= (others => '0');
        elsif rising_edge(clk) then
            wr_en_d1 <= wr_en;
            wr_en_d2 <= wr_en_d1;

            if pop = '1' then
                nxt := rd_ptr + 1;
            else
                nxt := rd_ptr;
            end if;
            rd_ptr <= nxt;
            head   <= mem(to_integer(nxt(ADDR_BITS - 1 downto 0)));

            if wr_en_d2 = '1' and pop = '0' then
                avail <= avail + 1;
            elsif wr_en_d2 = '0' and pop = '1' then
                avail <= avail - 1;
            end if;
        end if;
    end process;

    head_valid  <= '1' when avail /= 0 else '0';
    head_marker <= head(9);
    head_er     <= head(8);
    head_data   <= head(7 downto 0);

end architecture;
