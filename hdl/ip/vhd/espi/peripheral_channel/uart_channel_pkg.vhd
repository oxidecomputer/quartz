-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package uart_channel_pkg is

    type st_uart_t is record
        data : std_logic_vector(7 downto 0);
        valid : std_logic;
        ready : std_logic;
    end record;

    view uart_data_source of st_uart_t is
        data : out;
        valid: out;
        ready: in;
    end view;
    alias uart_data_sink is uart_data_source'converse;

    type uart_resp_t is record
        st : st_uart_t;
        avail_bytes : std_logic_vector(11 downto 0);
    end record;

    view uart_resp_src of uart_resp_t is
        st : view uart_data_source;
        avail_bytes : out;
    end view;
    alias uart_resp_sink is uart_resp_src'converse;




end package;