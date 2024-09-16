-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package espi_base_types_pkg is

    type opcode_t is record
        value: std_logic_vector(7 downto 0);
        valid: std_logic;
    end record;
    function rec_reset return opcode_t;

    type espi_cmd_header is record
        opcode : opcode_t;
        cycle_kind: std_logic_vector(7 downto 0);
        tag : std_logic_vector(3 downto 0);
        length: std_logic_vector(11 downto 0);
        valid: boolean;
    end record;

    type cycle_kind_info_t is record
        -- How many payload bytes are expected for this cycle kind/opcode combo
        cmd_payload_bytes: unsigned(7 downto 0);
        -- How many addr bytes are expected for this cycle kind/opcode combo
        cmd_addr_bytes: unsigned(3 downto 0);
    end record;
    function rec_reset return espi_cmd_header;

    type mem_request_header is record
        address : std_logic_vector(63 downto 0);
    end record;

    type status_t is record
        flash_np_avail: std_logic; -- bit13
        flash_c_avail: std_logic; --bit 12
        flash_np_free: std_logic; --bit 9
        flash_c_free: std_logic; -- bit 8 (always 1?)
        oob_avail: std_logic;
        vwire_avail: std_logic;
        np_avail: std_logic;
        pc_avail: std_logic;
        oob_free: std_logic;
        vwire_free: std_logic; -- always 1
        np_free: std_logic;
        pc_free: std_logic;
    end record;
    function pack(status: status_t) return std_logic_vector;
    function rec_reset return status_t;

    type response_info is record
        length: std_logic_vector(11 downto 0);
        response_code: std_logic;
        status: status_t;
        valid: std_logic;
    end record;

    type message_header is record
        msg_code : std_logic_vector(7 downto 0);
        msg_spec_byte0: std_logic_vector(7 downto 0);
        msg_spec_byte1: std_logic_vector(7 downto 0);
        msg_spec_byte2: std_logic_vector(7 downto 0);
        msg_spec_byte3: std_logic_vector(7 downto 0);
    end record;

    type channel_t is (NONE, REGISTERS, FLASH, PERIPH);

    type command_descriptor is record
        dpr_addr: std_logic_vector(11 downto 0);
        dpr_bytes_used: unsigned(11 downto 0);
        channel: channel_t;
        valid: boolean;
        done: boolean;
    end record;

    type cmd_reg_if is record
        enforce_crcs : boolean;
        write    : std_logic;
        read     : std_logic;
        addr     : std_logic_vector(15 downto 0);
        wdata    : std_logic_vector(31 downto 0);
        rdata    : std_logic_vector(31 downto 0);
        rdata_valid : std_logic;
    end record;

    view regs_side of cmd_reg_if is  -- the mode view of the record
        enforce_crcs : out;
        write       : in;
        read        : in;
        addr        : in;
        wdata       : in;
        rdata      : out;
        rdata_valid : out;
    end view;

    alias bus_side is regs_side'converse;
    type resp_reg_if is record
        write    : std_logic;
        read     : std_logic;
        addr     : std_logic_vector(15 downto 0);
        wdata    : std_logic_vector(31 downto 0);
        rdata    : std_logic_vector(31 downto 0);
        rdata_valid : std_logic;
    end record;



end package;

package body espi_base_types_pkg is

    function rec_reset return opcode_t is
        variable ret : opcode_t;
    begin
        ret.value := (others => '0');
        ret.valid := '0';
        return ret;
    end function;

    function rec_reset return espi_cmd_header is
        variable ret : espi_cmd_header;
    begin
        ret.opcode := rec_reset;
        ret.cycle_kind := (others => '0');
        ret.tag := (others => '0');
        ret.length := (others => '0');
        ret.valid := false;
        return ret;
    end function;

    function pack(status: status_t) return std_logic_vector is
        variable ret : std_logic_vector(15 downto 0) := (others => '0');
    begin
        ret(13) := status.flash_np_avail;
        ret(12) := status.flash_c_avail;
        ret(9) := status.flash_np_free;
        ret(8) := status.flash_c_free;
        ret(7) := status.oob_avail;
        ret(6) := status.vwire_avail;
        ret(5) := status.np_avail;
        ret(4) := status.pc_avail;
        ret(3) := status.oob_free;
        ret(2) := status.vwire_free;
        ret(1) := status.np_free;
        ret(0) := status.pc_free;
        return ret;
    end function;
    function rec_reset return status_t is
        variable ret : status_t;
    begin
        ret.flash_np_avail := '0';
        ret.flash_c_avail := '0';
        ret.flash_np_free := '0';
        ret.flash_c_free := '1';
        ret.oob_avail := '0';
        ret.vwire_avail := '0';
        ret.np_avail := '0';
        ret.pc_avail := '0';
        ret.oob_free := '0';
        ret.vwire_free := '1';
        ret.np_free := '0';
        ret.pc_free := '1';
        return ret;
    end function;
end package body;