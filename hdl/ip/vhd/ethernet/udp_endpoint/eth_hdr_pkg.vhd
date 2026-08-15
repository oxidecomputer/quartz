-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Ethernet/IPv6/UDP/ICMPv6 header records for the udp_endpoint. Parsers
-- accumulate header bytes into a shift register and unpack() once at the end
-- of each header; builders pack() a record and serialize with get_byte().
-- Packed layouts put the first byte on the wire in the most significant
-- position, so wire order is a straight high-to-low walk and all multi-byte
-- fields come out big-endian (network order) with no per-field swizzling.
--
-- The endpoint is IPv6-only: its address is the link-local address derived
-- from the MAC (EUI-64), so the address-forming helpers live here too.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package eth_hdr_pkg is

    subtype mac_addr_t is std_logic_vector(47 downto 0);
    subtype ipv6_addr_t is std_logic_vector(127 downto 0);

    constant MAC_BCAST : mac_addr_t := (others => '1');
    -- 33:33:00:00:00:01, the mapping of ff02::1
    constant MAC_ALL_NODES : mac_addr_t := X"333300000001";

    constant IPV6_UNSPECIFIED : ipv6_addr_t := (others => '0');
    -- ff02::1, link-local all-nodes
    constant IPV6_ALL_NODES : ipv6_addr_t := X"FF020000000000000000000000000001";

    constant ETHERTYPE_IPV6 : std_logic_vector(15 downto 0) := X"86DD";

    constant IPPROTO_UDP    : std_logic_vector(7 downto 0) := X"11";
    constant IPPROTO_ICMPV6 : std_logic_vector(7 downto 0) := X"3A";

    -- register value left in crc32_8wide after a frame *including* a valid
    -- FCS has been fed through it
    constant ETH_CRC32_RESIDUE : std_logic_vector(31 downto 0) := X"DEBB20E3";

    -- Ethernet II header, 14 bytes
    type eth_header_t is record
        dst_mac   : mac_addr_t;
        src_mac   : mac_addr_t;
        ethertype : std_logic_vector(15 downto 0);
    end record;
    constant ETH_HEADER_BYTES : natural := 14;
    function pack (h : eth_header_t) return std_logic_vector;
    function unpack_eth_header (d : std_logic_vector(8 * ETH_HEADER_BYTES - 1 downto 0)) return eth_header_t;

    -- IPv6 header, fixed 40 bytes (no options; extension headers are not
    -- accepted by this endpoint)
    type ipv6_header_t is record
        ver_tc_flow : std_logic_vector(31 downto 0);
        payload_len : std_logic_vector(15 downto 0);
        next_header : std_logic_vector(7 downto 0);
        hop_limit   : std_logic_vector(7 downto 0);
        src_ip      : ipv6_addr_t;
        dst_ip      : ipv6_addr_t;
    end record;
    constant IPV6_HEADER_BYTES : natural := 40;
    function pack (h : ipv6_header_t) return std_logic_vector;
    function unpack_ipv6_header (d : std_logic_vector(8 * IPV6_HEADER_BYTES - 1 downto 0)) return ipv6_header_t;

    -- UDP header, 8 bytes
    type udp_header_t is record
        src_port : std_logic_vector(15 downto 0);
        dst_port : std_logic_vector(15 downto 0);
        length   : std_logic_vector(15 downto 0);
        checksum : std_logic_vector(15 downto 0);
    end record;
    constant UDP_HEADER_BYTES : natural := 8;
    function pack (h : udp_header_t) return std_logic_vector;
    function unpack_udp_header (d : std_logic_vector(8 * UDP_HEADER_BYTES - 1 downto 0)) return udp_header_t;

    -- ICMPv6 types this endpoint knows
    constant ICMPV6_ECHO_REQUEST : std_logic_vector(7 downto 0) := X"80";
    constant ICMPV6_ECHO_REPLY   : std_logic_vector(7 downto 0) := X"81";
    constant ICMPV6_NEIGHBOR_SOL : std_logic_vector(7 downto 0) := X"87";
    constant ICMPV6_NEIGHBOR_ADV : std_logic_vector(7 downto 0) := X"88";

    -- NDP option types (RFC 4861)
    constant NDP_OPT_SOURCE_LL : std_logic_vector(7 downto 0) := X"01";
    constant NDP_OPT_TARGET_LL : std_logic_vector(7 downto 0) := X"02";

    -- fe80:: with the EUI-64 interface identifier of the MAC
    function link_local_from_mac (mac : mac_addr_t) return ipv6_addr_t;
    -- ff02::1:ffXX:XXXX for an address's low 24 bits
    function solicited_node (addr : ipv6_addr_t) return ipv6_addr_t;
    -- 33:33 mapping of a multicast address
    function mcast_mac (addr : ipv6_addr_t) return mac_addr_t;
    function is_multicast (addr : ipv6_addr_t) return boolean;

    -- byte idx of a packed header vector, in wire order (byte 0 first)
    function get_byte (v : std_logic_vector; idx : natural) return std_logic_vector;

    -- ones-complement (internet checksum) helpers. RTL accumulates 16-bit
    -- big-endian words into a wide unsigned and folds once at the end.
    function ones_comp_fold (acc : unsigned(31 downto 0)) return std_logic_vector;
    function ones_comp_add (a : std_logic_vector(15 downto 0); b : std_logic_vector(15 downto 0)) return std_logic_vector;
    -- ones-complement sum of a wide big-endian vector (a multiple of 16
    -- bits), for pseudo-header address terms
    function ones_comp_sum (v : std_logic_vector) return unsigned;

end package;

package body eth_hdr_pkg is

    function pack (h : eth_header_t) return std_logic_vector is
    begin
        return h.dst_mac & h.src_mac & h.ethertype;
    end function;

    function unpack_eth_header (d : std_logic_vector(8 * ETH_HEADER_BYTES - 1 downto 0)) return eth_header_t is
        variable h : eth_header_t;
    begin
        h.dst_mac   := d(111 downto 64);
        h.src_mac   := d(63 downto 16);
        h.ethertype := d(15 downto 0);
        return h;
    end function;

    function pack (h : ipv6_header_t) return std_logic_vector is
    begin
        return h.ver_tc_flow & h.payload_len & h.next_header & h.hop_limit &
               h.src_ip & h.dst_ip;
    end function;

    function unpack_ipv6_header (d : std_logic_vector(8 * IPV6_HEADER_BYTES - 1 downto 0)) return ipv6_header_t is
        variable h : ipv6_header_t;
    begin
        h.ver_tc_flow := d(319 downto 288);
        h.payload_len := d(287 downto 272);
        h.next_header := d(271 downto 264);
        h.hop_limit   := d(263 downto 256);
        h.src_ip      := d(255 downto 128);
        h.dst_ip      := d(127 downto 0);
        return h;
    end function;

    function pack (h : udp_header_t) return std_logic_vector is
    begin
        return h.src_port & h.dst_port & h.length & h.checksum;
    end function;

    function unpack_udp_header (d : std_logic_vector(8 * UDP_HEADER_BYTES - 1 downto 0)) return udp_header_t is
        variable h : udp_header_t;
    begin
        h.src_port := d(63 downto 48);
        h.dst_port := d(47 downto 32);
        h.length   := d(31 downto 16);
        h.checksum := d(15 downto 0);
        return h;
    end function;

    function link_local_from_mac (mac : mac_addr_t) return ipv6_addr_t is
        variable a : ipv6_addr_t;
    begin
        a(127 downto 64) := X"FE80000000000000";
        -- EUI-64: universal/local bit inverted, ff:fe in the middle
        a(63 downto 56)  := mac(47 downto 40) xor X"02";
        a(55 downto 40)  := mac(39 downto 24);
        a(39 downto 24)  := X"FFFE";
        a(23 downto 0)   := mac(23 downto 0);
        return a;
    end function;

    function solicited_node (addr : ipv6_addr_t) return ipv6_addr_t is
    begin
        return X"FF0200000000000000000001FF" & addr(23 downto 0);
    end function;

    function mcast_mac (addr : ipv6_addr_t) return mac_addr_t is
    begin
        return X"3333" & addr(31 downto 0);
    end function;

    function is_multicast (addr : ipv6_addr_t) return boolean is
    begin
        return addr(127 downto 120) = X"FF";
    end function;

    function get_byte (v : std_logic_vector; idx : natural) return std_logic_vector is
        -- normalize to a descending range starting at the top
        constant n : std_logic_vector(v'length - 1 downto 0) := v;
    begin
        return n(n'high - 8 * idx downto n'high - 8 * idx - 7);
    end function;

    function ones_comp_fold (acc : unsigned(31 downto 0)) return std_logic_vector is
        variable v : unsigned(31 downto 0) := acc;
    begin
        -- two folds always suffice for a 32-bit accumulator
        v := resize(v(15 downto 0), 32) + resize(v(31 downto 16), 32);
        v := resize(v(15 downto 0), 32) + resize(v(31 downto 16), 32);
        return std_logic_vector(v(15 downto 0));
    end function;

    function ones_comp_add (a : std_logic_vector(15 downto 0); b : std_logic_vector(15 downto 0)) return std_logic_vector is
        variable sum : unsigned(16 downto 0);
    begin
        sum := resize(unsigned(a), 17) + resize(unsigned(b), 17);
        return std_logic_vector(sum(15 downto 0) + resize(sum(16 downto 16), 16));
    end function;

    function ones_comp_sum (v : std_logic_vector) return unsigned is
        constant n : std_logic_vector(v'length - 1 downto 0) := v;
        variable sum : unsigned(31 downto 0) := (others => '0');
    begin
        for i in 0 to v'length / 16 - 1 loop
            sum := sum + resize(unsigned(n(16 * i + 15 downto 16 * i)), 32);
        end loop;
        return sum;
    end function;

end package body;
