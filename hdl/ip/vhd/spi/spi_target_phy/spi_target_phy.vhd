-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Simple SPI shifter PHY
-- shifts on sclk edges (post synchronizer) when chipselect is asserted low
-- "streaming" interface for data in and out, but due to the nature of SPI
-- there's no real backpressure here, so if you don't ack the valid rx data,
-- or provide the valid tx data in the appropriate window (approx 1/2 sclk period)
-- you missed the window. This block will overwrite the data in this case.
-- If you want more timing flexibility upstream, you'll need to add some
-- fifos or other buffering, but then have to deal with clearing down those
-- if chipsel is unexpectedly de-asserted.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.transforms_pkg.all;

entity spi_target_phy is
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- spi pins
        -- We're running these through meta sync so there's a rate limit
        -- here, related to your clock frequency
        csn  : in std_logic;
        sclk : in std_logic;
        copi : in std_logic;
        cipo : out std_logic;

        csn_syncd : out std_logic;
        -- streaming interface
        -- note that back pressure doesn't really make sense here
        -- so while this is a "streaming" interface, and there's a bit of timing
        -- flexibility, it's not really a back-pressureable interface in that
        -- you can't stall the transaction.  You have to either accept the data
        -- that's coming at line rate, and respond accordingly or you miss it.
        rx_data : out std_logic_vector(7 downto 0);
        rx_valid : out std_logic;
        rx_ready : in std_logic;

        tx_data : in std_logic_vector(7 downto 0);
        tx_valid : in std_logic;
        tx_ready : out std_logic

    );
end entity;

architecture rtl of spi_target_phy is

    signal sclk_syncd : std_logic;
    signal copi_syncd : std_logic;
    signal in_reg : std_logic_vector(7 downto 0);
    signal out_reg : std_logic_vector(7 downto 0);
    signal sclk_fedge : std_logic;
    signal sclk_redge : std_logic;
    signal sclk_last : std_logic;
    signal tx_bit_cnt   : std_logic_vector(2 downto 0);
    signal rx_bit_cnt   : std_logic_vector(2 downto 0);

    type   buffer_t is record
        data : std_logic_vector(7 downto 0);
        empty : std_logic;
    end record;
    signal tx_buffer : buffer_t;
    signal rx_buffer : buffer_t;
    signal first_bit_txd : std_logic;

begin

    -- Synchronize the async inputs, we have 3 of them here
    cs_meta_sync_inst: entity work.meta_sync
    port map(
        async_input => csn,
        clk => clk,
        sycnd_output => csn_syncd
    );

    sclk_meta_sync_inst: entity work.meta_sync
    port map(
        async_input => sclk,
        clk => clk,
        sycnd_output => sclk_syncd
    );

    data_meta_sync_inst: entity work.meta_sync
    port map(
        async_input => copi,
        clk => clk,
        sycnd_output => copi_syncd
    );

    -- Detect sclk edges, we'll need both redge and fedge
    sclk_edge_mon: process(clk, reset)
     begin
        if reset then
            sclk_last <= '0';
        elsif rising_edge(clk) then
            sclk_last <= sclk_syncd;
        end if;
    end process;
    sclk_redge <= sclk_syncd and not sclk_last;
    sclk_fedge <= not sclk_syncd and sclk_last;


    -- SPI is typically MSB first
    -- We're using a sentinel bit to indicate shifting is done
    -- rather than a counter
    -- sample on rising sclk
    in_shifter: process(clk, reset)
        variable new_value : std_logic_vector(7 downto 0);
    begin
        if reset = '1' then
            in_reg <= (others => '0');
            rx_bit_cnt <= (others => '0');
            rx_buffer <= (data => (others => '0'), empty => '1');
        elsif rising_edge(clk) then

            if csn_syncd = '1' then
                rx_buffer.empty <= '1';
            elsif rx_valid = '1' and rx_ready = '1' then
                rx_buffer.empty <= '1';
                -- read and store same cycle is dealt with 
                -- below, where if we store again, empty will be cleared
            end if;

            if csn_syncd = '1' then
                -- reset shifter, chip-sel is de-asserted
                in_reg <= (others => '0');
                rx_bit_cnt <= (others => '0');
            elsif sclk_redge = '1' then
                rx_bit_cnt <= rx_bit_cnt + 1;
                new_value := shift_in_at_0(in_reg, copi_syncd);
                in_reg <= new_value;
                if rx_bit_cnt = 7 then
                    rx_buffer.data <= new_value;
                    rx_buffer.empty <= '0';
                    rx_bit_cnt <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    --Outputs
    -- we hand out the parallel data from the shift register all the time
    -- and we use the upper bit as the valid signal, it's only high when the
    -- sentinel bit has shifted all the way up.
    rx_data <= in_reg;
    rx_valid <= not rx_buffer.empty;

    -- msb 1st
    -- shift out on falling sclk.
    out_shifter: process(clk, reset)
    begin
        if reset = '1' then
            out_reg <= (others => '0');
            tx_bit_cnt <= (others => '0');
            tx_buffer <= (data => (others => '0'), empty => '1');
            first_bit_txd <= '0';
        elsif rising_edge(clk) then

            -- Deal with the tx_buffer, in front of the pipeline
            -- upstream needs to beat our need for data by at least
            -- one clk (fast, not sclk) cycle.  This should be no problem
            if csn_syncd = '1' then
                tx_buffer.empty <= '1';
            elsif tx_valid = '1' and tx_ready = '1' then
                tx_buffer.data <= tx_data;
                tx_buffer.empty <= '0';
            end if;

            if csn_syncd = '1' then
                -- reset shifter, chip-sel is de-asserted
                out_reg <= (others => '0');
                first_bit_txd <= '0';
                tx_bit_cnt <= (others => '0');
            elsif sclk_fedge = '1' then
                tx_bit_cnt <= tx_bit_cnt + 1;
                out_reg <= shift_left(out_reg, 1);
                if tx_bit_cnt = 7 then
                    if tx_buffer.empty = '0' then
                        out_reg <= tx_buffer.data;
                        tx_buffer.empty <= '1';
                    end if;
                    tx_bit_cnt <= (others => '0');
                end if;
            end if;
            
        end if;
    end process;

    -- Outputs:
    -- Ready to accept when out buffer is empty and we're chip-selected.
    tx_ready <= '1' when tx_buffer.empty = '1' and csn_syncd = '0' else '0';
    -- Out bit is always the msb of the register
    cipo <= out_reg(out_reg'high);
end rtl;