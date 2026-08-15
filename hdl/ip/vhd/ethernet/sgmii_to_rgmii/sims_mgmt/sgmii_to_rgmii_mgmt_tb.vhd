-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- End-to-end tests for the management bridge over the real wire path: the
-- bench injects replicated octet frames at the SGMII link partner; they
-- cross the bridge, loop back through the RGMII pins into the management
-- tap, and management responses come back out the same way. Checks both
-- that plain traffic still forwards byte-identically through the new
-- buffered path, that neighbor discovery works over the wire, and that a
-- full multicast IDENTIFY transaction round-trips.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;
use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;
use work.eth_mgmt_pkg.all;
use work.eth_sim_pkg.all;
use work.crc_sim_pkg.all;

entity sgmii_to_rgmii_mgmt_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of sgmii_to_rgmii_mgmt_tb is

    constant TH_MAC    : mac_addr_t := X"020A0B0C0D0E";
    constant TH_IP     : ipv6_addr_t := link_local_from_mac(TH_MAC);
    constant HOST_MAC  : mac_addr_t := X"021122334455";
    constant HOST_IP   : ipv6_addr_t := link_local_from_mac(HOST_MAC);
    constant MGMT_PORT : std_logic_vector(15 downto 0) := X"6F78";

    type byte_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);
    type frame_arr_t is array (0 to 3) of byte_arr_t(0 to 1599);
    type nat_arr_t is array (0 to 3) of natural;

    -- deduplicated frames recovered at the partner (preamble included)
    signal rx_frames : frame_arr_t;
    signal rx_lens   : nat_arr_t := (others => 0);
    signal rx_count  : natural := 0;

begin

    th: entity work.sgmii_to_rgmii_mgmt_th;

    -- recover frames at the partner: first accept of each replication group
    capture: process is
        alias clk   is << signal th.clk : std_logic >>;
        alias reset is << signal th.dut_reset : std_logic >>;
        alias speed is << signal th.bridge_speed : eth_speed_t >>;
        alias p_g2r is << signal th.p_g2r : gmii_t >>;
        variable acc : natural := 0;
        variable dvp : std_logic := '0';
        variable idx : natural := 0;
    begin
        wait until rising_edge(clk);
        if reset = '1' then
            acc := 0;
            dvp := '0';
            idx := 0;
        else
            if p_g2r.dv = '1' then
                if dvp = '0' then
                    idx := 0;
                    acc := 0;
                end if;
                if acc = 0 then
                    if idx < 1600 and rx_count < 4 then
                        rx_frames(rx_count)(idx) <= p_g2r.data;
                    end if;
                    idx := idx + 1;
                end if;
                if acc = speed_cycles_per_byte(speed) - 1 then
                    acc := 0;
                else
                    acc := acc + 1;
                end if;
            elsif dvp = '1' then
                if rx_count < 4 then
                    rx_lens(rx_count) <= idx;
                    rx_count          <= rx_count + 1;
                end if;
            end if;
            dvp := p_g2r.dv;
        end if;
    end process;

    bench: process
        alias clk          is << signal th.clk : std_logic >>;
        alias reset        is << signal th.reset : std_logic >>;
        alias p_r2g        is << signal th.p_r2g : gmii_t >>;
        alias p_r2g_ready  is << signal th.p_r2g_ready : std_logic >>;
        alias bridge_link  is << signal th.bridge_link : std_logic >>;
        alias partner_link is << signal th.partner_link : std_logic >>;
        alias bridge_speed is << signal th.bridge_speed : eth_speed_t >>;
        alias fwd_drops    is << signal th.fwd_drops : unsigned(7 downto 0) >>;

        variable rep : positive := 10;

        procedure send_octet (constant d : in std_logic_vector(7 downto 0)) is
        begin
            for r in 1 to rep loop
                p_r2g.data <= d;
                p_r2g.er   <= '0';
                p_r2g.dv   <= '1';
                loop
                    wait until rising_edge(clk);
                    exit when p_r2g_ready = '1';
                end loop;
            end loop;
        end procedure;

        -- frame is DA..FCS; preamble added here, replicated onto the line
        procedure send_frame (constant f : in queue_t) is
            constant q : queue_t := copy(f);
        begin
            for p in 1 to 7 loop
                send_octet(X"55");
            end loop;
            send_octet(X"D5");
            while not is_empty(q) loop
                send_octet(std_logic_vector(to_unsigned(pop_byte(q), 8)));
            end loop;
            p_r2g <= GMII_IDLE;
            wait for 2 us;
        end procedure;

        procedure link_up is
        begin
            if bridge_link /= '1' then
                wait until bridge_link = '1';
            end if;
            if partner_link /= '1' then
                wait until partner_link = '1';
            end if;
            rep := speed_cycles_per_byte(bridge_speed);
            wait for 1 us;
        end procedure;

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

        variable base : natural;
        variable pay  : queue_t;
        variable fcs  : std_logic_vector(31 downto 0);
        variable plen : natural;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("transparent_forwarding") then
                link_up;
                base := rx_count;

                -- an arbitrary (non-management) frame must still loop back
                -- byte-identically through the buffered forward path
                pay := new_queue;
                for i in 0 to 99 loop
                    push_byte(pay, (i * 13 + 7) mod 256);
                end loop;
                pay := build_udp6_frame(X"02DEADBEEF00", HOST_MAC, HOST_IP,
                                        link_local_from_mac(X"02DEADBEEF00"),
                                        X"1234", X"5678", pay);
                -- keep an original copy for comparison
                send_frame(copy(pay));

                if rx_count <= base then
                    wait until rx_count > base for 4 ms;
                end if;
                check_equal(rx_count > base, true, "frame forwarded");
                -- 8 preamble + 142 (14+20+8+100 payload) + 4 FCS
                check_equal(rx_lens(base), 8 + byte_count(pay), "forwarded length");
                for i in 0 to byte_count(pay) - 1 loop
                    check_equal(to_integer(unsigned(rx_frames(base)(8 + i))),
                                pop_byte(pay), "forwarded byte " & integer'image(i));
                end loop;
                check_equal(fwd_drops, unsigned'(X"00"), "no drops");

            elsif run("ns_na_round_trip") then
                link_up;
                -- boot (flash identity load) has long finished by link-up,
                -- but give it margin anyway
                wait for 30 us;
                base := rx_count;

                -- solicit the bridge's link-local address over the wire
                send_frame(build_ns(
                    mcast_mac(solicited_node(TH_IP)), HOST_MAC, HOST_IP,
                    solicited_node(TH_IP), TH_IP, true));

                -- the multicast solicitation is itself forwarded back to
                -- the partner first; the advertisement is the second frame
                if rx_count <= base + 1 then
                    wait until rx_count > base + 1 for 4 ms;
                end if;
                check_equal(rx_count > base + 1, true, "advertisement arrived");
                base := base + 1;

                check_equal(frame_slv(base, 8, 6), HOST_MAC, "NA DA");
                check_equal(frame_slv(base, 14, 6), TH_MAC, "NA SA");
                check_equal(frame_slv(base, 30, 16), TH_IP, "NA src ip");
                check_equal(frame_slv(base, 46, 16), HOST_IP, "NA dst ip");
                check_equal(rx_frames(base)(62), ICMPV6_NEIGHBOR_ADV, "NA type");
                check_equal(rx_frames(base)(66), std_logic_vector'(X"60"),
                            "NA solicited+override");
                check_equal(frame_slv(base, 70, 16), TH_IP, "NA target");
                check_equal(frame_slv(base, 88, 6), TH_MAC, "NA TLL mac");

            elsif run("identify_round_trip") then
                link_up;
                -- boot (flash identity load) has long finished by link-up,
                -- but give it margin anyway
                wait for 30 us;
                base := rx_count;

                pay := new_queue;
                push_byte(pay, to_integer(unsigned(MGMT_MAGIC(31 downto 24))));
                push_byte(pay, to_integer(unsigned(MGMT_MAGIC(23 downto 16))));
                push_byte(pay, to_integer(unsigned(MGMT_MAGIC(15 downto 8))));
                push_byte(pay, to_integer(unsigned(MGMT_MAGIC(7 downto 0))));
                push_byte(pay, to_integer(unsigned(MGMT_VERSION)));
                push_byte(pay, to_integer(unsigned(CMD_IDENTIFY)));
                push_byte(pay, 16#00#);
                push_byte(pay, 16#2A#);
                send_frame(build_udp6_frame(
                    MAC_ALL_NODES, HOST_MAC, HOST_IP, IPV6_ALL_NODES,
                    X"C777", MGMT_PORT, pay));

                -- the multicast request is itself forwarded back to the
                -- partner first; the response is the second frame
                if rx_count <= base + 1 then
                    wait until rx_count > base + 1 for 4 ms;
                end if;
                check_equal(rx_count > base + 1, true, "response arrived");
                base := base + 1;

                -- Ethernet/IPv6/UDP framing of the response
                check_equal(frame_slv(base, 8, 6), HOST_MAC, "resp DA");
                check_equal(frame_slv(base, 14, 6), TH_MAC, "resp SA");
                check_equal(frame_slv(base, 20, 2), ETHERTYPE_IPV6, "resp ethertype");
                check_equal(frame_slv(base, 30, 16), TH_IP, "resp src ip");
                check_equal(frame_slv(base, 46, 16), HOST_IP, "resp dst ip");
                check_equal(frame_slv(base, 62, 2), MGMT_PORT, "resp src port");
                check_equal(frame_slv(base, 64, 2), std_logic_vector'(X"C777"),
                            "resp dst port");

                -- FCS over the whole response frame
                fcs := crc32_ethernet(frame_q(base, 8, rx_lens(base) - 12));
                check_equal(rx_frames(base)(rx_lens(base) - 4), fcs(7 downto 0), "FCS0");
                check_equal(rx_frames(base)(rx_lens(base) - 3), fcs(15 downto 8), "FCS1");
                check_equal(rx_frames(base)(rx_lens(base) - 2), fcs(23 downto 16), "FCS2");
                check_equal(rx_frames(base)(rx_lens(base) - 1), fcs(31 downto 24), "FCS3");

                -- management payload starts at 8 (preamble) + 62 (headers)
                check_equal(frame_slv(base, 70, 4), MGMT_MAGIC, "mgmt magic");
                check_equal(rx_frames(base)(74), MGMT_VERSION, "mgmt version");
                check_equal(rx_frames(base)(75),
                            std_logic_vector'(CMD_IDENTIFY or X"80"), "mgmt cmd");
                check_equal(frame_slv(base, 76, 2), std_logic_vector'(X"002A"), "mgmt seq");
                check_equal(rx_frames(base)(78), STATUS_OK, "mgmt status");
                check_equal(rx_frames(base)(79), MGMT_VERSION, "ident proto");
                check_equal(frame_slv(base, 80, 6), TH_MAC, "ident mac");
                check_equal(frame_slv(base, 86, 16), TH_IP, "ident ip");
                check_equal(frame_slv(base, 102, 4), std_logic_vector'(X"DEADBEEF"),
                            "ident fpga version");
                -- flash is blank in this harness: valid + default MAC
                check_equal(rx_frames(base)(106), std_logic_vector'(X"03"), "ident flags");
                for i in 0 to SERIAL_BYTES - 1 loop
                    check_equal(rx_frames(base)(107 + i), std_logic_vector'(X"00"),
                                "ident serial byte " & integer'image(i));
                end loop;
            end if;
        end loop;

        wait for 10 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 40 ms);

end tb;
