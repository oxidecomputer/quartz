-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


--! Bus master model based on ST's RM0433
--! figures 115 and 116
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

use vunit_lib.bus_master_pkg.all;

package stm32h7_fmc_sim_pkg is
    
    constant SP_BUS_HANDLE : bus_master_t := new_bus(data_length => 16, address_length => 26);


    procedure fmc_read32(
        signal net : inout network_t;
        constant address : std_logic_vector;
        variable data : inout std_logic_vector
    );

    procedure fmc_write32(
        signal net : inout network_t;
        constant address : std_logic_vector;
        variable data : inout std_logic_vector
    );

end package;

package body stm32h7_fmc_sim_pkg is

    procedure fmc_read32(
        signal net : inout network_t;
        constant address : std_logic_vector;
        variable data : inout std_logic_vector
    ) is
        variable queue : queue_t;
        constant BUTST_LENGTH : integer := 2;
    begin
        queue := new_queue;
        burst_read_bus(net, SP_BUS_HANDLE, address, BUTST_LENGTH, queue);
        data(15 downto 0) := pop_std_ulogic_vector(queue);
        data(31 downto 16) := pop_std_ulogic_vector(queue);
    end;
    procedure fmc_write32(
        signal net : inout network_t;
        constant address : std_logic_vector;
        variable data : inout std_logic_vector
    ) is
        variable queue : queue_t;
        constant BUTST_LENGTH : integer := 2;
    begin
        queue := new_queue;
        push_std_ulogic_vector(queue, data(15 downto 0));
        push_std_ulogic_vector(queue, data(31 downto 16));
        burst_write_bus(net, SP_BUS_HANDLE, address, BUTST_LENGTH, queue);
    end;
end package body;