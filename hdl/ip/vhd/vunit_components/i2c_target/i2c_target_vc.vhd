-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
use vunit_lib.sync_pkg.all;

use work.i2c_target_vc_pkg.all;

entity i2c_target_vc is
    generic (
        I2C_TARGET_VC   : i2c_target_vc_t
    );
    port (
        scl : inout std_logic   := 'Z';
        sda : inout std_logic   := 'Z';
    );
end entity;

architecture model of i2c_target_vc is

    type state_t is (
        IDLE,
        START,
        SEND_ACK,
        SEND_NACK,
        SEND_BYTE,
        GET_START_BYTE,
        GET_BYTE,
        GET_ACK,
        GET_STOP
    );

    signal state    : state_t := IDLE;

    signal start_condition  : boolean                     := FALSE;
    signal stop_condition   : boolean                     := FALSE;
    signal sda_last         : std_logic                     := '1';
    signal rx_data          : std_logic_vector(7 downto 0)  := (others => '0');
    signal rx_bit_count     : unsigned(3 downto 0)          := (others => '0');
    signal rx_done          : boolean                       := FALSE;
    signal rx_ackd          : boolean                       := FALSE;
    signal tx_data          : std_logic_vector(7 downto 0)  := (others => '0');
    signal tx_bit_count     : unsigned(3 downto 0)          := (others => '0');
    signal tx_done          : boolean                       := FALSE;

    signal scl_int  : std_logic := '1';
    signal sda_int  : std_logic := '1';
    signal scl_oe   : std_logic := '0';
    signal sda_oe   : std_logic := '0';

    signal reg_addr     : unsigned(7 downto 0)  := (others => '0');
    signal addr_set     : boolean               := FALSE;
    signal addr_incr    : boolean               := FALSE;
begin

    scl  <= '0' when scl_oe else 'Z';
    sda  <= '0' when sda_oe else 'Z';

    scl_int <= to_x01(scl);
    sda_int <= to_x01(sda);

    start_condition  <= sda_last = '1' and sda_int = '0' and scl_int = '1';
    stop_condition   <= sda_last = '0' and sda_int = '1' and scl_int = '1';

    -- sample SDA regularly to catch transitions
    sda_monitor: process
    begin
        wait for 20 ns;
        sda_last    <= sda_int;
    end process;

    transaction_sm: process
        variable event_msg          : msg_t;
        variable is_read            : boolean               := FALSE;
        variable reg_addr_v         : unsigned(7 downto 0)  := (others => '0');
        variable stop_during_write  : boolean               := FALSE;
    begin
        case state is

            when IDLE =>
                wait on start_condition;
                state <= START;
            
            when START =>
                event_msg   := new_msg(got_start);
                send(net, I2C_TARGET_VC.p_actor, event_msg);
                state       <= GET_START_BYTE;

            when GET_START_BYTE =>
                wait until rx_done or stop_condition;

                if stop_condition then
                    state   <= GET_STOP;
                else
                    if rx_data(7 downto 1) = address(I2C_TARGET_VC) then
                        state       <= SEND_ACK;
                        is_read     := rx_data(0) = '1';
                        event_msg   := new_msg(address_matched);
                        send(net, I2C_TARGET_VC.p_actor, event_msg);
                    else
                        state       <= SEND_NACK;
                        event_msg   := new_msg(address_different);
                        send(net, I2C_TARGET_VC.p_actor, event_msg);
                    end if;
                end if;

            when GET_BYTE =>
                wait until rx_done or start_condition or stop_condition;

                if start_condition then
                    state   <= START;
                elsif stop_condition then
                    state               <= GET_STOP;
                    stop_during_write   := TRUE;
                else
                    state   <= SEND_ACK;

                    if addr_incr then
                        reg_addr_v  := reg_addr + 1;
                    end if;

                    if addr_set then
                        write_word(memory(I2C_TARGET_VC), to_integer(reg_addr_v), rx_data);
                        event_msg   := new_msg(got_byte);
                        send(net, I2C_TARGET_VC.p_actor, event_msg);
                        addr_incr   <= TRUE;
                    else
                        addr_set    <= TRUE;
                        reg_addr_v  := unsigned(rx_data);
                    end if;
                end if;

            when SEND_ACK =>
                wait until (falling_edge(scl) and tx_done) or stop_condition;

                if stop_condition then
                    state   <= GET_STOP;
                else
                    if is_read then
                        state   <= SEND_BYTE;
                    else
                        state   <= GET_BYTE;
                    end if;
                end if;

            when SEND_NACK =>
                wait until falling_edge(scl) or stop_condition;
                state   <= GET_STOP;

            when SEND_BYTE =>
                wait until (falling_edge(scl) and tx_done) or stop_condition;

                if stop_condition then
                    state   <= GET_STOP;
                else
                    reg_addr_v  := reg_addr + 1;
                    state       <= GET_ACK;
                end if;

            when GET_ACK =>
                wait until rx_done;
                state   <= SEND_BYTE when rx_ackd else GET_STOP;

            when GET_STOP =>
                if not stop_condition then
                    wait until stop_condition or stop_during_write;
                end if;

                event_msg           := new_msg(got_stop);
                send(net, I2C_TARGET_VC.p_actor, event_msg);
                state               <= IDLE;
                addr_set            <= FALSE;
                addr_incr           <= FALSE;
                stop_during_write   := FALSE;

        end case;

        reg_addr    <= reg_addr_v;

        wait for 1 fs;
    end process;

    receive_sm: process
    begin
        wait until rising_edge(scl);
        rx_done <= FALSE;
        if state = GET_ACK then
            -- '0' = ACK, '1' = NACK
            rx_ackd         <= TRUE when sda_int = '0' else FALSE;
            rx_bit_count    <= to_unsigned(1, rx_bit_count'length);
        elsif state = GET_START_BYTE or state = GET_BYTE then
            rx_data         <= rx_data(rx_data'high-1 downto rx_data'low) & sda_int;
            rx_bit_count    <= rx_bit_count + 1;
        end if;

        wait until falling_edge(scl) or start_condition or stop_condition;
        if not falling_edge(scl) then
            rx_bit_count    <= (others => '0');
            wait until falling_edge(scl);
        end if;

        if ((state = GET_START_BYTE or state = GET_BYTE) and rx_bit_count = 8) or
            (state = GET_ACK and rx_bit_count = 1) then
            rx_done         <= TRUE;
            rx_bit_count    <= (others => '0');
        end if;
    end process;


    transmit_sm: process
        variable txd : std_logic_vector(7 downto 0) := (others => '0');
    begin
        wait until falling_edge(scl);
        tx_done <= FALSE;
        -- delay the SDA transition to a bit after SCL falls to allow the controller to release SDA
        wait for 100 ns;
        if state = SEND_ACK or state = SEND_NACK then
            sda_oe          <= '1' when state = SEND_ACK else '0';
            tx_bit_count    <= to_unsigned(1, tx_bit_count'length);
        elsif state = SEND_BYTE then
            if tx_bit_count = 0 then
                txd := read_word(I2C_TARGET_VC.p_buffer.p_memory_ref, natural(to_integer(reg_addr)), 1);
            else
                txd := tx_data(tx_data'high-1 downto tx_data'low) & '1';
            end if;
            sda_oe          <= not txd(7);
            tx_bit_count    <= tx_bit_count + 1;
        else
            -- release the bus
            sda_oe          <= '0';
        end if;
        tx_data <= txd;

        wait until rising_edge(scl);

        if ((state = SEND_ACK or state = SEND_NACK) and tx_bit_count = 1) or
            (state = SEND_BYTE and tx_bit_count = 8) then
            tx_done         <= TRUE;
            tx_bit_count    <= (others => '0');
        end if;

    end process;

end architecture;