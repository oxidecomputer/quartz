-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL 
-- plugin: https://terostechnology.github.io/terosHDLdoc/


--! A simple verification component that allows gpio stimulus
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use work.gpio_msg_pkg.all;


entity sim_gpio is
    generic(
        OUT_NUM_BITS : integer range 0 to 32;
        IN_NUM_BITS: integer range 0 to 32;
        ACTOR_NAME : string := "sim_gpio"
    );
    port(
        clk       : in std_logic;
        gpio_in   : in std_logic_vector(IN_NUM_BITS - 1 downto 0) := (others => '0');
        gpio_out  : out std_logic_vector(OUT_NUM_BITS - 1 downto 0) := (others => '0')
    );
end entity;
architecture model of sim_gpio is
begin
    main : process is
        variable self      : actor_t;
        variable data      : std_logic_vector(GPIO_MESAGE_DATA_WDITH - 1 downto 0);
        variable msg_type  : msg_type_t;
        variable request_msg, reply_msg : msg_t;
    begin
        self := new_actor(ACTOR_NAME);
        loop

            receive(net, self, request_msg);
            msg_type := message_type(request_msg);
            if msg_type = write_msg then
                -- get the payload
                data := pop(request_msg);
                --demonstration of logging and string_io functions
                -- not specifically needed for anything here
                info("Got write" & hex_image(data)); 
                -- We want sync transitions so let's adjust the output
                -- after the falling_edge of the clock and then wait for
                -- the rising edge after setting
                wait until falling_edge(clk);
                -- apply rx'd message to outputs
                gpio_out <= data(OUT_NUM_BITS - 1 downto 0); 
                -- make sure we assert through rising edge this
                -- prevents back-back messages from only eating
                -- delta-cycles and not actually being seen by the
                -- DUT which is (likely) rising-egde clocked
                wait until rising_edge(clk);
            elsif msg_type = read_msg then
                -- More logger demonstration
                info("got read");
                -- clear any stale data
                data := (others => '0');
                -- sample at rising edge, we're getting data presumably
                -- from a DUT that is clocked so we need to sample at rising
                -- edges
                wait until rising_edge(clk);
                data(IN_NUM_BITS - 1 downto 0) := gpio_in;
                -- create and send the reply message
                reply_msg := new_msg(read_reply_msg);
                push(reply_msg, data);
                reply(net, request_msg, reply_msg);

            else
                -- This shouldn't happen but will provide
                -- proper error reporting if it does
                unexpected_msg_type(msg_type);
            end if;

        end loop;
        wait;
    end process main;
end model;