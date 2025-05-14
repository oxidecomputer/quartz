-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.ignition_pkg.all;

entity ignition_target_common is
    generic(
        NUM_LEDS : positive := 2;
        NUM_BITS_IGNITION_ID : positive := 6
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        -- Serial interface
        sw0_serial_in : in std_logic;
        sw0_serial_out : out std_logic;
        sw1_serial_in : in std_logic;
        sw1_serial_out : out std_logic;
        -- Standard chip interface stuff
        ignit_to_ibc_pwren : out std_logic;
        hotswap_restart_l : out std_logic;
        ignit_led_l : out std_logic_vector(NUM_LEDS-1 downto 0);
        a3_pwr_fault_l : in std_logic;
        a2_pg : in  std_logic;
        sp_fault_l : in std_logic;
        rot_fault_l : in std_logic;
        push_btn_l : in std_logic;
        ignition_id : in std_logic_vector(NUM_BITS_IGNITION_ID-1 downto 0)
    );


end entity;

architecture rtl of ignition_target_common is
    constant NUM_SIDECAR_CHANNELS : positive := 2;
    signal serial_in : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serial_out : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_prealign_dataout : ignit_10b_data_t(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_prealign_dataout_valid : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_prealign_dataout_ready : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_prebuf_dataout_valid : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_prebuf_dataout_ready : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_postbuf_dataout : ignit_10b_data_t(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_postbuf_dataout_valid : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_postbuf_dataout_ready : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);

    signal serdes_10b_datain : ignit_10b_data_t(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_datain_valid : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_10b_datain_ready : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal serdes_bitslip : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0) := (others => '0');
    signal is_aligned : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal is_hello : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal is_power_on : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal is_power_off : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal is_restart : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);
    signal invert_rx : std_logic_vector(NUM_SIDECAR_CHANNELS-1 downto 0);

    signal decoded_valid : std_logic;
    signal decoded_data : ignit_rx_decode;

    signal system_status : system_status_t;
    signal request_status : request_status_t;
    signal system_faults : system_faults_t;
    signal link0_status : link_status_t;
    signal link0_events : link_events_t;
    signal link1_status : link_status_t;
    signal link1_events : link_events_t;
begin

    -- Two independent serial rx interfaces, one for each switch.
    serial_in(0) <= sw0_serial_in;
    serial_in(1) <= sw1_serial_in;
    
    -- One "serdes" for each sidecar channel into a skid buffer since
    -- we're time-domain multiplexing the decode data and two bytes could
    -- arrive at the same time so we need to store them so the serdes can
    -- continue sampling without backpressure.
    --
    -- On the tx side, we only need one serdes since we can send the same
    -- data to both switches.
    serdes_10b_datain_valid(1) <= '0';  -- we only use one transmitter make this optimize out
    serdes_10b_datain(1) <= (others => '0'); -- we only use one transmitter make this optimize out
    -- We share a tx path for both channels so they send the same data
    -- to each switch.
    sw1_serial_out <= serial_out(0);
    sw0_serial_out <= serial_out(0);

    xcvr_gen: for i in NUM_SIDECAR_CHANNELS-1 downto 0 generate
        -- This is the "serdes" block that samples and shifts 10bit words
        ls_xcvr: entity work.ls_serdes
            generic map(
                DATA_WIDTH => 10,
                NOMINAL_SAMPLE_CNTS => 5,
                SYNCHRONIZE => false -- Using LVDS primitives so data is already synchronized
            )
            port map(
                clk => clk,
                reset => reset,
                -- Serial interface
                serial_in => serial_in(i),
                serial_out => serial_out(i),
                data_out => serdes_10b_prealign_dataout(i),
                data_out_valid => serdes_10b_prealign_dataout_valid(i),
                data_out_ready => serdes_10b_prealign_dataout_ready(i),
                data_in  => serdes_10b_datain(i),
                data_in_valid => serdes_10b_datain_valid(i),
                data_in_ready => serdes_10b_datain_ready(i),
                bit_slip => serdes_bitslip(i),
                invert_rx => invert_rx(i)
            );
        -- This is pre-decoded data from the serdes, but we look for
        -- the k28.5 pattern which should be unique in the data stream
        -- We could do this faster with more registers but bit-slips
        -- when we've gone too long without a k28.5 pattern.
        -- TODO: We can tighten this up since igntion target only
        -- rx's small packets from the switch.
        -- TODO: we could add hysteresis to unlocking also.
        aligner_10bk285_inst: entity work.aligner_10bk28_5
         generic map(
            MIN_PATTERNS_TO_LOCK => 4,
            MAX_SYMBOLS_BEFORE_SLIP => 40
        )
         port map(
            clk => clk,
            reset => reset,
            data_in => serdes_10b_prealign_dataout(i),
            data_in_valid => serdes_10b_prealign_dataout_valid(i),
            data_in_align_ready => serdes_10b_prealign_dataout_ready(i),
            downstream_ready => serdes_10b_prebuf_dataout_ready(i),
            downstream_valid => serdes_10b_prebuf_dataout_valid(i),
            realign => '0',  -- We don't force re-alignment
            bit_slip => serdes_bitslip(i),
            is_locked => is_aligned(i)
        );

        -- Skid buffers for parallel data rx'd from the serdes
        -- We're sharing the 8b10b decoder but could rx packets
        -- at the same time so we need to store them in a buffer
        rx_skidbuffer_inst: entity work.skidbuffer
         generic map(
            WIDTH => 10
        )
         port map(
            clk => clk,
            reset => reset,
            sink_valid => serdes_10b_prebuf_dataout_valid(i),
            sink_data => serdes_10b_prealign_dataout(i),
            sink_ready => serdes_10b_prebuf_dataout_ready(i),
            source_valid => serdes_10b_postbuf_dataout_valid(i),
            source_data => serdes_10b_postbuf_dataout(i),
            source_ready => serdes_10b_postbuf_dataout_ready(i)
        );

        -- Note: the data flow jumps out of the for-generate here
        -- after the skid buffer and goes into the ignit_rx_pipe
        -- which is a single shared pipeline for both channels
        -- that does the 8b10b decode.

        -- Data from that block gets picked back up here in the 
        -- pkt parsing block, one for each channel where we
        -- decode the packets and check for errors etc.
        
        pkt_storage_inst: entity work.pkt_parsing
        generic map(
            CHAN_ID => i
        )
        port map(
            clk => clk,
            reset => reset,
            valid => decoded_valid,
            ignit_rx => decoded_data,
            pol_invert => invert_rx(i),
            is_locked => is_aligned(i),
            is_hello => is_hello(i),
            is_power_on => is_power_on(i),
            is_power_off =>is_power_off(i),
            is_restart => is_restart(i)      
        );
    end generate;

    -- Time-domain multiplexing of the serial interface
    -- and the 8b10b decoder so the bit-slipping state machine is
    -- in here also.
    ignit_rx_pipe_inst: entity work.ignit_rx_pipe
     port map(
        clk => clk,
        reset => reset,
        serdes_data => serdes_10b_postbuf_dataout,
        serdes_data_valid => serdes_10b_postbuf_dataout_valid,
        serdes_data_ready => serdes_10b_postbuf_dataout_ready,
        decoded_data_valid => decoded_valid,
        decoded_data_ready => '1',
        decoded_data => decoded_data
    );

    -- Shared TX module. No reason to have two of these so we don't
    ignition_tx_inst: entity work.ignition_tx
     generic map(
        NUM_LEDS => NUM_LEDS,
        NUM_BITS_IGNITION_ID => NUM_BITS_IGNITION_ID
    )
     port map(
        clk => clk,
        reset => reset,
        system_type_pins => 8x"AA",
        serdes_10b_datain => serdes_10b_datain(0),
        serdes_10b_datain_valid => serdes_10b_datain_valid(0),
        serdes_10b_datain_ready => serdes_10b_datain_ready(0),
        system_status => system_status,
        request_status => request_status,
        system_faults => system_faults,
        link0_status => link0_status,
        link0_events => link0_events,
        link1_status => link1_status,
        link1_events => link1_events
    );
  
    
    link0_status.polarity_inverted <= invert_rx(0);
    link0_status.receiver_aligned <= is_aligned(0);
    link0_status.receiver_locked <= '1';
    link1_status.polarity_inverted <= invert_rx(1);
    link1_status.receiver_aligned <= is_aligned(1);
    link1_status.receiver_locked <= '1';
   
    system_status <= (others => '0');
    system_faults <= (others => '0');
    request_status <= (others => '0');
    link0_events <= (others => '0');
    link1_events <= (others => '0');
    
     -- Ignition ID
     ignit_to_ibc_pwren <= ignition_id(NUM_BITS_IGNITION_ID-1);
     hotswap_restart_l <= push_btn_l;
    
     -- LED control
     ignit_led_l <= (others => '1');


end rtl;