-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.espi_base_types_pkg.all;

package espi_protocol_pkg is

    -- ESPI Header decodes
    -- Command opcodes
    constant opcode_put_pc : std_logic_vector(7 downto 0)                  := "00000000";
    constant opcode_get_pc : std_logic_vector(7 downto 0)                  := "00000001";
    constant opcode_put_np : std_logic_vector(7 downto 0)                  := "00000010";
    constant opcode_get_np : std_logic_vector(7 downto 0)                  := "00000011";
    constant opcode_put_iord_short_mask : std_logic_vector(7 downto 0)     := "010000--";
    constant opcode_put_iowr_short_mask : std_logic_vector(7 downto 0)     := "010000--";
    constant opcode_put_memrd32_short_mask : std_logic_vector(7 downto 0)  := "010010--";
    constant opcode_put_memwr32_short_mask  : std_logic_vector(7 downto 0) := "010011--";
    constant opcode_put_vwire : std_logic_vector(7 downto 0)               := "00000100";
    constant opcode_get_vwire : std_logic_vector(7 downto 0)               := "00000101";
    constant opcode_put_oob : std_logic_vector(7 downto 0)                 := "00000110";
    constant opcode_get_oob : std_logic_vector(7 downto 0)                 := "00000111";
    constant opcode_put_flash_c : std_logic_vector(7 downto 0)             := "00001000";
    constant opcode_get_flash_np : std_logic_vector(7 downto 0)            := "00001001";
    constant opcode_put_flash_np : std_logic_vector(7 downto 0)            := "00001010";
    constant opcode_get_flash_c : std_logic_vector(7 downto 0)             := "00001011";
    constant opcode_get_status : std_logic_vector(7 downto 0)              := "00100101";
    constant opcode_set_configuration : std_logic_vector(7 downto 0)       := "00100010";
    constant opcode_get_configuration : std_logic_vector(7 downto 0)       := "00100001";
    constant opcode_reset : std_logic_vector(7 downto 0)                   := "11111111";
    -- Cycle Types/Kinds. Note these are generally unique within a defined opcode
    -- but multiple opcodes may also re-use some of these
    -- eSPI Channel
    constant mem_read_32 : std_logic_vector(7 downto 0) := "00000000";
    constant mem_read_64 : std_logic_vector(7 downto 0) := "00000010";
    -- Flash channel (from  server addendum)
    constant flash_read : std_logic_vector(7 downto 0)      := "00000000";
    constant success_no_data : std_logic_vector(7 downto 0) := "00000110";

    -- We won't actually write/erase, our behavior catching this is TBD
    constant flash_write : std_logic_vector(7 downto 0) := "00000001";
    constant flash_erase : std_logic_vector(7 downto 0) := "00000010";

    constant message_with_data : std_logic_vector(7 downto 0) := "00010001";

    -- Header Indices for general eSPI packages
    constant cycle_type_idx : integer := 0;
    constant tag_len_idx : integer    := 1;
    constant len_low_idx : integer    := 2;
    -- Header Indices for get_set_configuration
    constant addr_high_idx : integer  := 0;
    constant addr_low_idx : integer   := 1;
    constant data_byte3_idx : integer := 2;
    constant data_byte2_idx : integer := 3;
    constant data_byte1_idx : integer := 4;
    constant data_byte0_idx : integer := 5;

    -- Cycle Types

    -- constant MEM_WRITE_32
    -- constant MEM_WRITE_64
    -- constant MESSAGE
    -- constant MESSAGE_WITH_DATA
    -- constant SUCCESS_NO_DATA
    -- constant SUCCESS_WITH_DATA
    -- constant UNSUCCESSFUL_NO_DATA
    -- -- OOB Message Channel
    -- constant OOB
    -- --
    -- constant FLASH_READ

    -- Flash cycle types
    -- Unused: corresponds to erase or write
    -- constant flash_success_no_data : std_logic_vector(7 downto 0) := "00000110";

    constant split_mid_complete : std_logic_vector(1 downto 0)   := "00";
    constant split_first_complete : std_logic_vector(1 downto 0) := "01";
    constant split_last_complete : std_logic_vector(1 downto 0)  := "10";
    constant split_only_complete : std_logic_vector(1 downto 0)  := "11";

    constant accept : std_logic_vector(1 downto 0)      := "00";
    constant no_response : std_logic_vector(1 downto 0) := "11";
    -- TODO: support response modifiers
    constant accept_code : std_logic_vector(7 downto 0) := "00001000";
    constant defer_code : std_logic_vector(7 downto 0)  := "00000001";

    -- function min_bytes_before_turn_by_opcode(opcode: std_logic_vector) return natural;
    -- function bytes_to_clocks(bytes: natural; mode: qspi_mode_t) return natural;
    -- function min_clks_before_turn_by_opcode(opcode: std_logic_vector; mode: qspi_mode_t) return natural;
    -- Using the opcode, get the number of bytes needed until we can determinine where the
    -- turn around cycles are. Some opcodes have fixed transmit sizes, and others have
    -- variable sizes
    -- function header_length_by_opcode (
    --     opcode: std_logic_vector
    -- ) return natural;
    function by_byte_msb_first (
        constant data : std_logic_vector;
        constant byte : std_logic_vector(7 downto 0);
        idx           : natural
    ) return std_logic_vector;

    function by_byte_lsb_first (
        constant data : std_logic_vector;
        constant byte : std_logic_vector(7 downto 0);
        idx           : natural
    ) return std_logic_vector;

    function payload_length (
        length_field: std_logic_vector
    ) return natural;

    function bytes_until_turn_known_by_opcode (
        opcode: std_logic_vector
    ) return natural;

    -- Once we've passed bytes_until_turn_known, we can fully determine the number of
    -- bytes before the turn
    function bytes_until_turn (
        opcode: std_logic_vector;
        cmd_length: std_logic_vector
    ) return natural;

    -- assumes index counts up as we go
    -- procedure by_byte_msb_first (
    --     variable data : inout std_logic_vector;
    --     constant byte : in std_logic_vector(7 downto 0);
    --     idx           : in natural
    -- );

    -- procedure by_byte_lsb_first (
    --     variable data : inout std_logic_vector;
    --     constant byte : in std_logic_vector(7 downto 0);
    --     idx           : in natural
    -- );

end package;

package body espi_protocol_pkg is

    -- function min_bytes_before_turn_by_opcode(opcode: std_logic_vector) return natural is
    -- begin
    --     case opcode is
    --         when OPCODE_GET_STATUS =>
    --             return 2; -- OP + CRC
    --         when OPCODE_GET_CONFIGURATION =>
    --            return 4; -- OP, 16bit addr, CRC
    --         when OPCODE_SET_CONFIGURATION =>
    --            return 8; -- OP, 16bit addr, 32bit data, CRC
    --         when others =>
    --            return 0;
    --     end case;
    -- end function;

    -- function bits_before_turn_by_opcode(bytes: natural; mode: qspi_mode_t) return natural is
    --   variable shift_amt : natural := 0;
    -- begin
    --     assert bytes <= 255 report "Too many bytes for this calcualtion";
    --     case mode is
    --         when single => shift_amt := 3;  -- need *8 so 2^^3
    --         when dual => shift_amt := 2; -- need *4 so 2^^2
    --         when quad => shift_amt := 1; -- need *2 so 2^^1
    --     end case;
    --     return to_integer(shift_left(to_unsigned(bytes, 8), shift_amt));
    -- end function;
    function payload_length (
        length_field: std_logic_vector
    ) return natural is
    begin
        if length_field = 0 then
            return 4096;
        else
            return to_integer(length_field);
        end if;
    end;

    -- Some opcodes encode two bits of length, this function takes
    -- the bottom two bits and returns the decoded number of bytes
    function req_length_by_opcode (
        opcode: std_logic_vector
    ) return natural is

        variable bytes : natural := 0;

    begin
        case opcode(1 downto 0) is
            when "00" =>
                bytes := 1;
            when "01" =>
                bytes := 2;
            when "11" =>
                bytes := 4;
            when others =>
                null;
        end case;
        return bytes;
    end;

    -- This function takes the opcode and determines how many bytes into the
    -- payload we need to be before we know where the turn-around cycles will be
    -- Since we don't have a CRC at the end, we have to trust the data we see at this
    -- point. Spec is unclear what should happen if we have a crc mismatch *and* crc
    -- checking is disabled.
    function bytes_until_turn_known_by_opcode (
        opcode: std_logic_vector
    ) return natural is

        variable bytes : natural := 0;

    begin
        case? opcode is
            when OPCODE_GET_STATUS =>
                bytes := 1; -- only opcode needed
            when OPCODE_GET_CONFIGURATION =>
                bytes := 1; -- only opcode needed
            when OPCODE_SET_CONFIGURATION =>
                bytes := 1; -- only opcode needed
            when OPCODE_PUT_IORD_SHORT_MASK =>
                bytes := 1; -- only opcode needed
            when OPCODE_PUT_MEMWR32_SHORT_MASK =>
                bytes := 1; -- only opcode needed
            when others =>
                bytes := 4;  -- everything else needs the length field also
        end case?;
        return bytes;
    end;

    function bytes_until_turn (
        opcode: std_logic_vector;
        cmd_length: std_logic_vector
    ) return natural is

        variable bytes : natural := 0;

    begin
        case? opcode is
            -- opcode + crc
            when OPCODE_GET_STATUS =>
                bytes := 1 + 1;
            -- opcode + 16bit addr +crc
            when OPCODE_GET_CONFIGURATION =>
                bytes := 1 + 2 + 1;
            -- opcode + 16bit addr + 32bit data + crc
            when OPCODE_SET_CONFIGURATION =>
                bytes := 1 + 2 + 4 + 1;
            -- opcode + 16bit addr + crc
            when OPCODE_PUT_IORD_SHORT_MASK =>
                bytes := 1 + 2 + 1;
            -- opcode + 16bit addr + 1/2/4 data + crc
            -- when OPCODE_PUT_IOWR_SHORT_MASK | OPCODE_PUT_MEMRD32_SHORT_MASK =>
            --     bytes := 1 + 2 + req_length_by_opcode(opcode) + 1;
            when others =>
                assert false
                    report "Not yet implemented";
        end case?;
        return bytes;
    end;

    function by_byte_msb_first (
        constant data : std_logic_vector;
        constant byte : std_logic_vector(7 downto 0);
        idx           : natural
    ) return std_logic_vector is

        variable ret_data : std_logic_vector(data'range);

    begin
        ret_data := data;
        -- can't use intermediate variables here for #VivadoReasons
        ret_data(data'high - idx * 8 downto data'high - idx * 8 - 7) := byte;
        return ret_data;
    end;

    function by_byte_lsb_first (
        constant data : std_logic_vector;
        constant byte : std_logic_vector(7 downto 0);
        idx           : natural
    ) return std_logic_vector is

        variable ret_data : std_logic_vector(data'range);

    begin
        ret_data := data;
        -- can't use intermediate variables here for #VivadoReasons
        ret_data(7 + idx * 8 downto idx * 8) := byte;
        return ret_data;
    end;

end package body;
