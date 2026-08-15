-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- End-to-end tests for the IPv6 udp_endpoint through the same seams the
-- bridge wrapper uses: frames go in as a byte_pop tap stream, responses
-- come out through gmii_pkt_buf/g2r_inject_mux and are reconstructed by a
-- free-running decimating sampler (the rgmii_tx contract). The bench plays
-- every other role: neighbor, ping host, datagram client, and the PCS RX
-- pushing forwarded traffic. All reference frames and checksums come from
-- eth_sim_pkg, computed independently of the RTL.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.gmii_pkg.all;
use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;
use work.eth_sim_pkg.all;
use work.crc_sim_pkg.all;

entity udp_endpoint_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of udp_endpoint_tb is

    constant CLIENT_PORT : std_logic_vector(15 downto 0) := X"6F78";
    constant DUT_MAC  : mac_addr_t := X"020A0B0C0D0E";
    constant HOST_MAC : mac_addr_t := X"021122334455";

    constant DUT_IP  : ipv6_addr_t := link_local_from_mac(DUT_MAC);
    constant HOST_IP : ipv6_addr_t := link_local_from_mac(HOST_MAC);

    type byte_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);
    type frame_arr_t is array (0 to 5) of byte_arr_t(0 to 1599);
    type nat_arr_t is array (0 to 5) of natural;

    -- frames reconstructed from g2r_out (preamble included)
    signal rx_frames : frame_arr_t;
    signal rx_lens   : nat_arr_t := (others => 0);
    signal rx_gaps   : nat_arr_t := (others => 0);
    signal rx_count  : natural := 0;

    -- datagrams delivered on the client interface
    signal cap_pay  : byte_arr_t(0 to 511);
    signal cap_len  : natural := 0;
    signal cap_meta : udp_rx_meta_t;
    signal cap_cnt  : natural := 0;

    -- forward-traffic driver control (runs concurrently with the bench)
    signal fwd_go     : std_logic := '0';
    signal fwd_frames : natural := 0;
    signal fwd_busy   : std_logic := '0';

    constant FWD_LEN : natural := 120;   -- pattern bytes per forwarded frame

    function fwd_pat (frame : natural; i : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned((frame * 89 + i * 7 + 3) mod 256, 8));
    end function;

begin

    th: entity work.udp_endpoint_th;

    -- free-running decimating sampler: the rgmii_tx contract (one sample
    -- per byte period at an arbitrary phase)
    capture: process is
        alias clk     is << signal th.clk : std_logic >>;
        alias reset   is << signal th.reset : std_logic >>;
        alias speed   is << signal th.speed : eth_speed_t >>;
        alias g2r_out is << signal th.g2r_out : gmii_t >>;
        variable phase : natural := 0;
        variable dvp   : std_logic := '0';
        variable idx   : natural := 0;
        variable gap   : natural := 0;
    begin
        wait until rising_edge(clk);
        if reset = '1' then
            phase := 0;
            dvp   := '0';
            idx   := 0;
            gap   := 0;
        elsif phase = speed_cycles_per_byte(speed) - 1 then
            phase := 0;
            if g2r_out.dv = '1' then
                if dvp = '0' then
                    idx := 0;
                end if;
                if idx < 1600 and rx_count < 6 then
                    rx_frames(rx_count)(idx) <= g2r_out.data;
                end if;
                idx := idx + 1;
            else
                if dvp = '1' and rx_count < 6 then
                    rx_lens(rx_count) <= idx;
                    rx_gaps(rx_count) <= gap;
                    rx_count          <= rx_count + 1;
                    gap := 0;
                end if;
                gap := gap + 1;
            end if;
            dvp := g2r_out.dv;
        else
            phase := phase + 1;
        end if;
    end process;

    -- record datagrams the endpoint delivers to its client
    client_capture: process is
        alias clk            is << signal th.clk : std_logic >>;
        alias client_rx      is << signal th.client_rx : udp_st_t >>;
        alias client_rx_meta is << signal th.client_rx_meta : udp_rx_meta_t >>;
        variable idx : natural := 0;
    begin
        wait until rising_edge(clk);
        if client_rx.valid = '1' then
            if idx < 512 then
                cap_pay(idx) <= client_rx.data;
            end if;
            idx := idx + 1;
            if client_rx.last = '1' then
                cap_meta <= client_rx_meta;
                cap_len  <= idx;
                cap_cnt  <= cap_cnt + 1;
                idx := 0;
            end if;
        end if;
    end process;

    -- forwarded-traffic source, concurrent with the bench: pushes fwd_frames
    -- pattern frames into the PCS-RX-side stream when fwd_go pulses
    fwd_driver: process is
        alias clk    is << signal th.clk : std_logic >>;
        alias speed  is << signal th.speed : eth_speed_t >>;
        alias g2r_in is << signal th.g2r_in : gmii_t >>;
        variable n : positive;
    begin
        wait until rising_edge(clk) and fwd_go = '1';
        fwd_busy <= '1';
        n := speed_cycles_per_byte(speed);
        for f in 0 to fwd_frames - 1 loop
            -- preamble
            for p in 0 to 7 loop
                if p = 7 then
                    g2r_in.data <= X"D5";
                else
                    g2r_in.data <= X"55";
                end if;
                g2r_in.dv <= '1';
                g2r_in.er <= '0';
                for c in 1 to n loop
                    wait until rising_edge(clk);
                end loop;
            end loop;
            for i in 0 to FWD_LEN - 1 loop
                g2r_in.data <= fwd_pat(f, i);
                for c in 1 to n loop
                    wait until rising_edge(clk);
                end loop;
            end loop;
            g2r_in <= GMII_IDLE;
            for c in 1 to 13 * n loop
                wait until rising_edge(clk);
            end loop;
        end loop;
        fwd_busy <= '0';
    end process;

    bench: process
        alias clk       is << signal th.clk : std_logic >>;
        alias reset     is << signal th.reset : std_logic >>;
        alias speed     is << signal th.speed : eth_speed_t >>;
        alias mac_valid is << signal th.mac_valid : std_logic >>;
        alias tap_data  is << signal th.tap_data : std_logic_vector(7 downto 0) >>;
        alias tap_er    is << signal th.tap_er : std_logic >>;
        alias tap_dv    is << signal th.tap_dv : std_logic >>;
        alias tap_pop   is << signal th.tap_pop : std_logic >>;
        alias status    is << signal th.status : endpoint_status_t >>;
        alias client_tx       is << signal th.client_tx : udp_st_t >>;
        alias client_tx_meta  is << signal th.client_tx_meta : udp_tx_meta_t >>;
        alias client_tx_ready is << signal th.client_tx_ready : std_logic >>;
        alias underrun  is << signal th.underrun : std_logic >>;
        alias drop_count is << signal th.drop_count : unsigned(7 downto 0) >>;

        variable n : positive := 1;

        -- drive one octet into the tap: data held for the byte period, pop
        -- pulsed on its last cycle, exactly as r2g_expander does
        procedure tap_octet (constant d : in std_logic_vector(7 downto 0)) is
        begin
            tap_data <= d;
            tap_dv   <= '1';
            for c in 1 to n - 1 loop
                wait until rising_edge(clk);
            end loop;
            tap_pop <= '1';
            wait until rising_edge(clk);
            tap_pop <= '0';
        end procedure;

        -- frame is DA..FCS; preamble added here
        procedure send_tap_frame (constant f : in queue_t) is
            constant q : queue_t := copy(f);
        begin
            for p in 1 to 7 loop
                tap_octet(X"55");
            end loop;
            tap_octet(X"D5");
            while not is_empty(q) loop
                tap_octet(std_logic_vector(to_unsigned(pop_byte(q), 8)));
            end loop;
            tap_dv <= '0';
            for c in 1 to 14 * n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- stream one datagram out of the client interface
        procedure client_send (
            constant payload : in queue_t;
            constant dst_ip  : in ipv6_addr_t;
            constant dst_port : in std_logic_vector(15 downto 0)
        ) is
            constant q : queue_t := copy(payload);
            variable b : std_logic_vector(7 downto 0);
        begin
            client_tx_meta <= (dst_ip => dst_ip, dst_port => dst_port,
                               src_port => CLIENT_PORT);
            while not is_empty(q) loop
                b := std_logic_vector(to_unsigned(pop_byte(q), 8));
                client_tx.data  <= b;
                client_tx.valid <= '1';
                if is_empty(q) then
                    client_tx.last <= '1';
                end if;
                loop
                    wait until rising_edge(clk);
                    exit when client_tx_ready = '1';
                end loop;
            end loop;
            client_tx <= UDP_ST_IDLE;
        end procedure;

        -- pull a captured frame region back into a queue
        impure function frame_q (
            constant fi    : natural;
            constant first : natural;
            constant len   : natural
        ) return queue_t is
            variable q : queue_t := new_queue;
        begin
            for i in first to first + len - 1 loop
                push_byte(q, to_integer(unsigned(rx_frames(fi)(i))));
            end loop;
            return q;
        end function;

        -- a short captured region as one big-endian vector, for check_equal
        impure function frame_slv (
            constant fi    : natural;
            constant first : natural;
            constant len   : natural
        ) return std_logic_vector is
            variable v : std_logic_vector(8 * len - 1 downto 0);
        begin
            for i in 0 to len - 1 loop
                v(v'high - 8 * i downto v'high - 8 * i - 7) := rx_frames(fi)(first + i);
            end loop;
            return v;
        end function;

        procedure check_wire_frame (constant fi : natural; constant what : string) is
            variable fcs : std_logic_vector(31 downto 0);
        begin
            for p in 0 to 6 loop
                check_equal(rx_frames(fi)(p), std_logic_vector'(X"55"),
                            what & ": preamble");
            end loop;
            check_equal(rx_frames(fi)(7), std_logic_vector'(X"D5"), what & ": SFD");
            check_true(rx_lens(fi) >= 72, what & ": minimum frame length");
            fcs := crc32_ethernet(frame_q(fi, 8, rx_lens(fi) - 12));
            check_equal(rx_frames(fi)(rx_lens(fi) - 4), fcs(7 downto 0), what & ": FCS0");
            check_equal(rx_frames(fi)(rx_lens(fi) - 3), fcs(15 downto 8), what & ": FCS1");
            check_equal(rx_frames(fi)(rx_lens(fi) - 2), fcs(23 downto 16), what & ": FCS2");
            check_equal(rx_frames(fi)(rx_lens(fi) - 1), fcs(31 downto 24), what & ": FCS3");
        end procedure;

        -- the common IPv6 framing of a response from the DUT
        procedure check_ip6_frame (
            constant fi      : natural;
            constant dst_mac : in mac_addr_t;
            constant dst_ip  : in ipv6_addr_t;
            constant nh      : in std_logic_vector(7 downto 0);
            constant what    : in string
        ) is
        begin
            check_wire_frame(fi, what);
            check_equal(frame_slv(fi, 8, 6), dst_mac, what & ": DA");
            check_equal(frame_slv(fi, 14, 6), DUT_MAC, what & ": SA");
            check_equal(frame_slv(fi, 20, 2), ETHERTYPE_IPV6, what & ": ethertype");
            check_equal(rx_frames(fi)(22)(7 downto 4),
                        std_logic_vector'(X"6"), what & ": version");
            check_equal(rx_frames(fi)(28), nh, what & ": next header");
            check_equal(frame_slv(fi, 30, 16), DUT_IP, what & ": src ip");
            check_equal(frame_slv(fi, 46, 16), dst_ip, what & ": dst ip");
        end procedure;

        -- ones-complement verify: a region containing its own checksum sums
        -- to all-ones with its pseudo-header
        impure function l4_sums_ok (
            constant fi  : natural;
            constant len : natural;
            constant src : ipv6_addr_t;
            constant dst : ipv6_addr_t;
            constant nh  : std_logic_vector(7 downto 0)
        ) return boolean is
            variable sum : unsigned(31 downto 0);
        begin
            sum := inet_sum(frame_q(fi, 62, len), pseudo6_sum(src, dst, len, nh));
            return ones_comp_fold(sum) = X"FFFF";
        end function;

        procedure wait_frames (constant target : natural; constant what : string) is
        begin
            if rx_count < target then
                wait until rx_count >= target for 4 ms;
            end if;
            check_equal(rx_count >= target, true, what & ": expected frame count");
        end procedure;

        -- forwarded traffic and an injected response sharing the output,
        -- at a caller-chosen speed
        procedure fwd_inject_test (constant sp : in eth_speed_t) is
            variable pay  : queue_t;
            variable base : natural;
        begin
            n := speed_cycles_per_byte(sp);
            speed <= sp;
            mac_valid <= '1';
            wait for 100 ns;
            base := rx_count;

            -- teach the endpoint who we are, and queue a response while
            -- forwarded traffic occupies the output
            pay := new_queue;
            push_byte(pay, 16#42#);
            send_tap_frame(build_udp6_frame(
                MAC_ALL_NODES, HOST_MAC, HOST_IP, IPV6_ALL_NODES,
                X"C789", CLIENT_PORT, pay));
            if cap_cnt = 0 then
                wait until cap_cnt = 1 for 1 ms;
            end if;
            check_equal(cap_cnt, 1, "query delivered");

            fwd_frames <= 2;
            fwd_go <= '1';
            wait until rising_edge(clk);
            fwd_go <= '0';

            pay := new_queue;
            for i in 0 to 63 loop
                push_byte(pay, (i * 11 + 2) mod 256);
            end loop;
            client_send(pay, HOST_IP, X"C789");

            wait_frames(base + 3, "two forwarded + one injected");
            if fwd_busy = '1' then
                wait until fwd_busy = '0' for 1 ms;
            end if;

            -- forwarded frames must be first (they have priority) and
            -- byte-identical; the response follows with a full IFG
            for f in 0 to 1 loop
                check_equal(rx_lens(base + f), 8 + FWD_LEN,
                            "fwd frame " & integer'image(f) & " length");
                for i in 0 to FWD_LEN - 1 loop
                    check_equal(rx_frames(base + f)(8 + i), fwd_pat(f, i),
                                "fwd " & integer'image(f) & " byte " & integer'image(i));
                end loop;
            end loop;
            check_wire_frame(base + 2, "injected response");
            check_equal(frame_slv(base + 2, 8, 6), HOST_MAC, "response DA");
            check_true(rx_gaps(base + 1) >= 12, "IFG before second fwd frame");
            check_true(rx_gaps(base + 2) >= 12, "IFG before injected frame");
            check_equal(underrun, '0', "no forward-path underrun");
            check_equal(drop_count, unsigned'(X"00"), "no forward-path drops");
        end procedure;

        variable pay  : queue_t;
        variable base : natural;
        variable plen : natural;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;
        wait until rising_edge(clk);

        while test_suite loop
            if run("ns_na") then
                n := 1;
                speed <= SPEED_1000;
                mac_valid <= '1';
                wait for 100 ns;
                check_equal(status.ip_valid, '1', "address valid with mac");
                check_equal(status.ip, DUT_IP, "link-local address");
                base := rx_count;

                -- solicitation for someone else's address must be ignored;
                -- the RX path is stop-and-wait, so space the two out
                send_tap_frame(build_ns(
                    mcast_mac(solicited_node(HOST_IP)), HOST_MAC, HOST_IP,
                    solicited_node(HOST_IP), HOST_IP, true));
                wait for 10 us;
                send_tap_frame(build_ns(
                    mcast_mac(solicited_node(DUT_IP)), HOST_MAC, HOST_IP,
                    solicited_node(DUT_IP), DUT_IP, true));
                wait_frames(base + 1, "neighbor advertisement");
                check_ip6_frame(base, HOST_MAC, HOST_IP, IPPROTO_ICMPV6, "NA");
                check_equal(rx_frames(base)(29), std_logic_vector'(X"FF"), "NA: hop limit");
                check_equal(rx_frames(base)(62), ICMPV6_NEIGHBOR_ADV, "NA: type");
                check_equal(rx_frames(base)(66), std_logic_vector'(X"60"),
                            "NA: solicited+override");
                check_equal(frame_slv(base, 70, 16), DUT_IP, "NA: target");
                check_equal(rx_frames(base)(86), NDP_OPT_TARGET_LL, "NA: TLL option");
                check_equal(rx_frames(base)(87), std_logic_vector'(X"01"), "NA: TLL len");
                check_equal(frame_slv(base, 88, 6), DUT_MAC, "NA: TLL mac");
                check_true(l4_sums_ok(base, 32, DUT_IP, HOST_IP, IPPROTO_ICMPV6),
                           "NA: ICMPv6 checksum");

            elsif run("dad_defense") then
                n := 1;
                speed <= SPEED_1000;
                mac_valid <= '1';
                wait for 100 ns;
                base := rx_count;

                -- another node probing our address: unspecified source, no
                -- SLL; the defense goes to all-nodes with S=0
                send_tap_frame(build_ns(
                    mcast_mac(solicited_node(DUT_IP)), HOST_MAC,
                    IPV6_UNSPECIFIED, solicited_node(DUT_IP), DUT_IP, false));
                wait_frames(base + 1, "DAD defense");
                check_ip6_frame(base, MAC_ALL_NODES, IPV6_ALL_NODES,
                                IPPROTO_ICMPV6, "DAD NA");
                check_equal(rx_frames(base)(62), ICMPV6_NEIGHBOR_ADV, "DAD NA: type");
                check_equal(rx_frames(base)(66), std_logic_vector'(X"20"),
                            "DAD NA: override only");
                check_equal(frame_slv(base, 70, 16), DUT_IP, "DAD NA: target");
                check_true(l4_sums_ok(base, 32, DUT_IP, IPV6_ALL_NODES, IPPROTO_ICMPV6),
                           "DAD NA: ICMPv6 checksum");

            elsif run("echo6") then
                n := 1;
                speed <= SPEED_1000;
                mac_valid <= '1';
                wait for 100 ns;
                base := rx_count;

                pay := new_queue;
                for i in 0 to 15 loop
                    push_byte(pay, (i * 17 + 5) mod 256);
                end loop;
                send_tap_frame(build_echo6(DUT_MAC, HOST_MAC, HOST_IP,
                                           DUT_IP, X"BEEF", X"0001", pay));
                wait_frames(base + 1, "echo reply");
                check_ip6_frame(base, HOST_MAC, HOST_IP, IPPROTO_ICMPV6, "echo");
                check_equal(rx_frames(base)(62), ICMPV6_ECHO_REPLY, "echo: type");
                check_equal(frame_slv(base, 66, 2),
                            std_logic_vector'(X"BEEF"), "echo: ident");
                check_equal(frame_slv(base, 68, 2),
                            std_logic_vector'(X"0001"), "echo: seq");
                for i in 0 to 15 loop
                    check_equal(rx_frames(base)(70 + i),
                                std_logic_vector(to_unsigned((i * 17 + 5) mod 256, 8)),
                                "echo: payload " & integer'image(i));
                end loop;
                check_true(l4_sums_ok(base, 24, DUT_IP, HOST_IP, IPPROTO_ICMPV6),
                           "echo: ICMPv6 checksum");

            elsif run("client_echo") then
                n := 1;
                speed <= SPEED_1000;
                mac_valid <= '1';
                wait for 100 ns;
                base := rx_count;

                pay := new_queue;
                for i in 0 to 31 loop
                    push_byte(pay, (i * 3 + 1) mod 256);
                end loop;
                send_tap_frame(build_udp6_frame(
                    DUT_MAC, HOST_MAC, HOST_IP, DUT_IP,
                    X"C123", CLIENT_PORT, pay));

                if cap_cnt = 0 then
                    wait until cap_cnt = 1 for 1 ms;
                end if;
                check_equal(cap_cnt, 1, "datagram delivered");
                check_equal(cap_len, 32, "payload length");
                check_equal(cap_meta.src_ip, HOST_IP, "meta src ip");
                check_equal(cap_meta.src_port, std_logic_vector'(X"C123"), "meta src port");
                check_equal(cap_meta.dst_port, CLIENT_PORT, "meta dst port");
                for i in 0 to 31 loop
                    check_equal(cap_pay(i),
                                std_logic_vector(to_unsigned((i * 3 + 1) mod 256, 8)),
                                "payload byte " & integer'image(i));
                end loop;

                -- reply; the endpoint must already know the host's MAC
                pay := new_queue;
                for i in 0 to 15 loop
                    push_byte(pay, 16#A0# + i);
                end loop;
                client_send(pay, HOST_IP, X"C123");
                wait_frames(base + 1, "client reply");
                check_ip6_frame(base, HOST_MAC, HOST_IP, IPPROTO_UDP, "reply");
                check_equal(frame_slv(base, 62, 2), CLIENT_PORT, "reply: src port");
                check_equal(frame_slv(base, 64, 2),
                            std_logic_vector'(X"C123"), "reply: dst port");
                plen := 8 + 16;
                check_equal(frame_slv(base, 66, 2),
                            std_logic_vector(to_unsigned(plen, 16)), "reply: udp len");
                check_true(l4_sums_ok(base, plen, DUT_IP, HOST_IP, IPPROTO_UDP),
                           "reply: udp checksum");
                for i in 0 to 15 loop
                    check_equal(rx_frames(base)(70 + i),
                                std_logic_vector(to_unsigned(16#A0# + i, 8)),
                                "reply payload " & integer'image(i));
                end loop;

            elsif run("client_multicast_discovery") then
                n := 1;
                speed <= SPEED_1000;
                mac_valid <= '1';
                wait for 100 ns;
                base := rx_count;

                -- an unknown device is found by sending to all-nodes; the
                -- reply is unicast using the pairing learned from the query
                pay := new_queue;
                for i in 0 to 7 loop
                    push_byte(pay, i);
                end loop;
                send_tap_frame(build_udp6_frame(
                    MAC_ALL_NODES, HOST_MAC, HOST_IP, IPV6_ALL_NODES,
                    X"C456", CLIENT_PORT, pay));

                if cap_cnt = 0 then
                    wait until cap_cnt = 1 for 1 ms;
                end if;
                check_equal(cap_cnt, 1, "multicast datagram delivered");

                pay := new_queue;
                for i in 0 to 7 loop
                    push_byte(pay, 16#50# + i);
                end loop;
                client_send(pay, HOST_IP, X"C456");
                wait_frames(base + 1, "discovery reply");
                check_ip6_frame(base, HOST_MAC, HOST_IP, IPPROTO_UDP,
                                "discovery reply");

            elsif run("forward_with_injection_1000") then
                fwd_inject_test(SPEED_1000);

            elsif run("forward_with_injection_100") then
                fwd_inject_test(SPEED_100);

            elsif run("bad_fcs_dropped") then
                n := 1;
                speed <= SPEED_1000;
                mac_valid <= '1';

                pay := new_queue;
                for i in 0 to 7 loop
                    push_byte(pay, i);
                end loop;
                pay := build_udp6_frame(
                    MAC_ALL_NODES, HOST_MAC, HOST_IP, IPV6_ALL_NODES,
                    X"C456", CLIENT_PORT, pay);
                -- one stray byte after the FCS makes the residue check fail
                push_byte(pay, 16#5A#);
                send_tap_frame(pay);
                wait until cap_cnt = 1 for 200 us;
                check_equal(cap_cnt, 0, "corrupt frame must not be delivered");
            end if;
        end loop;

        wait for 10 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 40 ms);

end tb;
