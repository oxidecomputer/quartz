-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII PCS testbench. The harness loops the line back on itself, so the PCS
-- negotiates with its own transmitter and then decodes frames it transmits.
-- Stimulus drives the r2g GMII octet stream through the valid/ready handshake;
-- a capture process records the decoded g2r octets for comparison.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.gmii_pkg.all;
use work.sgmii_pkg.all;

entity sgmii_pcs_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of sgmii_pcs_tb is

    type byte_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);

    -- capture buffer for the decoded receive stream (capture process is sole writer)
    signal rx_data  : byte_arr_t(0 to 255);
    signal rx_er    : std_logic_vector(0 to 255) := (others => '0');
    signal rx_count : natural := 0;

begin

    th: entity work.sgmii_pcs_th;

    -- record every decoded GMII octet
    capture: process is
        alias clk   is << signal th.clk : std_logic >>;
        alias reset is << signal th.reset : std_logic >>;
        alias g2r   is << signal th.g2r : gmii_t >>;
    begin
        wait until rising_edge(clk);
        if reset = '0' and g2r.dv = '1' then
            rx_data(rx_count) <= g2r.data;
            rx_er(rx_count)   <= g2r.er;
            rx_count          <= rx_count + 1;
        end if;
    end process;

    bench: process is

        alias clk       is << signal th.clk : std_logic >>;
        alias reset     is << signal th.reset : std_logic >>;
        alias r2g       is << signal th.r2g : gmii_t >>;
        alias r2g_ready is << signal th.r2g_ready : std_logic >>;
        alias link_up   is << signal th.link_up : std_logic >>;
        alias dut_speed is << signal th.speed : eth_speed_t >>;

        procedure send_octet (
            constant d  : in std_logic_vector(7 downto 0);
            constant er : in std_logic := '0'
        ) is
        begin
            r2g.data <= d;
            r2g.er   <= er;
            r2g.dv   <= '1';
            loop
                wait until rising_edge(clk);
                exit when r2g_ready = '1';
            end loop;
        end procedure;

        procedure send_frame (constant bytes : in byte_arr_t) is
        begin
            for i in bytes'range loop
                send_octet(bytes(i));
            end loop;
            r2g.dv <= '0';
            r2g.er <= '0';
        end procedure;

        variable base : natural;
    begin
        test_runner_setup(runner, runner_cfg);
        r2g <= GMII_IDLE;

        wait until reset = '0';
        wait for 500 ns;

        -- auto-negotiation must complete before any case runs
        if link_up /= '1' then
            wait until link_up = '1';
        end if;

        while test_suite loop
            if run("autoneg_link_up") then
                check_equal(link_up, '1', "link should be up after auto-neg");
                check_true(dut_speed = SPEED_1000, "resolved speed should be 1000");

            elsif run("frame_loopback") then
                base := rx_count;
                send_frame((x"55", x"55", x"d5", x"de", x"ad", x"be", x"ef"));
                wait for 3 us;
                check_equal(rx_count - base, 7, "should recover all 7 octets");
                check_equal(rx_data(base + 0), std_logic_vector'(x"55"), "octet 0 (/S/ -> preamble)");
                check_equal(rx_data(base + 2), std_logic_vector'(x"d5"), "SFD octet");
                check_equal(rx_data(base + 3), std_logic_vector'(x"de"), "payload 0");
                check_equal(rx_data(base + 6), std_logic_vector'(x"ef"), "payload 3");

            elsif run("two_frames_back_to_back") then
                base := rx_count;
                send_frame((x"55", x"11", x"22", x"33"));
                wait for 1 us;
                send_frame((x"55", x"44", x"55", x"66"));
                wait for 3 us;
                check_equal(rx_count - base, 8, "should recover both frames");
                check_equal(rx_data(base + 1), std_logic_vector'(x"11"), "frame 0 payload");
                check_equal(rx_data(base + 5), std_logic_vector'(x"44"), "frame 1 payload");

            elsif run("error_propagation") then
                base := rx_count;
                -- a mid-frame errored octet should surface as rx_er
                send_octet(x"55");
                send_octet(x"77");
                send_octet(x"88", er => '1');
                send_octet(x"99");
                r2g.dv <= '0';
                wait for 3 us;
                check_equal(rx_count - base, 4, "should recover 4 octets");
                check_equal(rx_er(base + 2), '1', "errored octet should set rx_er");
                check_equal(rx_er(base + 3), '0', "following octet should be clean");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 500 us);

end tb;
