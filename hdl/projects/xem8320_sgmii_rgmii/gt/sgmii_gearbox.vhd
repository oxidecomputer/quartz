-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII gearbox: 2:1 width conversion + comma re-alignment between the GTY raw
-- datapath and the soft SGMII PCS.
--
-- The GTY, with 8b10b bypassed, presents a 20-bit raw datapath at half the PCS
-- clock (line rate 1.25 Gb/s / 20 = 62.5 MHz), i.e. two 10-bit code groups per
-- GT clock. The soft PCS wants one 10-bit code group per 125 MHz clock. This
-- block serializes 20->10 on receive and packs 10->20 on transmit, and finds the
-- 10-bit code-group boundary itself (bit-slip on the K28.5 comma) so it does not
-- depend on the GT having aligned to a 10-bit boundary.
--
-- Clocking: everything runs in the 125 MHz PCS clock `clk`. `word_stb` is a
-- one-`clk` pulse that marks the boundary of each fresh 20-bit GT word (it must
-- be asserted on every other clk, phase-locked to the GT clock). `gt_rx_data` is
-- sampled when `word_stb` is high and must be stable across the GT word period;
-- `gt_tx_data` is likewise held for the GT to sample once per GT word. The
-- 62.5 MHz <-> 125 MHz interfacing is done in sgmii_gt (phase-aligned MMCM
-- clocks), so this block is a single-clock design and is directly testable.
--
-- Bit order: a code group is transmission order, bit 0 = 'a' (first on the wire),
-- matching decode_8b10b's datain and encode_8b10b's output. The GT is assumed to
-- present userdata bit 0 = first received bit; if a particular GT/config reverses
-- that, set BITREV.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity sgmii_gearbox is
    generic (
        -- slip threshold: consecutive non-comma code groups before advancing the
        -- bit-slip offset while unaligned. Must exceed the comma spacing of the
        -- SGMII idle stream (/K28.5/Dx/ -> a comma every 2 code groups).
        SLIP_THRESHOLD : positive := 20;
        -- commas that must arrive at the current bit-slip offset before declaring
        -- alignment (guards against a single accidental comma at a wrong offset).
        COMMAS_TO_LOCK : positive := 3;
        -- flip GT userdata bit order if the GT presents MSB-first
        BITREV         : boolean  := false
    );
    port (
        clk   : in    std_logic;   -- 125 MHz PCS clock
        reset : in    std_logic;

        -- GT-facing (20-bit; new word each word_stb)
        word_stb   : in    std_logic;
        gt_rx_data : in    std_logic_vector(19 downto 0);
        gt_tx_data : out   std_logic_vector(19 downto 0);

        -- PCS-facing (10-bit code groups at 125 MHz)
        rx_code    : out   std_logic_vector(9 downto 0);
        rx_aligned : out   std_logic;
        tx_code    : in    std_logic_vector(9 downto 0);

        -- debug: the latched raw 20-bit GT word (before serialization)
        dbg_word   : out   std_logic_vector(19 downto 0)
    );
end entity;

architecture rtl of sgmii_gearbox is

    -- K28.5 comma, both disparities, in transmission (datain) bit order.
    constant COMMA_RD_MINUS : std_logic_vector(9 downto 0) := "0101111100";
    constant COMMA_RD_PLUS  : std_logic_vector(9 downto 0) := "1010000011";

    function maybe_rev (d : std_logic_vector(19 downto 0)) return std_logic_vector is
        variable r : std_logic_vector(19 downto 0);
    begin
        if BITREV then
            for i in 0 to 19 loop
                r(i) := d(19 - i);
            end loop;
            return r;
        else
            return d;
        end if;
    end function;

    -- receive
    signal cur   : std_logic_vector(19 downto 0);   -- newest GT word
    signal prv   : std_logic_vector(19 downto 0);   -- previous GT word
    signal slip  : integer range 0 to 9 := 0;
    signal miss  : integer range 0 to SLIP_THRESHOLD := 0;
    signal good  : integer range 0 to COMMAS_TO_LOCK := 0;
    signal algn  : std_logic := '0';

    -- transmit
    signal tx_lo : std_logic_vector(9 downto 0) := (others => '0');

begin

    dbg_word <= cur;

    -- ===== Receive: 20 -> 10 with comma bit-slip =============================
    rx_proc: process (clk) is
        variable win  : std_logic_vector(39 downto 0);
        variable base : integer range 0 to 19;
        variable code : std_logic_vector(9 downto 0);
        variable comma : boolean;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cur        <= (others => '0');
                prv        <= (others => '0');
                slip       <= 0;
                miss       <= 0;
                good       <= 0;
                algn       <= '0';
                rx_code    <= (others => '0');
                rx_aligned <= '0';
            else
                -- Emit one code group each clk. word_stb selects the low
                -- (older) symbol of the lagged word `prv`, else the high symbol.
                -- Window places the oldest bit (prv(0)) at index 0.
                win  := cur & prv;
                if word_stb = '1' then
                    base := slip;
                else
                    base := slip + 10;
                end if;

                for j in 0 to 9 loop
                    code(j) := win(base + j);
                end loop;

                rx_code <= code;

                comma := (code = COMMA_RD_MINUS) or (code = COMMA_RD_PLUS);

                if algn = '0' then
                    if comma then
                        -- sustained commas at this offset -> lock
                        miss <= 0;
                        if good = COMMAS_TO_LOCK - 1 then
                            algn <= '1';
                        else
                            good <= good + 1;
                        end if;
                    elsif miss = SLIP_THRESHOLD then
                        -- no commas here: advance the 10-bit boundary, restart
                        if slip = 9 then
                            slip <= 0;
                        else
                            slip <= slip + 1;
                        end if;
                        miss <= 0;
                        good <= 0;
                    else
                        miss <= miss + 1;
                    end if;
                end if;

                rx_aligned <= algn;

                -- advance the word history on a fresh GT word
                if word_stb = '1' then
                    prv <= cur;
                    cur <= maybe_rev(gt_rx_data);
                end if;
            end if;
        end if;
    end process;

    -- ===== Transmit: 10 -> 20 ================================================
    tx_proc: process (clk) is
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tx_lo      <= (others => '0');
                gt_tx_data <= (others => '0');
            else
                if word_stb = '1' then
                    -- first (older) symbol of the pair
                    tx_lo <= tx_code;
                else
                    -- second (newer) symbol: present the assembled word.
                    -- low half = older symbol, high half = newer symbol.
                    gt_tx_data <= maybe_rev(tx_code & tx_lo);
                end if;
            end if;
        end if;
    end process;

end architecture;
