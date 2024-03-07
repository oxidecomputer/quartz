-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

package gpio_msg_pkg is
    constant write_msg : msg_type_t := new_msg_type("write");
    constant read_msg : msg_type_t := new_msg_type("read");
    constant read_reply_msg : msg_type_t := new_msg_type("read_reply");

    constant GPIO_MESAGE_DATA_WDITH : integer := 32;

    procedure set_gpio(
        signal net : inout network_t;
        constant actor: actor_t;
        variable data: in std_logic_vector(GPIO_MESAGE_DATA_WDITH - 1 downto 0)
    );
    procedure get_gpio(
        signal net : inout network_t;
        constant actor: actor_t;
        variable data: out std_logic_vector(GPIO_MESAGE_DATA_WDITH - 1 downto 0)
    );
   

end gpio_msg_pkg;

package body gpio_msg_pkg is
    -- Helper function for testbenches to set gpio's on the 
    -- sim gpio block.
    procedure set_gpio(
        signal net : inout network_t;
        constant actor: actor_t;
        variable data: in std_logic_vector(GPIO_MESAGE_DATA_WDITH - 1 downto 0)
    ) is
        variable request_msg: msg_t := new_msg(write_msg);
    begin
        push(request_msg, data);
        send(net, actor, request_msg);
    end;
    -- Helper function for testbenches to read gpio's on the 
    -- sim gpio block.
    procedure get_gpio(
        signal net : inout network_t;
        constant actor: actor_t;
        variable data: out std_logic_vector(GPIO_MESAGE_DATA_WDITH - 1 downto 0)
    ) is
        variable request_msg: msg_t := new_msg(read_msg);
        variable reply_msg: msg_t;
        variable msg_type : msg_type_t;
    begin
        push(request_msg, data);
        send(net, actor, request_msg);
        receive_reply(net, request_msg, reply_msg);
        msg_type := message_type(reply_msg);
        data := pop(reply_msg);
    end;
end package body;