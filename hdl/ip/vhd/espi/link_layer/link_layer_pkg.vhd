-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_protocol_pkg.all;

package link_layer_pkg is
    type size_info_t is record
        size: std_logic_vector(12 downto 0);
        valid: std_logic;
        invalid: std_logic;
    end record;
    function rec_reset return size_info_t;

    type hdr_t is record
        opcode: std_logic_vector(7 downto 0);
        cycle_type: std_logic_vector(7 downto 0);
        len: std_logic_vector(11 downto 0);
    end record;
    function rec_reset return hdr_t;

    -- This is relying on the VHDL 2019 feature
    -- for "interfaces"
    type byte_stream is record
        data  : std_logic_vector(7 downto 0);
        valid : std_logic;
        ready: std_logic;
    end record;

    view byte_source of byte_stream is  -- the mode view of the record
        valid, data : out;
        ready       : in;
    end view;

    alias byte_sink is byte_source'converse;

    view byte_stream_snooper_sink of byte_stream is
        data : in;
        valid : in;
        ready : in;
    end view;

    function known_size_by_opcode(h: hdr_t) return boolean;
    function known_size_by_cycle_type(h: hdr_t) return boolean;
    function known_size_by_length(h: hdr_t) return boolean;
    function size_by_header(h: hdr_t) return std_logic_vector;
end package;

package body link_layer_pkg is

    function known_size_by_opcode(h: hdr_t) return boolean is
    begin
        -- We're using case? (matching case) since some
        -- of the opcode constants have been defined with
        -- '-' (don't care) values.
        case? h.opcode is
            when opcode_get_status |
                 opcode_set_configuration |
                 opcode_get_configuration |
                 opcode_reset |
                 opcode_get_flash_c |
                 opcode_put_flash_np |
                 opcode_get_np |
                 opcode_put_vwire |
                 opcode_get_oob |
                 opcode_put_iowr_short_mask =>
                return true;
            when others =>
                return false;
        end case?;
    end function;

    function known_size_by_cycle_type(h: hdr_t) return boolean is
    begin
        -- We're using case? (matching case) since some
        -- of the opcode constants have been defined with
        -- '-' (don't care) values.
        case? h.opcode is
            when opcode_put_np |
                 opcode_get_pc =>
                return true;
            when others =>
                return false;
        end case?;
    end function;

    function known_size_by_length(h: hdr_t) return boolean is
    begin
        -- We're using case? (matching case) since some
        -- of the opcode constants have been defined with
        -- '-' (don't care) values.
        case? h.opcode is
            when opcode_put_pc |
                 opcode_put_oob =>
                return true;
            when others =>
                return false;
        end case?;
    end function;

    function size_by_header(h: hdr_t) return std_logic_vector is
        variable c_bits : natural := 0;
    begin
        -- We're using case? (matching case) since some
        -- of the opcode constants have been defined with
        -- '-' (don't care) values.
        case? h.opcode is
            when opcode_get_status |
                 -- opcode_get_np would go here but is not current supported
                 opcode_get_pc |
                 opcode_get_oob |
                 opcode_get_flash_c =>
                -- All of these are just opcode and crc
                return To_StdLogicVector(2, 13);
            when opcode_get_configuration =>
                -- Opcode, 2 bytes of addr, crc
                return To_StdLogicVector(4, 13);
            when opcode_set_configuration =>
                 -- Opcode, 2 bytes of addr, 4 bytes data, crc
                return To_StdLogicVector(8, 13);
            when opcode_put_vwire =>
                -- right now limited to 1 count, 1 index
                -- opcode, count, index, data, crc
                return To_StdLogicVector(5, 13);
            when opcode_put_iowr_short_mask =>
                -- opcode, 2 bytes address, 1, 2, or 4 bytes data, crc
                c_bits := to_integer(h.opcode(1 downto 0));
                return To_StdLogicVector(1 + 2 + 1 + c_bits + 1, 13);
            -- opcode_put_np not supported yet
            -- opcode_get_np not supported yet
            -- opcode_put_iord_short not supported yet
            -- opcode_put_memrd32_short not supported yet
            -- opcode_put_memwr32_short not supported yet
            -- opcode_get_vwire not supported yet
            -- opcode_put_flash_c not supported
            -- opcode_get_flash_np not supported
            when opcode_put_pc =>
                case h.cycle_type is
                    when message_with_data =>
                        -- opcode, standard header (3), 5 mesg header bytes, length bytes, crc
                        return To_StdLogicVector(1 + 3 + 5 + to_integer(h.len) + 1, 13);
                    when others =>
                        assert false report "Unsupported cycle type" severity failure;
                        return To_StdLogicVector(0, 13);
                end case;
            when opcode_put_flash_np =>
                -- opcode, standard header (3), 4 address bytes, length bytes, crc
                return To_StdLogicVector(1 + 3 + 4 + to_integer(h.len) + 1, 13);
            when opcode_put_oob =>
                -- opcode, standard header (3), length bytes, crc
                return To_StdLogicVector(1 + 3 + to_integer(h.len) + 1, 13);
            when others =>
                assert false report "Unknown opcode" severity failure;
                return To_StdLogicVector(0, 13);
        end case?;
    end function;

    -- Function overloading hacks for resetting records
    function rec_reset return size_info_t is
        variable rec: size_info_t := (
            (others => '0'),
            '0',
            '0'
        );
    begin
        return rec;
    end rec_reset;
    function rec_reset return hdr_t is
        variable rec: hdr_t := (
            (others => '0'),
            (others => '0'),
            (others => '0')
        );
    begin
        return rec;
    end rec_reset;
    
end package body;