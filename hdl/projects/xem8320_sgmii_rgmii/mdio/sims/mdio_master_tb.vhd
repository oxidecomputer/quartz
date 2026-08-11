-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Self-check for mdio_master: samples the emitted MDIO frame on the MDC rising
-- edges (as a PHY would) and checks the Clause-22 fields for a write, and checks
-- the read datapath captures 16 bits.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

entity mdio_master_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of mdio_master_tb is

    constant CLK_PER : time := 16 ns;   -- 62.5 MHz

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal start    : std_logic := '0';
    signal op_read  : std_logic := '0';
    signal phy_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal reg_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal wr_data  : std_logic_vector(15 downto 0) := (others => '0');
    signal busy     : std_logic;
    signal done     : std_logic;
    signal rd_data  : std_logic_vector(15 downto 0);

    signal mdc     : std_logic;
    signal mdio_o  : std_logic;
    signal mdio_oe : std_logic;
    signal mdio_i  : std_logic := '1';

    -- frame captured on MDC rising edges
    signal frame_rx : std_logic_vector(63 downto 0) := (others => '0');
    signal oe_ok    : boolean := true;
    signal capturing : boolean := false;

begin

    clk <= not clk after CLK_PER / 2;

    dut: entity work.mdio_master
        generic map (
            MDC_DIV_HALF => 4          -- fast MDC for a short sim
        )
        port map (
            clk => clk, reset => reset,
            start => start, op_read => op_read,
            phy_addr => phy_addr, reg_addr => reg_addr, wr_data => wr_data,
            busy => busy, done => done, rd_data => rd_data,
            mdc => mdc, mdio_o => mdio_o, mdio_oe => mdio_oe, mdio_i => mdio_i
        );

    -- sample the frame on MDC rising edges (PHY's sampling point)
    capture: process (mdc, capturing) is
    begin
        if capturing and rising_edge(mdc) then
            frame_rx <= frame_rx(62 downto 0) & mdio_o;
            -- during a write the master must drive the whole frame
            if op_read = '0' and mdio_oe /= '1' then
                oe_ok <= false;
            end if;
        end if;
    end process;

    bench: process is
    begin
        test_runner_setup(runner, runner_cfg);
        reset <= '1';
        wait for 5 * CLK_PER;
        wait until rising_edge(clk);
        reset <= '0';
        wait for 5 * CLK_PER;

        while test_suite loop

            if run("write_frame") then
                op_read  <= '0';
                phy_addr <= "00011";              -- 3
                reg_addr <= "01101";              -- 0x0D
                wr_data  <= x"401F";

                capturing <= true;
                wait until rising_edge(clk);
                start <= '1';
                wait until rising_edge(clk);
                start <= '0';

                wait until done = '1' for 200 us;
                check(done = '1', "write did not complete");
                capturing <= false;
                wait for 10 * CLK_PER;

                -- decode: preamble(63..32)=1, ST(31..30)=01, OP(29..28)=01,
                -- PHYAD(27..23), REGAD(22..18), TA(17..16)=10, DATA(15..0)
                check_equal(frame_rx(63 downto 32), std_logic_vector'(x"FFFFFFFF"), "preamble");
                check_equal(frame_rx(31 downto 30), std_logic_vector'("01"), "ST");
                check_equal(frame_rx(29 downto 28), std_logic_vector'("01"), "OP write");
                check_equal(frame_rx(27 downto 23), std_logic_vector'("00011"), "PHYAD");
                check_equal(frame_rx(22 downto 18), std_logic_vector'("01101"), "REGAD");
                check_equal(frame_rx(17 downto 16), std_logic_vector'("10"), "TA");
                check_equal(frame_rx(15 downto 0), std_logic_vector'(x"401F"), "DATA");
                check(oe_ok, "mdio_oe not driven throughout write");

            elsif run("read_capture") then
                op_read  <= '1';
                phy_addr <= "00000";
                reg_addr <= "01110";
                mdio_i   <= '1';                  -- PHY returns all ones
                wait until rising_edge(clk);
                start <= '1';
                wait until rising_edge(clk);
                start <= '0';

                wait until done = '1' for 200 us;
                check(done = '1', "read did not complete");
                check_equal(rd_data, std_logic_vector'(x"FFFF"), "read data (all ones)");
            end if;

        end loop;

        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

end architecture;
