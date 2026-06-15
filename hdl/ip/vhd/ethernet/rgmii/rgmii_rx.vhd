-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- RGMII receive: recover a GMII octet stream from the 4-bit DDR RGMII link. The
-- datapath is clocked by the received rxc. At 1000 Mbps each rxc cycle yields a
-- full byte (low nibble on the rising edge, high nibble on the falling edge); at
-- 100/10 Mbps each rxc cycle yields one SDR nibble and a byte spans two cycles,
-- aligned to the rising edge of RX_CTL (start of frame). During the inter-frame
-- gap (RX_CTL low) the rising-edge nibble carries the in-band status.
--
-- r2g is produced in the rxc clock domain; crossing into the PCS/system clock
-- domain is done with a dual-clock FIFO at the bridge level.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.rgmii_pkg.all;

entity rgmii_rx is
    port (
        reset : in    std_logic;

        speed : in    eth_speed_t;

        rgmii_rxc    : in    std_logic;
        rgmii_rx_ctl : in    std_logic;
        rgmii_rxd    : in    std_logic_vector(3 downto 0);

        gmii      : out   gmii_t;        -- r2g: recovered octets (rxc domain)
        rx_active : out   std_logic;     -- high for the duration of a frame (rxc domain)
        inband    : out   rgmii_inband_t
    );
end entity;

architecture rtl of rgmii_rx is

    signal is_1g : std_logic;

    -- iddr outputs (rxc domain)
    signal lo    : std_logic_vector(3 downto 0);   -- rising-edge nibble
    signal hi    : std_logic_vector(3 downto 0);   -- falling-edge nibble
    signal ctl_r : std_logic;
    signal ctl_f : std_logic;

    -- SDR byte assembly
    signal lo_reg     : std_logic_vector(3 downto 0);
    signal dv_reg     : std_logic;
    signal er_reg     : std_logic;
    signal first_nib  : std_logic;

begin

    is_1g <= '1' when speed = SPEED_1000 else '0';

    rxd_gen: for i in 0 to 3 generate
        iddr_i: entity work.iddr_wrapper
            port map (
                clk    => rgmii_rxc,
                q      => rgmii_rxd(i),
                d_rise => lo(i),
                d_fall => hi(i)
            );
    end generate;

    ctl_iddr: entity work.iddr_wrapper
        port map (
            clk    => rgmii_rxc,
            q      => rgmii_rx_ctl,
            d_rise => ctl_r,
            d_fall => ctl_f
        );

    recombine: process (rgmii_rxc, reset) is
    begin
        if reset = '1' then
            gmii      <= GMII_IDLE;
            rx_active <= '0';
            inband    <= RGMII_INBAND_RESET;
            lo_reg    <= (others => '0');
            dv_reg    <= '0';
            er_reg    <= '0';
            first_nib <= '1';
        elsif rising_edge(rgmii_rxc) then
            gmii.dv   <= '0';
            gmii.er   <= '0';
            rx_active <= ctl_r;   -- frame in progress while RX_CTL is asserted

            if ctl_r = '0' then
                -- inter-frame: decode in-band status, resync nibble alignment
                inband    <= nibble_to_inband(lo);
                first_nib <= '1';
            elsif is_1g = '1' then
                -- DDR: a whole byte each cycle
                gmii.data <= hi & lo;
                gmii.dv   <= '1';
                gmii.er   <= ctl_r xor ctl_f;
            else
                -- SDR: low nibble then high nibble across two cycles
                if first_nib = '1' then
                    lo_reg    <= lo;
                    dv_reg    <= ctl_r;
                    er_reg    <= ctl_r xor ctl_f;
                    first_nib <= '0';
                else
                    gmii.data <= lo & lo_reg;
                    gmii.dv   <= dv_reg;
                    gmii.er   <= er_reg or (ctl_r xor ctl_f);
                    first_nib <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture;
