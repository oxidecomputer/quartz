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
        GET_START_BYTE,
        GET_REG_BYTE,
        SEND_ACK,
        SEND_NACK,
        SEND_BYTE,
        GET_BYTE,
        GET_ACK,
        GET_STOP
    );

    signal state    : state_t := IDLE;

    signal start_condition  : std_logic                     := '0';
    signal rx_data          : std_logic_vector(7 downto 0)  := (others => '0');
    signal rx_bit_count     : unsigned(3 downto 0)          := (others => '0');
    signal rx_done          : std_logic                     := '0';
begin

    start_condition  <= '1' when sda = '0' and state = IDLE else '0';

    message_handler: process
        variable msg_type               : msg_type_t;
        variable request_msg, reply_msg : msg_t;
    begin
        receive(net, i2c_peripheral_vc.p_actor, request_msg);
        msg_type := message_type(request_msg);
    end process;

    transaction_sm: process
        variable event_msg : msg_t;
    begin
        wait on start_condition;
        event_msg   := new_msg(got_start);
        send(net, i2c_peripheral_vc.p_actor, event_msg);

        state   <= GET_START_BYTE;
        wait on rx_done;
        if rx_data(7 downto 1) = i2c_peripheral_vc.address then
            state       <= SEND_ACK;
            event_msg   := new_msg(address_matched);
            send(net, i2c_peripheral_vc.p_actor, event_msg);
        else
            state       <= SEND_NACK;
            event_msg   := new_msg(address_different);
            send(net, i2c_peripheral_vc.p_actor, event_msg);
        end if;
    end process;

    rx_done <= '1' when rx_bit_count = 8 else '0';

    receive_sm: process
        variable data_next  : std_logic_vector(7 downto 0)  := (others => '0');
    begin
        wait until rising_edge(scl);
        if state = GET_START_BYTE then
            data_next       := sda & rx_data(7 downto 1);
            rx_bit_count    <= rx_bit_count + 1;
        else
            rx_bit_count    <= (others => '0');
        end if;

        rx_data <= data_next;
    end process;

end architecture;