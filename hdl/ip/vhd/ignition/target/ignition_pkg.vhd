-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.helper_8b10b_pkg.all;

package ignition_pkg is
    -- Output from the multiplexed 8b10b decoder
    -- into state machine
    type ignit_10b_data_t is array (natural range <>) of std_logic_vector(9 downto 0);
        
    type ignit_rx_decode is record
        channel: std_logic;
        data: std_logic_vector(7 downto 0);
        ctrl: std_logic;
        disp_err : std_logic;
    end record;

    -- This block uses the 0x2F polynomial (x^8+x^5+x^3+x^2+x+1) with the parameters
    -- specified in the AUTOSTAR_SWS_CRCLibrary specification.
    -- See https://www.autosar.org/fileadmin/standards/R4.1.3/CP/AUTOSAR_SWS_CRCLibrary.pdf 
    -- This means an initial value of 0xFF and a final XOR value of 0xFF also
    constant CRC_XOR_FINAL_VALUE : std_logic_vector(7 downto 0) := (others => '1');

    -- Protocol details here.
    -- Status every ~25ms
    -- hello every ~50ms
    constant START_OF_MESSAGE : std_logic_vector(7 downto 0) := K28_0;
    constant END_OF_MESSAGE : std_logic_vector(7 downto 0) := K23_7;
    constant BONUS_END_CHAR : std_logic_vector(7 downto 0) := K29_7;
    
    constant D10_2 : std_logic_vector(7 downto 0) := 8x"4A"; -- IDLE1
    constant D12_2 : std_logic_vector(7 downto 0) := 8x"4C"; -- IDLE1 (inverted in 10b pattern)
    constant D19_5 : std_logic_vector(7 downto 0) := 8x"B3"; -- IDLE2
    constant D21_5 : std_logic_vector(7 downto 0) := 8x"B5"; -- IDLE2 (inverted in 10b pattern)
    
    constant IDLE1B : std_logic_vector(7 downto 0) := D10_2;
    constant IDLE2B : std_logic_vector(7 downto 0) := D19_5;
    

    -- System Type
    constant COMPUTE_SLED : std_logic_vector(7 downto 0) := "00010001";
    constant RACK_SWITCH : std_logic_vector(7 downto 0) := "00010010";
    constant POWER_SHELF_RMU : std_logic_vector(7 downto 0) := "00010011";

    -- System Status
    type system_status_t is record
        system_power_abort: std_logic;
        system_power_enabled: std_logic;
        controller0_present: std_logic;
        controller1_present: std_logic;
    end record;
    function to_9b_slv(
        constant rec : system_status_t
    ) return std_logic_vector;

    type msg_type_t is (Status, Hello, Request);
     function to_9b_slv(
        constant rec : msg_type_t
    ) return std_logic_vector;
        --1,2,3

    -- System Faults
    type system_faults_t is record
        rot : std_logic;
        sp  : std_logic;
        -- 2 reserved bits
        power_a2 : std_logic;
        power_a3 : std_logic;
    end record;
    function to_9b_slv(
        constant rec : system_faults_t
    ) return std_logic_vector;

    -- request status
    type request_status_t is record
        reset_in_progress: std_logic;
        power_on_in_progress: std_logic;
        power_off_in_progress: std_logic;
    end record;
    function to_9b_slv(
        constant rec : request_status_t
    ) return std_logic_vector;

    type link_events_t is record
        msg_checksum_invalid: std_logic;
        msg_type_invalid: std_logic;
        message_version_invalid: std_logic;
        ordered_set_invalid: std_logic;
        decoding_error: std_logic;
        encoding_error: std_logic;
    end record;
    function to_9b_slv(
        constant rec : link_events_t
    ) return std_logic_vector;

    type link_status_t is record
        polarity_inverted: std_logic;
        receiver_locked: std_logic;
        receiver_aligned: std_logic;
    end record;
    function to_9b_slv(
        constant rec : link_status_t
    ) return std_logic_vector;

    type request_t is (SystemPowerOff, SystemPowerOn, SystemReset);
    --  1/2/3

end ignition_pkg;

package body ignition_pkg is

    function to_9b_slv(
        constant rec : system_status_t
    ) return std_logic_vector is
        variable ret : std_logic_vector(8 downto 0);
    begin
        ret(8 downto 4) := (others => '0');
        ret(3) := rec.system_power_abort;
        ret(2) := rec.system_power_enabled;
        ret(1) := rec.controller1_present;
        ret(0) := rec.controller0_present;
        return ret;
    end function;

    function to_9b_slv(
        constant rec : msg_type_t
    ) return std_logic_vector is
        variable ret : std_logic_vector(8 downto 0);
    begin
        ret := (others => '0');
        case rec is
            when Status =>
                ret(1 downto 0) := "01";
            when Hello =>
                ret(1 downto 0) := "10";
            when Request =>
                ret(1 downto 0) := "11";
        end case;
        return ret;
    end function;

    function to_9b_slv(
        constant rec : system_faults_t
    ) return std_logic_vector is
        variable ret : std_logic_vector(8 downto 0);
    begin
        ret := (others => '0');
        ret(5) := rec.rot;
        ret(4) := rec.sp;
        ret(1) := rec.power_a2;
        ret(0) := rec.power_a3;
        return ret;
    end function;

    function to_9b_slv(
        constant rec : request_status_t
    ) return std_logic_vector is
        variable ret : std_logic_vector(8 downto 0);
    begin
        ret := (others => '0');
        ret(2) := rec.reset_in_progress;
        ret(1) := rec.power_on_in_progress;
        ret(0) := rec.power_off_in_progress;
        return ret;
    end function;

    function to_9b_slv(
        constant rec : link_events_t
    ) return std_logic_vector is
        variable ret : std_logic_vector(8 downto 0);
    begin
        ret := (others => '0');
        ret(5) := rec.msg_checksum_invalid;
        ret(4) := rec.msg_type_invalid;
        ret(3) := rec.message_version_invalid;
        ret(2) := rec.ordered_set_invalid;
        ret(1) := rec.decoding_error;
        ret(0) := rec.encoding_error;
        return ret;
    end function;

    function to_9b_slv(
        constant rec : link_status_t
    ) return std_logic_vector is
        variable ret : std_logic_vector(8 downto 0);
    begin
        ret := (others => '0');
        ret(2) := rec.polarity_inverted;
        ret(1) := rec.receiver_locked;
        ret(0) := rec.receiver_aligned;
        return ret;
    end function;

end ignition_pkg;