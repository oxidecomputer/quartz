-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package spi_axi_pkg is

    constant spi_opcode_write : std_logic_vector(3 downto 0) := "0000";
    constant spi_opcode_read : std_logic_vector(3 downto 0) := "0001";
    constant spi_opcode_bit_set : std_logic_vector(3 downto 0) := "0010";
    constant spi_opcode_bit_clr : std_logic_vector(3 downto 0) := "0011";
    constant spi_opcode_write_no_addr_incr : std_logic_vector(3 downto 0) := "0101";
    constant spi_opcode_read_no_addr_incr : std_logic_vector(3 downto 0) := "0110";

    function is_known_opcode(opcode : std_logic_vector(3 downto 0)) return boolean;
    function is_read_kind_opcode(opcode : std_logic_vector(3 downto 0)) return boolean;
    function is_write_kind_opcode(opcode : std_logic_vector(3 downto 0)) return boolean;
    function is_rmw_kind_opcode(opcode : std_logic_vector(3 downto 0)) return boolean;
    function is_incr_opcode(opcode : std_logic_vector(3 downto 0)) return boolean;

    function bit_operation_by_opcode(
        opcode : std_logic_vector(3 downto 0);
        rdata  : std_logic_vector(7 downto 0);
        wdata  : std_logic_vector(7 downto 0)
    ) return std_logic_vector;

end package;

package body spi_axi_pkg is

    function is_known_opcode(opcode : std_logic_vector(3 downto 0)) return boolean is
    begin
        -- known opcodes are 0-3 and 5,6
        return unsigned(opcode) < 4 or 
            opcode = spi_opcode_write_no_addr_incr or
            opcode = spi_opcode_read_no_addr_incr;
    end function;

    function is_read_kind_opcode(opcode : std_logic_vector(3 downto 0)) return boolean is
    begin
        -- only 2 read opcodes we have
        return opcode = spi_opcode_read or opcode = spi_opcode_read_no_addr_incr;
    end function;

    function is_incr_opcode(opcode : std_logic_vector(3 downto 0)) return boolean is
    begin
        return opcode /= spi_opcode_write_no_addr_incr and opcode /= spi_opcode_read_no_addr_incr;
    end function;

    function is_write_kind_opcode(opcode : std_logic_vector(3 downto 0)) return boolean is
    begin
        -- write opcodes are 0, 2, 3, and 5
        return opcode = spi_opcode_write or
            opcode = spi_opcode_write_no_addr_incr or
            opcode = spi_opcode_bit_set or
            opcode = spi_opcode_bit_clr;
    end function;

    function is_rmw_kind_opcode(opcode : std_logic_vector(3 downto 0)) return boolean is
    begin
        -- read modify write opcodes are  2 and 3
        return opcode = spi_opcode_bit_set or
            opcode = spi_opcode_bit_clr;
    end function;

    function bit_operation_by_opcode(
        opcode : std_logic_vector(3 downto 0);
        rdata  : std_logic_vector(7 downto 0);
        wdata  : std_logic_vector(7 downto 0)
    ) return std_logic_vector is

    begin
        case opcode is
            when spi_opcode_bit_set =>
                return rdata or wdata;
            when spi_opcode_bit_clr =>
                return rdata and (not wdata);
            when others =>
                assert false report "invalid opcode for bit operation";
                return rdata;
        end case;

    end function;


end package body;