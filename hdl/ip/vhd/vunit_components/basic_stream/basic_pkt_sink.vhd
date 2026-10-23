-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Packet-aware sink for a push-only stream: data with last and err flags
-- and no ready. basic_sink only listens while a pop is outstanding, which is
-- fine when it owns the backpressure but drops beats on a stream that cannot
-- be stalled. This one captures every beat as it arrives and hands whole
-- packets back through pop_basic_pkt.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;

entity basic_pkt_sink is
    generic (
        sink    : basic_sink_t
    );
    port (
        clk     : in std_logic;
        valid   : in std_logic;
        last    : in std_logic;
        err     : in std_logic := '0';
        data    : in std_logic_vector(data_length(sink)-1 downto 0)
    );
end entity;

architecture model of basic_pkt_sink is
    -- Beats are captured into one flat queue, each as data, last, err. The
    -- handler counts completed packets so a pop can wait for a whole one.
    constant captured : queue_t := new_queue;
    signal packets_captured : natural := 0;
begin

    capture: process
    begin
        wait until rising_edge(clk) and valid = '1';
        push(captured, data);
        push_boolean(captured, last = '1');
        push_boolean(captured, err = '1');
        if last = '1' then
            packets_captured <= packets_captured + 1;
        end if;
    end process;

    main: process
        variable msg, reply_msg : msg_t;
        variable msg_type       : msg_type_t;
        variable packets_popped : natural := 0;
        variable bytes          : queue_t;
        variable beat_data      : std_logic_vector(data'range);
        variable beat_last      : boolean;
        variable beat_err       : boolean;
    begin
        receive(net, sink.p_actor, msg);
        msg_type := message_type(msg);

        if msg_type = pop_basic_pkt_msg then
            if packets_captured <= packets_popped then
                wait until packets_captured > packets_popped;
            end if;
            bytes := new_queue;
            loop
                beat_data := pop(captured);
                beat_last := pop_boolean(captured);
                beat_err := pop_boolean(captured);
                push(bytes, beat_data);
                exit when beat_last;
            end loop;
            packets_popped := packets_popped + 1;

            reply_msg := new_msg;
            push_queue_ref(reply_msg, bytes);
            push_boolean(reply_msg, beat_err);
            reply(net, msg, reply_msg);
        else
            unexpected_msg_type(msg_type);
        end if;
    end process;

end architecture;
