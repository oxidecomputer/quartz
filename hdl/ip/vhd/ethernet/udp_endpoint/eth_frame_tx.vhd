-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Response frame builder. A requester presents a frame_tx_hdr_t and streams
-- a payload; this block serializes Ethernet and IPv6 headers from the packed
-- records into a small buffer, absorbs the payload, then patches the fields
-- it could not know up front: payload length is discovered from the stream's
-- last marker, so headers are first written with zero length/checksum while
-- a ones-complement accumulator runs, and a few small patch writes finish
-- the frame. The completed frame (DA..payload, no preamble/FCS --
-- g2r_inject_mux adds those) is then offered to the injector.
--
-- IPv6 has no header checksum, but both L4 checksums cover the
-- pseudo-header, so the builder owns checksum generation for UDP *and*
-- ICMPv6: an ICMPv6 requester streams its message with the checksum bytes
-- (offsets 2-3) zeroed and the builder patches the real value in. A
-- computed UDP checksum of 0x0000 is sent as 0xFFFF per RFC 768; for ICMPv6
-- zero is transmitted as-is (RFC 4443 has no such rule). The hop limit is
-- 255 for ICMPv6 -- NDP receivers require it -- and 64 for UDP.
--
-- The checksum is folded in over the patch cycles rather than computed in
-- one expression: summing two 128-bit addresses plus the payload
-- accumulator combinationally is a ~24-level carry tree that misses 8 ns
-- on slower parts. The address halves of the pseudo-header sum are
-- free-running pipeline registers off hdr_r (stable dozens of cycles
-- before use), the grand total registers during P_PLEN_HI, and the folded
-- complement registers during P_PLEN_LO -- one cycle before the earliest
-- state that writes it into the frame.
--
-- The read port is combinational (LUTRAM-sized buffer) because the injector
-- consumes one byte per clock at 1000M with no room for read latency.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;

entity eth_frame_tx is
    generic (
        ADDR_BITS : positive := 9    -- 512-byte response buffer
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        our_mac : in    mac_addr_t;

        -- requester side (one at a time; arbitration happens upstream)
        req      : in    std_logic;
        hdr      : in    frame_tx_hdr_t;
        grant    : out   std_logic;
        st       : in    udp_st_t;
        st_ready : out   std_logic;

        -- injector side
        inj_valid   : out   std_logic;
        inj_len     : out   unsigned(10 downto 0);
        inj_done    : in    std_logic;
        inj_rd_addr : in    unsigned(ADDR_BITS - 1 downto 0);
        inj_rd_data : out   std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of eth_frame_tx is

    type mem_t is array (0 to 2 ** ADDR_BITS - 1) of std_logic_vector(7 downto 0);
    signal mem : mem_t;
    -- Single synchronous write port, asynchronous read: distributed RAM.
    -- Every write in the state machine funnels through one (we, addr,
    -- data) trio at the bottom of the process -- synthesis dissolves an
    -- array with textually separate constant-index writes into thousands
    -- of flip-flops, attribute or no attribute.
    attribute ram_style : string;
    attribute ram_style of mem : signal is "distributed";

    type state_t is (IDLE, WR_ETH, WR_IP6, WR_UDP, PAYLOAD,
                     P_PLEN_HI, P_PLEN_LO,
                     P_ULEN_HI, P_ULEN_LO, P_USUM_HI, P_USUM_LO,
                     P_ICSUM_HI, P_ICSUM_LO,
                     READY);
    signal state : state_t := IDLE;

    signal hdr_r : frame_tx_hdr_t := FRAME_TX_HDR_IDLE;

    signal wr_ptr  : unsigned(ADDR_BITS - 1 downto 0) := (others => '0');
    signal idx     : natural range 0 to 63 := 0;
    signal pay_cnt : unsigned(10 downto 0) := (others => '0');

    signal pay_sum : unsigned(31 downto 0) := (others => '0');

    signal eth_pack : std_logic_vector(8 * ETH_HEADER_BYTES - 1 downto 0);
    signal ip6_pack : std_logic_vector(8 * IPV6_HEADER_BYTES - 1 downto 0);
    signal udp_pack : std_logic_vector(8 * UDP_HEADER_BYTES - 1 downto 0);

    signal udp_len  : unsigned(15 downto 0);
    signal ip6_plen : unsigned(15 downto 0);
    signal nh       : std_logic_vector(7 downto 0);
    signal hl       : std_logic_vector(7 downto 0);

    -- checksum pipeline (see header comment)
    signal src_sum_r  : unsigned(31 downto 0) := (others => '0');
    signal dst_sum_r  : unsigned(31 downto 0) := (others => '0');
    signal addr_sum_r : unsigned(31 downto 0) := (others => '0');
    signal l4_extra   : unsigned(31 downto 0);
    signal l4_sum     : unsigned(31 downto 0) := (others => '0');
    signal csum_r     : std_logic_vector(15 downto 0) := (others => '0');

    constant IP_OFF : natural := ETH_HEADER_BYTES;                       -- 14
    constant L4_OFF : natural := ETH_HEADER_BYTES + IPV6_HEADER_BYTES;   -- 54

begin

    inj_rd_data <= mem(to_integer(inj_rd_addr));

    grant    <= '1' when state /= IDLE and state /= READY else '0';
    st_ready <= '1' when state = PAYLOAD else '0';

    inj_valid <= '1' when state = READY else '0';

    -- combinational so it is coherent from the first READY cycle on
    inj_len <= resize(ip6_plen(10 downto 0), 11) + ETH_HEADER_BYTES + IPV6_HEADER_BYTES;

    udp_len  <= resize(pay_cnt, 16) + UDP_HEADER_BYTES;
    ip6_plen <= udp_len when hdr_r.kind = FRAME_IPV6_UDP else
                resize(pay_cnt, 16);

    -- the non-address, non-payload pseudo-header terms: for UDP the length
    -- twice (pseudo-header and UDP header), protocol, and the ports; for
    -- ICMPv6 just the length and protocol
    l4_extra <= resize(udp_len, 32) + resize(udp_len, 32)
                + resize(unsigned(IPPROTO_UDP), 32)
                + resize(unsigned(hdr_r.src_port), 32)
                + resize(unsigned(hdr_r.dst_port), 32)
                    when hdr_r.kind = FRAME_IPV6_UDP else
                resize(ip6_plen, 32) + resize(unsigned(IPPROTO_ICMPV6), 32);

    build_proc: process (clk, reset) is
        variable b : std_logic_vector(7 downto 0);
        variable folded : std_logic_vector(15 downto 0);
        -- the one write port (see the ram_style note above)
        variable v_we   : std_logic;
        variable v_addr : unsigned(ADDR_BITS - 1 downto 0);
        variable v_data : std_logic_vector(7 downto 0);
    begin
        if reset = '1' then
            state   <= IDLE;
            hdr_r   <= FRAME_TX_HDR_IDLE;
            wr_ptr  <= (others => '0');
            idx     <= 0;
            pay_cnt <= (others => '0');
            pay_sum <= (others => '0');
        elsif rising_edge(clk) then
            -- free-running pseudo-header address pipeline: hdr_r is stable
            -- from IDLE until the frame is done, so these have settled long
            -- before P_PLEN_HI samples addr_sum_r
            src_sum_r  <= ones_comp_sum(hdr_r.src_ip);
            dst_sum_r  <= ones_comp_sum(hdr_r.dst_ip);
            addr_sum_r <= src_sum_r + dst_sum_r;

            v_we   := '0';
            v_addr := (others => '0');
            v_data := (others => '0');

            case state is
                when IDLE =>
                    wr_ptr  <= (others => '0');
                    idx     <= 0;
                    pay_cnt <= (others => '0');
                    pay_sum <= (others => '0');
                    if req = '1' then
                        hdr_r <= hdr;
                        state <= WR_ETH;
                    end if;

                when WR_ETH =>
                    b := get_byte(eth_pack, idx);
                    v_we := '1'; v_addr := wr_ptr; v_data := b;
                    wr_ptr <= wr_ptr + 1;
                    if idx = ETH_HEADER_BYTES - 1 then
                        idx <= 0;
                        state <= WR_IP6;
                    else
                        idx <= idx + 1;
                    end if;

                when WR_IP6 =>
                    b := get_byte(ip6_pack, idx);
                    v_we := '1'; v_addr := wr_ptr; v_data := b;
                    wr_ptr <= wr_ptr + 1;
                    if idx = IPV6_HEADER_BYTES - 1 then
                        idx <= 0;
                        if hdr_r.kind = FRAME_IPV6_UDP then
                            state <= WR_UDP;
                        else
                            state <= PAYLOAD;
                        end if;
                    else
                        idx <= idx + 1;
                    end if;

                when WR_UDP =>
                    b := get_byte(udp_pack, idx);
                    v_we := '1'; v_addr := wr_ptr; v_data := b;
                    wr_ptr <= wr_ptr + 1;
                    if idx = UDP_HEADER_BYTES - 1 then
                        idx <= 0;
                        state <= PAYLOAD;
                    else
                        idx <= idx + 1;
                    end if;

                when PAYLOAD =>
                    if st.valid = '1' then
                        -- clamp instead of wrapping if a requester overruns
                        -- the buffer; bounded requesters never hit this
                        if wr_ptr /= 2 ** ADDR_BITS - 1 then
                            v_we := '1'; v_addr := wr_ptr; v_data := st.data;
                            wr_ptr <= wr_ptr + 1;
                            if pay_cnt(0) = '0' then
                                pay_sum <= pay_sum + shift_left(resize(unsigned(st.data), 32), 8);
                            else
                                pay_sum <= pay_sum + resize(unsigned(st.data), 32);
                            end if;
                            pay_cnt <= pay_cnt + 1;
                        end if;
                        if st.last = '1' then
                            state <= P_PLEN_HI;
                        end if;
                    end if;

                when P_PLEN_HI =>
                    v_we := '1'; v_addr := to_unsigned(IP_OFF + 4, ADDR_BITS);
                    v_data := std_logic_vector(ip6_plen(15 downto 8));
                    -- pay_cnt and pay_sum are final once PAYLOAD exits
                    l4_sum <= pay_sum + addr_sum_r + l4_extra;
                    state  <= P_PLEN_LO;

                when P_PLEN_LO =>
                    v_we := '1'; v_addr := to_unsigned(IP_OFF + 5, ADDR_BITS);
                    v_data := std_logic_vector(ip6_plen(7 downto 0));
                    folded := not ones_comp_fold(l4_sum);
                    if hdr_r.kind = FRAME_IPV6_UDP and folded = X"0000" then
                        -- RFC 768: a computed zero is sent as all-ones
                        csum_r <= X"FFFF";
                    else
                        csum_r <= folded;
                    end if;
                    if hdr_r.kind = FRAME_IPV6_UDP then
                        state <= P_ULEN_HI;
                    else
                        state <= P_ICSUM_HI;
                    end if;

                when P_ULEN_HI =>
                    v_we := '1'; v_addr := to_unsigned(L4_OFF + 4, ADDR_BITS);
                    v_data := std_logic_vector(udp_len(15 downto 8));
                    state <= P_ULEN_LO;

                when P_ULEN_LO =>
                    v_we := '1'; v_addr := to_unsigned(L4_OFF + 5, ADDR_BITS);
                    v_data := std_logic_vector(udp_len(7 downto 0));
                    state <= P_USUM_HI;

                when P_USUM_HI =>
                    v_we := '1'; v_addr := to_unsigned(L4_OFF + 6, ADDR_BITS);
                    v_data := csum_r(15 downto 8);
                    state <= P_USUM_LO;

                when P_USUM_LO =>
                    v_we := '1'; v_addr := to_unsigned(L4_OFF + 7, ADDR_BITS);
                    v_data := csum_r(7 downto 0);
                    state <= READY;

                when P_ICSUM_HI =>
                    v_we := '1'; v_addr := to_unsigned(L4_OFF + 2, ADDR_BITS);
                    v_data := csum_r(15 downto 8);
                    state <= P_ICSUM_LO;

                when P_ICSUM_LO =>
                    v_we := '1'; v_addr := to_unsigned(L4_OFF + 3, ADDR_BITS);
                    v_data := csum_r(7 downto 0);
                    state <= READY;

                when READY =>
                    if inj_done = '1' then
                        state <= IDLE;
                    end if;
            end case;

            if v_we = '1' then
                mem(to_integer(v_addr)) <= v_data;
            end if;
        end if;
    end process;

    -- packed header images serialized byte-by-byte above
    eth_pack <= pack(eth_header_t'(
        dst_mac   => hdr_r.dst_mac,
        src_mac   => our_mac,
        ethertype => ETHERTYPE_IPV6));

    nh <= IPPROTO_UDP when hdr_r.kind = FRAME_IPV6_UDP else IPPROTO_ICMPV6;
    -- NDP receivers require hop limit 255
    hl <= X"40" when hdr_r.kind = FRAME_IPV6_UDP else X"FF";

    ip6_pack <= pack(ipv6_header_t'(
        ver_tc_flow => X"60000000",
        payload_len => X"0000",              -- patched
        next_header => nh,
        hop_limit   => hl,
        src_ip      => hdr_r.src_ip,
        dst_ip      => hdr_r.dst_ip));

    udp_pack <= pack(udp_header_t'(
        src_port => hdr_r.src_port,
        dst_port => hdr_r.dst_port,
        length   => X"0000",                 -- patched
        checksum => X"0000"));               -- patched

end architecture;
