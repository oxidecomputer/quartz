-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII <-> RGMII media converter with in-band Ethernet management: the
-- same stitching as sgmii_to_rgmii (which is untouched and remains usable
-- without any of this), plus:
--
--   * the r2g stream is tapped (deduplicated via r2g_expander's byte_pop)
--     into udp_endpoint, an IPv6-only endpoint that answers NDP and ICMPv6
--     echo at its MAC-derived link-local address and hands UDP datagrams
--     on CLIENT_UDP_PORT to eth_mgmt;
--   * the g2r stream runs through gmii_pkt_buf and g2r_inject_mux so
--     management responses can be injected toward the RGMII side at frame
--     boundaries, forwarded traffic always taking priority;
--   * eth_mgmt implements the management protocol (identity, serial/MAC
--     update, application image flashing) against the SPI NOR through
--     mgmt_flash.
--
-- Forwarding remains byte-transparent in both directions; the management
-- plane only adds (bounded) latency in the SGMII->RGMII direction.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;
use work.rgmii_pkg.all;
use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;
use work.eth_mgmt_pkg.all;

entity sgmii_to_rgmii_mgmt is
    generic (
        INCLUDE_AUTONEG   : boolean  := true;
        LINK_TIMER_CYCLES : positive := 1250000;
        TARGET            : string   := "SIM";

        CLIENT_UDP_PORT : std_logic_vector(15 downto 0) := X"6F78";
        DEFAULT_MAC     : mac_addr_t := X"0A0B0C0D0E0F";
        DEFAULT_SERIAL  : std_logic_vector(8 * SERIAL_BYTES - 1 downto 0) := (others => '0');
        APP_IMAGE_BASE  : unsigned(31 downto 0) := X"00100000";
        APP_IMAGE_SIZE  : unsigned(31 downto 0) := X"00E00000";
        IDENTITY_BASE   : unsigned(31 downto 0) := X"00F00000";
        SCLK_DIVISOR    : unsigned(15 downto 0) := to_unsigned(4, 16)
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        fpga_version : in    std_logic_vector(31 downto 0);

        -- SGMII line side (already comma-aligned 10-bit code groups)
        rx_code       : in    std_logic_vector(9 downto 0);
        rx_code_valid : in    std_logic;
        tx_code       : out   std_logic_vector(9 downto 0);
        tx_code_valid : out   std_logic;

        -- RGMII line side
        rgmii_txc    : out   std_logic;
        rgmii_tx_ctl : out   std_logic;
        rgmii_txd    : out   std_logic_vector(3 downto 0);
        rgmii_rxc    : in    std_logic;
        rgmii_rx_ctl : in    std_logic;
        rgmii_rxd    : in    std_logic_vector(3 downto 0);

        -- SPI NOR
        spi_cs_n  : out   std_logic;
        spi_sclk  : out   std_logic;
        spi_io    : in    std_logic_vector(3 downto 0);
        spi_io_o  : out   std_logic_vector(3 downto 0);
        spi_io_oe : out   std_logic_vector(3 downto 0);

        -- auto-neg control / advertised ability
        an_enable  : in    std_logic := '1';
        an_restart : in    std_logic := '0';
        adv_config : in    sgmii_config_t := SGMII_CONFIG_RESET;

        -- resolved status
        link_up         : out   std_logic;
        speed           : out   eth_speed_t;
        duplex          : out   std_logic;
        rgmii_link_info : out   rgmii_inband_t;

        -- management observability
        mgmt_status      : out   endpoint_status_t;
        mgmt_mac         : out   mac_addr_t;
        mgmt_mac_default : out   std_logic;
        fwd_drops        : out   unsigned(7 downto 0)
    );
end entity;

architecture rtl of sgmii_to_rgmii_mgmt is

    signal g2r        : gmii_t;          -- PCS RX -> pkt buf
    signal g2r_muxed  : gmii_t;          -- inject mux -> RGMII TX
    signal r2g_rgmii  : gmii_t;          -- RGMII RX (rxc domain)
    signal r2g_pcs    : gmii_t;          -- expanded octet stream -> PCS TX
    signal r2g_ready  : std_logic;
    signal byte_pop   : std_logic;

    signal cur_speed : eth_speed_t;
    signal cur_link  : std_logic;
    signal inband    : rgmii_inband_t;

    signal head_valid  : std_logic;
    signal head_marker : std_logic;
    signal head_er     : std_logic;
    signal head_data   : std_logic_vector(7 downto 0);
    signal head_pop    : std_logic;

    signal inj_valid   : std_logic;
    signal inj_len     : unsigned(10 downto 0);
    signal inj_done    : std_logic;
    signal inj_rd_addr : unsigned(8 downto 0);
    signal inj_rd_data : std_logic_vector(7 downto 0);

    signal status_int : endpoint_status_t;

    signal mac_int    : mac_addr_t;
    signal mac_valid  : std_logic;

    signal client_rx       : udp_st_t;
    signal client_rx_meta  : udp_rx_meta_t;
    signal client_rx_ready : std_logic;
    signal client_tx       : udp_st_t;
    signal client_tx_meta  : udp_tx_meta_t;
    signal client_tx_ready : std_logic;

    signal f_req      : std_logic;
    signal f_op       : flash_op_t;
    signal f_addr     : std_logic_vector(31 downto 0);
    signal f_len      : unsigned(8 downto 0);
    signal f_busy     : std_logic;
    signal f_done     : std_logic;
    signal f_wr_data  : std_logic_vector(7 downto 0);
    signal f_wr_ack   : std_logic;
    signal f_rd_data  : std_logic_vector(7 downto 0);
    signal f_rd_valid : std_logic;

begin

    speed       <= cur_speed;
    link_up     <= cur_link;
    rgmii_link_info <= inband;
    mgmt_status <= status_int;
    mgmt_mac    <= mac_int;

    pcs_inst: entity work.sgmii_pcs
        generic map (
            INCLUDE_AUTONEG   => INCLUDE_AUTONEG,
            LINK_TIMER_CYCLES => LINK_TIMER_CYCLES
        )
        port map (
            clk           => clk,
            reset         => reset,
            rx_code       => rx_code,
            rx_code_valid => rx_code_valid,
            tx_code       => tx_code,
            tx_code_valid => tx_code_valid,
            g2r           => g2r,
            r2g           => r2g_pcs,
            r2g_ready     => r2g_ready,
            an_enable     => an_enable,
            an_restart    => an_restart,
            adv_config    => adv_config,
            link_up       => cur_link,
            speed         => cur_speed,
            duplex        => duplex,
            dbg_tx        => open
        );

    -- forward path: buffer + response injection at frame boundaries
    pkt_buf: entity work.gmii_pkt_buf
        generic map (
            ADDR_BITS => 11
        )
        port map (
            clk         => clk,
            reset       => reset,
            speed       => cur_speed,
            g2r_in      => g2r,
            head_valid  => head_valid,
            head_marker => head_marker,
            head_er     => head_er,
            head_data   => head_data,
            pop         => head_pop,
            drop_count  => fwd_drops
        );

    inject_mux: entity work.g2r_inject_mux
        port map (
            clk         => clk,
            reset       => reset,
            speed       => cur_speed,
            head_valid  => head_valid,
            head_marker => head_marker,
            head_er     => head_er,
            head_data   => head_data,
            pop         => head_pop,
            inj_valid   => inj_valid,
            inj_len     => inj_len,
            inj_rd_addr => inj_rd_addr,
            inj_rd_data => inj_rd_data,
            inj_done    => inj_done,
            g2r         => g2r_muxed,
            underrun    => open
        );

    rgmii_inst: entity work.rgmii_mac
        generic map (
            TARGET => TARGET
        )
        port map (
            clk          => clk,
            reset        => reset,
            speed        => cur_speed,
            g2r          => g2r_muxed,
            r2g          => r2g_rgmii,
            r2g_active   => open,
            inband       => inband,
            rgmii_txc    => rgmii_txc,
            rgmii_tx_ctl => rgmii_tx_ctl,
            rgmii_txd    => rgmii_txd,
            rgmii_rxc    => rgmii_rxc,
            rgmii_rx_ctl => rgmii_rx_ctl,
            rgmii_rxd    => rgmii_rxd
        );

    expander: entity work.r2g_expander
        port map (
            wr_clk     => rgmii_rxc,
            wr_reset   => reset,
            wr_data    => r2g_rgmii.data,
            wr_er      => r2g_rgmii.er,
            wr_en      => r2g_rgmii.dv,
            rd_clk     => clk,
            rd_reset   => reset,
            speed      => cur_speed,
            gmii       => r2g_pcs,
            gmii_ready => r2g_ready,
            byte_pop   => byte_pop,
            overflow   => open
        );

    endpoint: entity work.udp_endpoint
        generic map (
            CLIENT_UDP_PORT => CLIENT_UDP_PORT
        )
        port map (
            clk             => clk,
            reset           => reset,
            our_mac         => mac_int,
            mac_valid       => mac_valid,
            tap_data        => r2g_pcs.data,
            tap_er          => r2g_pcs.er,
            tap_dv          => r2g_pcs.dv,
            tap_pop         => byte_pop,
            inj_valid       => inj_valid,
            inj_len         => inj_len,
            inj_done        => inj_done,
            inj_rd_addr     => inj_rd_addr,
            inj_rd_data     => inj_rd_data,
            status          => status_int,
            client_rx       => client_rx,
            client_rx_meta  => client_rx_meta,
            client_rx_ready => client_rx_ready,
            client_tx       => client_tx,
            client_tx_meta  => client_tx_meta,
            client_tx_ready => client_tx_ready
        );

    mgmt: entity work.eth_mgmt
        generic map (
            DEFAULT_MAC    => DEFAULT_MAC,
            DEFAULT_SERIAL => DEFAULT_SERIAL,
            APP_IMAGE_BASE => APP_IMAGE_BASE,
            APP_IMAGE_SIZE => APP_IMAGE_SIZE,
            IDENTITY_BASE  => IDENTITY_BASE
        )
        port map (
            clk             => clk,
            reset           => reset,
            fpga_version    => fpga_version,
            endpoint_status => status_int,
            mac             => mac_int,
            mac_valid       => mac_valid,
            mac_is_default  => mgmt_mac_default,
            rx              => client_rx,
            rx_meta         => client_rx_meta,
            rx_ready        => client_rx_ready,
            tx              => client_tx,
            tx_meta         => client_tx_meta,
            tx_ready        => client_tx_ready,
            f_req           => f_req,
            f_op            => f_op,
            f_addr          => f_addr,
            f_len           => f_len,
            f_busy          => f_busy,
            f_done          => f_done,
            f_wr_data       => f_wr_data,
            f_wr_ack        => f_wr_ack,
            f_rd_data       => f_rd_data,
            f_rd_valid      => f_rd_valid
        );

    flash: entity work.mgmt_flash
        generic map (
            SCLK_DIVISOR => SCLK_DIVISOR
        )
        port map (
            clk      => clk,
            reset    => reset,
            req      => f_req,
            op       => f_op,
            addr     => f_addr,
            len      => f_len,
            busy     => f_busy,
            done     => f_done,
            wr_data  => f_wr_data,
            wr_ack   => f_wr_ack,
            rd_data  => f_rd_data,
            rd_valid => f_rd_valid,
            cs_n     => spi_cs_n,
            sclk     => spi_sclk,
            io       => spi_io,
            io_o     => spi_io_o,
            io_oe    => spi_io_oe
        );

end architecture;
