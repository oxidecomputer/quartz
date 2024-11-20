-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;

use work.i2c_peripheral_pkg.all;

entity i2c_peripheral is
    generic (
        i2c_peripheral_vc   : i2c_peripheral_t
    );
    port (
        -- initilize to 'H' to simulate pull-ups
        scl : inout std_logic := 'H';
        sda : inout std_logic := 'H';
    );
end entity;

architecture model of i2c_peripheral is

    type state_t is (
        IDLE,
        SEND_ACK,
        SEND_NACK,
        SEND_BYTE,
        GET_BYTE,
        GET_ACK,
        GET_STOP
    );

    signal state    : state_t := IDLE;

    signal start_condition  : std_logic                     := '0';
    signal stop_condition   : std_logic                     := '0';
    signal sda_last         : std_logic                     := 'H';
    signal rx_data          : std_logic_vector(7 downto 0)  := (others => '0');
    signal rx_bit_count     : unsigned(3 downto 0)          := (others => '0');
    signal rx_done          : std_logic                     := '0';
    signal rx_ackd          : boolean                       := FALSE;
    signal tx_data          : std_logic_vector(7 downto 0)  := (others => '0');
    signal tx_bit_count     : unsigned(3 downto 0)          := (others => '0');
    signal tx_done          : std_logic                     := '0';

    signal in_receiving_state       : boolean := FALSE;
    signal in_transmitting_state    : boolean := FALSE;
begin

    start_condition  <= '1' when sda_last = 'H' and sda = '0' and scl = 'H' else '0';
    stop_condition   <= '1' when sda_last = '0' and sda = 'H' and scl = 'H' else '0';

    -- message_handler: process
    --     variable msg_type               : msg_type_t;
    --     variable request_msg, reply_msg : msg_t;
    -- begin
    --     receive(net, i2c_peripheral_vc.p_actor, request_msg);
    --     msg_type := message_type(request_msg);
    -- end process;

    -- sample SDA regularly to catch transitions
    sda_monitor: process
    begin
        wait for 20 ns;
        sda_last    <= sda;
    end process;

    transaction_sm: process
        variable event_msg  : msg_t;
        variable is_read    : boolean := FALSE;
    begin
        -- IDLE: wait for a START
        wait on start_condition;
        event_msg   := new_msg(got_start);
        send(net, i2c_peripheral_vc.p_actor, event_msg);
        state   <= GET_BYTE;

        -- GET_BYTE: check address and acknowledge appropriately
        wait on rx_done;
        wait until falling_edge(scl);
        if rx_data(7 downto 1) = i2c_peripheral_vc.address then
            state       <= SEND_ACK;
            is_read     := rx_data(0) = '1';
            event_msg   := new_msg(address_matched);
            send(net, i2c_peripheral_vc.p_actor, event_msg);
        else
            state       <= SEND_NACK;
            event_msg   := new_msg(address_different);
            send(net, i2c_peripheral_vc.p_actor, event_msg);
        end if;

        -- SEND_ACK/NACK: acknowledge the START byte
        wait until falling_edge(scl);
        if state = SEND_ACK then
            if is_read then
                state   <= SEND_BYTE;
            else
                state   <= GET_BYTE;
            end if;
        else
            -- NACK'd
            state   <= GET_STOP;
        end if;
        wait until rising_edge(scl);

        if is_read then
            -- loop to respond to a controller read request
            while state /= GET_STOP loop
                -- SEND_BYTE: send the byte and then wait for an acknowledge
                wait on tx_done;
                wait until rising_edge(scl);
                state   <= GET_ACK;

                -- GET_ACK: see if the controller wants to continue reading or is finished
                wait on rx_done;
                state   <= SEND_BYTE when rx_ackd else GET_STOP;
            end loop;
        end if;

        -- GET_STOP: wait for a STOP
        wait on stop_condition;
        event_msg   := new_msg(got_stop);
        send(net, i2c_peripheral_vc.p_actor, event_msg);
        state   <= IDLE;
    end process;

    in_receiving_state  <= state = GET_BYTE or state = GET_ACK;
    rx_done <= '1' when (state = GET_BYTE and rx_bit_count = 8) or 
                        (state = GET_ACK and rx_bit_count = 1)
                else '0';

    receive_sm: process
        variable data_next  : std_logic_vector(7 downto 0)  := (others => '0');
        variable sda_v      : std_logic;
    begin
        wait until rising_edge(scl);

        if rx_done then
            rx_bit_count    <= (others => '0');
        elsif state = GET_ACK then
            -- '0' = ACK, 'H' = NACK
            rx_ackd         <= TRUE when sda = '0' else FALSE;
            rx_bit_count    <= to_unsigned(1, rx_bit_count'length);
        elsif state = GET_BYTE then
            sda_v           := '1' when sda = 'H' else '0';
            data_next       := sda_v & rx_data(7 downto 1);
            rx_bit_count    <= rx_bit_count + 1;            
        end if;

        rx_data <= data_next;
    end process;


    in_transmitting_state   <= state = SEND_ACK or state = SEND_NACK or state = SEND_BYTE;
    tx_done <= '1' when ((state = SEND_ACK or state = SEND_ACK) and tx_bit_count = 1) or 
                        (state = SEND_BYTE and tx_bit_count = 8)
                else '0';

    transmit_sm: process
        variable data_next  : std_logic_vector(7 downto 0)  := X"CC"; 
    begin
        if tx_done then
            tx_bit_count    <= (others => '0');
        end if;

        wait until falling_edge(scl);
        -- delay the SDA transition to a bit after SCL falls to allow the controller to release SDA
        wait for 25 ns;
        
        if tx_done then 
            -- release bus
            sda             <= 'H';
        elsif state = SEND_ACK or state = SEND_NACK then
            sda             <= '0' when state = SEND_ACK else 'H';
            tx_bit_count    <= to_unsigned(1, tx_bit_count'length);
        elsif state = SEND_BYTE then
            sda             <= 'H' when data_next(to_integer(tx_bit_count)) = '1' else '0';
            tx_bit_count    <= tx_bit_count + 1;
        end if;

        wait until rising_edge(scl);

    end process;

end architecture;