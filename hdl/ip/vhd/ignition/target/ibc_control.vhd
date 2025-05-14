-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company


-- Ignition is pretty simple.  It can can turn on the IBC
-- or turn off the IBC in response to commands.  Any command results
-- in a cool-down period where additional commands are NACKd.
-- We don't currently implement any of the monitoring features
-- since igntion1.0 also did not.
-- aux0 led = controller0 present
-- aux1 led = controller1 present
-- combined = both present
-- cooldown time: ~2seconds



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.time_pkg.all;

entity ibc_control is
    generic(
        COOLDOWN_CNTS : unsigned(26 downto 0)
    );
    port(
        clk     : in std_logic;
        reset   : in std_logic;

        ibc_enable : out std_logic;
        in_cooldown : out std_logic;
        power_on_in_progress : out std_logic;
        power_off_in_progress : out std_logic;
        restart_in_progress : out std_logic;

        power_on_cmd : in std_logic;
        power_off_cmd : in std_logic;
        restart_cmd : in std_logic
    );
end entity;

architecture rtl of ibc_control is
    type state_t is (IBC_OFF, IBC_ON, IBC_RESTART);
    
    type reg_t is record
        state : state_t;
        has_powered_up : std_logic;
        cmd_allowed : std_logic;
        cooldown_cnts : unsigned(31 downto 0);
    end record;
    constant rec_rset : reg_t := (
        state => IBC_OFF,
        has_powered_up => '0',
        cmd_allowed => '0',
        cooldown_cnts => (others => '0')
    );

    signal r,  rin : reg_t;
begin

    in_cooldown <= '1' when r.cmd_allowed = '0' else '0';
    restart_in_progress <= '1' when r.state = IBC_RESTART and r.cmd_allowed = '0' else '0';
    power_on_in_progress <= '1' when r.state = IBC_ON and r.cmd_allowed = '0' else '0';
    power_off_in_progress <= '1' when r.state = IBC_OFF and r.cmd_allowed = '0' else '0';

    sm:process(all)
        variable v : reg_t;
    begin
        v :=  r;

         if r.cooldown_cnts < COOLDOWN_CNTS then
            v.cooldown_cnts := r.cooldown_cnts + 1;
            v.cmd_allowed := '0';
        else
            v.cmd_allowed := '1';
        end if;

        case r.state is
            when IBC_OFF =>
                ibc_enable <= '0';
                -- We need to default sled power to on for the first power
                --up, otherwise we'll rely on our commanded state
                if r.has_powered_up = '0' then
                    v.has_powered_up := '1'; -- set this flag since we'll have
                    -- tried to power up autonomously.
                    v.state := IBC_ON;
                    v.cooldown_cnts := (others => '0');
                end if;
                if power_on_cmd = '1' then
                    v.state := IBC_ON;
                    v.cooldown_cnts := (others => '0');
                end if;
            when IBC_ON =>
                ibc_enable <= '1';
                if power_off_cmd = '1' and r.cmd_allowed = '1' then
                    v.state := IBC_OFF;
                    v.cooldown_cnts := (others => '0');
                    v.cmd_allowed := '0';
                elsif restart_cmd = '1' then
                    v.state := IBC_RESTART;
                end if;
            when IBC_RESTART =>
                ibc_enable <= '0';
                if r.cmd_allowed = '1' then
                    v.state := IBC_ON;
                    v.cooldown_cnts := (others => '0');
                    v.cmd_allowed := '0';
                end if;
                if power_off_cmd = '1' then
                    v.state := IBC_OFF;
                end if;
        end case;
        

        rin <= v;
    end process;



    reg: process(clk, reset)
    begin
        if reset = '1' then
            r <= rec_rset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;
end rtl;