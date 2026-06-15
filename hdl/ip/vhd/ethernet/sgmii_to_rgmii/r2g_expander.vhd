-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- r2g rate expander / clock crossing for the SGMII<->RGMII bridge. The RGMII RX
-- recovers logical octets in the rxc domain at the line rate; this block buffers
-- them in a small dual-clock (gray-coded) FIFO and presents them to the SGMII
-- PCS TX in the system clock domain using the valid/ready handshake. Each octet
-- is offered for `speed_cycles_per_byte` accepts before the FIFO is popped, so
-- the rate-agnostic PCS replicates it onto the 1.25 Gbaud SGMII line (10x/100x
-- at 100/10 Mbps, 1x at 1000).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;

entity r2g_expander is
    generic (
        ADDR_BITS : positive := 5     -- FIFO depth = 2**ADDR_BITS
    );
    port (
        -- write side (RGMII RX / rxc domain)
        wr_clk  : in    std_logic;
        wr_reset : in   std_logic;
        wr_data : in    std_logic_vector(7 downto 0);
        wr_er   : in    std_logic;
        wr_en   : in    std_logic;     -- one pulse per recovered octet

        -- read side (PCS TX / system clk domain)
        rd_clk  : in    std_logic;
        rd_reset : in   std_logic;
        speed   : in    eth_speed_t;
        gmii    : out   gmii_t;         -- to PCS TX r2g
        gmii_ready : in std_logic       -- PCS accept
    );
end entity;

architecture rtl of r2g_expander is

    constant DEPTH : positive := 2 ** ADDR_BITS;

    type mem_t is array (0 to DEPTH - 1) of std_logic_vector(8 downto 0);  -- {er, data}
    signal mem : mem_t;

    function bin2gray (b : unsigned) return unsigned is
    begin
        return b xor ('0' & b(b'high downto 1));
    end function;

    -- pointers carry one extra bit above the address for full/empty wrap
    signal wr_ptr      : unsigned(ADDR_BITS downto 0) := (others => '0');
    signal wr_ptr_gray : unsigned(ADDR_BITS downto 0) := (others => '0');
    signal rd_ptr      : unsigned(ADDR_BITS downto 0) := (others => '0');
    signal rd_ptr_gray : unsigned(ADDR_BITS downto 0) := (others => '0');

    -- write-pointer gray code synchronized into the read domain
    signal wr_gray_s1, wr_gray_s2 : unsigned(ADDR_BITS downto 0) := (others => '0');

    signal empty   : std_logic;
    signal acc     : natural range 0 to 99;
    signal head    : std_logic_vector(8 downto 0);

begin

    -- ---- write side -----------------------------------------------------
    wr_proc: process (wr_clk, wr_reset) is
    begin
        if wr_reset = '1' then
            wr_ptr      <= (others => '0');
            wr_ptr_gray <= (others => '0');
        elsif rising_edge(wr_clk) then
            if wr_en = '1' then
                mem(to_integer(wr_ptr(ADDR_BITS - 1 downto 0))) <= wr_er & wr_data;
                wr_ptr      <= wr_ptr + 1;
                wr_ptr_gray <= bin2gray(wr_ptr + 1);
            end if;
        end if;
    end process;

    -- ---- read side ------------------------------------------------------
    sync_proc: process (rd_clk, rd_reset) is
    begin
        if rd_reset = '1' then
            wr_gray_s1 <= (others => '0');
            wr_gray_s2 <= (others => '0');
        elsif rising_edge(rd_clk) then
            wr_gray_s1 <= wr_ptr_gray;
            wr_gray_s2 <= wr_gray_s1;
        end if;
    end process;

    empty <= '1' when rd_ptr_gray = wr_gray_s2 else '0';
    head  <= mem(to_integer(rd_ptr(ADDR_BITS - 1 downto 0)));

    gmii.data <= head(7 downto 0);
    gmii.er   <= head(8);
    gmii.dv   <= not empty;

    rd_proc: process (rd_clk, rd_reset) is
    begin
        if rd_reset = '1' then
            rd_ptr      <= (others => '0');
            rd_ptr_gray <= (others => '0');
            acc         <= 0;
        elsif rising_edge(rd_clk) then
            if empty = '0' and gmii_ready = '1' then
                -- offer the head octet for speed_cycles_per_byte accepts, then pop
                if acc = speed_cycles_per_byte(speed) - 1 then
                    acc         <= 0;
                    rd_ptr      <= rd_ptr + 1;
                    rd_ptr_gray <= bin2gray(rd_ptr + 1);
                else
                    acc <= acc + 1;
                end if;
            end if;
        end if;
    end process;

end architecture;
