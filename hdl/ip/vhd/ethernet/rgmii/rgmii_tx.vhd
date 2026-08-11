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
    signal status_nib : std_logic_vector(3 downto 0);
    signal txd_rise   : std_logic_vector(3 downto 0);
    signal txd_fall   : std_logic_vector(3 downto 0);
    signal ctl_rise   : std_logic;
    signal ctl_fall   : std_logic;

    signal txc_div  : std_logic;
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
    txc_div <= '1' when (phase mod half_cycles) < (half_cycles / 2) else '0';

    d_lo <= cur.data(3 downto 0);
    d_hi <= cur.data(7 downto 4);
    nib  <= d_hi when hi_half = '1' else d_lo;

    -- during the inter-frame gap drive the in-band status nibble (link up, the
    -- resolved speed/duplex) so the far end can recover link state
    status_nib <= inband_to_nibble((link => '1', duplex => '1', speed => speed));

    -- 1000: lo on rising / hi on falling. 100/10: selected nibble on both edges.
    -- When no frame octet is present, send in-band status instead.
    txd_rise <= status_nib when cur.dv = '0' else
                d_lo when is_1g = '1' else nib;
    txd_fall <= status_nib when cur.dv = '0' else
                d_hi when is_1g = '1' else nib;
    ctl_rise <= cur.dv;
    ctl_fall <= (cur.dv xor cur.er) when is_1g = '1' else cur.dv;

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
    -- pin's OLOGIC on a real device: at 1000 it forwards clk (rise='1'/fall='0');
    -- at 100/10 both edges carry the divided-clock level so the ODDR reproduces it.
    txc_rise <= '1' when is_1g = '1' else txc_div;
    txc_fall <= '0' when is_1g = '1' else txc_div;

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
