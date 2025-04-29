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
        GET_ADDR_BYTE,
        GET_BYTE,
        GET_ACK,
        GET_STOP
    );

    signal state    : state_t := IDLE;

    signal start_condition  : boolean                     := FALSE;
    signal stop_condition   : boolean                     := FALSE;
    signal rx_data          : std_logic_vector(7 downto 0)  := (others => '0');
    signal rx_bit_count     : unsigned(3 downto 0)          := (others => '0');
    signal rx_ackd          : boolean                       := FALSE;
    signal tx_data          : std_logic_vector(7 downto 0)  := (others => '0');
    signal tx_bit_count     : unsigned(3 downto 0)          := (others => '0');
    signal rx_byte_done     : std_logic                     := '0';
    signal rx_ack_done      : std_logic                     := '0';
    signal tx_byte_done     : std_logic                     := '0';
    signal tx_ack_done      : std_logic                     := '0';

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

    start_proc:process
    begin
        start_condition  <=  true when falling_edge(sda_int) and scl_int = '1' else false;
        wait on sda_int, scl_int;
    end process;

    stop_proc:process
    begin
        stop_condition  <=  true when rising_edge(sda_int) and scl_int = '1' else false;
        wait on sda_int, scl_int;
    end process;
        

    transaction_sm: process
        variable event_msg          : msg_t;
        variable is_read            : boolean               := FALSE;
        variable reg_addr_v         : unsigned(7 downto 0)  := (others => '0');
        variable stop_during_write  : boolean               := FALSE;
    begin
        case state is

            when IDLE =>
                wait until start_condition;
                state <= START;

            when START =>
                event_msg   := new_msg(got_start);
                send(net, I2C_TARGET_VC.p_actor, event_msg);
                state       <= GET_ADDR_BYTE;

            when GET_ADDR_BYTE =>
                wait until rx_byte_done = '1' or stop_condition;

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
                wait until rx_byte_done = '1' or start_condition or stop_condition;

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
                        report "Writing " & integer'image(to_integer(unsigned(rx_data))) &" to register " & integer'image(to_integer(reg_addr_v));
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
                wait until tx_ack_done = '1' or stop_condition;

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
                wait until tx_ack_done = '1' or stop_condition;
                state   <= GET_STOP;

            when SEND_BYTE =>
                wait until tx_byte_done = '1' or stop_condition;

                if stop_condition then
                    state   <= GET_STOP;
                else
                    reg_addr_v  := reg_addr + 1;
                    state       <= GET_ACK;
                end if;

            when GET_ACK =>
                if rx_ack_done = '0' then
                    wait until rx_ack_done = '1' or stop_condition;
                end if;
                state   <= SEND_BYTE when rx_ackd else GET_STOP;

            when GET_STOP =>
                event_msg           := new_msg(got_stop);
                send(net, I2C_TARGET_VC.p_actor, event_msg);
                state               <= IDLE;
                addr_set            <= FALSE;
                addr_incr           <= FALSE;
                stop_during_write   := FALSE;

        end case;

        reg_addr    <= reg_addr_v;
        wait for 0 ns; -- force a delta cycle so that everything updates

    end process;

    -- This block will hold for a start condition, stop and  hold after a stop condition
    -- and otherwise sample data on the rising edge of ever SCL.
    -- rx_bit_count will be 8 during the ACK phase on a standard transaction.
    receive_sm: process
        variable in_transaction : boolean := false;
    begin
        -- hold for the start of a transaction
        if not in_transaction then
            rx_bit_count <= (others => '0');
            wait until start_condition;
            in_transaction := true;  -- set flag so we bypass this check for every sample.
        end if;

        -- data phase, sample on rising edge
        wait until rising_edge(scl_int) or start_condition or stop_condition;
        if stop_condition then  -- Stop
            in_transaction := false; -- need to wait for the next start condition
            rx_bit_count <= (others => '0');
        elsif start_condition then -- Restart
            in_transaction := true; -- don't wait for the next start since we just got one
            rx_bit_count <= (others => '0');
        else -- was falling edge, sample data
            rx_data  <= rx_data(rx_data'high-1 downto rx_data'low) & sda_int;
            if rx_bit_count = 9 then
                rx_bit_count <= (0 => '1', others => '0');
            else
                rx_bit_count    <= rx_bit_count + 1;
            end if;
        end if;
    end process;
    rx_byte_done <= '1' when rx_bit_count = 8 and scl_int = '0' else '0';
    rx_ack_done <= '1' when rx_bit_count = 9 and scl_int = '0' else '0';
    rx_ackd <= true when rx_bit_count = 9 and sda_int = '0' else false;

    -- This block will transmit data in response to a command or acks as directed by the
    -- transaction state machine.
    transmit_sm: process
        variable own_bus : boolean := false;
        variable tx_bit_count_v : integer := 0;
        variable in_tx_transaction : boolean := false;
        variable txd : std_logic_vector(7 downto 0) := (others => '0');
    begin
        if not in_tx_transaction then
            sda_oe <= '0';
            own_bus := false;
            wait until start_condition;
            tx_bit_count_v := 0;
            in_tx_transaction := true;  -- set flag so we bypass this check for every sample.
        end if;
        wait until falling_edge(scl_int) or stop_condition;
        wait for 60 ns;  -- Bus turn-around time
        if stop_condition then  -- Stop
            in_tx_transaction := false; -- need to wait for the next start condition
            tx_bit_count_v := 0;
        else
            if state = SEND_BYTE then
                report "test: " & integer'image(tx_bit_count_v);
                if tx_bit_count_v = 0 or tx_bit_count_v = 9 then
                    txd := read_word(I2C_TARGET_VC.p_buffer.p_memory_ref, natural(to_integer(reg_addr)), 1);
                    report "Got " & integer'image(to_integer(unsigned(txd))) &" from register " & integer'image(to_integer(reg_addr));
                    tx_bit_count_v := 0;
                else
                    txd := tx_data(tx_data'high-1 downto tx_data'low) & '1';
                end if;
            end if;
            if tx_bit_count_v = 9 then
                tx_bit_count_v := 0;
            else 
                tx_bit_count_v := tx_bit_count_v + 1;
            end if;
            sda_oe <= '1' when state = SEND_ACK else
                      not txd(7) when state = SEND_BYTE else '0';
        end if;
        tx_data <= txd;
        tx_bit_count <= to_unsigned(tx_bit_count_v, tx_bit_count'length);

    end process;
    tx_byte_done <= '1' when rx_bit_count = 8 and scl_int = '0' else '0';
    tx_ack_done <= '1' when rx_bit_count = 9 and scl_int = '0' else '0';

end architecture;