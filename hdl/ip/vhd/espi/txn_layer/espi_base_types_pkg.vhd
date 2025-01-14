-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package espi_base_types_pkg is

    -- Enum for our qspi operating mode
    type qspi_mode_t is (single, dual, quad);
    function encode(mode: std_logic_vector(1 downto 0)) return qspi_mode_t;
    function decode(mode: qspi_mode_t) return std_logic_vector;

    type qspi_freq_t is (twenty, twentyfive, thirtythree, fifty, sixtysix);

    function wait_states_from_freq_and_mode(
        constant freq: qspi_freq_t;
        constant mode: qspi_mode_t
    ) return std_logic_vector;

    function get_qspi_shift_amt_by_mode (
        constant mode : qspi_mode_t
    ) return natural;

    function get_sclk_to_bytes_shift_amt_by_mode (
        constant mode : qspi_mode_t
    ) return natural;

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
    function unpack(status: std_logic_vector(15 downto 0)) return status_t;
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

    type vwire_if_type is record
        idx: integer range 0 to 255;
        dat: std_logic_vector(7 downto 0);
        wstrobe: std_logic;
    end record;

    view vwire_regs_side of vwire_if_type is
        idx: in;
        dat: in;
        wstrobe: in;
    end view;

    alias vwire_cmd_side is vwire_regs_side'converse;



end package;

package body espi_base_types_pkg is

    function wait_states_from_freq_and_mode(
        constant freq: qspi_freq_t;
        constant mode: qspi_mode_t
    ) return std_logic_vector is
        variable wait_states : std_logic_vector(3 downto 0) := (others => '0');
    begin
        -- As described in our block's documentation, 
        -- we arrive at a turn-around time of 53ns * 2 + 32 ns = 138ns. Each WAIT_STATE will count as 
        -- 1 byte-time per espi spec, so the number of needed waits changes based
        -- on the bus width and speed.  We've pre-calcuated them here.
        case freq is
            when twenty =>
                case mode is
                    when single =>
                        wait_states := To_Std_Logic_Vector(1, wait_states'length);
                    when dual =>
                        wait_states := To_Std_Logic_Vector(1, wait_states'length);
                    when quad =>
                        wait_states := To_Std_Logic_Vector(2, wait_states'length);
                end case;
            when twentyfive =>
                case mode is
                    when single =>
                        wait_states := To_Std_Logic_Vector(1, wait_states'length);
                    when dual =>
                        wait_states := To_Std_Logic_Vector(1, wait_states'length);
                    when quad =>
                        wait_states := To_Std_Logic_Vector(2, wait_states'length);
                end case;
            when thirtythree =>
                case mode is
                    when single =>
                        wait_states := To_Std_Logic_Vector(1, wait_states'length);
                    when dual =>
                        wait_states := To_Std_Logic_Vector(2, wait_states'length);
                    when quad =>
                        wait_states := To_Std_Logic_Vector(3, wait_states'length);
                end case;
            when fifty =>
                case mode is
                    when single =>
                        wait_states := To_Std_Logic_Vector(1, wait_states'length);
                    when dual =>
                        wait_states := To_Std_Logic_Vector(2, wait_states'length);
                    when quad =>
                        wait_states := To_Std_Logic_Vector(4, wait_states'length);
                end case;
            when sixtysix =>
                case mode is
                    when single =>
                        wait_states := To_Std_Logic_Vector(2, wait_states'length);
                    when dual =>
                        wait_states := To_Std_Logic_Vector(3, wait_states'length);
                    when quad =>
                        wait_states := To_Std_Logic_Vector(5, wait_states'length);
                end case;
        end case;


        return wait_states;
    end function;

    function encode(mode: std_logic_vector(1 downto 0)) return qspi_mode_t is
    begin
        case mode is
            when "01" =>
                return dual;
            when "10" =>
                return quad;
            when others =>
               return single;
        end case;

    end function;
    function decode(mode: qspi_mode_t) return std_logic_vector is
        variable ret_vec : std_logic_vector(1 downto 0);
    begin
        case mode is
            when single =>
                ret_vec := "00";
            when dual =>
                ret_vec := "01";
            when quad =>
                ret_vec := "10";
        end case;
        return ret_vec;
    end function;

    -- how many shifts of data are needed
    -- per sclk based on i/o mode
    function get_qspi_shift_amt_by_mode (
        constant mode : qspi_mode_t
    ) return natural is
    begin
        case mode is
            when single =>
                return 1;
            when dual =>
                return 2;
            when quad =>
                return 4;
        end case;
    end;

    -- Turn current sclk into current byte count
    function get_sclk_to_bytes_shift_amt_by_mode (
        constant mode : qspi_mode_t
    ) return natural is
    begin
        case mode is
            when single =>
                return 3;
            when dual =>
                return 2;
            when quad =>
                return 1;
        end case;
    end;

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
    function unpack(status: std_logic_vector(15 downto 0)) return status_t is
        variable ret : status_t;
    begin
        ret.flash_np_avail := status(13);
        ret.flash_c_avail := status(12);
        ret.flash_np_free := status(9);
        ret.flash_c_free := status(8);
        ret.oob_avail := status(7);
        ret.vwire_avail := status(6);
        ret.np_avail := status(5);
        ret.pc_avail := status(4);
        ret.oob_free := status(3);
        ret.vwire_free := status(2);
        ret.np_free := status(1);
        ret.pc_free := status(0);
        return ret;

    end;
    function rec_reset return status_t is
        variable ret : status_t;
    begin
        -- controller must ignore stuff that
        -- is not enabled or not ready, so
        -- we can set the "Free" bits to 1 here
        -- so as not to generate interrupts when
        -- the controller enables the peripheral
        ret.flash_np_avail := '0';
        ret.flash_c_avail := '0';
        ret.flash_np_free := '1';
        ret.flash_c_free := '1';
        ret.oob_avail := '0';
        ret.vwire_avail := '0';
        ret.np_avail := '0';
        ret.pc_avail := '0';
        ret.oob_free := '1';
        ret.vwire_free := '1';
        ret.np_free := '0';
        ret.pc_free := '1';
        return ret;
    end function;
end package body;