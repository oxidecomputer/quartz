-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Walks a validated frame in the eth_frame_rx buffer, fills header records,
-- filters, and dispatches (IPv6 only):
--
--   Neighbor Solicitation for our address -> Neighbor Advertisement (this
--     is the ARP-reply equivalent; DAD probes are answered to all-nodes)
--   ICMPv6 echo to our address           -> echo reply (streamed copy with
--     the checksum bytes zeroed; the builder computes the new checksum,
--     which spans the pseudo-header in ICMPv6)
--   UDP to CLIENT_UDP_PORT               -> payload + metadata to the
--     client, accepted unicast or to all-nodes ff02::1 (discovery)
--   anything else                        -> dropped
--
-- Every accepted frame also teaches the sender's IP->MAC pairing to the
-- endpoint's answer cache (from the NDP source link-layer option when
-- present, else the Ethernet source), which is what lets the endpoint
-- reply without ever soliciting neighbors itself.
--
-- Deliberate corner cuts (this is a management tap, not a full stack):
-- no extension headers (next header must be UDP or ICMPv6), no fragments,
-- L4 receive checksums are not verified (the FCS already gated the frame),
-- only the first NDP option is examined, hop-limit-255 validation of NDP is
-- skipped, and only all-nodes multicast is honored for UDP. The byte walk
-- takes three cycles per byte through the synchronous buffer port --
-- capture is stop-and-wait anyway, so decode speed only widens the
-- (documented, retry-covered) busy window.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;

entity eth_rx_parse is
    generic (
        CLIENT_UDP_PORT : std_logic_vector(15 downto 0);
        ADDR_BITS       : positive := 11
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- captured frame (eth_frame_rx)
        frame_valid : in    std_logic;
        frame_len   : in    unsigned(10 downto 0);
        frame_taken : out   std_logic;
        rd_addr     : out   unsigned(ADDR_BITS - 1 downto 0);
        rd_data     : in    std_logic_vector(7 downto 0);

        -- who we are
        our_mac  : in    mac_addr_t;
        our_ip   : in    ipv6_addr_t;
        ip_valid : in    std_logic;

        -- IP->MAC pairings observed in accepted frames
        learn_valid : out   std_logic;
        learn_ip    : out   ipv6_addr_t;
        learn_mac   : out   mac_addr_t;

        -- client datagram delivery
        client_rx       : out   udp_st_t;
        client_rx_meta  : out   udp_rx_meta_t;
        client_rx_ready : in    std_logic;

        -- frame builder (NA / echo responses)
        tx_req      : out   std_logic;
        tx_hdr      : out   frame_tx_hdr_t;
        tx_grant    : in    std_logic;
        tx_st       : out   udp_st_t;
        tx_st_ready : in    std_logic
    );
end entity;

architecture rtl of eth_rx_parse is

    type state_t is (IDLE, C_ETH, C_IP6, C_ICMP, C_NS, C_NSOPT,
                     NA_REQ, NA_STREAM,
                     ICMP_REQ, ICMP_PATCH, ICMP_COPY,
                     C_UDP, STREAM_PAY, DONE, WAIT_CLEAR);
    signal state : state_t := IDLE;

    -- 3-phase synchronous-read walk: set address, wait, consume
    signal sub  : natural range 0 to 2 := 0;
    signal bidx : unsigned(10 downto 0) := (others => '0');
    signal scnt : natural range 0 to 63 := 0;

    signal shreg : std_logic_vector(8 * IPV6_HEADER_BYTES - 1 downto 0) := (others => '0');

    signal eth_h : eth_header_t;
    signal ip_h  : ipv6_header_t;
    signal udp_h : udp_header_t;

    signal icmp_code : std_logic_vector(7 downto 0) := (others => '0');

    signal pay_len  : unsigned(10 downto 0) := (others => '0');
    signal pay_left : unsigned(10 downto 0) := (others => '0');

    -- NDP scratch
    signal sll_mac  : mac_addr_t := (others => '0');
    signal have_sll : std_logic := '0';
    signal opt_left : unsigned(10 downto 0) := (others => '0');
    signal na_flags : std_logic_vector(7 downto 0) := (others => '0');

    signal out_st  : udp_st_t := UDP_ST_IDLE;
    signal out_rdy : std_logic;
    signal meta_r  : udp_rx_meta_t;

    signal hdr_r : frame_tx_hdr_t := FRAME_TX_HDR_IDLE;

    signal na_pack : std_logic_vector(255 downto 0);

    constant NA_BYTES : natural := 32;
    constant L4_OFF   : natural := ETH_HEADER_BYTES + IPV6_HEADER_BYTES;   -- 54
    constant PAY_OFF  : natural := L4_OFF + UDP_HEADER_BYTES;              -- 62

begin

    tx_hdr <= hdr_r;

    -- neighbor advertisement: type, code, zeroed checksum (the builder
    -- fills it), flags, reserved, target = our address, TLL option
    na_pack <= ICMPV6_NEIGHBOR_ADV & X"00" & X"0000" &
               na_flags & X"000000" &
               our_ip &
               NDP_OPT_TARGET_LL & X"01" & our_mac;

    -- one mux serves whichever destination the current payload goes to
    client_rx <= out_st when state = STREAM_PAY else UDP_ST_IDLE;
    tx_st     <= out_st when state = NA_STREAM or state = ICMP_PATCH or state = ICMP_COPY else UDP_ST_IDLE;
    out_rdy   <= tx_st_ready when state = NA_STREAM or state = ICMP_PATCH or state = ICMP_COPY else
                 client_rx_ready;

    client_rx_meta <= meta_r;

    parse_proc: process (clk, reset) is
        variable b : std_logic_vector(7 downto 0);
        variable v_eth : eth_header_t;
        variable v_ip  : ipv6_header_t;
        variable v_udp : udp_header_t;
        variable nshreg : std_logic_vector(shreg'range);
        variable v_target : ipv6_addr_t;
    begin
        if reset = '1' then
            state       <= IDLE;
            sub         <= 0;
            bidx        <= (others => '0');
            scnt        <= 0;
            frame_taken <= '0';
            learn_valid <= '0';
            out_st      <= UDP_ST_IDLE;
            tx_req      <= '0';
            rd_addr     <= (others => '0');
        elsif rising_edge(clk) then
            frame_taken <= '0';
            learn_valid <= '0';

            case state is
                when IDLE =>
                    sub  <= 0;
                    scnt <= 0;
                    bidx <= (others => '0');
                    out_st <= UDP_ST_IDLE;
                    if frame_valid = '1' then
                        state <= C_ETH;
                    end if;

                -- generic 3-phase byte fetch: sub 0 sets the address, sub 1
                -- covers the synchronous read, sub 2 consumes rd_data
                when C_ETH | C_IP6 | C_ICMP | C_NS | C_NSOPT | C_UDP =>
                    if sub = 0 then
                        rd_addr <= resize(bidx, ADDR_BITS);
                        sub <= 1;
                    elsif sub = 1 then
                        sub <= 2;
                    else
                        b := rd_data;
                        nshreg := shreg(shreg'high - 8 downto 0) & b;
                        shreg <= nshreg;
                        bidx  <= bidx + 1;
                        sub   <= 0;

                        if state = C_ETH and scnt = ETH_HEADER_BYTES - 1 then
                            v_eth := unpack_eth_header(nshreg(8 * ETH_HEADER_BYTES - 1 downto 0));
                            eth_h <= v_eth;
                            scnt  <= 0;
                            if v_eth.dst_mac /= our_mac and
                               v_eth.dst_mac /= MAC_ALL_NODES and
                               v_eth.dst_mac /= mcast_mac(solicited_node(our_ip)) then
                                state <= DONE;
                            elsif v_eth.ethertype = ETHERTYPE_IPV6 and ip_valid = '1' then
                                state <= C_IP6;
                            else
                                state <= DONE;
                            end if;

                        elsif state = C_IP6 and scnt = IPV6_HEADER_BYTES - 1 then
                            v_ip := unpack_ipv6_header(nshreg);
                            ip_h <= v_ip;
                            scnt <= 0;
                            if v_ip.ver_tc_flow(31 downto 28) /= X"6" or
                               unsigned(v_ip.payload_len) >
                               resize(frame_len, 16) - ETH_HEADER_BYTES - IPV6_HEADER_BYTES then
                                state <= DONE;
                            elsif v_ip.next_header = IPPROTO_ICMPV6 then
                                if unsigned(v_ip.payload_len) >= 4 then
                                    state <= C_ICMP;
                                else
                                    state <= DONE;
                                end if;
                            elsif v_ip.next_header = IPPROTO_UDP then
                                state <= C_UDP;
                            else
                                state <= DONE;
                            end if;

                        elsif state = C_ICMP and scnt = 3 then
                            -- type, code, checksum collected (checksum is
                            -- not verified; it is regenerated on the reply)
                            scnt <= 0;
                            icmp_code <= nshreg(23 downto 16);
                            if nshreg(31 downto 24) = ICMPV6_ECHO_REQUEST and
                               nshreg(23 downto 16) = X"00" and
                               ip_h.dst_ip = our_ip and
                               unsigned(ip_h.payload_len) >= 8 and
                               unsigned(ip_h.payload_len) <= 400 then
                                -- upper bound keeps the echo inside the
                                -- 512-byte response buffer; huge pings are
                                -- simply not answered
                                learn_valid <= '1';
                                learn_ip    <= ip_h.src_ip;
                                learn_mac   <= eth_h.src_mac;
                                hdr_r <= (
                                    kind     => FRAME_IPV6_ICMP,
                                    dst_mac  => eth_h.src_mac,
                                    dst_ip   => ip_h.src_ip,
                                    src_ip   => our_ip,
                                    dst_port => (others => '0'),
                                    src_port => (others => '0'));
                                pay_left <= resize(unsigned(ip_h.payload_len), 11) - 4;
                                tx_req <= '1';
                                state  <= ICMP_REQ;
                            elsif nshreg(31 downto 24) = ICMPV6_NEIGHBOR_SOL and
                                  nshreg(23 downto 16) = X"00" and
                                  (ip_h.dst_ip = our_ip or
                                   ip_h.dst_ip = solicited_node(our_ip)) and
                                  unsigned(ip_h.payload_len) >= 24 then
                                have_sll <= '0';
                                opt_left <= resize(unsigned(ip_h.payload_len), 11) - 24;
                                state    <= C_NS;
                            else
                                state <= DONE;
                            end if;

                        elsif state = C_NS and scnt = 19 then
                            -- 4 reserved bytes then the 16-byte target
                            v_target := nshreg(127 downto 0);
                            scnt <= 0;
                            if v_target /= our_ip then
                                state <= DONE;
                            elsif opt_left >= 8 then
                                state <= C_NSOPT;
                            else
                                state <= NA_REQ;
                            end if;

                        elsif state = C_NSOPT and scnt = 7 then
                            -- first option only; a host's solicitation
                            -- carries its source link-layer address here
                            scnt <= 0;
                            if nshreg(63 downto 56) = NDP_OPT_SOURCE_LL and
                               nshreg(55 downto 48) = X"01" then
                                sll_mac  <= nshreg(47 downto 0);
                                have_sll <= '1';
                            end if;
                            state <= NA_REQ;

                        elsif state = C_UDP and scnt = UDP_HEADER_BYTES - 1 then
                            v_udp := unpack_udp_header(nshreg(8 * UDP_HEADER_BYTES - 1 downto 0));
                            udp_h <= v_udp;
                            scnt  <= 0;
                            if unsigned(v_udp.length) < UDP_HEADER_BYTES or
                               resize(unsigned(v_udp.length), 16) >
                               unsigned(ip_h.payload_len) then
                                state <= DONE;
                            elsif v_udp.dst_port = CLIENT_UDP_PORT and
                                  (ip_h.dst_ip = our_ip or
                                   ip_h.dst_ip = IPV6_ALL_NODES) then
                                learn_valid <= '1';
                                learn_ip    <= ip_h.src_ip;
                                learn_mac   <= eth_h.src_mac;
                                pay_len  <= resize(unsigned(v_udp.length), 11) - UDP_HEADER_BYTES;
                                pay_left <= resize(unsigned(v_udp.length), 11) - UDP_HEADER_BYTES;
                                bidx     <= to_unsigned(PAY_OFF, 11);
                                meta_r   <= (
                                    src_ip   => ip_h.src_ip,
                                    src_port => v_udp.src_port,
                                    dst_port => v_udp.dst_port,
                                    length   => resize(unsigned(v_udp.length), 11) - UDP_HEADER_BYTES);
                                state <= STREAM_PAY;
                            else
                                state <= DONE;
                            end if;
                        else
                            scnt <= scnt + 1;
                        end if;
                    end if;

                -- build the neighbor advertisement header/addressing; a DAD
                -- probe (unspecified source) is answered to all-nodes with
                -- the solicited flag clear, anything else unicast back
                -- header registers settle at least a cycle before the
                -- builder can latch them (grant lags the request)
                when NA_REQ =>
                    tx_req <= '1';
                    if ip_h.src_ip = IPV6_UNSPECIFIED then
                        na_flags <= X"20";               -- override only
                        hdr_r <= (
                            kind     => FRAME_IPV6_ICMP,
                            dst_mac  => MAC_ALL_NODES,
                            dst_ip   => IPV6_ALL_NODES,
                            src_ip   => our_ip,
                            dst_port => (others => '0'),
                            src_port => (others => '0'));
                    else
                        na_flags <= X"60";               -- solicited + override
                        learn_valid <= '1';
                        learn_ip    <= ip_h.src_ip;
                        if have_sll = '1' then
                            learn_mac <= sll_mac;
                        else
                            learn_mac <= eth_h.src_mac;
                        end if;
                        if have_sll = '1' then
                            hdr_r.dst_mac <= sll_mac;
                        else
                            hdr_r.dst_mac <= eth_h.src_mac;
                        end if;
                        hdr_r.kind     <= FRAME_IPV6_ICMP;
                        hdr_r.dst_ip   <= ip_h.src_ip;
                        hdr_r.src_ip   <= our_ip;
                        hdr_r.dst_port <= (others => '0');
                        hdr_r.src_port <= (others => '0');
                    end if;
                    if tx_grant = '1' then
                        tx_req <= '0';
                        scnt   <= 0;
                        state  <= NA_STREAM;
                    end if;

                when NA_STREAM =>
                    if out_st.valid = '0' then
                        out_st.data  <= get_byte(na_pack, scnt);
                        out_st.valid <= '1';
                        if scnt = NA_BYTES - 1 then
                            out_st.last <= '1';
                        end if;
                    elsif out_rdy = '1' then
                        out_st <= UDP_ST_IDLE;
                        if scnt = NA_BYTES - 1 then
                            state <= DONE;
                        else
                            scnt <= scnt + 1;
                        end if;
                    end if;

                when ICMP_REQ =>
                    if tx_grant = '1' then
                        tx_req <= '0';
                        scnt   <= 0;
                        state  <= ICMP_PATCH;
                    end if;

                -- first four ICMPv6 bytes of the reply: type, copied code,
                -- and a zeroed checksum for the builder to fill (the ICMPv6
                -- checksum spans the pseudo-header, which only the builder
                -- knows in full)
                when ICMP_PATCH =>
                    if out_st.valid = '0' then
                        case scnt is
                            when 0 => out_st.data <= ICMPV6_ECHO_REPLY;
                            when 1 => out_st.data <= icmp_code;
                            when others => out_st.data <= X"00";
                        end case;
                        out_st.valid <= '1';
                    elsif out_rdy = '1' then
                        out_st <= UDP_ST_IDLE;
                        if scnt = 3 then
                            bidx  <= to_unsigned(L4_OFF + 4, 11);
                            sub   <= 0;
                            state <= ICMP_COPY;
                        else
                            scnt <= scnt + 1;
                        end if;
                    end if;

                when ICMP_COPY =>
                    if sub = 0 then
                        rd_addr <= resize(bidx, ADDR_BITS);
                        sub <= 1;
                    elsif sub = 1 then
                        sub <= 2;
                    else
                        if out_st.valid = '0' then
                            out_st.data  <= rd_data;
                            out_st.valid <= '1';
                            if pay_left = 1 then
                                out_st.last <= '1';
                            end if;
                        elsif out_rdy = '1' then
                            out_st <= UDP_ST_IDLE;
                            bidx   <= bidx + 1;
                            sub    <= 0;
                            if pay_left = 1 then
                                state <= DONE;
                            else
                                pay_left <= pay_left - 1;
                            end if;
                        end if;
                    end if;

                when STREAM_PAY =>
                    if pay_left = 0 then
                        -- zero-length datagram: deliver nothing
                        state <= DONE;
                    elsif sub = 0 then
                        rd_addr <= resize(bidx, ADDR_BITS);
                        sub <= 1;
                    elsif sub = 1 then
                        sub <= 2;
                    else
                        if out_st.valid = '0' then
                            out_st.data  <= rd_data;
                            out_st.valid <= '1';
                            if pay_left = 1 then
                                out_st.last <= '1';
                            end if;
                        elsif out_rdy = '1' then
                            out_st <= UDP_ST_IDLE;
                            bidx   <= bidx + 1;
                            sub    <= 0;
                            if pay_left = 1 then
                                state <= DONE;
                            else
                                pay_left <= pay_left - 1;
                            end if;
                        end if;
                    end if;

                when DONE =>
                    out_st      <= UDP_ST_IDLE;
                    tx_req      <= '0';
                    frame_taken <= '1';
                    state       <= WAIT_CLEAR;

                -- frame_valid takes a cycle to fall after frame_taken; going
                -- straight to IDLE would parse the same frame twice
                when WAIT_CLEAR =>
                    if frame_valid = '0' then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

end architecture;
