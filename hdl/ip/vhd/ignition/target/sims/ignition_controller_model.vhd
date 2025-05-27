-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- want to take a streaming interface with data (9bit, 8 data + control)
-- generate IDLE sequences unless packets in-bound then send those
-- 


library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.helper_8b10b_pkg.all;
use work.ignition_pkg.all;
use work.basic_stream_pkg.all;
use work.ignition_sim_pkg.all;

use work.basic_stream_pkg.all;
entity ignition_controller_model is
    generic(
        source  : basic_source_t
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        serial_in  : in std_logic;
        serial_out : out std_logic
    );
end entity;

architecture model of ignition_controller_model is
    type state_t is (IDLE1A, IDLE1B, IDLE2A, IDLE2B, DATA);
    signal state : state_t := IDLE1A;
    signal next_idle : state_t := IDLE2B;
    signal from_ctrlr_data_valid : std_logic := '0';
    signal from_ctrlr_data_ready : std_logic := '0';
    signal from_ctrlr_data : std_logic_vector(8 downto 0) := (others => '0');
    signal preencode_data : std_logic_vector(8 downto 0);
    signal tx_disp_in : std_logic := '0';
    signal tx_disp_out : std_logic;
    signal tx_encoded_data : std_logic_vector(9 downto 0);
    signal tx_mux_valid : std_logic;
    signal expected_encode : encoded_8b10b_t;
    signal data_ack : std_logic;
    signal hello_wdog_enabled : boolean := true;
    signal rx_disp_in : std_logic := '0';
    signal rx_disp_out : std_logic;
    signal rx_encoded_data : std_logic_vector(9 downto 0);
    signal rx_valid : std_logic;
    signal rx_ready : std_logic;
    signal rx_decoded_data : std_logic_vector(8 downto 0);
    



begin

    hello_wdog: process
        variable cmd : cmd_t;
    begin
        if hello_wdog_enabled then
            wait until state = IDLE1A or state = IDLE2A;
            cmd := build_hello_cmd;
            send_cmd(net, source, cmd);
            wait for 100 us; -- TODO: this could be configurable
        else
            wait on hello_wdog_enabled;
        end if;
    end process;

    -- Use this building block to send 9bits of data 
    -- from the TB into this block.
    -- This will get shovelled into an 8b10b encoder
    -- and sent out the serial interface. If no data
    -- is present then we'll generate IDLE1/IDLE2 patterns
    -- and we can't interrupt them.
    basic_source_inst: entity work.basic_source
     generic map(
        source => source
    )
     port map(
        clk => clk,
        ready => data_ack,
        valid => from_ctrlr_data_valid,
        data => from_ctrlr_data
    );

    data_ack <= '1' when state = DATA and from_ctrlr_data_ready = '1' else
                '0';

    gen: process
     begin
            if reset = '1' then
                wait until reset = '0';
            end if;
            case state is
                when IDLE1A =>
                    wait until rising_edge(clk) and tx_mux_valid = '1' and from_ctrlr_data_ready = '1';
                    state <= IDLE1B;
                when IDLE1B =>
                    -- Have the opportunity to send data next clock
                    wait until rising_edge(clk) and tx_mux_valid = '1' and from_ctrlr_data_ready = '1';
                    if from_ctrlr_data_valid = '1' then
                        state <= DATA;
                        next_idle <= IDLE2A;
                    else
                        state <= IDLE2A;
                    end if;
                when IDLE2A =>
                    wait until rising_edge(clk) and tx_mux_valid = '1' and from_ctrlr_data_ready = '1';
                    state <= IDLE2B;
                when IDLE2B =>
                   wait until rising_edge(clk) and tx_mux_valid = '1' and from_ctrlr_data_ready = '1';
                    -- Have the opportunity to send data now
                    if from_ctrlr_data_valid = '1' then
                        state <= DATA;
                        next_idle <= IDLE1A;
                    else
                        state <= IDLE1A;
                    end if;
                when DATA =>
                    wait until rising_edge(clk);
                    -- If we're empty, send IDLEs again
                    if from_ctrlr_data_valid = '0' then
                        state <= next_idle;
                    end if;
            end case;
            wait for 0 ns;
    end process;


    preencode_data <= '1' & K28_5 when state = IDLE1A or state = IDLE2A else
                      '0' & D10_2 when state = IDLE1B else
                      '0' & D19_5 when state = IDLE2B else
                      from_ctrlr_data;
    tx_mux_valid <= '1' when state /= DATA else
                    from_ctrlr_data_valid;

    encode_8b10b_inst: entity work.encode_8b10b
     port map(
        datain => preencode_data,
        dispin => tx_disp_in,
        dataout => tx_encoded_data,
        dispout => tx_disp_out
    );
    expected_encode <= encode(preencode_data(7 downto 0), preencode_data(8), tx_disp_in);

    tx_disp_reg: process(clk)
     begin
        if rising_edge(clk) then
            if tx_mux_valid and from_ctrlr_data_ready then
                tx_disp_in <= tx_disp_out;
            end if;
        end if;
    end process;

    ls_serdes_inst: entity work.ls_serdes
     generic map(
        NOMINAL_SAMPLE_CNTS => 5,
        DATA_WIDTH => 10,
        SYNCHRONIZE => false -- Using LVDS primitives so data is already synchronized
    )
     port map(
        clk => clk,
        reset => reset,
        serial_in => serial_in,
        serial_out => serial_out,
        data_out => rx_encoded_data,
        data_out_valid => rx_valid,
        data_out_ready => '1',
        data_in => tx_encoded_data,
        data_in_valid => tx_mux_valid,
        data_in_ready => from_ctrlr_data_ready,
        bit_slip => '0',
        invert_rx => '0'
    );

     rx_disp_reg: process(clk)
     begin
        if rising_edge(clk) then
            if rx_valid and rx_ready then
                rx_disp_in <= rx_disp_out;
            end if;
        end if;
    end process;

    decode_8b10b_inst: entity work.decode_8b10b
     port map(
        datain => rx_encoded_data,
        dispin => rx_disp_in,
        dataout => rx_decoded_data,
        dispout => rx_disp_out
    );

    rx_ready <= '1';

end model;
