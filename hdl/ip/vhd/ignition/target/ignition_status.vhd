-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.time_pkg.all;
use work.ignition_pkg.all;

entity ignition_status is
    generic(
         RESEND_CNTS : unsigned(20 downto 0)
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        hello : in std_logic_vector(1 downto 0);
        aligned : in std_logic_vector(1 downto 0);
        locked  : in std_logic_vector(1 downto 0);
        polarity_inv : in std_logic_vector(1 downto 0);
        bad_checksum : in std_logic_vector(1 downto 0);
        bad_decode : in std_logic_vector(1 downto 0);
        invalid_msg_version : in std_logic_vector(1 downto 0);
        invalid_msg_type : in std_logic_vector(1 downto 0);
        ordered_set_invalid : in std_logic_vector(1 downto 0);
        -- ibc status
        reset_in_progress : in std_logic;
        power_on_in_progress : in std_logic;
        power_off_in_progress : in std_logic;
        ibc_power_enabled : in std_logic;
        

        send_strobe : out std_logic;  -- timer or status change.
        packet_sent : in std_logic; -- packet has been sent

        system_status : out system_status_t;
        request_status : out request_status_t;
        link0_status : out link_status_t;
        link0_events : out link_events_t;
        link1_status : out link_status_t;
        link1_events : out link_events_t


    );
end entity;

architecture rtl of ignition_status is
    type state_t is (IDLE, SENDING);
    type small_cnts_t is array(0 to 1) of unsigned(2 downto 0);

    type reg_t is record
        state : state_t;
        strobe  : std_logic;
        pend : std_logic;
        counter : unsigned(RESEND_CNTS'range);
        timer_exp : std_logic;
        link0_events_pend : link_events_t;
        link0_events : link_events_t;
        link1_events_pend : link_events_t;
        link1_events : link_events_t;
        reset_in_progress_last : std_logic;
        power_on_in_progress_last : std_logic;
        power_off_in_progress_last : std_logic;
        ibc_power_enabled_last : std_logic;
        hello_cnts : small_cnts_t;
        liveliness_counts : small_cnts_t;
        controller_present : std_logic_vector(1 downto 0);
    end record;
    constant rec_reset : reg_t := (
        state => IDLE,
        strobe => '0',
        pend => '0',
        counter => (others => '0'),
        timer_exp => '0',
        link0_events_pend => (others => '0'),
        link0_events => (others => '0'),
        link1_events => (others => '0'),
        link1_events_pend => (others => '0'),
        reset_in_progress_last => '0',
        power_on_in_progress_last => '0',
        power_off_in_progress_last => '0',
        ibc_power_enabled_last => '0',
        hello_cnts => (others => (others => '0')),
        liveliness_counts => (others => (others => '0')),
        controller_present => (others => '0')
    );
    
    signal r, rin : reg_t;
begin

    -- Not implemented, with no power monitor, nothing can abort.
    system_status.system_power_abort <= '0';
    system_status.system_power_enabled <= ibc_power_enabled;
    system_status.controller0_present <= r.controller_present(0);
    system_status.controller1_present <= r.controller_present(1);


    link0_status.polarity_inverted <= polarity_inv(0);
    link0_status.receiver_aligned <= aligned(0);
    link0_status.receiver_locked <= locked(0);

    link1_status.polarity_inverted <= polarity_inv(1);
    link1_status.receiver_aligned <= aligned(1);
    link1_status.receiver_locked <= locked(1);

    request_status.power_off_in_progress <= power_off_in_progress;
    request_status.power_on_in_progress <= power_on_in_progress;
    request_status.reset_in_progress <= reset_in_progress;

    send_strobe <= r.strobe;
    link0_events <= r.link0_events;
    link1_events <= r.link1_events;

    -- Store any errors until next send
    store_and_send:process(all)
        variable v : reg_t;
    begin
        v := r;

        v.strobe := '0';

        if r.counter = RESEND_CNTS then
            v.timer_exp := '1';
        else
            v.counter := r.counter + 1;
        end if;

        v.reset_in_progress_last := reset_in_progress;
        v.power_on_in_progress_last := power_on_in_progress;
        v.power_off_in_progress_last := power_off_in_progress;
        v.ibc_power_enabled_last := ibc_power_enabled;

        -- hello counters to indicate controller presence after
        -- seeing 3 hellos.
        for i in 0 to 1 loop
           if aligned(i) = '0' then
                v.hello_cnts(i) := (others => '0');
            elsif hello(i) = '1' and r.hello_cnts(i) < 3 then
               v.hello_cnts(i) := v.hello_cnts(i) + 1;
            end if;
            if r.hello_cnts(i) = 3 then
                v.controller_present(i) := '1';
            end if;

            if hello(i) = '1' then
                v.liveliness_counts(i) := (others => '1');
            elsif r.timer_exp = '1' and r.liveliness_counts(i) > 0 then
                v.liveliness_counts(i) := r.liveliness_counts(i) - 1;
            elsif r.liveliness_counts(i) = 0 then
                v.controller_present(i) := '0';
                v.hello_cnts(i) := (others => '0');
            end if;
        end loop;

        case r.state is
            when IDLE =>

                if r.timer_exp = '1' or r.pend = '1' then
                    v.state := SENDING;
                    v.strobe := '1';
                    v.pend := '0';
                    -- store current events, clear pending events
                    -- anything same-cycle will pick up below.
                    v.link0_events := r.link0_events_pend;
                    v.link1_events := r.link1_events_pend;
                    v.link0_events_pend := (others => '0');
                    v.link1_events_pend := (others => '0');
                    v.timer_exp := '0';
                    v.counter := (others => '0'); -- reset counter
                end if;

            when SENDING =>
                if packet_sent = '1' then
                    v.state := IDLE;
                    v.link0_events := (others => '0');
                    v.link1_events := (others => '0');
                end if;

        end case;

        if bad_checksum /= "00" then
            v.link1_events_pend.msg_checksum_invalid := bad_checksum(0);
            v.link1_events_pend.msg_checksum_invalid := bad_checksum(1);
            v.pend := '1';
        end if;
        if bad_decode /= "00" then
            v.link1_events_pend.decoding_error := bad_decode(0);
            v.link1_events_pend.decoding_error := bad_decode(1);
            v.pend := '1';
        end if;
        if invalid_msg_version /= "00" then
            v.link1_events_pend.message_version_invalid := invalid_msg_version(0);
            v.link1_events_pend.message_version_invalid := invalid_msg_version(1);
            v.pend := '1';
        end if;
        if invalid_msg_type /= "00" then
            v.link1_events_pend.msg_type_invalid := invalid_msg_type(0);
            v.link1_events_pend.msg_type_invalid := invalid_msg_type(1);
            v.pend := '1';
        end if;
        if ordered_set_invalid /= "00" then
            v.link1_events_pend.ordered_set_invalid := ordered_set_invalid(0);
            v.link1_events_pend.ordered_set_invalid := ordered_set_invalid(1);
            v.pend := '1';
        end if;
        if (
        r.reset_in_progress_last /= reset_in_progress or
        r.power_on_in_progress_last /= power_on_in_progress or
        r.power_off_in_progress_last /= power_off_in_progress or
        r.ibc_power_enabled_last /= ibc_power_enabled) then
            v.pend := '1';
        end if;


        rin <= v;
    end  process;


    reg: process(clk, reset)
    begin
        if reset = '1' then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    

end  rtl;