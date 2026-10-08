-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;
use work.interlink_pkg.all;
use work.interlink_sim_pkg.all;
use work.axi_st8_pkg;

-- Two link ends, A and B, joined by a wire model in each direction. With
-- SERIAL false the 10-bit symbols go straight across, one per CHAR_GAP
-- clocks, which is fast and is where most of the testing happens. With
-- SERIAL true each end gets an ls_serdes and the two are joined by actual
-- serial wires, which is slow but exercises bit alignment and polarity the
-- way hardware would.
--
-- Every user channel has a packet source and a capturing sink at each end.
entity interlink_th is
    generic (
        SERIAL : boolean := false;
        CHAR_GAP : positive := 1;
        PREEMPT_CHANNEL : natural := sim_preempt_channel;
        IDLE_INTERVAL_LOCKED : positive := 4470;
        IDLE_INTERVAL_FAST : positive := 32;
        IDLES_TO_LOCK : positive := 2;
        STATS_INTERVAL_IDLES : natural := 8
    );
end entity;

architecture th of interlink_th is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';

    signal a_serdes : serdes_if_t;
    signal b_serdes : serdes_if_t;
    signal a_tx_chans : axi_st8_pkg.axi_st_pkt_array_t(1 to sim_num_channels);
    signal b_tx_chans : axi_st8_pkg.axi_st_pkt_array_t(1 to sim_num_channels);
    signal a_rx_chans : rx_st_array_t(1 to sim_num_channels);
    signal b_rx_chans : rx_st_array_t(1 to sim_num_channels);
    signal a_status : link_status_t;
    signal b_status : link_status_t;
    signal a_counters : link_counters_t;
    signal b_counters : link_counters_t;
    signal a_partner : link_counters_t;
    signal b_partner : link_counters_t;
    signal a_partner_valid : std_logic;
    signal b_partner_valid : std_logic;
    signal a_scramble : std_logic := '1';
    signal b_scramble : std_logic := '1';
    signal a_link_reset : std_logic := '0';
    signal b_link_reset : std_logic := '0';
    signal counters_clear : std_logic := '0';

    signal ab_data : std_logic_vector(9 downto 0);
    signal ab_valid : std_logic;
    signal ab_ready : std_logic;
    signal ba_data : std_logic_vector(9 downto 0);
    signal ba_valid : std_logic;
    signal ba_ready : std_logic;

    signal a_serial_out : std_logic;
    signal b_serial_out : std_logic;
    signal invert_serial_ab : std_logic := '0';
    signal invert_serial_ba : std_logic := '0';
begin

    clk <= not clk after 10 ns;
    reset <= '0' after 200 ns;

    link_a: entity work.interlink_top
        generic map (
            NUM_CHANNELS => sim_num_channels,
            PREEMPT_CHANNEL => PREEMPT_CHANNEL,
            IDLE_INTERVAL_LOCKED => IDLE_INTERVAL_LOCKED,
            IDLE_INTERVAL_FAST => IDLE_INTERVAL_FAST,
            IDLES_TO_LOCK => IDLES_TO_LOCK,
            STATS_INTERVAL_IDLES => STATS_INTERVAL_IDLES
        )
        port map (
            clk => clk,
            reset => reset,
            scramble_enable => a_scramble,
            link_reset => a_link_reset,
            tx_chans => a_tx_chans,
            rx_chans => a_rx_chans,
            link_status => a_status,
            counters => a_counters,
            counters_clear => counters_clear,
            partner_counters => a_partner,
            partner_counters_valid => a_partner_valid,
            serdes => a_serdes
        );

    link_b: entity work.interlink_top
        generic map (
            NUM_CHANNELS => sim_num_channels,
            PREEMPT_CHANNEL => PREEMPT_CHANNEL,
            IDLE_INTERVAL_LOCKED => IDLE_INTERVAL_LOCKED,
            IDLE_INTERVAL_FAST => IDLE_INTERVAL_FAST,
            IDLES_TO_LOCK => IDLES_TO_LOCK,
            STATS_INTERVAL_IDLES => STATS_INTERVAL_IDLES
        )
        port map (
            clk => clk,
            reset => reset,
            scramble_enable => b_scramble,
            link_reset => b_link_reset,
            tx_chans => b_tx_chans,
            rx_chans => b_rx_chans,
            link_status => b_status,
            counters => b_counters,
            counters_clear => counters_clear,
            partner_counters => b_partner,
            partner_counters_valid => b_partner_valid,
            serdes => b_serdes
        );

    wire_ab: entity work.interlink_sim_wire
        generic map (
            actor_name => "wire_ab",
            CHAR_GAP => CHAR_GAP,
            PACED => not SERIAL
        )
        port map (
            clk => clk,
            reset => reset,
            in_data => a_serdes.tx_data,
            in_valid => a_serdes.tx_valid,
            in_ready => a_serdes.tx_ready,
            out_data => ab_data,
            out_valid => ab_valid,
            out_ready => ab_ready
        );

    wire_ba: entity work.interlink_sim_wire
        generic map (
            actor_name => "wire_ba",
            CHAR_GAP => CHAR_GAP,
            PACED => not SERIAL
        )
        port map (
            clk => clk,
            reset => reset,
            in_data => b_serdes.tx_data,
            in_valid => b_serdes.tx_valid,
            in_ready => b_serdes.tx_ready,
            out_data => ba_data,
            out_valid => ba_valid,
            out_ready => ba_ready
        );

    bypass_gen: if not SERIAL generate
        b_serdes.rx_data <= ab_data;
        b_serdes.rx_valid <= ab_valid;
        ab_ready <= b_serdes.rx_ready;
        a_serdes.rx_data <= ba_data;
        a_serdes.rx_valid <= ba_valid;
        ba_ready <= a_serdes.rx_ready;
    else generate
        -- Three samples per bit keeps the serial runs tolerable; a real
        -- design would use more.
        ls_serdes_a: entity work.ls_serdes
            generic map (
                NOMINAL_SAMPLE_CNTS => 3,
                DATA_WIDTH => 10,
                SYNCHRONIZE => false
            )
            port map (
                clk => clk,
                reset => reset,
                serial_in => b_serial_out xor invert_serial_ba,
                serial_out => a_serial_out,
                data_out => a_serdes.rx_data,
                data_out_valid => a_serdes.rx_valid,
                data_out_ready => a_serdes.rx_ready,
                data_in => ab_data,
                data_in_valid => ab_valid,
                data_in_ready => ab_ready,
                bit_slip => a_serdes.bit_slip,
                invert_rx => '0'
            );

        ls_serdes_b: entity work.ls_serdes
            generic map (
                NOMINAL_SAMPLE_CNTS => 3,
                DATA_WIDTH => 10,
                SYNCHRONIZE => false
            )
            port map (
                clk => clk,
                reset => reset,
                serial_in => a_serial_out xor invert_serial_ab,
                serial_out => b_serial_out,
                data_out => b_serdes.rx_data,
                data_out_valid => b_serdes.rx_valid,
                data_out_ready => b_serdes.rx_ready,
                data_in => ba_data,
                data_in_valid => ba_valid,
                data_in_ready => ba_ready,
                bit_slip => b_serdes.bit_slip,
                invert_rx => '0'
            );
    end generate;

    chan_gen: for i in 1 to sim_num_channels generate
        a_source: entity work.basic_pkt_source
            generic map (
                source => a_sources(i)
            )
            port map (
                clk => clk,
                ready => a_tx_chans(i).ready,
                valid => a_tx_chans(i).valid,
                last => a_tx_chans(i).last,
                data => a_tx_chans(i).data
            );

        b_source: entity work.basic_pkt_source
            generic map (
                source => b_sources(i)
            )
            port map (
                clk => clk,
                ready => b_tx_chans(i).ready,
                valid => b_tx_chans(i).valid,
                last => b_tx_chans(i).last,
                data => b_tx_chans(i).data
            );

        a_sink: entity work.basic_pkt_sink
            generic map (
                sink => a_sinks(i)
            )
            port map (
                clk => clk,
                valid => a_rx_chans(i).valid,
                last => a_rx_chans(i).last,
                err => a_rx_chans(i).error,
                data => a_rx_chans(i).data
            );

        b_sink: entity work.basic_pkt_sink
            generic map (
                sink => b_sinks(i)
            )
            port map (
                clk => clk,
                valid => b_rx_chans(i).valid,
                last => b_rx_chans(i).last,
                err => b_rx_chans(i).error,
                data => b_rx_chans(i).data
            );
    end generate;

end th;
