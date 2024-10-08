-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;
use work.spi_nor_regs_pkg.all;

package spi_nor_tb_pkg is

    constant bus_handle : bus_master_t := new_bus(data_length => 32,
                                                  address_length => 26);

    procedure write_instr (
        signal net : inout network_t;
        data       : std_logic_vector
    );

    procedure write_dummy (
        signal net : inout network_t;
        data       : integer
    );

    procedure write_addr (
        signal net : inout network_t;
        data       : std_logic_vector
    );

    procedure write_data (
        signal net : inout network_t;
        data       : std_logic_vector
    );

    procedure write_data_size (
        signal net : inout network_t;
        data       : integer
    );

end package;

package body spi_nor_tb_pkg is

    procedure write_instr (
        signal net : inout network_t;
        data       : std_logic_vector
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(INSTR_OFFSET + 16#100#, bus_handle.p_address_length), resize(data, 32));
    end;

    procedure write_addr (
        signal net : inout network_t;
        data       : std_logic_vector
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(ADDR_OFFSET + 16#100#, bus_handle.p_address_length), resize(data, 32));
    end;

    procedure write_dummy (
        signal net : inout network_t;
        data       : integer
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(DUMMYCYCLES_OFFSET + 16#100#, bus_handle.p_address_length), To_StdLogicVector(data, 32));
    end;

    procedure write_data_size (
        signal net : inout network_t;
        data       : integer
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(DATABYTES_OFFSET + 16#100#, bus_handle.p_address_length), To_StdLogicVector(data, 32));
    end;

    procedure write_data (
        signal net : inout network_t;
        data       : std_logic_vector
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(TX_FIFO_WDATA_OFFSET + 16#100#, bus_handle.p_address_length), resize(data, 32));
    end;

end package body;
