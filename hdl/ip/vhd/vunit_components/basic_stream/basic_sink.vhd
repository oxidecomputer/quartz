-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company
--
-- A basic sink for streamed data that can apply backpressure.

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;

entity basic_sink is
    generic (
        sink    : basic_sink_t
    );
    port (
        clk     : in std_logic;
        ready   : out std_logic := '0';
        valid   : in std_logic;
        data    : in std_logic_vector(data_length(sink)-1 downto 0)
    );
end entity;

architecture model of basic_sink is
begin

    main: process
        variable msg, reply_msg : msg_t;
        variable msg_type       : msg_type_t;
        variable rnd            : RandomPType;
    begin
        receive(net, sink.p_actor, msg);
        msg_type := message_type(msg);

        if msg_type = stream_pop_msg or msg_type = pop_basic_stream_msg then
            loop
                -- loop until ready
                while rnd.Uniform(0.0, 1.0) > sink.ready_high_probability loop
                    wait until rising_edge(clk);
                end loop;
                ready <= '1';
                -- wait for a clk rising edge to sample valid
                wait until ready = '1' and rising_edge(clk);
                if valid = '1' then
                    reply_msg := new_msg;
                    push_std_ulogic_vector(reply_msg, data);
                    reply(net, msg, reply_msg);
                    ready <= '0';
                    exit;
                end if;
                ready <= '0';
            end loop;
        else
            unexpected_msg_type(msg_type);
        end if;
    end process;

end architecture;