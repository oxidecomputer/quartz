-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Testbench-side reference constructors for Ethernet/IPv6/UDP/ICMPv6
-- frames, independent of the RTL implementations: checksums and FCS are
-- computed here the long way so the DUT is checked against a second
-- opinion. Frames are byte queues covering DA..FCS (no preamble; the TB's
-- wire drivers add it).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

use work.eth_hdr_pkg.all;
use work.crc_sim_pkg.all;

package eth_sim_pkg is

    procedure push_u16 (q : queue_t; v : std_logic_vector(15 downto 0));
    procedure push_u32 (q : queue_t; v : std_logic_vector(31 downto 0));
    procedure push_mac (q : queue_t; v : mac_addr_t);
    procedure push_ip6 (q : queue_t; v : ipv6_addr_t);

    -- number of byte elements in a queue (vunit's length() counts internal
    -- storage including type tags, not elements)
    impure function byte_count (data : queue_t) return natural;

    -- ones-complement sum of a byte queue as big-endian 16-bit words (odd
    -- length zero-padded), added to acc; returns the un-complemented sum
    impure function inet_sum (data : queue_t; acc : unsigned(31 downto 0)) return unsigned;

    -- IPv6 pseudo-header sum for an upper-layer length and next header
    function pseudo6_sum (
        src : ipv6_addr_t;
        dst : ipv6_addr_t;
        len : natural;
        nh  : std_logic_vector(7 downto 0)
    ) return unsigned;

    -- append the Ethernet FCS (wire byte order) to a DA..payload queue
    procedure append_fcs (q : queue_t; corrupt : boolean := false);

    -- complete frames, DA..FCS
    impure function build_udp6_frame (
        dst_mac  : mac_addr_t;
        src_mac  : mac_addr_t;
        src_ip   : ipv6_addr_t;
        dst_ip   : ipv6_addr_t;
        src_port : std_logic_vector(15 downto 0);
        dst_port : std_logic_vector(15 downto 0);
        payload  : queue_t
    ) return queue_t;

    -- neighbor solicitation; src_ip = :: and include_sll = false makes a
    -- DAD probe
    impure function build_ns (
        dst_mac     : mac_addr_t;
        src_mac     : mac_addr_t;
        src_ip      : ipv6_addr_t;
        dst_ip      : ipv6_addr_t;
        target      : ipv6_addr_t;
        include_sll : boolean
    ) return queue_t;

    impure function build_echo6 (
        dst_mac : mac_addr_t;
        src_mac : mac_addr_t;
        src_ip  : ipv6_addr_t;
        dst_ip  : ipv6_addr_t;
        ident   : std_logic_vector(15 downto 0);
        seqnum  : std_logic_vector(15 downto 0);
        payload : queue_t
    ) return queue_t;

end package;

package body eth_sim_pkg is

    procedure push_u16 (q : queue_t; v : std_logic_vector(15 downto 0)) is
    begin
        push_byte(q, to_integer(unsigned(v(15 downto 8))));
        push_byte(q, to_integer(unsigned(v(7 downto 0))));
    end procedure;

    procedure push_u32 (q : queue_t; v : std_logic_vector(31 downto 0)) is
    begin
        push_u16(q, v(31 downto 16));
        push_u16(q, v(15 downto 0));
    end procedure;

    procedure push_mac (q : queue_t; v : mac_addr_t) is
    begin
        push_u32(q, v(47 downto 16));
        push_u16(q, v(15 downto 0));
    end procedure;

    procedure push_ip6 (q : queue_t; v : ipv6_addr_t) is
    begin
        push_u32(q, v(127 downto 96));
        push_u32(q, v(95 downto 64));
        push_u32(q, v(63 downto 32));
        push_u32(q, v(31 downto 0));
    end procedure;

    impure function byte_count (data : queue_t) return natural is
        constant q : queue_t := copy(data);
        variable n : natural := 0;
        variable scratch : integer;
    begin
        while not is_empty(q) loop
            scratch := pop_byte(q);
            n := n + 1;
        end loop;
        return n;
    end function;

    impure function inet_sum (data : queue_t; acc : unsigned(31 downto 0)) return unsigned is
        constant q : queue_t := copy(data);
        variable sum : unsigned(31 downto 0) := acc;
        variable hi : natural;
    begin
        while not is_empty(q) loop
            hi := pop_byte(q);
            if is_empty(q) then
                sum := sum + shift_left(to_unsigned(hi, 32), 8);
            else
                sum := sum + shift_left(to_unsigned(hi, 32), 8)
                           + to_unsigned(pop_byte(q), 32);
            end if;
        end loop;
        return sum;
    end function;

    function pseudo6_sum (
        src : ipv6_addr_t;
        dst : ipv6_addr_t;
        len : natural;
        nh  : std_logic_vector(7 downto 0)
    ) return unsigned is
    begin
        return ones_comp_sum(src) + ones_comp_sum(dst)
               + to_unsigned(len, 32) + resize(unsigned(nh), 32);
    end function;

    procedure append_fcs (q : queue_t; corrupt : boolean := false) is
        variable fcs : std_logic_vector(31 downto 0);
    begin
        fcs := crc32_ethernet(q, gen_invalid_crc => corrupt);
        push_byte(q, to_integer(unsigned(fcs(7 downto 0))));
        push_byte(q, to_integer(unsigned(fcs(15 downto 8))));
        push_byte(q, to_integer(unsigned(fcs(23 downto 16))));
        push_byte(q, to_integer(unsigned(fcs(31 downto 24))));
    end procedure;

    -- shared ethernet + IPv6 header prefix
    procedure push_headers (
        q       : queue_t;
        dst_mac : mac_addr_t;
        src_mac : mac_addr_t;
        src_ip  : ipv6_addr_t;
        dst_ip  : ipv6_addr_t;
        plen    : natural;
        nh      : std_logic_vector(7 downto 0);
        hl      : std_logic_vector(7 downto 0)
    ) is
    begin
        push_mac(q, dst_mac);
        push_mac(q, src_mac);
        push_u16(q, ETHERTYPE_IPV6);
        push_u32(q, X"60000000");
        push_u16(q, std_logic_vector(to_unsigned(plen, 16)));
        push_byte(q, to_integer(unsigned(nh)));
        push_byte(q, to_integer(unsigned(hl)));
        push_ip6(q, src_ip);
        push_ip6(q, dst_ip);
    end procedure;

    impure function build_udp6_frame (
        dst_mac  : mac_addr_t;
        src_mac  : mac_addr_t;
        src_ip   : ipv6_addr_t;
        dst_ip   : ipv6_addr_t;
        src_port : std_logic_vector(15 downto 0);
        dst_port : std_logic_vector(15 downto 0);
        payload  : queue_t
    ) return queue_t is
        constant pay : queue_t := copy(payload);
        variable q    : queue_t := new_queue;
        variable ulen : natural;
        variable sum  : unsigned(31 downto 0);
        variable csum : std_logic_vector(15 downto 0);
    begin
        ulen := byte_count(pay) + 8;
        push_headers(q, dst_mac, src_mac, src_ip, dst_ip, ulen, IPPROTO_UDP, X"40");

        sum := pseudo6_sum(src_ip, dst_ip, ulen, IPPROTO_UDP)
               + resize(unsigned(src_port), 32) + resize(unsigned(dst_port), 32)
               + to_unsigned(ulen, 32);
        sum := inet_sum(pay, sum);
        csum := not ones_comp_fold(sum);
        if csum = X"0000" then
            csum := X"FFFF";
        end if;

        push_u16(q, src_port);
        push_u16(q, dst_port);
        push_u16(q, std_logic_vector(to_unsigned(ulen, 16)));
        push_u16(q, csum);
        while not is_empty(pay) loop
            push_byte(q, pop_byte(pay));
        end loop;

        -- frames below the 60-byte minimum are padded like a real MAC would
        while byte_count(q) < 60 loop
            push_byte(q, 0);
        end loop;
        append_fcs(q);
        return q;
    end function;

    impure function build_ns (
        dst_mac     : mac_addr_t;
        src_mac     : mac_addr_t;
        src_ip      : ipv6_addr_t;
        dst_ip      : ipv6_addr_t;
        target      : ipv6_addr_t;
        include_sll : boolean
    ) return queue_t is
        variable q    : queue_t := new_queue;
        variable msg  : queue_t := new_queue;
        variable plen : natural;
        variable csum : std_logic_vector(15 downto 0);
    begin
        if include_sll then
            plen := 32;
        else
            plen := 24;
        end if;

        -- message with zeroed checksum, for the checksum computation
        push_byte(msg, to_integer(unsigned(ICMPV6_NEIGHBOR_SOL)));
        push_byte(msg, 0);
        push_u16(msg, X"0000");
        push_u32(msg, X"00000000");
        push_ip6(msg, target);
        if include_sll then
            push_byte(msg, to_integer(unsigned(NDP_OPT_SOURCE_LL)));
            push_byte(msg, 1);
            push_mac(msg, src_mac);
        end if;
        csum := not ones_comp_fold(
            inet_sum(msg, pseudo6_sum(src_ip, dst_ip, plen, IPPROTO_ICMPV6)));

        push_headers(q, dst_mac, src_mac, src_ip, dst_ip, plen, IPPROTO_ICMPV6, X"FF");
        push_byte(q, to_integer(unsigned(ICMPV6_NEIGHBOR_SOL)));
        push_byte(q, 0);
        push_u16(q, csum);
        push_u32(q, X"00000000");
        push_ip6(q, target);
        if include_sll then
            push_byte(q, to_integer(unsigned(NDP_OPT_SOURCE_LL)));
            push_byte(q, 1);
            push_mac(q, src_mac);
        end if;

        while byte_count(q) < 60 loop
            push_byte(q, 0);
        end loop;
        append_fcs(q);
        return q;
    end function;

    impure function build_echo6 (
        dst_mac : mac_addr_t;
        src_mac : mac_addr_t;
        src_ip  : ipv6_addr_t;
        dst_ip  : ipv6_addr_t;
        ident   : std_logic_vector(15 downto 0);
        seqnum  : std_logic_vector(15 downto 0);
        payload : queue_t
    ) return queue_t is
        constant pay : queue_t := copy(payload);
        variable q    : queue_t := new_queue;
        variable msg  : queue_t := new_queue;
        variable plen : natural;
        variable csum : std_logic_vector(15 downto 0);
        variable scratch : integer;
    begin
        plen := byte_count(pay) + 8;

        push_byte(msg, to_integer(unsigned(ICMPV6_ECHO_REQUEST)));
        push_byte(msg, 0);
        push_u16(msg, X"0000");
        push_u16(msg, ident);
        push_u16(msg, seqnum);
        push_q_copy: while not is_empty(pay) loop
            push_byte(msg, pop_byte(pay));
        end loop;
        csum := not ones_comp_fold(
            inet_sum(msg, pseudo6_sum(src_ip, dst_ip, plen, IPPROTO_ICMPV6)));

        push_headers(q, dst_mac, src_mac, src_ip, dst_ip, plen, IPPROTO_ICMPV6, X"40");
        -- re-emit the message, this time with the checksum, consuming msg
        push_byte(q, pop_byte(msg));   -- type
        push_byte(q, pop_byte(msg));   -- code
        push_u16(q, csum);
        scratch := pop_byte(msg);      -- discard the zeroed checksum
        scratch := pop_byte(msg);
        while not is_empty(msg) loop
            push_byte(q, pop_byte(msg));
        end loop;

        while byte_count(q) < 60 loop
            push_byte(q, 0);
        end loop;
        append_fcs(q);
        return q;
    end function;

end package body;
