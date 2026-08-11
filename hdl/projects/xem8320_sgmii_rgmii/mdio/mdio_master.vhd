-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Minimal IEEE 802.3 Clause-22 MDIO master. Drives one read or write MDIO frame
-- per `start` pulse:
--
--   preamble(32x'1') ST(01) OP(W=01/R=10) PHYAD(5) REGAD(5) TA(2) DATA(16)
--
-- MDIO output changes on the MDC falling edge and is sampled by the PHY on the
-- rising edge; for reads the master tri-states during the turnaround and samples
-- DATA on the rising edges. MDC frequency is CLK_HZ / (2*MDC_DIV_HALF).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity mdio_master is
    generic (
        -- MDC half-period in `clk` cycles. Default gives ~2.5 MHz from 62.5 MHz.
        MDC_DIV_HALF : positive := 13
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- command interface
        start    : in    std_logic;                     -- pulse to launch a frame
        op_read  : in    std_logic;                     -- '1' read, '0' write
        phy_addr : in    std_logic_vector(4 downto 0);
        reg_addr : in    std_logic_vector(4 downto 0);
        wr_data  : in    std_logic_vector(15 downto 0);
        busy     : out   std_logic;
        done     : out   std_logic;                     -- one-cycle pulse at end
        rd_data  : out   std_logic_vector(15 downto 0);

        -- MDIO pins (mdio is tri-state: drive mdio_o when mdio_oe = '1')
        mdc     : out   std_logic;
        mdio_o  : out   std_logic;
        mdio_oe : out   std_logic;
        mdio_i  : in    std_logic
    );
end entity;

architecture rtl of mdio_master is

    type state_t is (IDLE, RUN, FINISH);
    signal state : state_t := IDLE;

    signal mdc_cnt  : integer range 0 to MDC_DIV_HALF - 1 := 0;
    signal mdc_r    : std_logic := '1';
    signal mdc_fall : std_logic;
    signal mdc_rise : std_logic;

    signal bit_idx  : integer range 0 to 63 := 0;
    signal frame    : std_logic_vector(63 downto 0);
    signal is_read  : std_logic := '0';
    signal rd_shift : std_logic_vector(15 downto 0) := (others => '0');

begin

    busy <= '0' when state = IDLE else '1';

    -- MDC generation + edge strobes
    mdc <= mdc_r;

    mdc_gen: process (clk) is
    begin
        if rising_edge(clk) then
            mdc_fall <= '0';
            mdc_rise <= '0';
            if state = IDLE then
                mdc_cnt <= 0;
                mdc_r   <= '1';
            elsif mdc_cnt = MDC_DIV_HALF - 1 then
                mdc_cnt <= 0;
                mdc_r   <= not mdc_r;
                if mdc_r = '1' then
                    mdc_fall <= '1';   -- about to go low
                else
                    mdc_rise <= '1';   -- about to go high
                end if;
            else
                mdc_cnt <= mdc_cnt + 1;
            end if;
        end if;
    end process;

    -- Frame shifter. Present each bit on the MDC falling edge; for reads sample
    -- DATA on the rising edge.
    frame_proc: process (clk) is
    begin
        if rising_edge(clk) then
            done <= '0';

            case state is

                when IDLE =>
                    mdio_oe <= '0';
                    mdio_o  <= '1';
                    if start = '1' then
                        is_read <= op_read;
                        -- assemble the 64-bit frame, MSB (frame(63)) sent first
                        frame(63 downto 32) <= (others => '1');            -- preamble
                        frame(31 downto 30) <= "01";                       -- ST
                        frame(29 downto 28) <= op_read & not op_read;       -- OP: W=01 R=10
                        frame(27 downto 23) <= phy_addr;
                        frame(22 downto 18) <= reg_addr;
                        frame(17 downto 16) <= "10";                       -- TA (write)
                        frame(15 downto 0)  <= wr_data;
                        bit_idx <= 0;
                        state   <= RUN;
                    end if;

                when RUN =>
                    -- drive bit on falling edge
                    if mdc_fall = '1' then
                        mdio_o <= frame(63 - bit_idx);
                        -- output-enable: header (0..45) always driven; TA+DATA
                        -- (46..63) driven only for writes.
                        if bit_idx <= 45 then
                            mdio_oe <= '1';
                        elsif is_read = '1' then
                            mdio_oe <= '0';
                        else
                            mdio_oe <= '1';
                        end if;
                    end if;

                    -- sample read DATA on rising edge, then advance
                    if mdc_rise = '1' then
                        if is_read = '1' and bit_idx >= 48 then
                            rd_shift <= rd_shift(14 downto 0) & mdio_i;
                        end if;
                        if bit_idx = 63 then
                            state <= FINISH;
                        else
                            bit_idx <= bit_idx + 1;
                        end if;
                    end if;

                when FINISH =>
                    mdio_oe <= '0';
                    rd_data <= rd_shift;
                    done    <= '1';
                    state   <= IDLE;

            end case;

            if reset = '1' then
                state   <= IDLE;
                mdio_oe <= '0';
                mdio_o  <= '1';
                done    <= '0';
            end if;
        end if;
    end process;

end architecture;
