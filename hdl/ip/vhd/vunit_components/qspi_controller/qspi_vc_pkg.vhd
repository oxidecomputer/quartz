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
use vunit_lib.sync_pkg.all;

package qspi_vc_pkg is

    -- Message defs
    constant set_period     : msg_type_t   := new_msg_type("set_period");
    constant set_qspi_mode  : msg_type_t   := new_msg_type("set_qspi_mode");
    constant enqueue_tx_bytes : msg_type_t := new_msg_type("enqueue_tx_bytes");
    constant get_rx_bytes : msg_type_t     := new_msg_type("get_rx_bytes");
    constant enqueue_txn      : msg_type_t := new_msg_type("enqueue_txn");
    constant alert_status     : msg_type_t := new_msg_type("alert_status");

    -- bfm types
    type qspi_mode_t is (single, dual, quad);

    -- This sets up transactions
    type txn_type is record
        num_tx_bytes : natural;
        num_rx_bytes : natural;
    end record;

    function encode (
        mode: qspi_mode_t
    ) return std_logic_vector;

    -- test
    function decode (
        mode_vec: std_logic_vector
    ) return qspi_mode_t;

    type qspi_vc_t is record
        -- Private
        p_actor     : actor_t;
        p_ack_actor : actor_t;
        p_logger    : logger_t;
    end record;

    constant qspi_vc_logger : logger_t := get_logger("work:qspi_vc");

    impure function new_qspi_vc (
        name : string := "";
        logger : logger_t := qspi_vc_logger
    )
        return qspi_vc_t;

    ----------
    -- bfm api
    --
    procedure enqueue_transaction (
        signal net            : inout network_t;
        constant actor        : actor_t;
        constant num_tx_bytes : natural;
        constant num_rx_bytes : natural

    );

    procedure enqueue_tx_data_bytes (
        signal net         : inout network_t;
        constant actor     : actor_t;
        constant num_bytes : natural;
        constant data      : queue_t
    );

    procedure set_mode (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant mode  : qspi_mode_t
    );

    procedure get_rx_queue (
        signal net     : inout network_t;
        constant actor : actor_t;
        variable data  : inout queue_t
    );

    procedure has_pending_alert (
        signal net     : inout network_t;
        constant actor : actor_t;
        variable alert : out boolean
    );

end package;

package body qspi_vc_pkg is

    function encode (
        mode: qspi_mode_t
    ) return std_logic_vector is

        variable vec : std_logic_vector(7 downto 0);

    begin
        vec := std_logic_vector(to_unsigned(qspi_mode_t'pos(mode), 8));
        return vec;
    end;

    function decode (
        mode_vec: std_logic_vector
    ) return qspi_mode_t is
    begin
        return qspi_mode_t'val(to_integer(unsigned(mode_vec)));
    end;

    impure function new_qspi_vc (
        name : string := "";
        logger : logger_t := qspi_vc_logger
    )
      return qspi_vc_t is
    begin
        return (p_actor => new_actor(name),
              p_ack_actor => new_actor(name & " read-ack"),
              p_logger => logger
          );
    end;

    procedure enqueue_transaction (
        signal net            : inout network_t;
        constant actor        : actor_t;
        constant num_tx_bytes : natural;
        constant num_rx_bytes : natural

    ) is

        variable request_msg : msg_t := new_msg(enqueue_txn);

    begin
        push(request_msg, num_tx_bytes);
        push(request_msg, num_rx_bytes);
        send(net, actor, request_msg);
        wait_until_idle(net, actor);
    end;

    procedure enqueue_tx_data_bytes (
        signal net         : inout network_t;
        constant actor     : actor_t;
        constant num_bytes : natural;
        constant data      : queue_t
    ) is

        variable request_msg : msg_t := new_msg(enqueue_tx_bytes);

    begin
        push(request_msg, num_bytes);
        for i in 1 to num_bytes loop
            push(request_msg, pop_byte(data));
        end loop;
        send(net, actor, request_msg);
        wait_until_idle(net, actor);
    end;

    procedure set_mode (
        signal net     : inout network_t;
        constant actor : actor_t;
        constant mode  : qspi_mode_t
    ) is

        variable request_msg : msg_t := new_msg(set_qspi_mode);

    begin
        push(request_msg, encode(mode));
        send(net, actor, request_msg);
    end;

    procedure get_rx_queue (
        signal net     : inout network_t;
        constant actor : actor_t;
        variable data  : inout queue_t
    ) is

        variable request_msg : msg_t := new_msg(get_rx_bytes);
        variable reply_msg   : msg_t;
        variable count       : natural;

    begin
        send(net, actor, request_msg);
        receive_reply(net, request_msg, reply_msg);
        count := pop(reply_msg);
        for i in 1 to count loop
            push_byte(data, pop(reply_msg));
        end loop;
        delete(reply_msg);
    end;

    procedure has_pending_alert (
        signal net     : inout network_t;
        constant actor : actor_t;
        variable alert : out boolean
    ) is

        variable request_msg : msg_t := new_msg(alert_status);
        variable reply_msg   : msg_t;

    begin
        send(net, actor, request_msg);
        receive_reply(net, request_msg, reply_msg);
        alert := pop(reply_msg);
        delete(reply_msg);
    end;

end package body;
