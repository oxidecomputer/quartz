-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Self-check for sgmii_gearbox: the 2:1 width conversion and the comma bit-slip
-- re-alignment. Drives a deliberately mis-framed 20-bit stream of alternating
-- comma / data code groups and checks the gearbox locks and recovers the exact
-- 10-bit code-group stream; also packs a known 10-bit stream and checks the
-- 20-bit output; and confirms the gearbox K28.5 constants match this repo's
-- 8b10b encoder (i.e. the bit order is right for real hardware).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

use work.helper_8b10b_pkg.all;

entity sgmii_gearbox_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of sgmii_gearbox_tb is

    constant CLK_PER : time := 8 ns;   -- 125 MHz

    -- code-group patterns (transmission order, bit 0 = 'a'); comma matches the
    -- gearbox constant, data is an arbitrary non-comma group.
    constant G_COMMA : std_logic_vector(9 downto 0) := "0101111100";
    constant G_DATA  : std_logic_vector(9 downto 0) := "1001101000";
    constant OFFSET  : natural := 3;   -- deliberate mis-framing

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal word_stb   : std_logic := '0';
    signal gt_rx_data : std_logic_vector(19 downto 0) := (others => '0');
    signal gt_tx_data : std_logic_vector(19 downto 0);
    signal rx_code    : std_logic_vector(9 downto 0);
    signal rx_aligned : std_logic;
    signal tx_code    : std_logic_vector(9 downto 0) := (others => '0');

begin

    clk <= not clk after CLK_PER / 2;

    dut: entity work.sgmii_gearbox
        port map (
            clk        => clk,
            reset      => reset,
            word_stb   => word_stb,
            gt_rx_data => gt_rx_data,
            gt_tx_data => gt_tx_data,
            rx_code    => rx_code,
            rx_aligned => rx_aligned,
            tx_code    => tx_code
        );

    bench: process is

        constant NG    : natural := 200;                 -- code groups in the stream
        constant NBITS : natural := OFFSET + 10 * NG;
        constant NWORD : natural := NBITS / 20;

        variable stream : std_logic_vector(0 to NBITS - 1) := (others => '0');
        variable g      : std_logic_vector(9 downto 0);
        variable word   : std_logic_vector(19 downto 0);

        variable aligned_seen : boolean := false;
        variable n_checked    : natural := 0;
        variable n_comma      : natural := 0;
        variable n_bad        : natural := 0;

        constant enc_rd0 : encoded_8b10b_t := encode(K28_5, '1', '0');
        constant enc_rd1 : encoded_8b10b_t := encode(K28_5, '1', '1');
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop

            if run("comma_constants") then
                -- the two K28.5 encodings must be exactly the gearbox's comma
                -- constants (proves the bit order matches this repo's codec)
                check((enc_rd0.data = "0101111100" and enc_rd1.data = "1010000011") or
                      (enc_rd0.data = "1010000011" and enc_rd1.data = "0101111100"),
                      "K28.5 encodings " & to_string(enc_rd0.data) & "/" &
                      to_string(enc_rd1.data) & " do not match the gearbox comma constants");

            elsif run("rx_align") then
                -- build a mis-framed alternating comma/data stream
                for k in 0 to NG - 1 loop
                    if k mod 2 = 0 then
                        g := G_COMMA;
                    else
                        g := G_DATA;
                    end if;
                    for j in 0 to 9 loop
                        stream(OFFSET + 10 * k + j) := g(j);
                    end loop;
                end loop;

                reset <= '1';
                wait for 5 * CLK_PER;
                wait until rising_edge(clk);
                reset <= '0';

                for n in 0 to NWORD - 1 loop
                    for i in 0 to 19 loop
                        word(i) := stream(20 * n + i);
                    end loop;
                    gt_rx_data <= word;

                    -- word_stb high for the first of the two clk cycles
                    word_stb <= '1';
                    wait until rising_edge(clk);
                    if rx_aligned = '1' then
                        aligned_seen := true;
                    end if;
                    if aligned_seen then
                        n_checked := n_checked + 1;
                        if rx_code = G_COMMA then
                            n_comma := n_comma + 1;
                        elsif rx_code /= G_DATA then
                            n_bad := n_bad + 1;
                        end if;
                    end if;

                    word_stb <= '0';
                    wait until rising_edge(clk);
                    if rx_aligned = '1' then
                        aligned_seen := true;
                    end if;
                    if aligned_seen then
                        n_checked := n_checked + 1;
                        if rx_code = G_COMMA then
                            n_comma := n_comma + 1;
                        elsif rx_code /= G_DATA then
                            n_bad := n_bad + 1;
                        end if;
                    end if;
                end loop;

                check(aligned_seen, "gearbox never aligned");
                check(n_checked > 40, "not enough post-align samples");
                -- once aligned every code group must be one of the two patterns
                check_equal(n_bad, 0, "garbage code group(s) after alignment");
                -- and the comma cadence (every other group) must be recovered
                check(n_comma > n_checked / 4, "commas not recovered at cadence");

            elsif run("tx_pack") then
                reset <= '1';
                wait for 5 * CLK_PER;
                wait until rising_edge(clk);
                reset <= '0';

                -- first (older) symbol on the word_stb cycle, second on the next
                tx_code  <= G_COMMA;
                word_stb <= '1';
                wait until rising_edge(clk);
                tx_code  <= G_DATA;
                word_stb <= '0';
                wait until rising_edge(clk);   -- gt_tx_data updates this edge
                wait until rising_edge(clk);   -- settle

                check_equal(gt_tx_data(9 downto 0), G_COMMA, "tx low half (older symbol)");
                check_equal(gt_tx_data(19 downto 10), G_DATA, "tx high half (newer symbol)");
            end if;

        end loop;

        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

end architecture;
