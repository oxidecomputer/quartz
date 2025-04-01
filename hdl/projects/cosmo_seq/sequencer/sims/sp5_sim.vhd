-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sequencer_io_pkg.all;

entity sp5_model is
    port (
        clk : in std_logic;
        reset : in std_logic;

        sp5_pins : view sp5_seq_at_sp5
    );
end entity;

architecture model of sp5_model is
 
    type state_t is (IDLE, RSM_RST, WAIT_FOR_PB, SLPS, WAIT_PWRGOOD, SP5_PWR_OK, OUT_OF_RESET);
    signal state : state_t := IDLE;

begin

    -- this is the sunny day sequence
    sm: process
    begin

        case state is
            when IDLE =>
                wait until rising_edge(sp5_pins.rsmrst_l);
                state <= RSM_RST;

            when RSM_RST =>
                wait for 10 us;
                state <= WAIT_FOR_PB;

            when WAIT_FOR_PB =>
                wait until falling_edge(sp5_pins.pwr_btn_l);
                wait for 360 us;
                state <= SLPS;
            
            when SLPS =>
                state <= WAIT_PWRGOOD;

            when WAIT_PWRGOOD =>
                wait until sp5_pins.pwr_good = '1';
                wait for 200 us;  -- shortened from 20.4 ms
                state <= SP5_PWR_OK;

            when SP5_PWR_OK =>
                wait for 200 us;  -- shortened from 28.6 ms
                state <= OUT_OF_RESET;

            when OUT_OF_RESET =>
                if sp5_pins.rsmrst_l = '0' then
                    state <= IDLE;
                end if;
        end case;
        wait until rising_edge(clk);
    end process;
    -- power button fedge, max 360us to slp_sx_edges

    --separately
    --rsm_rst_redge from sequencer and s3 rails good 1ms to pwrgood from seq
    --from pwrgood to pwrok max 20.4ms
    --from pwrgood to reset_l release max of 28.6ms

    sp5_pins.thermtrip_l <= 'Z';
    -- using latches here but it's sim so it should be fine
    sp5_pins.reset_l <= 'Z' when state = IDLE else '0' when state /= OUT_OF_RESET else '1';
    sp5_pins.pwr_ok <= '1' when state = SP5_PWR_OK else '0' when state = IDLE;
    sp5_pins.slp_s3_l <= '0' when state = IDLE else '1' when state = SLPS;
    sp5_pins.slp_s5_l <= '0' when state = IDLE else '1' when state = SLPS;
end model;