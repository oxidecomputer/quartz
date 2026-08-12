-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil_common_pkg.all;

-- Sim-only AXI-Lite responder that deliberately does *not* look like
-- axil_target_txn. Every responder in the tree today ties wready to awready and
-- makes bvalid a single-cycle pulse, which means the interconnect has only ever
-- seen one handshake shape. This model:
--   * accepts AW and W independently, each after its own stall
--   * delays B and R by a variable number of cycles after the address phase
--   * holds BVALID/RVALID until the corresponding READY
-- The stalls come from an LFSR so the pattern varies across a test but is
-- identical run to run.

entity axil_slow_responder is
    generic (
        addr_width : integer := 8;
        -- LFSR seed, so multiple instances can stall differently
        seed : std_logic_vector(7 downto 0) := x"A5"
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        awvalid : in    std_logic;
        awready : out   std_logic;
        awaddr  : in    std_logic_vector(addr_width - 1 downto 0);

        wvalid : in    std_logic;
        wready : out   std_logic;
        wdata  : in    std_logic_vector(31 downto 0);
        wstrb  : in    std_logic_vector(3 downto 0);

        bvalid : out   std_logic;
        bready : in    std_logic;
        bresp  : out   std_logic_vector(1 downto 0);

        arvalid : in    std_logic;
        arready : out   std_logic;
        araddr  : in    std_logic_vector(addr_width - 1 downto 0);

        rvalid : out   std_logic;
        rready : in    std_logic;
        rdata  : out   std_logic_vector(31 downto 0);
        rresp  : out   std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of axil_slow_responder is

    constant NUM_WORDS : integer := 16;
    constant MAX_DELAY : integer := 3;

    type storage_t is array (0 to NUM_WORDS - 1) of std_logic_vector(31 downto 0);

    signal storage : storage_t;
    signal lfsr    : std_logic_vector(7 downto 0);

    signal aw_done : std_logic;
    signal w_done  : std_logic;
    signal ar_done : std_logic;

    signal aw_cnt : integer range 0 to MAX_DELAY;
    signal w_cnt  : integer range 0 to MAX_DELAY;
    signal b_cnt  : integer range 0 to MAX_DELAY;
    signal ar_cnt : integer range 0 to MAX_DELAY;
    signal r_cnt  : integer range 0 to MAX_DELAY;

    signal awaddr_reg : std_logic_vector(addr_width - 1 downto 0);
    signal wdata_reg  : std_logic_vector(31 downto 0);
    signal wstrb_reg  : std_logic_vector(3 downto 0);
    signal rdata_reg  : std_logic_vector(31 downto 0);

    function delay_of (constant bits : std_logic_vector(1 downto 0)) return integer is
    begin
        return to_integer(unsigned(bits));
    end function;

begin

    bresp <= OKAY;
    rresp <= OKAY;
    rdata <= rdata_reg;

    lfsr_gen: process(clk, reset)
    begin
        if reset = '1' then
            lfsr <= seed;
        elsif rising_edge(clk) then
            lfsr <= lfsr(6 downto 0) & (lfsr(7) xor lfsr(5) xor lfsr(4) xor lfsr(3));
        end if;
    end process;

    txn: process(clk, reset)
        variable idx : integer range 0 to NUM_WORDS - 1;
    begin
        if reset = '1' then
            storage <= (others => (others => '0'));
            awready <= '0';
            wready  <= '0';
            bvalid  <= '0';
            arready <= '0';
            rvalid  <= '0';
            aw_done <= '0';
            w_done  <= '0';
            ar_done <= '0';
            aw_cnt  <= 0;
            w_cnt   <= 1;
            b_cnt   <= 1;
            ar_cnt  <= 0;
            r_cnt   <= 1;
        elsif rising_edge(clk) then
            -- readys are single cycle pulses
            awready <= '0';
            wready  <= '0';
            arready <= '0';

            -- capture whatever handshaked this cycle
            if awready = '1' and awvalid = '1' then
                aw_done    <= '1';
                awaddr_reg <= awaddr;
            end if;
            if wready = '1' and wvalid = '1' then
                w_done    <= '1';
                wdata_reg <= wdata;
                wstrb_reg <= wstrb;
            end if;
            if arready = '1' and arvalid = '1' then
                ar_done   <= '1';
                idx       := to_integer(unsigned(araddr(5 downto 2)));
                rdata_reg <= storage(idx);
            end if;

            -- stall, then accept. AW and W are completely independent.
            if aw_done = '0' and awready = '0' and awvalid = '1' then
                if aw_cnt = 0 then
                    awready <= '1';
                else
                    aw_cnt <= aw_cnt - 1;
                end if;
            end if;
            if w_done = '0' and wready = '0' and wvalid = '1' then
                if w_cnt = 0 then
                    wready <= '1';
                else
                    w_cnt <= w_cnt - 1;
                end if;
            end if;
            if ar_done = '0' and arready = '0' and arvalid = '1' then
                if ar_cnt = 0 then
                    arready <= '1';
                else
                    ar_cnt <= ar_cnt - 1;
                end if;
            end if;

            -- responses, held until ready
            if aw_done = '1' and w_done = '1' and bvalid = '0' then
                if b_cnt = 0 then
                    bvalid <= '1';
                    idx    := to_integer(unsigned(awaddr_reg(5 downto 2)));
                    for byte in 0 to 3 loop
                        if wstrb_reg(byte) = '1' then
                            storage(idx)(8 * byte + 7 downto 8 * byte) <= wdata_reg(8 * byte + 7 downto 8 * byte);
                        end if;
                    end loop;
                else
                    b_cnt <= b_cnt - 1;
                end if;
            end if;
            if ar_done = '1' and rvalid = '0' then
                if r_cnt = 0 then
                    rvalid <= '1';
                else
                    r_cnt <= r_cnt - 1;
                end if;
            end if;

            -- teardown, and pick the next set of stalls
            if bvalid = '1' and bready = '1' then
                bvalid  <= '0';
                aw_done <= '0';
                w_done  <= '0';
                aw_cnt  <= delay_of(lfsr(1 downto 0));
                w_cnt   <= delay_of(lfsr(3 downto 2));
                b_cnt   <= delay_of(lfsr(5 downto 4));
            end if;
            if rvalid = '1' and rready = '1' then
                rvalid  <= '0';
                ar_done <= '0';
                ar_cnt  <= delay_of(lfsr(4 downto 3));
                r_cnt   <= delay_of(lfsr(7 downto 6));
            end if;
        end if;
    end process;

end rtl;
