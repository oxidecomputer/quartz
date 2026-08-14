-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- RGMII adapter testbench. With the harness looping the RGMII pins back, an
-- octet driven on g2r is transmitted on the DDR link and recovered on r2g. Each
-- octet is held for the speed's byte period so the transmitter samples it once.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.gmii_pkg.all;
use work.rgmii_pkg.all;

entity rgmii_mac_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of rgmii_mac_tb is

    type byte_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);

    signal rx_data  : byte_arr_t(0 to 255);
    signal rx_er    : std_logic_vector(0 to 255) := (others => '0');
    signal rx_count : natural := 0;

begin

    th: entity work.rgmii_mac_th;

    -- r2g lives in the recovered rxc clock domain, so sample it there
    capture: process is
        alias rxc is << signal th.s_txc : std_logic >>;
        alias r2g is << signal th.r2g : gmii_t >>;
    begin
        wait until rising_edge(rxc);
        if r2g.dv = '1' then
            rx_data(rx_count) <= r2g.data;
            rx_er(rx_count)   <= r2g.er;
            rx_count          <= rx_count + 1;
        end if;
    end process;

    bench: process is

        alias clk      is << signal th.clk : std_logic >>;
        alias reset    is << signal th.reset : std_logic >>;
        alias tb_reset is << signal th.tb_reset : std_logic >>;
        alias speed    is << signal th.speed : eth_speed_t >>;
        alias g2r      is << signal th.g2r : gmii_t >>;
        alias inband   is << signal th.inband : rgmii_inband_t >>;
        alias s_txc    is << signal th.s_txc : std_logic >>;

        variable base  : natural;
        variable t0    : time;
        variable t_hi  : time;
        variable t_per : time;

        procedure restart (constant sp : in eth_speed_t) is
        begin
            speed    <= sp;
            g2r      <= GMII_IDLE;
            tb_reset <= '1';
            wait for 200 ns;
            tb_reset <= '0';
            wait for 200 ns;
        end procedure;

        procedure send_frame (
            constant bytes : in byte_arr_t;
            constant sp    : in eth_speed_t;
            constant er_at : in integer := -1   -- octet index marked tx_er
        ) is
            constant n : positive := speed_cycles_per_byte(sp);
        begin
            for i in bytes'range loop
                g2r.data <= bytes(i);
                g2r.er   <= '1' when i = er_at else '0';
                g2r.dv   <= '1';
                for j in 1 to n loop
                    wait until rising_edge(clk);
                end loop;
            end loop;
            g2r.dv <= '0';
            g2r.er <= '0';
        end procedure;

        procedure check_frame (constant bytes : in byte_arr_t) is
            variable base : natural;
        begin
            base := rx_count;
            send_frame(bytes, speed);
            wait for 5 us;
            check_equal(rx_count - base, bytes'length, "recovered octet count");
            for i in bytes'range loop
                check_equal(rx_data(base + i), bytes(i),
                            "octet " & integer'image(i));
            end loop;
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 300 ns;

        while test_suite loop
            if run("loopback_1000") then
                restart(SPEED_1000);
                check_frame((x"55", x"d5", x"12", x"34", x"56", x"78", x"9a"));

            elsif run("loopback_100") then
                restart(SPEED_100);
                check_frame((x"55", x"d5", x"aa", x"bb", x"cc"));

            elsif run("loopback_10") then
                restart(SPEED_10);
                check_frame((x"55", x"d5", x"de", x"ad"));

            elsif run("ipg_no_inband_from_mac") then
                -- as the MAC we drive TXD low during the inter-frame gap (in-band
                -- status is a PHY->MAC construct), so the looped-back decode must
                -- show link down rather than phantom status
                restart(SPEED_100);
                wait for 2 us;
                check_true(inband.link = '0', "MAC must not emit in-band status");

            elsif run("tx_er_falling_edge_100") then
                -- tx_er must survive the RGMII crossing at 100M: it rides the
                -- TX_CTL falling edge (tx_en xor tx_er) at every speed, not just
                -- at 1000
                restart(SPEED_100);
                base := rx_count;
                send_frame((x"55", x"d5", x"11", x"22"), SPEED_100, er_at => 2);
                wait for 5 us;
                check_equal(rx_count - base, 4, "recovered octet count");
                check_equal(rx_er(base + 1), '0', "clean octet must not flag er");
                check_equal(rx_er(base + 2), '1', "errored octet must flag er");
                check_equal(rx_er(base + 3), '0', "following octet must be clean");

            elsif run("txc_duty_100") then
                -- RGMII wants 45-55% duty on txc; a naive /5 divider gives 40/60
                restart(SPEED_100);
                wait for 1 us;
                for k in 1 to 5 loop
                    wait until rising_edge(s_txc);
                    t0 := now;
                    wait until falling_edge(s_txc);
                    t_hi := now - t0;
                    wait until rising_edge(s_txc);
                    t_per := now - t0;
                    check_equal(t_per, 40 ns, "txc period at 100M");
                    check(t_hi >= 18 ns and t_hi <= 22 ns,
                          "txc high time " & time'image(t_hi) & " outside 45-55% duty");
                end loop;

            elsif run("txc_duty_10") then
                restart(SPEED_10);
                wait for 3 us;
                for k in 1 to 3 loop
                    wait until rising_edge(s_txc);
                    t0 := now;
                    wait until falling_edge(s_txc);
                    t_hi := now - t0;
                    wait until rising_edge(s_txc);
                    t_per := now - t0;
                    check_equal(t_per, 400 ns, "txc period at 10M");
                    check(t_hi >= 180 ns and t_hi <= 220 ns,
                          "txc high time " & time'image(t_hi) & " outside 45-55% duty");
                end loop;
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 2 ms);

end tb;
