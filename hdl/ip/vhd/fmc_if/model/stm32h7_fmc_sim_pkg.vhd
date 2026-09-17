-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Testbench-facing helpers for driving the STM32H7 FMC controller model.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.sync_pkg.all;

package stm32h7_fmc_sim_pkg is

    constant sp_bus_handle : bus_master_t := new_bus(data_length => 16, address_length => 26);

    procedure fmc_read32 (
        signal net       : inout network_t;
        constant address : std_logic_vector;
        variable data    : inout std_logic_vector
    );

    -- Blocks until the bus cycle has completed on the FMC pins. Note the
    -- posted write may still be crossing into the AXI domain when this
    -- returns; a subsequent fmc_read32 orders behind it, or wait for the
    -- CDC/AXI latency before checking memory directly.
    procedure fmc_write32 (
        signal net       : inout network_t;
        constant address : std_logic_vector;
        variable data    : inout std_logic_vector
    );

    -- Fire-and-forget variant, for queuing back-to-back traffic.
    procedure fmc_write32_nb (
        signal net       : inout network_t;
        constant address : std_logic_vector;
        variable data    : inout std_logic_vector
    );

    -- Blocks until every previously queued transaction's bus cycle is done.
    procedure fmc_wait_idle (
        signal net : inout network_t
    );

end package;

package body stm32h7_fmc_sim_pkg is

    procedure fmc_read32 (
        signal net       : inout network_t;
        constant address : std_logic_vector;
        variable data    : inout std_logic_vector
    ) is

        variable queue        : queue_t;
        constant burst_length : integer := 2;

    begin
        queue              := new_queue;
        burst_read_bus(net, SP_BUS_HANDLE, address, BURST_LENGTH, queue);
        data(15 downto 0)  := pop_std_ulogic_vector(queue);
        data(31 downto 16) := pop_std_ulogic_vector(queue);
    end;

    procedure fmc_write32_nb (
        signal net       : inout network_t;
        constant address : std_logic_vector;
        variable data    : inout std_logic_vector
    ) is

        variable queue        : queue_t;
        constant burst_length : integer := 2;

    begin
        queue := new_queue;
        push_std_ulogic_vector(queue, data(15 downto 0));
        push_std_ulogic_vector(queue, data(31 downto 16));
        burst_write_bus(net, SP_BUS_HANDLE, address, BURST_LENGTH, queue);
    end;

    procedure fmc_write32 (
        signal net       : inout network_t;
        constant address : std_logic_vector;
        variable data    : inout std_logic_vector
    ) is
    begin
        fmc_write32_nb(net, address, data);
        fmc_wait_idle(net);
    end;

    procedure fmc_wait_idle (
        signal net : inout network_t
    ) is
    begin
        wait_until_idle(net, SP_BUS_HANDLE.p_actor);
    end;

end package body;
