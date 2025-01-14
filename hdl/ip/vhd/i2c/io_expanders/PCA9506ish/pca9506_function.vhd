-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.i2c_base_types_pkg.all;
use work.pca9506_pkg.all;

entity pca9506ish_function is
    generic(
        -- i2c address of the mux
        i2c_addr : std_logic_vector(6 downto 0) := 7x"70"
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        -- PHY interface
        -- instruction interface
        inst_data : in std_logic_vector(7 downto 0);
        inst_valid : in std_logic;
        inst_ready : out std_logic;
        in_ack_phase: in std_logic;
        ack_next : out std_logic;
        txn_header : in i2c_header;
        start_condition : in std_logic;
        stop_condition : in std_logic;
        -- response interface
        resp_data : out std_logic_vector(7 downto 0);
        resp_valid : out std_logic;
        resp_ready : in std_logic;

        -- internal register interface
        read_data : in std_logic_vector(7 downto 0);
        write_data : out std_logic_vector(7 downto 0);
        read_strobe : out std_logic;
        write_strobe : out std_logic;
        cmd_ptr : out cmd_t
    );
end entity;

architecture rtl of pca9506ish_function is

    type state_t is (IDLE, WAIT_FOR_ACKNACK, WAIT_FOR_ACK_PHASE, ACK, NACK, COMMAND, DO_WRITE, DO_READ);
    
    type reg_t is record
        state : state_t;
        post_ack_state : state_t;
        read_strobe : std_logic;
        write_strobe : std_logic;
        cmd_reg : cmd_t;
        data : std_logic_vector(7 downto 0);
        data_valid: std_logic;
        increment : std_logic;
    end record;

    constant rec_reset : reg_t := (
        state => IDLE, 
        post_ack_state => IDLE,
        read_strobe => '0', 
        write_strobe => '0', 
        cmd_reg => default_reset,
        data => (others => '0'),
        data_valid => '0',
        increment => '0'
    );

    signal r, rin : reg_t;

begin

   --assign some outputs
   read_strobe <= r.read_strobe;
   write_strobe <= r.write_strobe;
   cmd_ptr <= r.cmd_reg;
   resp_data <= r.data;
   ack_next <= '1' when r.state = ACK else '0';
   write_data <= r.data;
   inst_ready <= '1' when r.state = COMMAND or r.state = DO_WRITE else '0';
   resp_valid <= r.data_valid;

    cm: process(all)
    variable v : reg_t;
    begin
        v := r;

        case r.state is
            when IDLE =>
                v.increment := '0';
                if txn_header.valid = '1' and txn_header.tgt_addr = i2c_addr then
                    v.state := ACK;
                    if txn_header.read_write_n = '0' then
                        -- all writes go through command state after target
                        v.post_ack_state := COMMAND;
                    else
                        -- post repeated start, reads bypass command state
                        -- and immediately do reads
                        v.post_ack_state := DO_READ;
                        -- pointer is valid
                    end if;
                end if;


            when COMMAND =>
                if inst_valid = '1' and inst_ready = '1' then
                    v.cmd_reg.ai := inst_data(7);
                    v.cmd_reg.pointer := inst_data(5 downto 0);
                    v.post_ack_state := DO_WRITE;
                    v.state := ACK;
                end if;

            when DO_WRITE =>
                if inst_valid = '1' and inst_ready = '1' then
                    v.data := inst_data;
                    v.state := ACK;
                    v.write_strobe := '1';
                    v.increment := v.cmd_reg.ai;
                end if;

            when DO_READ =>
                v.read_strobe := '1';
                v.data_valid := '1';
                v.data := read_data;
                v.state := WAIT_FOR_ACK_PHASE;

            when ACK =>
                -- clear any single-cycle strobes
                v.write_strobe := '0';
                v.read_strobe := '0';
                -- wait for ack time to finish
                if in_ack_phase = '0' then
                    v.state := r.post_ack_state;
                    if r.increment then
                        -- do a category-wrapping increment
                        v.cmd_reg.pointer := category_wrapping_increment(r.cmd_reg.pointer);
                    end if;
                end if;
            when NACK =>
                if in_ack_phase = '0' then
                    v.state := IDLE;
                end if;

            when WAIT_FOR_ACK_PHASE =>
                    -- clear any single-cycle strobes
                    v.write_strobe := '0';
                    v.read_strobe := '0';
                    if resp_valid = '1' and resp_ready = '1' then
                        v.data_valid := '0';
                        v.increment := v.cmd_reg.ai;
                    end if;
                    if in_ack_phase = '1' then
                        v.state := WAIT_FOR_ACKNACK;
                    end if;

            when WAIT_FOR_ACKNACK =>
                 -- clear any single-cycle strobes
                 v.write_strobe := '0';
                 v.read_strobe := '0';
                if in_ack_phase = '0' then
                    v.state := DO_READ; 
                    if r.increment then
                        -- do a category-wrapping increment
                        v.cmd_reg.pointer := category_wrapping_increment(r.cmd_reg.pointer);
                    end if;
                end if;

            when others =>
                v.state := IDLE;

        end case;

        if resp_valid = '1' and resp_ready = '1' then
            v.data_valid := '0';
        end if;

        -- No matter where we were, do cleanup if we see a stop
        if start_condition = '1' or stop_condition = '1' then
            v.state := IDLE;
            v.write_strobe := '0';
            v.read_strobe := '0';
        end if;
                
        rin <= v;
    end process;


  reg: process(clk, reset)
    begin
        if reset = '1' then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
end process;


end rtl;