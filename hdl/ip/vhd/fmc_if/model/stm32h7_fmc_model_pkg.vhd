-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Control messages for the STM32H7 FMC controller model. These ride the
-- same actor as the VUnit bus-master traffic so they stay ordered with the
-- transactions they configure.

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
use vunit_lib.bus_master_pkg.all;

package stm32h7_fmc_model_pkg is

    constant set_txn_gap_msg : msg_type_t := new_msg_type("fmc_set_txn_gap");
    constant abort_next_msg  : msg_type_t := new_msg_type("fmc_abort_next");

    -- Insert this many extra idle fmc_clk cycles between subsequent bus
    -- transactions (0 = back-to-back, the default).
    procedure fmc_set_txn_gap (
        signal net          : inout network_t;
        constant bus_handle : bus_master_t;
        constant cycles     : natural
    );

    -- Arm a one-shot mid-transaction abort: the next transaction deasserts
    -- chip select after `after_beats` data beats have transferred
    -- (0 = abort right after the address phase).
    procedure fmc_abort_next (
        signal net           : inout network_t;
        constant bus_handle  : bus_master_t;
        constant after_beats : natural
    );

end package;

package body stm32h7_fmc_model_pkg is

    procedure fmc_set_txn_gap (
        signal net          : inout network_t;
        constant bus_handle : bus_master_t;
        constant cycles     : natural
    ) is
        variable request_msg : msg_t := new_msg(set_txn_gap_msg);
    begin
        push_integer(request_msg, cycles);
        send(net, bus_handle.p_actor, request_msg);
    end;

    procedure fmc_abort_next (
        signal net           : inout network_t;
        constant bus_handle  : bus_master_t;
        constant after_beats : natural
    ) is
        variable request_msg : msg_t := new_msg(abort_next_msg);
    begin
        push_integer(request_msg, after_beats);
        send(net, bus_handle.p_actor, request_msg);
    end;

end package body;
