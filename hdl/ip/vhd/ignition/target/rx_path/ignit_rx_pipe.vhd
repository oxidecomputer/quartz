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

entity ignit_rx_pipe is
    generic(
        NUM_CHANNELS : positive := 2
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        --
        -- from serdes interfaces
        serdes_data : ignit_10b_data_t(NUM_CHANNELS-1 downto 0);
        serdes_data_valid : in std_logic_vector(NUM_CHANNELS-1 downto 0);
        serdes_data_ready : out std_logic_vector(NUM_CHANNELS-1 downto 0);
        -- to downstream logic
        decoded_data_valid : out std_logic;
        decoded_data_ready : in std_logic;
        decoded_data : out ignit_rx_decode
    );
end entity;

architecture rtl of ignit_rx_pipe is
    type state_t is (CH0, CH1);

    type reg_t is record
      state: state_t;
      in_ready: std_logic;
      out_valid: std_logic;
      running_disp: std_logic_vector(NUM_CHANNELS-1 downto 0);
      chan_info: ignit_rx_decode;
    end record;
    constant reset_val : reg_t := (
            state => CH0,
            in_ready => '0',
            out_valid => '0',
            running_disp => (others => '0'),
            chan_info => (
                  channel => '0', 
                  data => (others => '0'), 
                  ctrl => '0', 
                  disp_err => '0')
    );  

    signal r, rin : reg_t;
    signal cur_disp: std_logic;
    signal other_valid: std_logic;
    signal new_disp: std_logic;
    signal code_err: std_logic;
    signal disp_err: std_logic;
    signal cur_valid: std_logic;
    signal demux_encoded_data: std_logic_vector(9 downto 0);
    signal decoded_int_data : std_logic_vector(8 downto 0);


begin

    decoded_data <= r.chan_info;
    decoded_data_valid <= r.out_valid;
    -- simple comb mux to select the data going into the decoder
    -- and a few other signal muxes to make the state machine easier
    -- to manage
    comb_mux: process(all)
    begin
        if r.state = CH0 then
            demux_encoded_data <= serdes_data(0);
            cur_disp <= r.running_disp(0);
            cur_valid <= serdes_data_valid(0);
            other_valid <= serdes_data_valid(1);
            serdes_data_ready <= (0 => r.in_ready, 1 => '0');
        else
            demux_encoded_data <= serdes_data(1);
            cur_disp <= r.running_disp(1);
            cur_valid <= serdes_data_valid(1);
            other_valid <= serdes_data_valid(0);
            serdes_data_ready <= (1 => r.in_ready, 0 => '0');
        end if;
    end process;

    -- 8b10b decoder
    decode_8b10b_inst: entity work.decode_8b10b
     port map(
        datain => demux_encoded_data,
        dispin => cur_disp,
        dataout => decoded_int_data,
        dispout => new_disp,
        code_err => code_err,
        disp_err => disp_err
    );

    -- We run a small state machine here to bounce between the incoming
    -- data streams and share the 8b10b decoder in a time-domain-multiplexed
    -- fashion. at 10Mbps we have 5 clocks per bit, so we can easily
    -- keep up with the data rate which is coming in on both channels so
    -- long as we keep back pressure to a minium which should be easy.
    -- We're trying to save as many registers as possible so we have the 
    -- fewest number of actual registers we can manage.  The output from
    -- this block, post-decode is registered to break the combinatorial
    -- path and allow downstream logic some handshake flexibility.
    statemachine: process(all)
    variable v: reg_t;
    begin
        v := r;

         -- clear in-flag after transfer
         if cur_valid and r.in_ready then
            v.in_ready := '0'; 
        end if;
        -- clear out-flag after transfer
        if r.out_valid and decoded_data_ready then
            v.out_valid := '0';
        end if;

        case r.state is
            -- Both states are nearly identical, we just use the state to determine
            -- indexing
            when others =>
                -- can accept new data when we have room
                if cur_valid = '1' and r.in_ready = '0' and r.out_valid = '0' then
                    v.chan_info.channel := '1' when r.state = CH1 else '0';
                    v.chan_info.data := decoded_int_data(7 downto 0);
                    v.chan_info.ctrl := decoded_int_data(8);
                    v.chan_info.disp_err := disp_err;
                    if r.state = CH0 then
                        v.running_disp(0) := new_disp;
                    else
                        v.running_disp(1) := new_disp;
                    end if;
                    v.out_valid := '1';
                    v.in_ready := '1';
                end if;
                if cur_valid = '0' and other_valid = '1' then
                    v.state := CH0 when r.state = CH1 else CH1;
                end if;
        end case;
        rin <= v;
    end process;


    -- mux registers
    mux_ctrl: process(clk, reset)
     begin
        if reset then
            r <= reset_val;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;