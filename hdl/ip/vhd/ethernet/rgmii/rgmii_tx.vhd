-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- RGMII transmit: drive the 4-bit DDR RGMII link from the g2r GMII octet stream.
--
-- At 1000 Mbps the low nibble is launched on the rising edge of txc and the high
-- nibble on the falling edge (true DDR, 125 MHz). TX_CTL carries tx_en on the
-- rising edge and tx_en XOR tx_er on the falling edge. At 100/10 Mbps the link
-- runs SDR: the same nibble is presented on both edges and each nibble occupies
-- a divided txc period, so a byte spans two txc periods. The g2r stream arrives
-- replicated (10x/100x) from the rate-agnostic PCS; this block decimates by
-- sampling one octet per byte period.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.rgmii_pkg.all;

entity rgmii_tx is
    generic (
        TARGET : string := "SIM"   -- DDR primitive target (see oddr_wrapper)
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        speed : in    eth_speed_t;
        gmii  : in    gmii_t;        -- g2r: octets to transmit

        rgmii_txc    : out   std_logic;
        rgmii_tx_ctl : out   std_logic;
        rgmii_txd    : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of rgmii_tx is

    signal byte_cycles : positive;            -- byte period in clk cycles (1/10/100)
    signal half_cycles : positive;            -- one nibble period
    signal is_1g       : std_logic;

    signal phase   : natural range 0 to 99;   -- position within the byte period
    signal hi_half : std_logic;               -- high-nibble half of the byte
    signal cur     : gmii_t;                   -- decimated octet for this byte period

    signal d_lo, d_hi : std_logic_vector(3 downto 0);
    signal nib        : std_logic_vector(3 downto 0);
    signal txd_rise   : std_logic_vector(3 downto 0);
    signal txd_fall   : std_logic_vector(3 downto 0);
    signal ctl_rise   : std_logic;
    signal ctl_fall   : std_logic;

    signal nphase   : natural range 0 to 49;   -- position within one txc period
    signal txc_rise : std_logic;
    signal txc_fall : std_logic;

begin

    byte_cycles <= speed_cycles_per_byte(speed);
    half_cycles <= 1 when speed = SPEED_1000 else speed_cycles_per_byte(speed) / 2;
    is_1g       <= '1' when speed = SPEED_1000 else '0';

    -- phase / decimation: sample one octet per byte period
    rate: process (clk, reset) is
    begin
        if reset = '1' then
            phase <= 0;
            cur   <= GMII_IDLE;
        elsif rising_edge(clk) then
            if phase = byte_cycles - 1 then
                phase <= 0;
                cur   <= gmii;
            else
                phase <= phase + 1;
            end if;
        end if;
    end process;

    hi_half <= '1' when phase >= half_cycles else '0';

    d_lo <= cur.data(3 downto 0);
    d_hi <= cur.data(7 downto 4);
    nib  <= d_hi when hi_half = '1' else d_lo;

    -- 1000: lo on rising / hi on falling. 100/10: selected nibble on both edges.
    -- We are the MAC on this link, so TXD is meaningless during the inter-frame
    -- gap (in-band status is a PHY->MAC construct): drive zeros.
    txd_rise <= (others => '0') when cur.dv = '0' else
                d_lo when is_1g = '1' else nib;
    txd_fall <= (others => '0') when cur.dv = '0' else
                d_hi when is_1g = '1' else nib;
    -- TX_CTL: tx_en on the rising edge, tx_en xor tx_er on the falling edge, at
    -- every speed (RGMII v2.0 table 2; the encoding is not 1000-only)
    ctl_rise <= cur.dv;
    ctl_fall <= cur.dv xor cur.er;

    txd_gen: for i in 0 to 3 generate
        oddr_i: entity work.oddr_wrapper
            generic map (
                TARGET => TARGET
            )
            port map (
                clk    => clk,
                d_rise => txd_rise(i),
                d_fall => txd_fall(i),
                q      => rgmii_txd(i)
            );
    end generate;

    ctl_oddr: entity work.oddr_wrapper
        generic map (
            TARGET => TARGET
        )
        port map (
            clk    => clk,
            d_rise => ctl_rise,
            d_fall => ctl_fall,
            q      => rgmii_tx_ctl
        );

    -- txc: DDR-forwarded 125 MHz clock at 1000, divided clock at 100/10. The ODDR
    -- output drives the pin directly (no fabric mux) so it can be placed in the
    -- pin's OLOGIC on a real device: at 1000 it forwards clk (rise='1'/fall='0').
    -- At 100/10 the divided clock is built at ODDR half-cycle granularity: a txc
    -- period spans half_cycles clks = 2*half_cycles half-cycles, of which exactly
    -- half are driven high, giving a true 50% duty cycle even when half_cycles is
    -- odd (5 at 100M would otherwise round to 40/60, outside the RGMII 45-55%).
    nphase <= phase mod half_cycles;
    txc_rise <= '1' when is_1g = '1' else
                '1' when 2 * nphase < half_cycles else '0';
    txc_fall <= '0' when is_1g = '1' else
                '1' when 2 * nphase + 1 < half_cycles else '0';

    txc_oddr: entity work.oddr_wrapper
        generic map (
            TARGET => TARGET
        )
        port map (
            clk    => clk,
            d_rise => txc_rise,
            d_fall => txc_fall,
            q      => rgmii_txc
        );

end architecture;
