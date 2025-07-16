-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;

package i2c_ctrl_vc_pkg is

    -- How to model data patterns?
    -- i2c has the following data patterns from the controller's perspective:
    -- We can send the whole pattern as a "write" expecting the target to ack after each byte
    -- We can send the some bytes as a "write" and then do a restart to the same addr and read some bytes
    -- we can send the pattern as a read.
    -- this implies we have a to_target portion of the transaction and an optional from_target portion.
    --to_target_data is not empty, we are doing a write, at least to start, send all the data to the target
    -- if expected bytes is 0 we were only doing a write. if not, we need to do a restart after the write and
    -- then ack/nack reads as directed

     -- Message defs
    constant i2c_send_byte     : msg_type_t   := new_msg_type("i2c_send_byte");
    constant i2c_send_start    : msg_type_t   := new_msg_type("i2c_send_start");
    constant i2c_send_stop     : msg_type_t   := new_msg_type("i2c_send_stop");
    constant i2c_get_byte      : msg_type_t   := new_msg_type("i2c_get_byte");
    constant i2c_send_ack      : msg_type_t   := new_msg_type("i2c_send_ack");
    constant i2c_send_nack     : msg_type_t   := new_msg_type("i2c_send_nack");
    constant i2c_get_ack_nack  : msg_type_t   := new_msg_type("i2c_get_ack_nack");

    constant i2c_ctrl_vc_logger : logger_t := get_logger("work:i2c_ctrl_vc");

    constant READ_BIT : std_logic := '1';
    constant WRITE_BIT : std_logic := '0';

    type i2c_ctrl_vc_t is record
        -- Private
        p_actor     : actor_t;
        p_logger    : logger_t;
    end record;

    impure function new_i2c_ctrl_vc(
        name : string := "";
        logger : logger_t := i2c_ctrl_vc_logger
    )
        return i2c_ctrl_vc_t;

    impure function contains_all_acks(
        constant ack_queue : queue_t
    )
        return boolean;

    impure function target_addr_nack(
        constant ack_queue : queue_t
    )
        return boolean;
    
    impure function ack_queue_matches(
        constant ack_queue : queue_t;
        constant expected_ack_queue : queue_t
    )
        return boolean;

    -- BFM procs:
    -- send a write-style transaction to the i2c bus
    -- unidirectional data with target acking/nacking everything
    procedure i2c_write_txn (
        signal net            : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant tx_data      : queue_t;
        constant ack_queue    : queue_t;
        constant user_actor   : in actor_t := null_actor
    );
    procedure blocking_i2c_write_txn (
        signal net            : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant tx_data      : queue_t;
        constant ack_queue : queue_t;
        constant user_actor        : in actor_t := null_actor
    );

    -- send a read-style transaction to the i2c bus
    -- controller to the target for target addr, target acks
    -- target to controller for remainder, controller acks
    procedure i2c_read_txn (
        signal net : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant bytes_to_read : integer;
        constant rx_data  : queue_t;
        variable tgt_ackd : out boolean;
        constant user_actor : in actor_t := null_actor
    );

    procedure blocking_i2c_read_txn (
        signal net : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant bytes_to_read : integer;
        constant rx_data  : queue_t;
        variable tgt_ackd : out boolean;
        constant user_actor : in actor_t := null_actor
    );

    -- send a mixed transaction to the i2c bus
    -- a mixed transaction has some number of writes
    -- followed by a restart with read
    -- and the some number of reads
    procedure i2c_mixed_txn (
        signal net : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant tx_data      : queue_t;
        constant bytes_to_read : integer;
        constant rx_data      : queue_t;
        constant ack_queue    : queue_t;
        constant ack_last_read : boolean := false;
        constant user_actor : in actor_t := null_actor
    );

     procedure blocking_i2c_mixed_txn (
        signal net : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant tx_data      : queue_t;
        constant bytes_to_read : integer;
        constant rx_data      : queue_t;
        constant ack_queue    : queue_t;
        constant ack_last_read : boolean := false;
        constant user_actor : in actor_t := null_actor
    );

end package;


package body i2c_ctrl_vc_pkg is

    impure function new_i2c_ctrl_vc (
        name : string := "";
        logger : logger_t := i2c_ctrl_vc_logger
    )
      return i2c_ctrl_vc_t is
    begin
        return (p_actor => new_actor(name),
              p_logger => logger
          );
    end;

    impure function contains_all_acks (
        constant ack_queue : queue_t
    )
        return boolean is
        variable mut_queue : queue_t := copy(ack_queue);
    begin
        if is_empty(mut_queue) then
            info("ack queue is unexpectedly empty");
            return false;
        end if;
        while not is_empty(mut_queue) loop
            if pop_boolean(mut_queue) = false then
                return false;
            end if;
        end loop;
        return true;  -- found one or more acks, no nacks
    end function;

    impure function target_addr_nack(
        constant ack_queue : queue_t
    )
        return boolean is
        variable mut_queue : queue_t := copy(ack_queue);
    begin
        if is_empty(mut_queue) then
            info("ack queue is unexpectedly empty");
            return false;
        end if;
        -- We only care about the first boolean, if it's false, we have a nack
        -- so return true
        if pop_boolean(mut_queue) = false then
            flush(mut_queue);
            return true;
        else
            flush(mut_queue);
            return false;
        end if;
    end function;

    impure function ack_queue_matches(
        constant ack_queue : queue_t;
        constant expected_ack_queue : queue_t
    )
        return boolean is
        variable mut_queue : queue_t := copy(ack_queue);
        variable mut_expected_queue : queue_t := copy(expected_ack_queue);
    begin
        if length(mut_queue) /= length(mut_expected_queue) then
            info("ack queue length does not match expected ack queue length");
            return false;
        end if;
        while not is_empty(mut_queue) loop
            if pop_boolean(mut_queue) /= pop_boolean(mut_expected_queue) then
                warning("ack queue does not match expected ack queue");
                return false;
            end if;
        end loop;
        return true;
    end function;


    -- a standard write transaction that takes a queue of bytes
    -- and ships them off as a write to the i2c bus
    procedure i2c_write_txn (
        signal net            : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant tx_data      : queue_t;
        constant ack_queue : queue_t;
        constant user_actor        : in actor_t := null_actor
    ) is
        variable request_msg : msg_t := new_msg(i2c_send_start);
        variable reply_msg : msg_t;
        variable actor : actor_t;
        variable tgt_addr_rw : std_logic_vector(7 downto 0);
    begin
        flush(ack_queue);  -- clear ack queue, since this is an "output" from this block
        if user_actor = null_actor then
            actor := find("i2c_ctrl_vc");
        else
            actor := user_actor;
        end if;
        -- send start (msg defined in variable initialization)
        send(net, actor, request_msg);
        -- send target address
        request_msg := new_msg(i2c_send_byte);
        -- set rw bit , and put in the target address
        tgt_addr_rw := target_addr & WRITE_BIT;
        push(request_msg, to_integer(tgt_addr_rw));
        send(net, actor, request_msg);
        -- Get Ack/Nack from target
        request_msg := new_msg(i2c_get_ack_nack);
        send(net, actor, request_msg);
        receive_reply(net, request_msg, reply_msg);
        -- Put Ack/Nack into ack queue
        push_boolean(ack_queue, pop_boolean(reply_msg));
        delete(reply_msg);
        -- loop through data sending and waiting for acks
        while not is_empty(tx_data) loop
            -- send data byte
            request_msg := new_msg(i2c_send_byte);
            push(request_msg, pop_byte(tx_data));
            send(net, actor, request_msg);
            -- Get Ack/Nack from target, expecting ack
            request_msg := new_msg(i2c_get_ack_nack);
            send(net, actor, request_msg);
            receive_reply(net, request_msg, reply_msg);
            -- Put Ack/Nack into ack queue
            push_boolean(ack_queue, pop_boolean(reply_msg));
            delete(reply_msg);
        end loop;
        -- send stop
        request_msg := new_msg(i2c_send_stop);
        send(net, actor, request_msg);

    end procedure;
    -- blocking version of i2c_write_txn
    procedure blocking_i2c_write_txn (
        signal net            : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant tx_data      : queue_t;
        constant ack_queue : queue_t;
        constant user_actor        : in actor_t := null_actor
        
    ) is
         variable actor : actor_t;
    begin
        if user_actor = null_actor then
            actor := find("i2c_ctrl_vc");
        else
            actor := user_actor;
        end if;
        i2c_write_txn(net, target_addr, tx_data, ack_queue, actor);
        wait_until_idle(net, actor);
    end;

    -- a read transaction that issues the i2c address as a read
    -- and attempts to read the specified number of bytes. Each
    -- byte puts ack/nack into the ack_queue
    -- rx-d data in the rx_data queue.
    procedure i2c_read_txn (
        signal net : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant bytes_to_read : integer;
        constant rx_data  : queue_t;
        variable tgt_ackd : out boolean;
        constant user_actor : in actor_t := null_actor
    ) is 
        variable request_msg : msg_t := new_msg(i2c_send_start);
        variable reply_msg : msg_t;
        variable actor : actor_t;
        variable tgt_addr_rw : std_logic_vector(7 downto 0);
    begin
        if user_actor = null_actor then
            actor := find("i2c_ctrl_vc");
        else
            actor := user_actor;
        end if;
        -- send start (msg defined in variable initialization)
        send(net, actor, request_msg);
        -- send target address
        request_msg := new_msg(i2c_send_byte);
        -- set rw bit to 1 (read), and put in the target address
        tgt_addr_rw := target_addr & READ_BIT;
        push(request_msg, to_integer(tgt_addr_rw));
        send(net, actor, request_msg);
        -- Get Ack/Nack from target
        request_msg := new_msg(i2c_get_ack_nack);
        send(net, actor, request_msg);
        receive_reply(net, request_msg, reply_msg);
        -- Put Ack/Nack into ack queue
        tgt_ackd := pop_boolean(reply_msg);
        delete(reply_msg);
        -- Now we read target bytes on these transactions the controller should ack
        for i in 0 to bytes_to_read-1 loop
            -- get data byte
            request_msg := new_msg(i2c_get_byte);
            send(net, actor, request_msg);
            receive_reply(net, request_msg, reply_msg);
            -- store data into rx queue
            push_byte(rx_data, pop(reply_msg));
            -- Ack data, except for the last
            if i = bytes_to_read-1 then
                request_msg := new_msg(i2c_send_nack);
            else
                request_msg := new_msg(i2c_send_ack);
            end if;
            send(net, actor, request_msg);
        end loop;
        -- send stop
        request_msg := new_msg(i2c_send_stop);
        send(net, actor, request_msg);
    end procedure;

    procedure blocking_i2c_read_txn (
        signal net : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant bytes_to_read : integer;
        constant rx_data  : queue_t;
        variable tgt_ackd : out boolean;
        constant user_actor : in actor_t := null_actor
    ) is
        variable actor : actor_t;
    begin
        if user_actor = null_actor then
            actor := find("i2c_ctrl_vc");
        else
            actor := user_actor;
        end if;
        i2c_read_txn(net, target_addr, bytes_to_read, rx_data, tgt_ackd, actor);
        wait_until_idle(net, actor);
    end;

    procedure i2c_mixed_txn (
        signal net : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant tx_data      : queue_t;
        constant bytes_to_read : integer;
        constant rx_data      : queue_t;
        constant ack_queue    : queue_t;
        constant ack_last_read : boolean := false;
        constant user_actor : in actor_t := null_actor
    ) is
        variable request_msg : msg_t := new_msg(i2c_send_start);
        variable reply_msg : msg_t;
        variable actor : actor_t;
        variable tgt_addr_rw : std_logic_vector(7 downto 0);
    begin
        if user_actor = null_actor then
            actor := find("i2c_ctrl_vc");
        else
            actor := user_actor;
        end if;

        -- send start (msg defined in variable initialization)
        send(net, actor, request_msg);
        -- send target address
        request_msg := new_msg(i2c_send_byte);
        -- set rw bit , and put in the target address
        tgt_addr_rw := target_addr & WRITE_BIT;
        push(request_msg, to_integer(tgt_addr_rw));
        send(net, actor, request_msg);
        -- Get Ack/Nack from target
        request_msg := new_msg(i2c_get_ack_nack);
        send(net, actor, request_msg);
        receive_reply(net, request_msg, reply_msg);
        -- Put Ack/Nack into ack queue
        push_boolean(ack_queue, pop_boolean(reply_msg));
        delete(reply_msg);
        -- loop through wr sending and waiting for acks
        while not is_empty(tx_data) loop
            -- send data byte
            request_msg := new_msg(i2c_send_byte);
            push(request_msg, pop_byte(tx_data));
            send(net, actor, request_msg);
            -- Get Ack/Nack from target, expecting ack
            request_msg := new_msg(i2c_get_ack_nack);
            send(net, actor, request_msg);
            receive_reply(net, request_msg, reply_msg);
            -- Put Ack/Nack into ack queue
            push_boolean(ack_queue, pop_boolean(reply_msg));
            delete(reply_msg);
        end loop;
        -- send restart
        request_msg := new_msg(i2c_send_start);
        send(net, actor, request_msg);
         -- send target address, now as a read
         request_msg := new_msg(i2c_send_byte);
         -- set rw bit to 1 (read), and put in the target address
         tgt_addr_rw := target_addr & READ_BIT;
         push(request_msg, to_integer(tgt_addr_rw));
         send(net, actor, request_msg);
         -- Get Ack/Nack from target
         request_msg := new_msg(i2c_get_ack_nack);
         send(net, actor, request_msg);
         receive_reply(net, request_msg, reply_msg);
         -- Put Ack/Nack into ack queue
         push_boolean(ack_queue, pop_boolean(reply_msg));
         delete(reply_msg);

         -- Now we read target bytes on these transactions the controller should ack
        for i in 0 to bytes_to_read-1 loop
            -- get data byte
            request_msg := new_msg(i2c_get_byte);
            send(net, actor, request_msg);
            receive_reply(net, request_msg, reply_msg);
            -- store data into rx queue
            push_byte(rx_data, pop(reply_msg));
            -- Ack/Nack data
            if i = bytes_to_read-1 and ack_last_read = false then
                request_msg := new_msg(i2c_send_nack);
            else
                request_msg := new_msg(i2c_send_ack);
            end if;
            send(net, actor, request_msg);
        end loop;
        -- send stop
        request_msg := new_msg(i2c_send_stop);
        send(net, actor, request_msg);
    end procedure;

    procedure blocking_i2c_mixed_txn (
        signal net : inout network_t;
        constant target_addr  : std_logic_vector(6 downto 0);
        constant tx_data      : queue_t;
        constant bytes_to_read : integer;
        constant rx_data      : queue_t;
        constant ack_queue    : queue_t;
        constant ack_last_read : boolean := false;
        constant user_actor : in actor_t := null_actor
    ) is
        variable actor : actor_t;
    begin
        if user_actor = null_actor then
            actor := find("i2c_ctrl_vc");
        else
            actor := user_actor;
        end if;
        i2c_mixed_txn(net, target_addr, tx_data, bytes_to_read, rx_data, ack_queue, ack_last_read, actor);
        wait_until_idle(net, actor);
    end;

end package body;