-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- DP83867 startup init: enables RGMII internal delay (RGMII-ID) so the PHY
-- centers RXC in the RX data eye and delays its TX sampling. The SZG-ENET1G's
-- PAP-package part has no DLL-skew straps, so this must be set over MDIO.
--
-- The delay controls live in the extended (MMD) register space, reached via the
-- Clause-45-over-Clause-22 indirect mechanism (REGCR 0x0D / ADDAR 0x0E, devad
-- 0x1F):
--   RGMIIDCTL (0x0086) = 0x71  -> TX delay 2.00 ns, RX delay 0.50 ns
--                                 (0.25 ns per step: 0x7 = 2.00, 0x1 = 0.50)
--   RGMIICTL  (0x0032) |= 0x03 -> enable TX (bit1) and RX (bit0) clock delay
-- RGMIICTL is read-modify-written so the reset defaults of its other bits are
-- preserved.
--
-- Why the RX delay is 0.50 ns rather than the 2.00 ns that centers RXC in the
-- eye at the pins: the FPGA captures RXD with rxc through a BUFG, whose ~2.7 ns
-- insertion delay is wider than the 2.4 ns eye the PHY guarantees (datasheet
-- SNLS484J section 6.9: +/-1.2 ns min about each edge). Centering at the pins
-- therefore lands the internal capture edge outside the data window and 1000M
-- fails hold by ~1 ns. Advancing the PHY's RX clock trades setup for hold
-- roughly 1:1, and this interface has ~3.4 ns of setup to spend, so 0.50 ns
-- puts both checks in the clear. See the RGMII timing section of
-- hdl/projects/xem8320_eth_mgmt/README.md for the measured numbers and the
-- setting-versus-margin table.
--
-- The value is a constant below because the RX figure must match the input
-- delays in each project's timing XDC; change them together.
--
-- It then restricts copper auto-negotiation to 100BASE-TX full duplex, so the
-- link comes up 100M regardless of the switch config (the bridge runs at a fixed
-- 100M). These are standard (directly-addressable) MII registers:
--   GBCR (0x09) = 0x0000  -> do not advertise 1000BASE-T
--   ANAR (0x04) = 0x0101  -> advertise 100BASE-TX full duplex only (802.3 sel)
--   BMCR (0x00) = 0x1200  -> auto-neg enable + restart

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity dp83867_init is
    generic (
        PHY_ADDR : std_logic_vector(4 downto 0) := "00000"   -- SZG-ENET1G straps 0
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        start : in    std_logic;   -- pulse once the PHY is out of reset
        done  : out   std_logic;   -- high after the sequence completes

        -- to mdio_master
        m_start   : out   std_logic;
        m_op_read : out   std_logic;
        m_reg     : out   std_logic_vector(4 downto 0);
        m_wr_data : out   std_logic_vector(15 downto 0);
        m_busy    : in    std_logic;
        m_done    : in    std_logic;
        m_rd_data : in    std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of dp83867_init is

    constant REGCR : std_logic_vector(4 downto 0) := "01101";   -- 0x0D
    constant ADDAR : std_logic_vector(4 downto 0) := "01110";   -- 0x0E
    constant BMCR  : std_logic_vector(4 downto 0) := "00000";   -- 0x00
    constant ANAR  : std_logic_vector(4 downto 0) := "00100";   -- 0x04
    constant GBCR  : std_logic_vector(4 downto 0) := "01001";   -- 0x09 (1000BASE-T ctrl)

    -- RGMIIDCTL: [7:4] TX clock delay, [3:0] RX clock delay, 0.25 ns per step
    -- (0x0 = 0.25 ns ... 0xF = 4.00 ns). Keep in step with the rgmii_rx_delay
    -- value in the projects' timing constraints.
    constant RGMII_TX_DELAY : std_logic_vector(3 downto 0) := x"7";   -- 2.00 ns
    constant RGMII_RX_DELAY : std_logic_vector(3 downto 0) := x"1";   -- 0.50 ns
    constant RGMIIDCTL_VAL  : std_logic_vector(15 downto 0) :=
        x"00" & RGMII_TX_DELAY & RGMII_RX_DELAY;

    constant LAST_STEP : integer := 11;

    type state_t is (IDLE, ISSUE, WAIT_DONE, COMPLETE);
    signal state : state_t := IDLE;

    signal step   : integer range 0 to LAST_STEP := 0;
    signal rmw    : std_logic_vector(15 downto 0) := (others => '0');

begin

    done <= '1' when state = COMPLETE else '0';

    -- command for the current step
    cmd: process (all) is
    begin
        m_op_read <= '0';
        m_reg     <= REGCR;
        m_wr_data <= (others => '0');
        case step is
            -- RGMIIDCTL (0x0086)
            when 0 => m_reg <= REGCR; m_wr_data <= x"001F";
            when 1 => m_reg <= ADDAR; m_wr_data <= x"0086";
            when 2 => m_reg <= REGCR; m_wr_data <= x"401F";
            when 3 => m_reg <= ADDAR; m_wr_data <= RGMIIDCTL_VAL;
            -- RGMIICTL (0x0032) |= 0x0003  (read-modify-write)
            when 4 => m_reg <= REGCR; m_wr_data <= x"001F";
            when 5 => m_reg <= ADDAR; m_wr_data <= x"0032";
            when 6 => m_reg <= REGCR; m_wr_data <= x"401F";
            when 7 => m_reg <= ADDAR; m_op_read <= '1';           -- read RGMIICTL
            when 8 => m_reg <= ADDAR; m_wr_data <= rmw or x"0003"; -- enable delays
            -- restrict copper auto-neg to 100BASE-TX full duplex
            when 9  => m_reg <= GBCR; m_wr_data <= x"0000";       -- no 1000BASE-T
            when 10 => m_reg <= ANAR; m_wr_data <= x"0101";       -- 100BASE-TX FD
            when others => m_reg <= BMCR; m_wr_data <= x"1200";   -- AN enable + restart
        end case;
    end process;

    seq: process (clk) is
    begin
        if rising_edge(clk) then
            m_start <= '0';

            case state is
                when IDLE =>
                    if start = '1' then
                        step  <= 0;
                        state <= ISSUE;
                    end if;

                when ISSUE =>
                    if m_busy = '0' then
                        m_start <= '1';
                        state   <= WAIT_DONE;
                    end if;

                when WAIT_DONE =>
                    if m_done = '1' then
                        if step = 7 then
                            rmw <= m_rd_data;      -- captured RGMIICTL
                        end if;
                        if step = LAST_STEP then
                            state <= COMPLETE;
                        else
                            step  <= step + 1;
                            state <= ISSUE;
                        end if;
                    end if;

                when COMPLETE =>
                    null;
            end case;

            if reset = '1' then
                state   <= IDLE;
                step    <= 0;
                m_start <= '0';
            end if;
        end if;
    end process;

end architecture;
