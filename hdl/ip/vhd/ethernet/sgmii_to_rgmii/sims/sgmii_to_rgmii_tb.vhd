-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Integration testbench for the SGMII<->RGMII bridge. A frame injected at the
-- SGMII link partner traverses the whole bridge (SGMII PCS -> RGMII TX -> RGMII
-- loopback -> RGMII RX -> SGMII PCS) and returns to the partner. At 100/10 Mbps
-- the SGMII line carries each octet replicated; the testbench injects the
-- replicated stream and decimates the recovered stream for comparison.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;

entity sgmii_to_rgmii_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of sgmii_to_rgmii_tb is

    type byte_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);

    signal rx_data  : byte_arr_t(0 to 1023);
    signal rx_count : natural := 0;

begin

    th: entity work.sgmii_to_rgmii_th;

    capture: process is
        alias clk   is << signal th.clk : std_logic >>;
        alias p_g2r is << signal th.p_g2r : gmii_t >>;
    begin
        wait until rising_edge(clk);
        if p_g2r.dv = '1' then
            rx_data(rx_count) <= p_g2r.data;
            rx_count          <= rx_count + 1;
        end if;
    end process;

    bench: process is

        alias clk         is << signal th.clk : std_logic >>;
        alias reset       is << signal th.reset : std_logic >>;
        alias tb_reset    is << signal th.tb_reset : std_logic >>;
        alias adv         is << signal th.adv : sgmii_config_t >>;
        alias p_r2g       is << signal th.p_r2g : gmii_t >>;
        alias p_r2g_ready is << signal th.p_r2g_ready : std_logic >>;
        alias bridge_link is << signal th.bridge_link : std_logic >>;
        alias part_link   is << signal th.partner_link : std_logic >>;

        -- inject one octet, replicated `rep` times onto the SGMII line
        procedure send_octet (constant d : in std_logic_vector(7 downto 0);
                              constant rep : in positive) is
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

        procedure run_frame (constant bytes : in byte_arr_t; constant sp : in eth_speed_t) is
            constant rep  : positive := speed_cycles_per_byte(sp);
            variable base : natural;
        begin
            -- bring the link up at the requested speed
            adv.speed <= sp;
            tb_reset  <= '1';
            wait for 200 ns;
            tb_reset  <= '0';
            if bridge_link /= '1' then
                wait until bridge_link = '1';
            end if;
            if part_link /= '1' then
                wait until part_link = '1';
            end if;
            wait for 1 us;

            base := rx_count;
            for i in bytes'range loop
                send_octet(bytes(i), rep);
            end loop;
            p_r2g.dv <= '0';
            wait for 20 us;

            -- the recovered stream is replicated `rep` times; decimate and compare
            check_true(rx_count - base >= bytes'length * rep - rep,
                       "recovered enough octets");
            for i in bytes'range loop
                check_equal(rx_data(base + i * rep), bytes(i),
                            "octet " & integer'image(i) & " round-trips");
            end loop;
        end procedure;

    begin
        test_runner_setup(runner, runner_cfg);
        p_r2g <= GMII_IDLE;
        wait until reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("bridge_1000") then
                run_frame((x"55", x"55", x"d5", x"de", x"ad", x"be", x"ef"), SPEED_1000);

            elsif run("bridge_100") then
                run_frame((x"55", x"d5", x"12", x"34"), SPEED_100);

            elsif run("bridge_10") then
                run_frame((x"55", x"d5", x"a5"), SPEED_10);
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 5 ms);

end tb;
