-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company
--
-- This block monitors two I2C SDA signals, `a` and `b`, with the intention thatt hey are
-- essentially connected but proxied by the FPGA. It assumes the inactive state for the bus is high,
-- and then monitors for `a` or `b` to pull the line low. It will then grant whichever side pulled
-- the line low the bus until that side releases it, at which point after HYSTERESIS_CYCLES both
-- sides will be resampled again.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sda_arbiter is
    generic (
        HYSTERESIS_CYCLES : natural
    );
    port (
        clk     : in std_logic;
        reset   : in std_logic;

        a       : in std_logic;
        b       : in std_logic;
        enabled : in std_logic;
        a_grant : out std_logic;
        b_grant : out std_logic
    );
end entity;

architecture rtl of sda_arbiter is
    type sda_control_t is (
        NONE,
        GRANT_A,
        GRANT_B
    );
    signal sda_state : sda_control_t;
    signal last_grant : sda_control_t;
    signal hysteresis_cntr : natural range 0 to HYSTERESIS_CYCLES;
begin

    a_grant <= '1' when sda_state = GRANT_A else '0';
    b_grant <= '1' when sda_state = GRANT_B else '0';

    arbitration : process(clk, reset)
    begin
        if reset then
            sda_state       <= NONE;
            last_grant      <= NONE;
            hysteresis_cntr <= 0;
        elsif rising_edge(clk) then
            if enabled then

                    case sda_state is
                        when NONE =>
                            -- We were came from GRANT_A so a was high.
                            if last_grant = GRANT_A and a = '0' then
                                sda_state    <= GRANT_A;
                            -- We were came from GRANT_B so B was high
                            elsif last_grant = GRANT_B and b = '0' then
                                sda_state    <= GRANT_B;
                            -- else wait our counter and then decide
                            elsif hysteresis_cntr = HYSTERESIS_CYCLES then
                                if a = '0' and b = '1' then
                                    sda_state    <= GRANT_A;
                                elsif a = '1' and b = '0' then
                                    sda_state    <= GRANT_B;
                                end if;
                            else 
                                hysteresis_cntr <= hysteresis_cntr + 1;
                            end if;

                        when GRANT_A =>
                            -- A is done, go back to NONE
                            if a = '1' then
                                sda_state  <= NONE;
                                last_grant <= GRANT_A;
                                hysteresis_cntr <= 0;
                            end if;

                        when GRANT_B =>
                            -- A is done, go back to NONE
                            if b = '1' then
                                last_grant <= GRANT_B;
                                sda_state   <= NONE;
                                hysteresis_cntr <= 0;
                            end if;
                    end case;

            else
                sda_state  <= NONE;
                hysteresis_cntr <= 0;
            end if;
        end if;
    end process;

end architecture;