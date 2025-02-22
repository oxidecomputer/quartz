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
    context vunit_lib.vc_context;

use vunit_lib.sync_pkg.all;


package qspi_vc_pkg is

    -- Message defs
    constant do_reset     : msg_type_t   := new_msg_type("do_reset");
    constant set_period     : msg_type_t   := new_msg_type("set_period");
    constant set_qspi_mode  : msg_type_t   := new_msg_type("set_qspi_mode");
    constant enqueue_tx_bytes : msg_type_t := new_msg_type("enqueue_tx_bytes");
    constant get_rx_bytes : msg_type_t     := new_msg_type("get_rx_bytes");
    constant enqueue_txn      : msg_type_t := new_msg_type("enqueue_txn");
    constant ensure_start   : msg_type_t := new_msg_type("ensure_start");
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
        p_checker   : checker_t;
    end record;

    impure function new_qspi_vc (
        name : string := "";
        logger : logger_t := null_logger;
        checker: checker_t := null_checker;
        actor : actor_t := null_actor;
        unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
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

    procedure enqueue_and_execute_transaction (
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

    procedure wait_until_start (
        signal net : inout network_t;
        constant actor : actor_t
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

    -- VUnit VC rule #2: constructor starts with "new_"
    impure function new_qspi_vc (
        name : string := "";
        logger : logger_t := null_logger;
        checker: checker_t := null_checker;
        actor : actor_t := null_actor;
        unexpected_msg_type_policy : unexpected_msg_type_policy_t := fail
    )
      return qspi_vc_t is
    begin
        return (p_actor => new_actor(name),
              p_ack_actor => new_actor(name & " read-ack"),
              p_logger => logger,
              p_checker => checker
          );
    end;

    procedure wait_until_start (
        signal net : inout network_t;
        constant actor : actor_t
    ) is
            
            variable request_msg : msg_t := new_msg(ensure_start);
            variable ack : boolean;
    begin
        send(net, actor, request_msg);
        request(net, actor, request_msg, ack);
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

    procedure enqueue_and_execute_transaction (
        signal net            : inout network_t;
        constant actor        : actor_t;
        constant num_tx_bytes : natural;
        constant num_rx_bytes : natural

    )is

        variable request_msg : msg_t := new_msg(enqueue_txn);

    begin
        push(request_msg, num_tx_bytes);
        push(request_msg, num_rx_bytes);
        send(net, actor, request_msg);
        wait_until_start(net, actor);
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
