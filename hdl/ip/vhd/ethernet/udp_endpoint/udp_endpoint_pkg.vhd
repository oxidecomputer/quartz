-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Interface types for the udp_endpoint: the generic UDP datagram interface a
-- client protocol block uses (no L2/L3 knowledge required on the client
-- side), plus the internal frame-builder request record shared by the
-- endpoint's own responders (NDP/ICMPv6 echo) and the client TX path.
--
-- Streams are one-directional records (data/valid/last) with a separate
-- ready signal travelling the other way, VHDL-2008 style. A transfer happens
-- on a rising edge where valid and ready are both high; metadata records are
-- held stable from the first transfer of a datagram through the last.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.eth_hdr_pkg.all;

package udp_endpoint_pkg is

    type udp_st_t is record
        data  : std_logic_vector(7 downto 0);
        valid : std_logic;
        last  : std_logic;
    end record;
    constant UDP_ST_IDLE : udp_st_t := (data => (others => '0'), valid => '0', last => '0');

    -- metadata for a received datagram, valid alongside the payload stream
    type udp_rx_meta_t is record
        src_ip   : ipv6_addr_t;
        src_port : std_logic_vector(15 downto 0);
        dst_port : std_logic_vector(15 downto 0);
        length   : unsigned(10 downto 0);   -- payload bytes
    end record;

    -- metadata a client supplies with a datagram to transmit; payload length
    -- is discovered from the stream's last marker
    type udp_tx_meta_t is record
        dst_ip   : ipv6_addr_t;
        dst_port : std_logic_vector(15 downto 0);
        src_port : std_logic_vector(15 downto 0);
    end record;

    -- endpoint status, for observability and for clients that report it.
    -- The address is the MAC-derived link-local address, so ip_valid simply
    -- tracks mac_valid.
    type endpoint_status_t is record
        ip       : ipv6_addr_t;
        ip_valid : std_logic;
    end record;

    -- internal: frame builder request header. The builder writes the
    -- Ethernet and IPv6 headers and computes the L4 checksum (UDP, or
    -- ICMPv6 whose checksum also covers the pseudo-header).
    type frame_kind_t is (FRAME_IPV6_UDP, FRAME_IPV6_ICMP);
    type frame_tx_hdr_t is record
        kind     : frame_kind_t;
        dst_mac  : mac_addr_t;
        dst_ip   : ipv6_addr_t;
        src_ip   : ipv6_addr_t;
        dst_port : std_logic_vector(15 downto 0);   -- FRAME_IPV6_UDP only
        src_port : std_logic_vector(15 downto 0);   -- FRAME_IPV6_UDP only
    end record;
    constant FRAME_TX_HDR_IDLE : frame_tx_hdr_t := (
        kind     => FRAME_IPV6_UDP,
        dst_mac  => (others => '0'),
        dst_ip   => (others => '0'),
        src_ip   => (others => '0'),
        dst_port => (others => '0'),
        src_port => (others => '0')
    );

end package;
