-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Wire-protocol constants for the Ethernet management block. The normative
-- description lives in docs/mgmt_protocol.adoc; these constants and the
-- Rust CLI both implement that document.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package eth_mgmt_pkg is

    -- "OXMG"
    constant MGMT_MAGIC : std_logic_vector(31 downto 0) := X"4F584D47";
    constant MGMT_VERSION : std_logic_vector(7 downto 0) := X"01";

    -- request header: magic(4) version(1) command(1) seq(2), payload from 8
    constant MGMT_HDR_BYTES : natural := 8;
    -- response adds a status byte at offset 8
    constant SERIAL_BYTES : natural := 32;

    constant CMD_IDENTIFY    : std_logic_vector(7 downto 0) := X"01";
    constant CMD_SET_SERIAL  : std_logic_vector(7 downto 0) := X"02";
    constant CMD_SET_MAC     : std_logic_vector(7 downto 0) := X"03";
    constant CMD_FLASH_ERASE : std_logic_vector(7 downto 0) := X"04";
    constant CMD_FLASH_WRITE : std_logic_vector(7 downto 0) := X"05";
    constant CMD_FLASH_READ  : std_logic_vector(7 downto 0) := X"06";
    constant CMD_RESPONSE_BIT : natural := 7;   -- response = command or 0x80

    constant STATUS_OK              : std_logic_vector(7 downto 0) := X"00";
    constant STATUS_BAD_VERSION     : std_logic_vector(7 downto 0) := X"01";
    constant STATUS_BAD_CMD         : std_logic_vector(7 downto 0) := X"02";
    constant STATUS_BAD_SERIAL_ECHO : std_logic_vector(7 downto 0) := X"03";
    constant STATUS_BAD_ADDR        : std_logic_vector(7 downto 0) := X"04";
    constant STATUS_BAD_LEN         : std_logic_vector(7 downto 0) := X"05";
    constant STATUS_FLASH_ERR       : std_logic_vector(7 downto 0) := X"06";
    constant STATUS_BUSY            : std_logic_vector(7 downto 0) := X"07";

    -- IDENTIFY response payload: proto_ver(1) mac(6) ip(16) fpga_version(4)
    -- flags(1) serial(32)
    constant IDENTIFY_PAYLOAD_BYTES : natural := 60;
    -- flags bits: 0 = address valid, 1 = MAC is the default (flash blank)

    -- interface between eth_mgmt and mgmt_flash
    type flash_op_t is (FLASH_OP_READ, FLASH_OP_PROGRAM, FLASH_OP_ERASE);

end package;
