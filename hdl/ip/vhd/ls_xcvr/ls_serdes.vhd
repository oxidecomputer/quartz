-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.transforms_pkg.all;

entity ls_serdes is
    generic(
        NOMINAL_SAMPLE_CNTS : positive;
        DATA_WIDTH : positive;
        SYNCHRONIZE : boolean
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        -- Serial interface
        serial_in   : in  std_logic;
        serial_out  : out std_logic;
        -- Parallel interface
        data_out    : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_out_valid : out std_logic;
        data_out_ready : in  std_logic;
        data_in     : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_in_valid : in  std_logic;
        data_in_ready : out std_logic;
        -- control interface
        bit_slip   : in  std_logic;
        invert_rx  : in  std_logic

    );
end entity;

architecture rtl of ls_serdes is
    -- On the rx side, we want to sample at the mid-point of the bit period.
    constant SAMPLE_POINT : integer := (NOMINAL_SAMPLE_CNTS - 1) / 2;
    signal rx_buffer : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal tx_buffer : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin

    -- We want to sample at the middle of the bit period so we need to reset the counter
    -- when we see bit transitions.
    deserializer: block
        signal sample_cnts : integer range 0 to NOMINAL_SAMPLE_CNTS - 1;
        signal bit_cnts : integer range 0 to DATA_WIDTH - 1;
        signal transition : std_logic;
        signal serial_in_syncd : std_logic;
        signal serial_in_final : std_logic;
        signal serial_in_syncd_last : std_logic;
        signal bit_slip_pend : std_logic;
    begin

        -- We may be using LVDS primitives so data may already be sycn'd
        sync_gen: if SYNCHRONIZE generate
            -- meta sync serial_in
            scl_meta:entity work.meta_sync
            port map(
               async_input => serial_in,
               clk => clk,
               sycnd_output => serial_in_syncd
           );
        else generate
            serial_in_syncd <= serial_in;
        end generate;

        -- transition detector
        transition_det: process(clk, reset)
        begin
            if reset then
                serial_in_syncd_last <= '0';
            elsif rising_edge(clk) then
                serial_in_syncd_last <= serial_in_syncd;
            end if;
        end process;
        transition <= serial_in_syncd xor serial_in_syncd_last;

        serial_in_final <= serial_in_syncd when invert_rx = '0' else not serial_in_syncd;


        sampler: process(clk, reset)
        begin
            if reset then
                -- reset the counter
                sample_cnts <= 0;
                bit_cnts <= 0;
                data_out_valid <= '0';
                bit_slip_pend <= '0';
            elsif rising_edge(clk) then
                if bit_slip = '1' then
                    bit_slip_pend <= '1';
                end if;
                if data_out_ready and data_out_valid then
                    data_out_valid <= '0';
                end if;
                if sample_cnts = SAMPLE_POINT then
                    -- always shift in at the end of the sample period
                    rx_buffer <= shift_in_at_high(rx_buffer, serial_in_final);
                    sample_cnts <= sample_cnts + 1;
                    -- increment bit counter (rollover) so long as we're not bit-slipping
                    if not bit_slip_pend then
                        -- increment the bit counter
                        if bit_cnts = DATA_WIDTH - 1 then
                            -- reset the bit counter
                            bit_cnts <= 0;
                            -- set the output valid signal
                            data_out_valid <= '1';
                        else
                            -- increment the bit counter
                            bit_cnts <= bit_cnts + 1;
                        end if;
                    else
                        -- slipping, clear flag, but don't count
                        bit_slip_pend <= '0';
                    end if;
                else
                    if transition = '1' or sample_cnts = NOMINAL_SAMPLE_CNTS - 1 then
                        -- reset the sample counter
                        -- If we were set to sample here, we certainly don't want to do so
                        -- as we've become un-aligned with the data rate.
                        -- this provides a pseudo-cdr, and re-aligns to the incoming data stream
                        sample_cnts <= 0;
                    else
                        -- increment the sample counter
                        sample_cnts <= sample_cnts + 1;
                    end if;
                end if;
            end if;
        end process;

    end block;
    data_out <= rx_buffer;

    serializer: block
        signal sample_cnts : integer range 0 to NOMINAL_SAMPLE_CNTS - 1 := 0;
        signal bit_cnts : integer range 0 to DATA_WIDTH - 1 := 0;
    begin

        tx: process(clk, reset)
        begin
            if reset then
                bit_cnts <= 0;
                sample_cnts <= 0;
                tx_buffer <= (others => '0');
            elsif rising_edge(clk) then

                if sample_cnts = NOMINAL_SAMPLE_CNTS - 1 then
                    sample_cnts <= 0;
                    if data_in_ready = '1' and data_in_valid = '1' then
                        tx_buffer <= data_in;
                        bit_cnts <= 0;
                    else
                        tx_buffer <= shift_right(tx_buffer, 1);
                        if bit_cnts = DATA_WIDTH - 1 then
                            -- reset the bit counter
                            bit_cnts <= 0;
                        else
                            bit_cnts <= bit_cnts + 1;
                        end if;
                    end if;
                else
                    sample_cnts <= sample_cnts + 1;
                end if;

            end if;
        end process;
        data_in_ready <= '1' when sample_cnts = NOMINAL_SAMPLE_CNTS - 1 and bit_cnts = DATA_WIDTH - 1 else '0';
        serial_out <= tx_buffer(tx_buffer'low);
    end block;

end rtl;