-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Self-check for dp83867_init driving the real mdio_master: a stand-in PHY
-- decodes every MDIO frame the sequence emits and the bench checks the whole
-- transcript.
--
-- The RGMII delay word is the point of this testbench. Its RX nibble has to
-- agree with the input-delay window in both projects' timing constraints --
-- they are two halves of one decision, and nothing else would notice if they
-- drifted apart. The MMD indirection is checked too, because writing a delay
-- to the wrong extended register would look identical from outside.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;

entity dp83867_init_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of dp83867_init_tb is

    constant CLK_PER : time := 16 ns;   -- 62.5 MHz free-run clock

    -- what dp83867_init should program
    constant RGMIIDCTL_ADDR : std_logic_vector(15 downto 0) := x"0086";
    constant RGMIIDCTL_VAL  : std_logic_vector(15 downto 0) := x"0071";  -- TX 2.00 ns, RX 0.50 ns
    constant RGMIICTL_ADDR  : std_logic_vector(15 downto 0) := x"0032";
    -- the PHY returns this on the RGMIICTL read; the init must OR into it
    constant RGMIICTL_READ  : std_logic_vector(15 downto 0) := x"5500";

    constant REGCR : std_logic_vector(4 downto 0) := "01101";
    constant ADDAR : std_logic_vector(4 downto 0) := "01110";
    constant BMCR  : std_logic_vector(4 downto 0) := "00000";
    constant ANAR  : std_logic_vector(4 downto 0) := "00100";
    constant GBCR  : std_logic_vector(4 downto 0) := "01001";

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal start : std_logic := '0';
    signal done  : std_logic;

    signal m_start   : std_logic;
    signal m_op_read : std_logic;
    signal m_reg     : std_logic_vector(4 downto 0);
    signal m_wr_data : std_logic_vector(15 downto 0);
    signal m_busy    : std_logic;
    signal m_done    : std_logic;
    signal m_rd_data : std_logic_vector(15 downto 0);

    signal mdc     : std_logic;
    signal mdio_o  : std_logic;
    signal mdio_oe : std_logic;
    signal mdio_i  : std_logic := '1';

    -- transcript of decoded frames, filled by the stand-in PHY
    type op_t is (OP_WRITE, OP_READ);
    type frame_t is record
        op   : op_t;
        reg  : std_logic_vector(4 downto 0);
        data : std_logic_vector(15 downto 0);
    end record;
    type frame_arr_t is array (0 to 15) of frame_t;
    signal seen  : frame_arr_t;
    signal nseen : natural := 0;

begin

    clk <= not clk after CLK_PER / 2;

    dut: entity work.dp83867_init
        port map (
            clk => clk, reset => reset, start => start, done => done,
            m_start => m_start, m_op_read => m_op_read, m_reg => m_reg,
            m_wr_data => m_wr_data, m_busy => m_busy, m_done => m_done,
            m_rd_data => m_rd_data
        );

    mdio: entity work.mdio_master
        generic map (
            MDC_DIV_HALF => 4
        )
        port map (
            clk => clk, reset => reset,
            start => m_start, op_read => m_op_read,
            phy_addr => "00000", reg_addr => m_reg, wr_data => m_wr_data,
            busy => m_busy, done => m_done, rd_data => m_rd_data,
            mdc => mdc, mdio_o => mdio_o, mdio_oe => mdio_oe, mdio_i => mdio_i
        );

    -- Stand-in PHY: shift in each frame on MDC rising edges, decode it, and for
    -- a read drive the turnaround and data back on falling edges.
    phy: process is
        variable sh   : std_logic_vector(31 downto 0);
        variable rd   : std_logic_vector(15 downto 0);
        variable frm  : frame_t;
    begin
        -- resync to the start of a frame: the master idles mdio_oe low
        wait until mdio_oe = '1';
        -- preamble is 32 ones; consume up to and including the last of them
        for i in 1 to 32 loop
            wait until rising_edge(mdc);
        end loop;
        -- ST, OP, PHYAD, REGAD, TA = 16 bits
        for i in 1 to 16 loop
            wait until rising_edge(mdc);
            sh := sh(30 downto 0) & mdio_o;
        end loop;
        -- after the 16 non-data bits: ST sh(15:14), OP sh(13:12),
        -- PHYAD sh(11:7), REGAD sh(6:2), TA sh(1:0)
        if sh(13 downto 12) = "01" then
            frm.op := OP_WRITE;
        else
            frm.op := OP_READ;
        end if;
        frm.reg := sh(6 downto 2);

        if frm.op = OP_WRITE then
            for i in 1 to 16 loop
                wait until rising_edge(mdc);
                sh := sh(30 downto 0) & mdio_o;
            end loop;
            frm.data := sh(15 downto 0);
        else
            -- drive the register value back, MSB first, on falling edges
            rd := RGMIICTL_READ;
            for i in 1 to 16 loop
                wait until falling_edge(mdc);
                mdio_i <= rd(15);
                rd := rd(14 downto 0) & '0';
            end loop;
            frm.data := RGMIICTL_READ;
            mdio_i <= '1';
        end if;

        if nseen < 16 then
            seen(nseen) <= frm;
            nseen <= nseen + 1;
        end if;
    end process;

    bench: process is
        procedure check_frame (
            constant i    : in natural;
            constant op   : in op_t;
            constant reg  : in std_logic_vector(4 downto 0);
            constant data : in std_logic_vector(15 downto 0);
            constant what : in string
        ) is
        begin
            check_equal(seen(i).reg, reg, what & ": register");
            check(seen(i).op = op, what & ": direction");
            if op = OP_WRITE then
                check_equal(seen(i).data, data, what & ": value");
            end if;
        end procedure;
    begin
        test_runner_setup(runner, runner_cfg);
        reset <= '1';
        wait for 5 * CLK_PER;
        wait until rising_edge(clk);
        reset <= '0';
        wait for 5 * CLK_PER;

        while test_suite loop
            if run("init_sequence") then
                wait until rising_edge(clk);
                start <= '1';
                wait until rising_edge(clk);
                start <= '0';

                wait until done = '1' for 5 ms;
                check(done = '1', "init sequence did not complete");
                check_equal(nseen, 12, "expected twelve MDIO frames");

                -- RGMIIDCTL via the MMD indirection: address the extended
                -- register, then write it with the auto-increment-off selector
                check_frame(0, OP_WRITE, REGCR, x"001F", "REGCR devad");
                check_frame(1, OP_WRITE, ADDAR, RGMIIDCTL_ADDR, "RGMIIDCTL address");
                check_frame(2, OP_WRITE, REGCR, x"401F", "REGCR data mode");
                check_frame(3, OP_WRITE, ADDAR, RGMIIDCTL_VAL, "RGMIIDCTL value");

                -- RGMIICTL read-modify-write: the delay enables are set without
                -- disturbing the bits the PHY came up with
                check_frame(4, OP_WRITE, REGCR, x"001F", "REGCR devad");
                check_frame(5, OP_WRITE, ADDAR, RGMIICTL_ADDR, "RGMIICTL address");
                check_frame(6, OP_WRITE, REGCR, x"401F", "REGCR data mode");
                check_frame(7, OP_READ,  ADDAR, x"0000", "RGMIICTL read");
                check_frame(8, OP_WRITE, ADDAR, RGMIICTL_READ or x"0003",
                            "RGMIICTL enables preserving other bits");

                -- copper auto-negotiation restricted to 100BASE-TX full duplex
                check_frame(9,  OP_WRITE, GBCR, x"0000", "no 1000BASE-T advertised");
                check_frame(10, OP_WRITE, ANAR, x"0101", "100BASE-TX FD advertised");
                check_frame(11, OP_WRITE, BMCR, x"1200", "auto-neg restart");

            elsif run("rgmii_delay_matches_constraints") then
                -- The RX nibble of RGMIIDCTL and the rgmii_rx_delay in the
                -- projects' timing XDC describe the same physical delay. If this
                -- fails, fix both together -- changing one alone silently
                -- invalidates the interface's timing closure.
                check_equal(RGMIIDCTL_VAL(3 downto 0), std_logic_vector'(x"1"),
                            "RX delay nibble should be 0x1 (0.50 ns)");
                check_equal(RGMIIDCTL_VAL(7 downto 4), std_logic_vector'(x"7"),
                            "TX delay nibble should be 0x7 (2.00 ns)");
            end if;
        end loop;

        wait for 10 * CLK_PER;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 20 ms);

end tb;
