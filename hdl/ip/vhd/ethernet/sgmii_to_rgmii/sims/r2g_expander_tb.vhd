-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- r2g_expander stress test with a real ppm offset between the write (RGMII rxc)
-- and read (PCS) clock domains. The write side mimics the 100M RGMII RX (one
-- octet every two 25 MHz cycles) running 200 ppm SLOW relative to the read
-- side -- the worst case for mid-frame underrun, which pure cut-through fails:
-- the PCS consumes at exactly the nominal octet rate, so with no buffered head
-- start the read side catches the writer mid-frame, dv drops, and the frame is
-- truncated on the line with an early /T/. The store-and-forward threshold must
-- absorb the drift across a max-length frame; the checks assert every octet of
-- a 1518-octet frame arrives in one unbroken dv burst, frames do not merge, and
-- the FIFO never overflows.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

use work.gmii_pkg.all;

entity r2g_expander_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of r2g_expander_tb is

    -- 25 MHz minus ~200 ppm on the write side; read side exactly 125 MHz
    constant WR_PER : time := 40008 ps;
    constant RD_PER : time := 8 ns;

    constant FRAME1_LEN : natural := 1518;
    constant FRAME2_LEN : natural := 64;

    signal wr_clk : std_logic := '0';
    signal rd_clk : std_logic := '0';
    signal reset  : std_logic := '1';

    signal wr_data : std_logic_vector(7 downto 0) := (others => '0');
    signal wr_er   : std_logic := '0';
    signal wr_en   : std_logic := '0';

    signal gmii     : gmii_t;
    signal ready    : std_logic;
    signal byte_pop : std_logic;
    signal overflow : std_logic;

    -- read-side reconstruction (checker process is sole writer)
    type byte_arr_t is array (natural range <>) of std_logic_vector(7 downto 0);
    signal rx_data   : byte_arr_t(0 to FRAME1_LEN + FRAME2_LEN + 15);
    signal rx_count  : natural := 0;
    signal frame_len : natural := 0;   -- octets in the current dv burst
    signal len1      : natural := 0;
    signal len2      : natural := 0;
    signal nframes   : natural := 0;

    -- independent reconstruction from the deduplicated byte_pop tap
    signal pop_data  : byte_arr_t(0 to FRAME1_LEN + FRAME2_LEN + 15);
    signal pop_count : natural := 0;

begin

    wr_clk <= not wr_clk after WR_PER / 2;
    rd_clk <= not rd_clk after RD_PER / 2;
    reset  <= '0' after 200 ns;

    dut: entity work.r2g_expander
        port map (
            wr_clk     => wr_clk,
            wr_reset   => reset,
            wr_data    => wr_data,
            wr_er      => wr_er,
            wr_en      => wr_en,
            rd_clk     => rd_clk,
            rd_reset   => reset,
            speed      => SPEED_100,
            gmii       => gmii,
            gmii_ready => ready,
            byte_pop   => byte_pop,
            overflow   => overflow
        );

    -- the PCS TX accepts every cycle while in-frame; mimic that
    ready <= gmii.dv;

    -- reconstruct octets (first accept of each 10-accept group) and burst
    -- lengths; a mid-frame underrun shows up as a short first burst
    checker: process (rd_clk) is
        variable acc : natural range 0 to 9 := 0;
        variable dvp : std_logic := '0';
    begin
        if rising_edge(rd_clk) then
            if reset = '1' then
                acc := 0;
                dvp := '0';
            else
                if gmii.dv = '1' and ready = '1' then
                    if acc = 0 then
                        rx_data(rx_count) <= gmii.data;
                        rx_count          <= rx_count + 1;
                        frame_len         <= frame_len + 1;
                    end if;
                    if acc = 9 then
                        acc := 0;
                    else
                        acc := acc + 1;
                    end if;
                end if;
                if dvp = '1' and gmii.dv = '0' then
                    -- burst ended
                    if nframes = 0 then
                        len1 <= frame_len;
                    else
                        len2 <= frame_len;
                    end if;
                    nframes   <= nframes + 1;
                    frame_len <= 0;
                    acc       := 0;
                end if;
                dvp := gmii.dv;
            end if;
        end if;
    end process;

    -- the tap must deliver exactly one pulse per logical octet, while
    -- gmii.data still carries that octet
    pop_checker: process (rd_clk) is
    begin
        if rising_edge(rd_clk) then
            if reset = '1' then
                pop_count <= 0;
            elsif byte_pop = '1' then
                pop_data(pop_count) <= gmii.data;
                pop_count           <= pop_count + 1;
            end if;
        end if;
    end process;

    bench: process is
        procedure wr_octet (constant d : in std_logic_vector(7 downto 0)) is
        begin
            -- one octet every two wr_clk cycles, as the 100M RGMII RX produces
            wait until rising_edge(wr_clk);
            wr_data <= d;
            wr_en   <= '1';
            wait until rising_edge(wr_clk);
            wr_en   <= '0';
        end procedure;
    begin
        test_runner_setup(runner, runner_cfg);
        wait until reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("ppm_skew_no_truncation") then
                for i in 0 to FRAME1_LEN - 1 loop
                    wr_octet(std_logic_vector(to_unsigned(i mod 251, 8)));
                end loop;
                -- standard 12-octet inter-frame gap on the write side
                for i in 1 to 24 loop
                    wait until rising_edge(wr_clk);
                end loop;
                for i in 0 to FRAME2_LEN - 1 loop
                    wr_octet(std_logic_vector(to_unsigned((i + 7) mod 251, 8)));
                end loop;

                -- both frames must drain completely
                wait until nframes = 2 for 500 us;
                check_equal(nframes, 2, "both frames must appear as dv bursts");
                check_equal(len1, FRAME1_LEN,
                            "max-length frame truncated mid-burst (underrun)");
                check_equal(len2, FRAME2_LEN, "second frame length");
                check_equal(overflow, '0', "FIFO overflow");
                for i in 0 to FRAME1_LEN - 1 loop
                    check_equal(rx_data(i),
                                std_logic_vector(to_unsigned(i mod 251, 8)),
                                "frame 1 octet " & integer'image(i));
                end loop;
                for i in 0 to FRAME2_LEN - 1 loop
                    check_equal(rx_data(FRAME1_LEN + i),
                                std_logic_vector(to_unsigned((i + 7) mod 251, 8)),
                                "frame 2 octet " & integer'image(i));
                end loop;

                -- byte_pop tap: exactly one pulse per octet, data matching
                check_equal(pop_count, FRAME1_LEN + FRAME2_LEN,
                            "byte_pop pulses must match total octet count");
                for i in 0 to FRAME1_LEN + FRAME2_LEN - 1 loop
                    check_equal(pop_data(i), rx_data(i),
                                "byte_pop octet " & integer'image(i));
                end loop;
            end if;
        end loop;

        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

end tb;
