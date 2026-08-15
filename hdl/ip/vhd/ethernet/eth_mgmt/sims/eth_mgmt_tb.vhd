-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Protocol-level tests for eth_mgmt (with the real mgmt_flash sequencer and
-- a behavioral SPI flash underneath). The bench plays udp_endpoint: it
-- streams request datagrams in and validates responses, per
-- docs/mgmt_protocol.adoc.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;
use work.eth_mgmt_pkg.all;

entity eth_mgmt_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of eth_mgmt_tb is

    constant HOST_MAC  : mac_addr_t := X"021122334455";
    constant HOST_IP   : ipv6_addr_t := link_local_from_mac(HOST_MAC);
    constant HOST_PORT : std_logic_vector(15 downto 0) := X"C222";
    constant MGMT_PORT : std_logic_vector(15 downto 0) := X"6F78";
    constant TH_DEFAULT_MAC : mac_addr_t := X"020A0B0C0D0E";

    -- "913-0000019:006:2ABC1234" zero-padded to 32 bytes
    constant NEW_SERIAL_STR : string := "913-0000019:006:2ABC1234";

    type byte_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);

    signal resp_bytes : byte_arr_t(0 to 511);
    signal resp_len   : natural := 0;
    signal resp_cnt   : natural := 0;
    signal resp_dst_ip   : ipv6_addr_t;
    signal resp_dst_port : std_logic_vector(15 downto 0);

begin

    th: entity work.eth_mgmt_th;

    -- collect response datagrams
    resp_capture: process is
        alias clk     is << signal th.clk : std_logic >>;
        alias tx      is << signal th.tx : udp_st_t >>;
        alias tx_meta is << signal th.tx_meta : udp_tx_meta_t >>;
        variable idx : natural := 0;
    begin
        wait until rising_edge(clk);
        if tx.valid = '1' then
            if idx < 512 then
                resp_bytes(idx) <= tx.data;
            end if;
            idx := idx + 1;
            if tx.last = '1' then
                resp_len      <= idx;
                resp_dst_ip   <= tx_meta.dst_ip;
                resp_dst_port <= tx_meta.dst_port;
                resp_cnt      <= resp_cnt + 1;
                idx := 0;
            end if;
        end if;
    end process;

    bench: process
        alias clk       is << signal th.clk : std_logic >>;
        alias reset     is << signal th.reset : std_logic >>;
        alias tb_reset  is << signal th.tb_reset : std_logic >>;
        alias rx        is << signal th.rx : udp_st_t >>;
        alias rx_meta   is << signal th.rx_meta : udp_rx_meta_t >>;
        alias mac       is << signal th.mac : mac_addr_t >>;
        alias mac_valid is << signal th.mac_valid : std_logic >>;

        variable seen : natural := 0;

        procedure send_req (
            constant cmd     : in std_logic_vector(7 downto 0);
            constant seq     : in std_logic_vector(15 downto 0);
            constant payload : in queue_t;
            constant magic   : in std_logic_vector(31 downto 0) := MGMT_MAGIC;
            constant version : in std_logic_vector(7 downto 0) := MGMT_VERSION
        ) is
            constant q : queue_t := copy(payload);
            variable hdr : queue_t := new_queue;
            variable b : std_logic_vector(7 downto 0);
            variable total : natural;
        begin
            push_byte(hdr, to_integer(unsigned(magic(31 downto 24))));
            push_byte(hdr, to_integer(unsigned(magic(23 downto 16))));
            push_byte(hdr, to_integer(unsigned(magic(15 downto 8))));
            push_byte(hdr, to_integer(unsigned(magic(7 downto 0))));
            push_byte(hdr, to_integer(unsigned(version)));
            push_byte(hdr, to_integer(unsigned(cmd)));
            push_byte(hdr, to_integer(unsigned(seq(15 downto 8))));
            push_byte(hdr, to_integer(unsigned(seq(7 downto 0))));
            while not is_empty(q) loop
                push_byte(hdr, pop_byte(q));
            end loop;

            -- in the real system the network round trip guarantees a gap
            -- between a response and the next request; give the engine the
            -- same slack here so it has re-armed
            wait for 200 ns;
            wait until rising_edge(clk);

            total := 0;
            rx_meta <= (src_ip => HOST_IP, src_port => HOST_PORT,
                        dst_port => MGMT_PORT, length => (others => '0'));
            while not is_empty(hdr) loop
                b := std_logic_vector(to_unsigned(pop_byte(hdr), 8));
                rx.data  <= b;
                rx.valid <= '1';
                if is_empty(hdr) then
                    rx.last <= '1';
                end if;
                wait until rising_edge(clk);
            end loop;
            rx <= UDP_ST_IDLE;
        end procedure;

        procedure expect_resp (
            constant cmd    : in std_logic_vector(7 downto 0);
            constant seq    : in std_logic_vector(15 downto 0);
            constant status : in std_logic_vector(7 downto 0);
            constant what   : in string;
            constant timeout : in time := 1 ms
        ) is
        begin
            if resp_cnt = seen then
                wait until resp_cnt > seen for timeout;
            end if;
            check_equal(resp_cnt > seen, true, what & ": response arrived");
            seen := resp_cnt;
            check_equal(resp_bytes(0) & resp_bytes(1) & resp_bytes(2) & resp_bytes(3),
                        MGMT_MAGIC, what & ": magic");
            check_equal(resp_bytes(4), MGMT_VERSION, what & ": version");
            check_equal(resp_bytes(5), std_logic_vector'(cmd or X"80"), what & ": cmd echo");
            check_equal(resp_bytes(6) & resp_bytes(7), seq, what & ": seq echo");
            check_equal(resp_bytes(8), status, what & ": status");
            check_equal(resp_dst_ip, HOST_IP, what & ": addressed to requester");
            check_equal(resp_dst_port, HOST_PORT, what & ": requester port");
        end procedure;

        procedure expect_silence (constant what : in string) is
        begin
            wait for 100 us;
            check_equal(resp_cnt, seen, what & ": no response");
        end procedure;

        -- current serial as a queue (32 bytes)
        impure function serial_q (constant s : string) return queue_t is
            variable q : queue_t := new_queue;
        begin
            for i in 1 to s'length loop
                push_byte(q, character'pos(s(i)));
            end loop;
            for i in s'length to SERIAL_BYTES - 1 loop
                push_byte(q, 0);
            end loop;
            return q;
        end function;

        impure function zeros_q (constant n : natural) return queue_t is
            variable q : queue_t := new_queue;
        begin
            for i in 1 to n loop
                push_byte(q, 0);
            end loop;
            return q;
        end function;

        procedure push_q (q : queue_t; src : queue_t) is
            constant c : queue_t := copy(src);
        begin
            while not is_empty(c) loop
                push_byte(q, pop_byte(c));
            end loop;
        end procedure;

        procedure push_u32q (q : queue_t; v : std_logic_vector(31 downto 0)) is
        begin
            push_byte(q, to_integer(unsigned(v(31 downto 24))));
            push_byte(q, to_integer(unsigned(v(23 downto 16))));
            push_byte(q, to_integer(unsigned(v(15 downto 8))));
            push_byte(q, to_integer(unsigned(v(7 downto 0))));
        end procedure;

        -- run a SET_SERIAL to the well-known new value, from default state
        procedure do_set_serial (constant seq : in std_logic_vector(15 downto 0)) is
            variable pay : queue_t := new_queue;
        begin
            push_q(pay, zeros_q(SERIAL_BYTES));            -- echo of default
            push_q(pay, serial_q(NEW_SERIAL_STR));
            send_req(CMD_SET_SERIAL, seq, pay);
            expect_resp(CMD_SET_SERIAL, seq, STATUS_OK, "set_serial", 5 ms);
        end procedure;

        variable pay : queue_t;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        if mac_valid /= '1' then
            wait until mac_valid = '1' for 1 ms;
        end if;
        check_equal(mac_valid, '1', "boot completed");
        wait for 1 us;
        wait until rising_edge(clk);

        while test_suite loop
            if run("boot_defaults_and_identify") then
                check_equal(mac, TH_DEFAULT_MAC, "default MAC after blank flash");
                send_req(CMD_IDENTIFY, X"0001", new_queue);
                expect_resp(CMD_IDENTIFY, X"0001", STATUS_OK, "identify");
                check_equal(resp_len, 9 + IDENTIFY_PAYLOAD_BYTES, "identify length");
                check_equal(resp_bytes(9), MGMT_VERSION, "proto version");
                check_equal(resp_bytes(10) & resp_bytes(11) & resp_bytes(12) &
                            resp_bytes(13) & resp_bytes(14) & resp_bytes(15),
                            TH_DEFAULT_MAC, "mac");
                for i in 0 to 15 loop
                    check_equal(resp_bytes(16 + i),
                                get_byte(link_local_from_mac(TH_DEFAULT_MAC), i),
                                "link-local ip byte " & integer'image(i));
                end loop;
                check_equal(resp_bytes(32) & resp_bytes(33) & resp_bytes(34) & resp_bytes(35),
                            std_logic_vector'(X"DEADBEEF"), "fpga version");
                check_equal(resp_bytes(36), std_logic_vector'(X"03"),
                            "flags: address valid + default mac");
                for i in 0 to SERIAL_BYTES - 1 loop
                    check_equal(resp_bytes(37 + i), std_logic_vector'(X"00"),
                                "default serial byte " & integer'image(i));
                end loop;

            elsif run("set_serial_replay_and_echo") then
                do_set_serial(X"0002");

                -- identify now reports the new serial
                send_req(CMD_IDENTIFY, X"0003", new_queue);
                expect_resp(CMD_IDENTIFY, X"0003", STATUS_OK, "identify after set");
                for i in 1 to NEW_SERIAL_STR'length loop
                    check_equal(resp_bytes(37 + i - 1),
                                std_logic_vector(to_unsigned(character'pos(NEW_SERIAL_STR(i)), 8)),
                                "serial byte " & integer'image(i));
                end loop;

                -- retransmission of the same command+seq: cached OK even
                -- though the echo no longer matches
                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_q(pay, serial_q(NEW_SERIAL_STR));
                send_req(CMD_SET_SERIAL, X"0002", pay);
                expect_resp(CMD_SET_SERIAL, X"0002", STATUS_OK, "replayed set_serial");

                -- a new attempt with a stale echo is refused
                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_q(pay, serial_q("STALE"));
                send_req(CMD_SET_SERIAL, X"0004", pay);
                expect_resp(CMD_SET_SERIAL, X"0004", STATUS_BAD_SERIAL_ECHO, "stale echo");

            elsif run("set_mac_and_flash_readback") then
                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_byte(pay, 16#02#);
                push_byte(pay, 16#AA#);
                push_byte(pay, 16#BB#);
                push_byte(pay, 16#CC#);
                push_byte(pay, 16#DD#);
                push_byte(pay, 16#EE#);
                send_req(CMD_SET_MAC, X"0005", pay);
                expect_resp(CMD_SET_MAC, X"0005", STATUS_OK, "set_mac", 5 ms);

                -- live MAC unchanged until reset
                check_equal(mac, TH_DEFAULT_MAC, "live mac unchanged");

                -- but the identity sector holds the new one
                pay := new_queue;
                push_u32q(pay, X"00000000");
                push_byte(pay, 0);
                push_byte(pay, 6);
                send_req(CMD_FLASH_READ, X"0006", pay);
                expect_resp(CMD_FLASH_READ, X"0006", STATUS_OK, "read mac sector");
                check_equal(resp_len, 9 + 6, "read length");
                check_equal(resp_bytes(9) & resp_bytes(10) & resp_bytes(11) &
                            resp_bytes(12) & resp_bytes(13) & resp_bytes(14),
                            std_logic_vector'(X"02AABBCCDDEE"), "mac in flash");

            elsif run("flash_write_read_erase") then
                -- erase the first app sector, write a pattern, read it back
                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_u32q(pay, X"00002000");
                send_req(CMD_FLASH_ERASE, X"0010", pay);
                expect_resp(CMD_FLASH_ERASE, X"0010", STATUS_OK, "erase", 10 ms);

                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_u32q(pay, X"00002000");
                push_byte(pay, 0);
                push_byte(pay, 64);
                for i in 0 to 63 loop
                    push_byte(pay, (i * 5 + 1) mod 256);
                end loop;
                send_req(CMD_FLASH_WRITE, X"0011", pay);
                expect_resp(CMD_FLASH_WRITE, X"0011", STATUS_OK, "write", 10 ms);

                pay := new_queue;
                push_u32q(pay, X"00002000");
                push_byte(pay, 0);
                push_byte(pay, 64);
                send_req(CMD_FLASH_READ, X"0012", pay);
                expect_resp(CMD_FLASH_READ, X"0012", STATUS_OK, "readback");
                check_equal(resp_len, 9 + 64, "readback length");
                for i in 0 to 63 loop
                    check_equal(resp_bytes(9 + i),
                                std_logic_vector(to_unsigned((i * 5 + 1) mod 256, 8)),
                                "readback byte " & integer'image(i));
                end loop;

            elsif run("guards_and_errors") then
                -- erase outside the app region
                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_u32q(pay, X"00001000");
                send_req(CMD_FLASH_ERASE, X"0020", pay);
                expect_resp(CMD_FLASH_ERASE, X"0020", STATUS_BAD_ADDR, "erase identity refused");

                -- unaligned erase
                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_u32q(pay, X"00002100");
                send_req(CMD_FLASH_ERASE, X"0021", pay);
                expect_resp(CMD_FLASH_ERASE, X"0021", STATUS_BAD_ADDR, "unaligned erase refused");

                -- page-crossing write
                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_u32q(pay, X"000020F0");
                push_byte(pay, 0);
                push_byte(pay, 32);
                for i in 0 to 31 loop
                    push_byte(pay, i);
                end loop;
                send_req(CMD_FLASH_WRITE, X"0022", pay);
                expect_resp(CMD_FLASH_WRITE, X"0022", STATUS_BAD_LEN, "page cross refused");

                -- unknown command
                send_req(X"7E", X"0023", new_queue);
                expect_resp(X"7E", X"0023", STATUS_BAD_CMD, "unknown cmd");

                -- wrong version
                send_req(CMD_IDENTIFY, X"0024", new_queue, version => X"02");
                expect_resp(CMD_IDENTIFY, X"0024", STATUS_BAD_VERSION, "bad version");

                -- wrong magic: silence
                send_req(CMD_IDENTIFY, X"0025", new_queue, magic => X"12345678");
                expect_silence("bad magic");

            elsif run("busy_during_erase") then
                pay := new_queue;
                push_q(pay, zeros_q(SERIAL_BYTES));
                push_u32q(pay, X"00002000");
                send_req(CMD_FLASH_ERASE, X"0030", pay);

                -- immediately poke it again: the erase is in flight
                wait for 5 us;
                send_req(CMD_IDENTIFY, X"0031", new_queue);
                expect_resp(CMD_IDENTIFY, X"0031", STATUS_BUSY, "busy answer");
                expect_resp(CMD_FLASH_ERASE, X"0030", STATUS_OK, "erase completion", 10 ms);

            elsif run("reboot_loads_identity") then
                do_set_serial(X"0040");
                pay := new_queue;
                push_q(pay, serial_q(NEW_SERIAL_STR));    -- echo is new serial now
                push_byte(pay, 16#02#);
                push_byte(pay, 16#AA#);
                push_byte(pay, 16#BB#);
                push_byte(pay, 16#CC#);
                push_byte(pay, 16#DD#);
                push_byte(pay, 16#EE#);
                send_req(CMD_SET_MAC, X"0041", pay);
                expect_resp(CMD_SET_MAC, X"0041", STATUS_OK, "set_mac", 5 ms);

                tb_reset <= '1';
                wait for 100 ns;
                tb_reset <= '0';
                wait until mac_valid = '1' for 1 ms;
                check_equal(mac_valid, '1', "reboot completed");
                check_equal(mac, std_logic_vector'(X"02AABBCCDDEE"), "mac from flash");

                send_req(CMD_IDENTIFY, X"0042", new_queue);
                expect_resp(CMD_IDENTIFY, X"0042", STATUS_OK, "identify after reboot");
                check_equal(resp_bytes(36), std_logic_vector'(X"01"),
                            "flags: mac now from flash");
                for i in 1 to NEW_SERIAL_STR'length loop
                    check_equal(resp_bytes(37 + i - 1),
                                std_logic_vector(to_unsigned(character'pos(NEW_SERIAL_STR(i)), 8)),
                                "serial byte " & integer'image(i));
                end loop;
            end if;
        end loop;

        wait for 10 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 ms);

end tb;
