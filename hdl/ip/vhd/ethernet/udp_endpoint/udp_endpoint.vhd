-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Reusable minimal IPv6 network endpoint: receives frames from the r2g tap,
-- answers Neighbor Solicitation and ICMPv6 echo itself, and hands UDP
-- datagrams on CLIENT_UDP_PORT to an attached protocol block through a
-- generic stream+metadata interface (see udp_endpoint_pkg). The client
-- needs no knowledge of addresses, headers, or checksums; its transmit
-- datagrams are wrapped, checksummed and injected here.
--
-- The address is the link-local address derived from the MAC (EUI-64), so
-- there is no acquisition protocol at all: the endpoint is reachable as
-- soon as the MAC is settled (ip_valid = mac_valid). Discovery works by
-- sending to all-nodes multicast ff02::1, which is always accepted on the
-- client port.
--
-- Outbound addressing never solicits neighbors: a 4-entry cache learns
-- IP->MAC pairings from accepted inbound frames (every request teaches the
-- responder its answer path), multicast destinations map algorithmically
-- to 33:33: MACs, and a datagram to an unknown unicast address is silently
-- discarded -- the peer's retry re-teaches the cache.
--
-- The single frame builder is shared by the NDP/echo responder (in the
-- parser) and the client TX path, in that fixed priority; everything here
-- is stop-and-wait so contention just serializes.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;

entity udp_endpoint is
    generic (
        CLIENT_UDP_PORT : std_logic_vector(15 downto 0)
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- identity (MAC arrives from flash/defaults via the mgmt block)
        our_mac   : in    mac_addr_t;
        mac_valid : in    std_logic;

        -- deduplicated tap of the RGMII RX stream (r2g_expander byte_pop)
        tap_data : in    std_logic_vector(7 downto 0);
        tap_er   : in    std_logic;
        tap_dv   : in    std_logic;
        tap_pop  : in    std_logic;

        -- response frames to g2r_inject_mux
        inj_valid   : out   std_logic;
        inj_len     : out   unsigned(10 downto 0);
        inj_done    : in    std_logic;
        inj_rd_addr : in    unsigned(8 downto 0);
        inj_rd_data : out   std_logic_vector(7 downto 0);

        status : out   endpoint_status_t;

        -- client datagram interface
        client_rx       : out   udp_st_t;
        client_rx_meta  : out   udp_rx_meta_t;
        client_rx_ready : in    std_logic;
        client_tx       : in    udp_st_t;
        client_tx_meta  : in    udp_tx_meta_t;
        client_tx_ready : out   std_logic
    );
end entity;

architecture rtl of udp_endpoint is

    signal our_ip   : ipv6_addr_t;
    signal ip_valid : std_logic;

    -- frame rx <-> parser
    signal frame_valid : std_logic;
    signal frame_len   : unsigned(10 downto 0);
    signal frame_taken : std_logic;
    signal rx_rd_addr  : unsigned(10 downto 0);
    signal rx_rd_data  : std_logic_vector(7 downto 0);

    -- learn/cache
    signal learn_valid : std_logic;
    signal learn_ip    : ipv6_addr_t;
    signal learn_mac   : mac_addr_t;

    type cache_entry_t is record
        ip    : ipv6_addr_t;
        mac   : mac_addr_t;
        valid : std_logic;
    end record;
    type cache_t is array (0 to 3) of cache_entry_t;
    signal cache  : cache_t := (others => (ip => (others => '0'),
                                           mac => (others => '0'),
                                           valid => '0'));
    signal cache_wr : natural range 0 to 3 := 0;

    signal lookup_hit : std_logic;
    signal lookup_mac : mac_addr_t;

    -- builder and its two requesters
    signal b_req, b_grant : std_logic;
    signal b_hdr          : frame_tx_hdr_t;
    signal b_st           : udp_st_t;
    signal b_st_ready     : std_logic;

    signal p_req   : std_logic;
    signal p_hdr   : frame_tx_hdr_t;
    signal p_st    : udp_st_t;
    signal p_grant : std_logic;
    signal p_ready : std_logic;

    signal c_req   : std_logic;
    signal c_hdr   : frame_tx_hdr_t;
    signal c_grant : std_logic;
    signal c_ready : std_logic;

    type owner_t is (O_NONE, O_PARSER, O_CLIENT);
    signal owner      : owner_t := O_NONE;
    signal seen_grant : std_logic := '0';

    -- client tx resolution
    type ct_state_t is (CT_IDLE, CT_REQ, CT_STREAM, CT_SINK);
    signal ct : ct_state_t := CT_IDLE;
    signal ct_dst_mac : mac_addr_t := (others => '0');

begin

    -- the whole address story: link-local, straight from the MAC
    our_ip   <= link_local_from_mac(our_mac);
    ip_valid <= mac_valid;

    status <= (ip => our_ip, ip_valid => ip_valid);

    frame_rx: entity work.eth_frame_rx
        generic map (
            ADDR_BITS => 11
        )
        port map (
            clk         => clk,
            reset       => reset,
            tap_data    => tap_data,
            tap_er      => tap_er,
            tap_dv      => tap_dv,
            tap_pop     => tap_pop,
            frame_valid => frame_valid,
            frame_len   => frame_len,
            frame_taken => frame_taken,
            rd_addr     => rx_rd_addr,
            rd_data     => rx_rd_data
        );

    parser: entity work.eth_rx_parse
        generic map (
            CLIENT_UDP_PORT => CLIENT_UDP_PORT,
            ADDR_BITS       => 11
        )
        port map (
            clk             => clk,
            reset           => reset,
            frame_valid     => frame_valid,
            frame_len       => frame_len,
            frame_taken     => frame_taken,
            rd_addr         => rx_rd_addr,
            rd_data         => rx_rd_data,
            our_mac         => our_mac,
            our_ip          => our_ip,
            ip_valid        => ip_valid,
            learn_valid     => learn_valid,
            learn_ip        => learn_ip,
            learn_mac       => learn_mac,
            client_rx       => client_rx,
            client_rx_meta  => client_rx_meta,
            client_rx_ready => client_rx_ready,
            tx_req          => p_req,
            tx_hdr          => p_hdr,
            tx_grant        => p_grant,
            tx_st           => p_st,
            tx_st_ready     => p_ready
        );

    builder: entity work.eth_frame_tx
        generic map (
            ADDR_BITS => 9
        )
        port map (
            clk         => clk,
            reset       => reset,
            our_mac     => our_mac,
            req         => b_req,
            hdr         => b_hdr,
            grant       => b_grant,
            st          => b_st,
            st_ready    => b_st_ready,
            inj_valid   => inj_valid,
            inj_len     => inj_len,
            inj_done    => inj_done,
            inj_rd_addr => inj_rd_addr,
            inj_rd_data => inj_rd_data
        );

    -- ---- IP->MAC answer cache ---------------------------------------------
    cache_proc: process (clk, reset) is
        variable matched : boolean;
    begin
        if reset = '1' then
            for i in cache'range loop
                cache(i).valid <= '0';
            end loop;
            cache_wr <= 0;
        elsif rising_edge(clk) then
            if learn_valid = '1' then
                matched := false;
                for i in cache'range loop
                    if cache(i).valid = '1' and cache(i).ip = learn_ip then
                        cache(i).mac <= learn_mac;
                        matched := true;
                    end if;
                end loop;
                if not matched then
                    cache(cache_wr).ip    <= learn_ip;
                    cache(cache_wr).mac   <= learn_mac;
                    cache(cache_wr).valid <= '1';
                    if cache_wr = 3 then
                        cache_wr <= 0;
                    else
                        cache_wr <= cache_wr + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    lookup_proc: process (all) is
    begin
        lookup_hit <= '0';
        lookup_mac <= (others => '0');
        for i in cache'range loop
            if cache(i).valid = '1' and cache(i).ip = client_tx_meta.dst_ip then
                lookup_hit <= '1';
                lookup_mac <= cache(i).mac;
            end if;
        end loop;
    end process;

    -- ---- client TX: resolve, then hand the stream to the builder ----------
    ct_proc: process (clk, reset) is
    begin
        if reset = '1' then
            ct <= CT_IDLE;
            ct_dst_mac <= (others => '0');
        elsif rising_edge(clk) then
            case ct is
                when CT_IDLE =>
                    if client_tx.valid = '1' then
                        if is_multicast(client_tx_meta.dst_ip) then
                            ct_dst_mac <= mcast_mac(client_tx_meta.dst_ip);
                            ct <= CT_REQ;
                        elsif lookup_hit = '1' then
                            ct_dst_mac <= lookup_mac;
                            ct <= CT_REQ;
                        else
                            -- unknown unicast destination: discard; the
                            -- peer's retry re-teaches the cache
                            ct <= CT_SINK;
                        end if;
                    end if;

                when CT_REQ =>
                    if c_grant = '1' then
                        ct <= CT_STREAM;
                    end if;

                when CT_STREAM =>
                    if client_tx.valid = '1' and c_ready = '1' and client_tx.last = '1' then
                        ct <= CT_IDLE;
                    end if;

                when CT_SINK =>
                    if client_tx.valid = '1' and client_tx.last = '1' then
                        ct <= CT_IDLE;
                    end if;
            end case;
        end if;
    end process;

    c_req <= '1' when ct = CT_REQ else '0';
    c_hdr <= (
        kind     => FRAME_IPV6_UDP,
        dst_mac  => ct_dst_mac,
        dst_ip   => client_tx_meta.dst_ip,
        src_ip   => our_ip,
        dst_port => client_tx_meta.dst_port,
        src_port => client_tx_meta.src_port);

    client_tx_ready <= c_ready when ct = CT_STREAM else
                       '1' when ct = CT_SINK else
                       '0';

    -- ---- builder arbitration: parser > client -----------------------------
    arb_proc: process (clk, reset) is
    begin
        if reset = '1' then
            owner      <= O_NONE;
            seen_grant <= '0';
        elsif rising_edge(clk) then
            case owner is
                when O_NONE =>
                    seen_grant <= '0';
                    if p_req = '1' then
                        owner <= O_PARSER;
                    elsif c_req = '1' then
                        owner <= O_CLIENT;
                    end if;

                when others =>
                    if b_grant = '1' then
                        seen_grant <= '1';
                    elsif seen_grant = '1' then
                        -- build finished (grant fell); the frame is now the
                        -- injector's problem
                        owner      <= O_NONE;
                        seen_grant <= '0';
                    end if;
            end case;
        end if;
    end process;

    b_req <= p_req when owner = O_PARSER else
             c_req when owner = O_CLIENT else
             '0';
    b_hdr <= p_hdr when owner = O_PARSER else
             c_hdr;
    b_st  <= p_st when owner = O_PARSER else
             client_tx when owner = O_CLIENT and ct = CT_STREAM else
             UDP_ST_IDLE;

    p_grant <= b_grant when owner = O_PARSER else '0';
    c_grant <= b_grant when owner = O_CLIENT else '0';

    p_ready <= b_st_ready when owner = O_PARSER else '0';
    c_ready <= b_st_ready when owner = O_CLIENT else '0';

end architecture;
