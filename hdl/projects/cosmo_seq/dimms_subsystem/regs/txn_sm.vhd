-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity txn_sm is
    port(
        clk        : in std_logic;
        reset      : in std_logic;

        start_flag : in std_logic;
        request : out std_logic;
        grant   : in std_logic;

        cmd_valid : out std_logic;

        done : in std_logic;
        aborted : in std_logic;

    );
end entity;

architecture rtl of txn_sm is

    type state_t is (IDLE, REQ, WAIT_UNTIL_BUSY, SENDING_CMD, ABORT);

    signal state : state_t;
begin
    
    process(clk, reset)
    begin
        if reset then
            request <= '0';
            state <= IDLE;
            cmd_valid <= '0';
            

        elsif rising_edge(clk) then
            cmd_valid <= '0';  -- single cycle
            case state is
                when IDLE =>
                    request <= '0';
                    if start_flag = '1' then
                        state <= REQ;
                        request <= '1';
                    end if;

                when REQ =>
                    if grant = '1' then
                        state <= WAIT_UNTIL_BUSY;
                        cmd_valid <= '1';
                    end if;

                when WAIT_UNTIL_BUSY =>
                    if done = '0' then
                        state <= SENDING_CMD;
                    end if;
                when SENDING_CMD =>
                    if aborted = '1' then
                        state <= ABORT;
                        request <= '0'; -- free the bus due to abort
                    elsif done = '1' then
                        state <= IDLE;
                        request <= '0';
                    end if;

                when ABORT =>
                    -- need to re-try the transaction
                    state <= REQ;
                    request <= '1';

            end case;
        end if;

    end process;

end rtl;