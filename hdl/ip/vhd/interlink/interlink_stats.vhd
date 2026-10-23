-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.interlink_pkg.all;
use work.axi_st8_pkg;

-- Link statistics: the local counters, the periodic statistics packet we
-- send on channel 0, and the decoder for the partner's. The packet payload
-- is provisional, the RFD leaves it to the implementation.
--
-- The send interval is counted in IDLEs rather than characters because an
-- IDLE counter is a handful of bits and the cadence it gives (every n IDLEs)
-- is naturally slower than the partner's lock acquisition.
entity interlink_stats is
    generic (
        -- Send every n IDLEs, 0 disables the transmitter.
        STATS_INTERVAL_IDLES : natural;
        STATS_RX_ENABLE : boolean
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        clear : in std_logic;

        events : in link_events_t;
        status : in link_status_t;
        idle_sent : in std_logic;
        counters : out link_counters_t;

        -- Channel 0 source into the framer and channel 0 stream from the deframer
        stats_tx : view axi_st8_pkg.axi_st_pkt_source;
        stats_rx : view rx_source'converse;
        partner_counters : out link_counters_t;
        partner_counters_valid : out std_logic
    );
end entity;

architecture rtl of interlink_stats is
    signal counts : counter_array_t;
    signal status_flags : std_logic_vector(7 downto 0);
begin

    counters <= to_counters(counts);

    status_flags <= (
        STATS_FLAG_LOCKED => status.rx_locked,
        STATS_FLAG_INVERTED => status.rx_polarity_inverted,
        STATS_FLAG_SCRAMBLE => status.partner_scramble_enabled,
        STATS_FLAG_ALIGNED => status.rx_aligned,
        others => '0'
    );

    counters_reg: process(clk, reset)
    begin
        if reset then
            counts <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if clear then
                counts <= (others => (others => '0'));
            else
                for i in counts'range loop
                    counts(i) <= saturating_inc(counts(i), events(i));
                end loop;
            end if;
        end if;
    end process;

    tx_gen: if STATS_INTERVAL_IDLES /= 0 generate
        type reg_t is record
            idle_cnt : natural range 0 to STATS_INTERVAL_IDLES - 1;
            sending : std_logic;
            idx : natural range 0 to STATS_PKT_BYTES - 1;
            snapshot : counter_array_t;
            flags : std_logic_vector(7 downto 0);
        end record;
        constant rec_reset : reg_t := (
            idle_cnt => 0,
            sending => '0',
            idx => 0,
            snapshot => (others => (others => '0')),
            flags => (others => '0')
        );
        signal r, rin : reg_t;
    begin
        -- A snapshot keeps the packet self-consistent while it dribbles out
        -- a byte per character slot.
        stats_tx.valid <= r.sending;
        stats_tx.data <= stats_byte(r.snapshot, r.flags, r.idx);
        stats_tx.last <= '1' when r.idx = STATS_PKT_BYTES - 1 else '0';

        sm: process(all)
            variable v : reg_t;
        begin
            v := r;

            if idle_sent = '1' then
                if r.idle_cnt = STATS_INTERVAL_IDLES - 1 then
                    v.idle_cnt := 0;
                    -- If the last one is still going out we just skip a turn.
                    if r.sending = '0' then
                        v.snapshot := counts;
                        v.flags := status_flags;
                        v.idx := 0;
                        v.sending := '1';
                    end if;
                else
                    v.idle_cnt := r.idle_cnt + 1;
                end if;
            end if;

            if r.sending = '1' and stats_tx.ready = '1' then
                if r.idx = STATS_PKT_BYTES - 1 then
                    v.sending := '0';
                    v.idx := 0;
                else
                    v.idx := r.idx + 1;
                end if;
            end if;

            rin <= v;
        end process;

        reg: process(clk, reset)
        begin
            if reset then
                r <= rec_reset;
            elsif rising_edge(clk) then
                r <= rin;
            end if;
        end process;
    else generate
        stats_tx.valid <= '0';
        stats_tx.data <= (others => '0');
        stats_tx.last <= '0';
    end generate;

    rx_gen: if STATS_RX_ENABLE generate
        type byte_array_t is array (0 to STATS_PKT_BYTES - 1) of std_logic_vector(7 downto 0);
        signal buf : byte_array_t;
        signal count : natural range 0 to STATS_PKT_BYTES;
        signal valid : std_logic;
    begin
        partner_counters_valid <= valid;

        decode: process(clk, reset)
            variable arr : counter_array_t;
            variable bytes : byte_array_t;
        begin
            if reset then
                buf <= (others => (others => '0'));
                count <= 0;
                valid <= '0';
                partner_counters <= (others => (others => '0'));
            elsif rising_edge(clk) then
                valid <= '0';
                if stats_rx.valid = '1' then
                    -- The beat on the bus is the last byte of the packet when
                    -- last is set, so decode from a copy that includes it
                    -- rather than from the register it has not reached yet.
                    bytes := buf;
                    if count < STATS_PKT_BYTES then
                        bytes(count) := stats_rx.data;
                        count <= count + 1;
                    end if;
                    buf <= bytes;
                    if stats_rx.last = '1' then
                        count <= 0;
                        -- Only a complete, clean packet of a format we know
                        -- updates the partner's numbers.
                        if count = STATS_PKT_BYTES - 1 and stats_rx.error = '0' and bytes(0) = STATS_FORMAT then
                            for i in arr'range loop
                                arr(i) := unsigned(std_logic_vector'(bytes(2 + 2 * i) & bytes(3 + 2 * i)));
                            end loop;
                            partner_counters <= to_counters(arr);
                            valid <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end process;
    else generate
        partner_counters <= (others => (others => '0'));
        partner_counters_valid <= '0';
    end generate;

end rtl;
