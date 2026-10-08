-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.interlink_pkg.all;

-- The part of the physical layer that is the same for every serdes: 8b10b
-- coding, comma alignment and polarity correction. Below this is a plain
-- 10-bit symbol interface, so a low-speed oversampler, an LVDS SERDES
-- primitive or a transceiver wrapper can all sit underneath it. A
-- transceiver that does its own 8b10b skips this block and drives the
-- character interface of interlink_link directly.
--
-- Polarity is corrected here by inverting the 10-bit symbol rather than at
-- the serdes so it works the same way whatever the serdes is.
entity interlink_phy_8b10b is
    generic (
        ALIGN_PATTERNS_TO_LOCK : positive;
        ALIGN_SYMBOLS_BEFORE_SLIP : positive;
        ALIGN_SYMBOLS_BEFORE_UNLOCK : positive
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        tx_char : view char_source'converse;
        rx_char : view char_source;
        rx_code_err : out std_logic;
        rx_disp_err : out std_logic;
        rx_aligned : out std_logic;
        polarity_inverted : in std_logic;
        realign : in std_logic;

        serdes : view serdes_link_side
    );
end entity;

architecture rtl of interlink_phy_8b10b is
    signal tx_disp : std_logic;
    signal tx_disp_next : std_logic;
    signal rx_symbol : std_logic_vector(9 downto 0);
    signal rx_symbol_valid : std_logic;
    signal rx_corrected : std_logic_vector(9 downto 0);
    signal aligned_valid : std_logic;
    signal rx_disp : std_logic;
    signal rx_disp_next : std_logic;
    signal decoded : std_logic_vector(8 downto 0);
    signal code_err : std_logic;
    signal disp_err : std_logic;
begin

    -- Transmit: the framer always has a character ready, we just encode it
    -- and carry the running disparity across the slots the serdes accepts.
    encode_8b10b_inst: entity work.encode_8b10b
        port map (
            datain => tx_char.ctrl & tx_char.data,
            dispin => tx_disp,
            dataout => serdes.tx_data,
            dispout => tx_disp_next
        );
    serdes.tx_valid <= tx_char.valid;
    tx_char.ready <= serdes.tx_ready;

    tx_disp_reg: process(clk, reset)
    begin
        if reset then
            tx_disp <= '0';
        elsif rising_edge(clk) then
            if tx_char.valid = '1' and serdes.tx_ready = '1' then
                tx_disp <= tx_disp_next;
            end if;
        end if;
    end process;

    -- Receive: capture the symbol the cycle it is offered since a serdes may
    -- not hold it, align, correct polarity, decode, register.
    serdes.rx_ready <= '1';

    rx_capture: process(clk, reset)
    begin
        if reset then
            rx_symbol <= (others => '0');
            rx_symbol_valid <= '0';
        elsif rising_edge(clk) then
            rx_symbol_valid <= serdes.rx_valid;
            if serdes.rx_valid = '1' then
                rx_symbol <= serdes.rx_data;
            end if;
        end if;
    end process;

    -- The comma is polarity symmetric so the aligner does not care which way
    -- the wires are and can run on the uncorrected symbol.
    aligner_10bk28_5_inst: entity work.aligner_10bk28_5
        generic map (
            MIN_PATTERNS_TO_LOCK => ALIGN_PATTERNS_TO_LOCK,
            MAX_SYMBOLS_BEFORE_SLIP => ALIGN_SYMBOLS_BEFORE_SLIP,
            MAX_SYMBOLS_BEFORE_UNLOCK => ALIGN_SYMBOLS_BEFORE_UNLOCK
        )
        port map (
            clk => clk,
            reset => reset,
            data_in => rx_symbol,
            data_in_valid => rx_symbol_valid,
            data_in_align_ready => open,
            downstream_ready => '1',
            downstream_valid => aligned_valid,
            realign => realign,
            bit_slip => serdes.bit_slip,
            is_locked => rx_aligned
        );

    rx_corrected <= not rx_symbol when polarity_inverted = '1' else rx_symbol;

    decode_8b10b_inst: entity work.decode_8b10b
        port map (
            datain => rx_corrected,
            dispin => rx_disp,
            dataout => decoded,
            dispout => rx_disp_next,
            code_err => code_err,
            disp_err => disp_err
        );

    rx_reg: process(clk, reset)
    begin
        if reset then
            rx_disp <= '0';
            rx_char.valid <= '0';
            rx_char.ctrl <= '0';
            rx_char.data <= (others => '0');
            rx_code_err <= '0';
            rx_disp_err <= '0';
        elsif rising_edge(clk) then
            rx_char.valid <= aligned_valid;
            if aligned_valid = '1' then
                rx_disp <= rx_disp_next;
                rx_char.ctrl <= decoded(8);
                rx_char.data <= decoded(7 downto 0);
                rx_code_err <= code_err;
                rx_disp_err <= disp_err;
            end if;
        end if;
    end process;

end rtl;
