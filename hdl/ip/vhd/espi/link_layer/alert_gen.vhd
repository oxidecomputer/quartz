-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity alert_gen is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        alert_needed : in std_logic;
        cs_n  : in    std_logic;

        active_alert : out std_logic


    );
end entity;

architecture rtl of alert_gen is
    type cs_monitor_t is (no_alert_allowed, alert_allowed);
    signal cs_monitor_state : cs_monitor_t;
    type alert_state_t is (idle, wait_for_allowed, alert);
    signal alert_state : alert_state_t;
    signal cs_cntr : natural range 0 to 3 := 0;
    constant cs_deassert_delay : natural := 2;

begin

    active_alert <= '1' when alert_state = alert else '0';

    -- We have some fairly slow minimum delay timings for the alert pin
    -- this block monitors the chip select and provides an alert_allowed
    -- window for the alert processor.
    cs_mon:process(clk, reset)
    begin
        if reset then
            cs_monitor_state <= no_alert_allowed;
            cs_cntr <= 0;
        elsif rising_edge(clk) then
            case cs_monitor_state is 
                when no_alert_allowed =>
                    if cs_n = '1' then
                        cs_cntr <= cs_cntr + 1;
                    else 
                        cs_cntr <= 0;
                    end if;
                    if cs_cntr >= cs_deassert_delay then
                        cs_monitor_state <= alert_allowed;
                    end if;
                when alert_allowed =>
                    if cs_n = '0' then
                        cs_monitor_state <= no_alert_allowed;
                        cs_cntr <= 0;
                    end if;
            end case;
        end if;
    end process;

    alert_processor: process(clk, reset)
    begin
        if reset then
            alert_state <= idle;
        elsif rising_edge(clk) then
            -- If we have an alert to send, we can send it by pulling
            --io[1] low, but only when cs is not asserted.
            -- it is possible that we will send a status before this
            -- is needed, in which case we should not send the alert
            -- since the status was current.
            case alert_state is
                when idle =>
                    if alert_needed = '1' and cs_monitor_state = alert_allowed then
                        alert_state <= alert;
                    elsif alert_needed then
                        alert_state <= wait_for_allowed;
                    end if;
                when wait_for_allowed =>
                    if not alert_needed then
                        alert_state <= idle;
                    elsif cs_monitor_state = alert_allowed then
                        alert_state <= alert;
                    end if;
                when alert =>
                    if not alert_needed then
                        alert_state <= idle;
                    elsif cs_n = '0' or cs_monitor_state = no_alert_allowed then
                        alert_state <= idle;
                    end if;
            end case;
        
        end if;
    end process;

end rtl;