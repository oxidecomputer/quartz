-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

package basic_stream_pkg is

    type basic_source_t is record
        valid_high_probability  : real range 0.0 to 1.0;
        -- private
        p_actor         : actor_t;
        p_data_length   : natural;
        p_logger        : logger_t;
    end record;

    type basic_sink_t is record
        ready_high_probability  : real range 0.0 to 1.0;
        -- private
        p_actor         : actor_t;
        p_data_length   : natural;
        p_logger        : logger_t;
    end record;

    constant basic_stream_logger    : logger_t := get_logger("work:basic_stream_pkg");

    impure function new_basic_source(
        data_length             : natural;
        valid_high_probability  : real := 1.0;
        logger                  : logger_t := basic_stream_logger;
        actor                   : actor_t := null_actor
    ) return basic_source_t;

    impure function new_basic_sink(
        data_length             : natural;
        ready_high_probability  : real := 1.0;
        logger                  : logger_t := basic_stream_logger;
        actor                   : actor_t := null_actor
    ) return basic_sink_t;

    impure function data_length(source : basic_source_t) return natural;
    impure function data_length(source : basic_sink_t) return natural;

    impure function as_stream(source : basic_source_t) return stream_master_t;
    impure function as_stream(sink : basic_sink_t) return stream_slave_t;

    constant push_basic_stream_msg          : msg_type_t := new_msg_type("push basic stream");
    constant pop_basic_stream_msg           : msg_type_t := new_msg_type("pop basic stream");
    constant basic_stream_transaction_msg   : msg_type_t := new_msg_type("basic stream transaction");

    procedure push_basic_stream(
        signal net      : inout network_t;
        basic_source    : basic_source_t;
        data            : std_logic_vector
    );

    procedure pop_basic_stream(
        signal net : inout network_t;
        basic_sink : basic_sink_t;
        variable data : inout std_logic_vector
    );

    type basic_stream_transaction_t is record
        data : std_logic_vector;
    end record;

    procedure push_basic_stream_transaction(
        msg : msg_t; 
        basic_stream_transaction : basic_stream_transaction_t
    );

    procedure pop_basic_stream_transaction(
        constant msg                        : in msg_t;
        variable basic_stream_transaction   : out basic_stream_transaction_t
    );

    impure function new_basic_stream_transaction_msg(
        basic_stream_transaction : basic_stream_transaction_t
    ) return msg_t;

    procedure handle_basic_stream_transaction(
        variable msg_type           : inout msg_type_t;
        variable msg                : inout msg_t;
        variable basic_transaction  : out basic_stream_transaction_t
    );

end package;

package body basic_stream_pkg is

    impure function new_basic_source(
        data_length             : natural;
        valid_high_probability  : real := 1.0;
        logger                  : logger_t := basic_stream_logger;
        actor                   : actor_t := null_actor
    ) return basic_source_t is
        variable p_actor : actor_t;
    begin
        p_actor := actor when actor /= null_actor else new_actor;

        return (
            valid_high_probability => valid_high_probability,
            p_actor => p_actor,
            p_data_length => data_length,
            p_logger => logger
        );
    end;

    impure function new_basic_sink(
        data_length             : natural;
        ready_high_probability  : real := 1.0;
        logger                  : logger_t := basic_stream_logger;
        actor                   : actor_t := null_actor)
    return basic_sink_t is
        variable p_actor : actor_t;
    begin
        p_actor := actor when actor /= null_actor else new_actor;

        return (
            ready_high_probability => ready_high_probability,
            p_actor => p_actor,
            p_data_length => data_length,
            p_logger => logger
        );
    end;

    impure function data_length(source : basic_source_t) return natural is
    begin
        return source.p_data_length;
    end;

    impure function data_length(source : basic_sink_t) return natural is
    begin
        return source.p_data_length;
    end;

    impure function as_stream(source : basic_source_t) return stream_master_t is
    begin
        return (p_actor => source.p_actor);
    end;

    impure function as_stream(sink : basic_sink_t) return stream_slave_t is
    begin
        return (p_actor => sink.p_actor);
    end;

    procedure push_basic_stream(
        signal net      : inout network_t;
        basic_source    : basic_source_t;
        data            : std_logic_vector
    ) is
        variable msg : msg_t := new_msg(push_basic_stream_msg);
        variable basic_stream_transaction : basic_stream_transaction_t(data(data'length - 1 downto 0));
    begin
        basic_stream_transaction.data := data;
        push_basic_stream_transaction(msg, basic_stream_transaction);
        send(net, basic_source.p_actor, msg);
    end;

    procedure pop_basic_stream(
        signal net : inout network_t;
        basic_sink : basic_sink_t;
        variable data : inout std_logic_vector
    ) is
        variable reference : msg_t := new_msg(pop_basic_stream_msg);
        variable reply_msg : msg_t;
        variable basic_stream_transaction : basic_stream_transaction_t(data(data'length - 1 downto 0));
    begin
        send(net, basic_sink.p_actor, reference);
        receive_reply(net, reference, reply_msg);
        pop_basic_stream_transaction(reply_msg, basic_stream_transaction);
        data := basic_stream_transaction.data;
        delete(reference);
        delete(reply_msg);
    end;

    procedure push_basic_stream_transaction(
        msg                         : msg_t;
        basic_stream_transaction    : basic_stream_transaction_t
    ) is
    begin
        push_std_ulogic_vector(msg, basic_stream_transaction.data);
    end;

    procedure pop_basic_stream_transaction(
        constant msg                        : in msg_t;
        variable basic_stream_transaction   : out basic_stream_transaction_t
    ) is
    begin
        basic_stream_transaction.data := pop_std_ulogic_vector(msg);
    end;

  impure function new_basic_stream_transaction_msg(
    basic_stream_transaction : basic_stream_transaction_t
  ) return msg_t is
        variable msg : msg_t;
    begin
        msg := new_msg(basic_stream_transaction_msg);
        push_basic_stream_transaction(msg, basic_stream_transaction);
        return msg;
    end;

    procedure handle_basic_stream_transaction(
        variable msg_type           : inout msg_type_t;
        variable msg                : inout msg_t;
        variable basic_transaction  : out basic_stream_transaction_t) is
    begin
        if msg_type = basic_stream_transaction_msg then
            handle_message(msg_type);
            pop_basic_stream_transaction(msg, basic_transaction);
        end if;
    end;

end package body;