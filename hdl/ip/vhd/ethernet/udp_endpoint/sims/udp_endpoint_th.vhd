-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Harness for udp_endpoint: instantiates the endpoint plus the forward-path
-- buffer and inject mux exactly as sgmii_to_rgmii_mgmt will, with the
-- bench standing in for the rest of the bridge:
--
--   tap_*   emulates the r2g_expander byte_pop tap (frames from the wire)
--           (IPv6-only endpoint: no DHCP, address derived from the MAC)
--   g2r_in  emulates the PCS RX replicated stream (frames being forwarded)
--   g2r_out is what would reach rgmii_tx; a free-running decimating sampler
--           (like rgmii_tx's own) reconstructs frames into arrays for the
--           bench, recording the inter-frame gap in byte periods
--
-- The bench drives everything through hierarchical aliases.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;
use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;

entity udp_endpoint_th is
end entity;

architecture th of udp_endpoint_th is

    constant CLIENT_PORT : std_logic_vector(15 downto 0) := X"6F78";
    constant DUT_MAC     : mac_addr_t := X"020A0B0C0D0E";

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal speed : eth_speed_t := SPEED_1000;

    signal mac_valid : std_logic := '0';

    -- bench-driven tap (r2g direction)
    signal tap_data : std_logic_vector(7 downto 0) := (others => '0');
    signal tap_er   : std_logic := '0';
    signal tap_dv   : std_logic := '0';
    signal tap_pop  : std_logic := '0';

    -- bench-driven forward stream (g2r direction, replicated)
    signal g2r_in : gmii_t := GMII_IDLE;

    -- buffer <-> mux
    signal head_valid  : std_logic;
    signal head_marker : std_logic;
    signal head_er     : std_logic;
    signal head_data   : std_logic_vector(7 downto 0);
    signal head_pop    : std_logic;
    signal drop_count  : unsigned(7 downto 0);

    -- endpoint <-> mux
    signal inj_valid   : std_logic;
    signal inj_len     : unsigned(10 downto 0);
    signal inj_done    : std_logic;
    signal inj_rd_addr : unsigned(8 downto 0);
    signal inj_rd_data : std_logic_vector(7 downto 0);

    signal g2r_out  : gmii_t;
    signal underrun : std_logic;

    signal status : endpoint_status_t;

    -- client datagram interface (bench is the client)
    signal client_rx       : udp_st_t;
    signal client_rx_meta  : udp_rx_meta_t;
    signal client_rx_ready : std_logic := '1';
    signal client_tx       : udp_st_t := UDP_ST_IDLE;
    signal client_tx_meta  : udp_tx_meta_t := (
        dst_ip => (others => '0'), dst_port => (others => '0'),
        src_port => (others => '0'));
    signal client_tx_ready : std_logic;

begin

    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    pkt_buf: entity work.gmii_pkt_buf
        generic map (
            ADDR_BITS => 11
        )
        port map (
            clk         => clk,
            reset       => reset,
            speed       => speed,
            g2r_in      => g2r_in,
            head_valid  => head_valid,
            head_marker => head_marker,
            head_er     => head_er,
            head_data   => head_data,
            pop         => head_pop,
            drop_count  => drop_count
        );

    mux: entity work.g2r_inject_mux
        port map (
            clk         => clk,
            reset       => reset,
            speed       => speed,
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
            g2r         => g2r_out,
            underrun    => underrun
        );

    dut: entity work.udp_endpoint
        generic map (
            CLIENT_UDP_PORT => CLIENT_PORT
        )
        port map (
            clk             => clk,
            reset           => reset,
            our_mac         => DUT_MAC,
            mac_valid       => mac_valid,
            tap_data        => tap_data,
            tap_er          => tap_er,
            tap_dv          => tap_dv,
            tap_pop         => tap_pop,
            inj_valid       => inj_valid,
            inj_len         => inj_len,
            inj_done        => inj_done,
            inj_rd_addr     => inj_rd_addr,
            inj_rd_data     => inj_rd_data,
            status          => status,
            client_rx       => client_rx,
            client_rx_meta  => client_rx_meta,
            client_rx_ready => client_rx_ready,
            client_tx       => client_tx,
            client_tx_meta  => client_tx_meta,
            client_tx_ready => client_tx_ready
        );

end th;
