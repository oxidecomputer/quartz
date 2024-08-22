-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package spi_nor_pkg is

    -- unsupported opcodes:
    -- All dual/dual I/O opcodes 0xBB, 0xBC, 0xEB, 0xEC
    -- No set burst wrap 0x77
    -- No Read MFG Dual/Quad I/O 0x92, 0x94

    type io_mode is (single, dual, quad);

    type addr_kind_t is (none, bit24, bit32);

    type data_kind_t is (none, read, write);

    type txn_info_t is record
        -- This opcode will issue dummy cycles after the instruction
        uses_dummys : boolean;
        addr_kind   : addr_kind_t;
        data_kind   : data_kind_t;
        -- this opcode uses this mode for tx/rx data;
        data_mode : io_mode;
    end record;
    constant txn_info_t_reset : txn_info_t := (false, none, none, single);
    -- Based on the W25Q01JV Datasheet
    constant WRITE_ENABLE_OP : std_logic_vector(7 downto 0)     := x"06";
    constant WRITE_ENABLE_VS_OP : std_logic_vector(7 downto 0)  := x"50";
    constant WRITE_DISABLE_OP : std_logic_vector(7 downto 0)    := x"04";
    constant READ_STATUS_REG1_OP : std_logic_vector(7 downto 0) := x"05";
    constant READ_STATUS_REG2_OP : std_logic_vector(7 downto 0) := x"35";
    constant READ_STATUS_REG3_OP : std_logic_vector(7 downto 0) := x"15";

    constant WRITE_STATUS_REG1_OP : std_logic_vector(7 downto 0) := x"01";
    constant WRITE_STATUS_REG2_OP : std_logic_vector(7 downto 0) := x"31";
    constant WRITE_STATUS_REG3_OP : std_logic_vector(7 downto 0) := x"11";

    constant ENTER_4BYTE_MODE_OP : std_logic_vector(7 downto 0)     := x"B7";
    constant EXIT_4BYTE_MODE_OP : std_logic_vector(7 downto 0)      := x"E9";
    constant READ_DATA_OP : std_logic_vector(7 downto 0)            := x"03";
    constant READ_DATA_4BYTE_OP : std_logic_vector(7 downto 0)      := x"13";
    constant FAST_READ_OP : std_logic_vector(7 downto 0)            := x"0B";
    constant FAST_READ_4BYTE_OP : std_logic_vector(7 downto 0)      := x"0C";
    constant FAST_READ_4BYTE_DUAL_OP : std_logic_vector(7 downto 0) := x"3C";
    constant FAST_READ_DUAL_OP : std_logic_vector(7 downto 0)       := x"3B";
    constant FAST_READ_QUAD_OP : std_logic_vector(7 downto 0)       := x"6B";
    constant FAST_READ_4BYTE_QUAD_OP : std_logic_vector(7 downto 0) := x"6C";

    constant SET_READ_PARAMS_OP : std_logic_vector(7 downto 0)               := x"C0";
    constant PAGE_PROGRAM_OP : std_logic_vector(7 downto 0)                  := x"02";
    constant PAGE_PROGRAM_4BYTE_OP : std_logic_vector(7 downto 0)            := x"12";
    constant QUAD_INPUT_PAGE_PROGRAM_OP : std_logic_vector(7 downto 0)       := x"32";
    constant QUAD_INPUT_PAGE_PROGRAM_4BYTE_OP : std_logic_vector(7 downto 0) := x"34";
    constant SECTOR_ERASE_OP : std_logic_vector(7 downto 0)                  := x"20";
    constant SECTOR_ERASE_4BYTE_OP : std_logic_vector(7 downto 0)            := x"21";
    constant BLOCK_ERASE_32K_OP : std_logic_vector(7 downto 0)               := x"52";
    constant BLOCK_ERASE_64K_OP : std_logic_vector(7 downto 0)               := x"D8";
    constant BLOCK_ERASE_64K_4BYTE_OP : std_logic_vector(7 downto 0)         := x"DC";
    constant CHIP_ERASE_OP : std_logic_vector(7 downto 0)                    := x"C7";
    constant CHIP_ERASE_ALT_OP : std_logic_vector(7 downto 0)                := x"60";
    constant READ_MFG_ID_OP : std_logic_vector(7 downto 0)                   := x"90";
    constant READ_UNIQUE_ID_OP : std_logic_vector(7 downto 0)                := x"4B";
    constant READ_JEDEC_ID_OP : std_logic_vector(7 downto 0)                 := x"9F";
    constant READ_SFDP_OP : std_logic_vector(7 downto 0)                     := x"5A";
    constant ERASE_SECURITY_REG_OP : std_logic_vector(7 downto 0)            := x"44";
    constant PROGRAM_SECURITY_REG_OP : std_logic_vector(7 downto 0)          := x"42";
    constant READ_SECURITY_REGS_OP : std_logic_vector(7 downto 0)            := x"48";
    constant SECTOR_LOCK_OP : std_logic_vector(7 downto 0)                   := x"36";
    constant SECTOR_UNLOCK_OP : std_logic_vector(7 downto 0)                 := x"39";
    constant READ_SECTOR_LOCK_OP : std_logic_vector(7 downto 0)              := x"3D";

    function get_txn_info (
        opcode: std_logic_vector
    ) return txn_info_t;

end package;

package body spi_nor_pkg is

    function get_txn_info (
        opcode: std_logic_vector
    ) return txn_info_t is

        variable info : txn_info_t := (false, none, none, single);

    begin
        case opcode is
            when READ_STATUS_REG1_OP |
                 READ_STATUS_REG2_OP |
                 READ_STATUS_REG3_OP =>
                info.data_kind := read;
            when WRITE_STATUS_REG1_OP |
                 WRITE_STATUS_REG2_OP |
                 WRITE_STATUS_REG3_OP =>
                info.data_kind := write;
            when READ_DATA_OP =>
                info.addr_kind := bit24;
                info.data_kind := read;
            when READ_DATA_4BYTE_OP =>
                info.addr_kind := bit32;
                info.data_kind := read;
            when FAST_READ_OP =>
                info.addr_kind := bit24;
                info.uses_dummys := true;
                info.data_kind := read;
            when FAST_READ_4BYTE_OP =>
                info.addr_kind := bit32;
                info.uses_dummys := true;
                info.data_kind := read;
            when FAST_READ_DUAL_OP =>
                info.addr_kind := bit24;
                info.uses_dummys := true;
                info.data_kind := read;
                info.data_mode := dual;
            when FAST_READ_4BYTE_DUAL_OP =>
                info.addr_kind := bit32;
                info.uses_dummys := true;
                info.data_kind := read;
                info.data_mode := dual;
            when FAST_READ_QUAD_OP =>
                info.addr_kind := bit24;
                info.uses_dummys := true;
                info.data_kind := read;
                info.data_mode := quad;
            when FAST_READ_4BYTE_QUAD_OP =>
                info.addr_kind := bit32;
                info.uses_dummys := true;
                info.data_kind := read;
                info.data_mode := quad;
            when SET_READ_PARAMS_OP =>
                info.data_kind := write;
            when PAGE_PROGRAM_OP =>
                info.addr_kind := bit24;
                info.data_kind := write;
            when PAGE_PROGRAM_4BYTE_OP =>
                info.addr_kind := bit32;
                info.data_kind := write;
            when QUAD_INPUT_PAGE_PROGRAM_OP =>
                info.addr_kind := bit24;
                info.data_kind := write;
                info.data_mode := quad;
            when QUAD_INPUT_PAGE_PROGRAM_4BYTE_OP =>
                info.addr_kind := bit32;
                info.data_kind := write;
                info.data_mode := quad;
            when SECTOR_ERASE_OP =>
                info.addr_kind := bit24;
            when SECTOR_ERASE_4BYTE_OP =>
                info.addr_kind := bit32;
            when BLOCK_ERASE_32k_OP | BLOCK_ERASE_64K_OP =>
                info.addr_kind := bit24;
            when BLOCK_ERASE_64K_4BYTE_OP =>
                info.addr_kind := bit32;
            when READ_MFG_ID_OP =>
                info.addr_kind := bit24;
                info.data_kind := read;
            when READ_UNIQUE_ID_OP =>
                info.uses_dummys := true;
                info.data_kind := read;
            when READ_JEDEC_ID_OP =>
                info.data_kind := read;
            when READ_SFDP_OP =>
                info.addr_kind := bit24;
                info.data_kind := read;
            when ERASE_SECURITY_REG_OP =>
                info.addr_kind := bit24;
            when PROGRAM_SECURITY_REG_OP =>
                info.data_kind := write;
                info.addr_kind := bit24;
            when READ_SECURITY_REGS_OP =>
                info.data_kind := read;
                info.addr_kind := bit24;
                info.uses_dummys := true;
            when SECTOR_LOCK_OP| SECTOR_UNLOCK_OP =>
                info.addr_kind := bit24;
            when READ_SECTOR_LOCK_OP =>
                info.addr_kind := bit24;
                info.data_kind := read;
            when others =>
                -- the default for single instruction options
                -- with no address, no data, no dummy cycles
                null;
        end case;
        return info;
    end;

end package body;
