-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/

-- A verification component that acts as an i2c controller
-- It is expected that the testbench will pull the i2c lines
-- to 'H' and so we only drive low or float high-impedance
-- in this block as a real controller would also do.
    
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;

use work.i2c_ctrl_vc_pkg.all;

entity i2c_controller_vc is
    generic (
        i2c_ctrl_vc : i2c_ctrl_vc_t
    );
    port (
        scl : inout std_logic := 'Z';
        sda : inout std_logic := 'Z'
    );
end entity;

architecture model of i2c_controller_vc is
    constant sclk_per : time := 800 ns;
    constant thd_sta : time := 200 ns;
    constant tsu_sto : time := 200 ns;
    constant tbuf : time := 200 ns;
    type state_t is (IDLE, START, STOP, IN_DATA, OUT_DATA, ACK, NACK, GET_ACK_OR_NACK);
    signal state : state_t := IDLE;
    type flags_t is record
        gen_start : boolean;
        gen_stop : boolean;
    end record;
    signal i2c_tx_data : std_logic_vector(7 downto 0);  -- for debug/tracing etc
    signal i2c_rx_data : std_logic_vector(7 downto 0);  -- for debug/tracing etc

    function decode(byte : integer range 0 to 255) return flags_t is
        variable byte_as_bits : std_logic_vector(7 downto 0);
        variable flags : flags_t;
    begin
        byte_as_bits := To_StdLogicVector(byte, 8);
        flags.gen_start := byte_as_bits(0) = '1';
        flags.gen_stop := byte_as_bits(1) = '1';
        return flags;
    end function;

    function encode(flags : flags_t) return integer is
        variable byte_as_bits : std_logic_vector(7 downto 0);
    begin
        byte_as_bits(0) := '1' when flags.gen_start else '0';
        byte_as_bits(1) := '1' when flags.gen_stop else '0';
        return To_Integer(byte_as_bits);
    end function;

    signal aligner_en : boolean := true;
    signal aligner_int : std_logic := '0';

begin

    -- want to test i2c controllers:
    -- generate i2c transactions of arbitrary length
    -- control whether start/stop are generated.
    -- there are 3 kinds of i2c transactions:
    -- pure write transactions where there's no bus turnaround. Acks/nacks only from target
    --  S | TGTA & W | ACK | DATA..N | ACK/NACK..N| P
    -- pure read transactions
    -- i2c_transmit(byte_queue, generate start, stop after, expected acks)
    -- i2c_receive(byte_queue, generate start, stop after, expected acks)
    -- bus clear (send 9 sclks)

    -- separate thread to provide a synchronizing mechanism
    -- so we can line things up appropriately  This creates
    -- a toggler that can be used to align the sclk and sda
    aligner:process
    begin
        if aligner_en = false then
            aligner_int <= '0';
            wait until aligner_en;
        else
            wait for sclk_per/2;
            aligner_int <= not aligner_int;
        end if;
        
    end process;


    messages: process
        variable msg_type               : msg_type_t;
        variable request_msg, reply_msg : msg_t;
        variable flags                  : flags_t;
        variable ack_nack        : std_logic;
        variable payload             : std_logic_vector(7 downto 0);
        variable byte               : natural;
        procedure gen_start is
            -- High to low transition of SDA while SCL is high
            begin
                if scl = '0' then
                    sda <= 'Z';
                    wait until rising_edge(aligner_int);
                end if;
                state <= START;
                scl <= 'Z';
                sda <= 'Z';
                wait for 60 ns; -- need to be longer than 50ns glitch timing
                sda <= '0';
                wait for thd_sta * 4;
                wait until falling_edge(aligner_int);
                scl <= '0';     -- scl is now low, ready for bits
                wait for 60 ns; -- need to be longer than 50ns glitch timing
                sda <= 'Z';     -- allow sda to float high now that scl is low
            end procedure;
            procedure gen_stop is
                -- assume scl is low
                begin
                    state <= STOP;
                    sda <= '0';
                    wait for tsu_sto;
                    wait until rising_edge(aligner_int);
                    scl <= 'Z';
                    wait for 60 ns;
                    sda <= 'Z';
                    wait for tbuf;
                    wait until falling_edge(aligner_int);
            end procedure;
            procedure shift_out_byte(
                constant payload        : std_logic_vector(7 downto 0)
            ) is
            begin
                state <= OUT_DATA;
                i2c_tx_data <= payload;
                -- assume we're immediately after a start condition or 
                -- after the sclk fedge of an ack/nack
                -- scl must be low coming in and going out
                -- msb first
                for i in 7 downto 0 loop
                    sda <= '0' when payload(i) = '0' else 'Z';  -- clock is low put data out on sda
                    wait until rising_edge(aligner_int);
                    scl <= 'Z';
                    wait until falling_edge(aligner_int);
                    scl <= '0';
                end loop;
            end procedure;
            procedure shift_in_byte(
                variable payload : inout std_logic_vector(7 downto 0)
            ) is
            begin
                state <= IN_DATA;
                -- assume we're immediately after a start condition or an
                -- ack/nack
                -- scl must be low coming in and going out
                -- msb first
                for i in 7 downto 0 loop
                    wait until rising_edge(aligner_int);
                    scl <= 'Z';
                    -- sample sda
                    payload(i) := to_x01(sda);
                    wait until falling_edge(aligner_int);
                    scl <= '0';
                end loop;
                i2c_rx_data <= payload;
            end procedure;
            procedure send_ack is
            begin
                state <= ACK;
                -- assume at beginning of sclk_low period
                sda <= '0';
                wait until rising_edge(aligner_int);
                scl <= 'Z';
                wait until falling_edge(aligner_int);
                sda <= 'Z';
            end procedure;
            procedure send_nack is
            begin
                state <= ACK;
                -- assume at beginning of sclk_low period
                sda <= 'Z';
                wait until rising_edge(aligner_int);
                scl <= 'Z';
                wait until falling_edge(aligner_int);
                sda <= 'Z';
            end procedure;
            procedure get_ack_nack(
                variable ack_nack : out std_logic
            ) is
            begin
                state <= GET_ACK_OR_NACK;
                -- assume at beginning of sclk_low period
                sda <= 'Z';
                wait until rising_edge(aligner_int);
                scl <= 'Z';
                wait until falling_edge(aligner_int);
                ack_nack := to_x01(sda);  -- sample at the very end
                scl <= '0';
            end procedure;
    begin
        state <= IDLE;
        receive(net, i2c_ctrl_vc.p_actor, request_msg);
        msg_type := message_type(request_msg);

        if msg_type = i2c_send_byte then -- blocking
            byte := pop(request_msg);
            shift_out_byte(To_StdLogicVector(byte, 8));
        elsif msg_type = i2c_send_start then -- blocking
            gen_start;
        elsif msg_type = i2c_send_stop then -- blocking
            gen_stop;
        elsif msg_type = i2c_get_byte then -- blocking
            shift_in_byte(payload);
            reply_msg := new_msg;
            push(reply_msg, to_integer(payload));
            reply(net, request_msg, reply_msg);
        elsif msg_type = i2c_send_ack then -- blocking
            send_ack;
        elsif msg_type = i2c_send_nack then -- blocking
            send_nack;
        elsif msg_type = i2c_get_ack_nack then -- blocking
            get_ack_nack(ack_nack);
            reply_msg := new_msg;
            push(reply_msg, ack_nack = '0');  -- 0 is a positive ack
            reply(net, request_msg, reply_msg);
        else
            unexpected_msg_type(msg_type);
        end if;

    end process;



end;