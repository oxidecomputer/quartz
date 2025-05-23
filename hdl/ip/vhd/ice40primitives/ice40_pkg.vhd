-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package ice40_pkg is
    -- PinTYPEs
    -- Input types
    constant InputRegistered : std_logic_vector(1 downto 0) := "00";
    constant InputNonRegistered : std_logic_vector(1 downto 0) := "01";
    constant InputLatch : std_logic_vector(1 downto 0) := "11";
    constant InputRegisteredLatch : std_logic_vector(1 downto 0) := "10";
    -- Output types
    constant OutputDisabled : std_logic_vector(3 downto 0) := "0000";
    constant OutputNonRegistered : std_logic_vector(3 downto 0) := "0110";
    constant OutputTriState : std_logic_vector(3 downto 0) := "1010";
    constant OutputRegistered : std_logic_vector(3 downto 0) := "0101";
    constant OutputRegisteredEnable : std_logic_vector(3 downto 0) := "1001";
    constant OutputEnableRegistered : std_logic_vector(3 downto 0) := "1110";
    constant OutputRegisteredEnableRegistered : std_logic_vector(3 downto 0) := "1101";
    constant OutputRegisteredInverted : std_logic_vector(3 downto 0) := "0111";
    constant OutputRegisteredEnableInverted : std_logic_vector(3 downto 0) := "1011";
    constant OutputRegisteredEnableRegisteredInverted : std_logic_vector(3 downto 0) := "1111";
    -- DDR types
    constant DDDROutputDisabled : std_logic_vector(3 downto 0) := "0000";
    constant DDROutputRegistered : std_logic_vector(3 downto 0) := "0110";
    constant DDROutputRegisteredEnable : std_logic_vector(3 downto 0) := "1000";
    constant DDROutputRegisteredEnableRegistered : std_logic_vector(3 downto 0) := "1100";


    -- See Lattice using Differential I/O (LVDS, Sub-LVDS) in iCE40 LP/HX Devices
    component SB_IO is
        generic (
                -- Specify the polarity of all FFs in the IO to
                -- be falling edge when NEG_TRIGGER = 1.
                -- Default is rising edge.
                NEG_TRIGGER : std_logic := '0';
                PIN_TYPE : std_logic_vector(5 downto 0);
                -- By default, the IO will have NO pull up.
                -- This parameter is used only on bank 0, 1,
                -- and 2. Ignored when it is placed at bank 3
                PULLUP : std_logic := '0';
                IO_STANDARD : string := "SB_LVCMOS"
        );
        port (
                -- This is the actual pin
                PACKAGE_PIN : inout std_logic;
                -- 0: Input data flows freely
                -- 1: Last data value on pad held constant (for power savings)
                LATCH_INPUT_VALUE : in  std_logic := '0';
                -- 0: Flip-flops hold current value
                -- 1: Flip-flops accept new data on the active clock edge
                CLOCK_ENABLE : in std_logic := '1';
                -- Input clock for all flipflops
                INPUT_CLK  : in std_logic := '0';
                OUTPUT_CLK : in std_logic := '0';
                OUTPUT_ENABLE : in std_logic;
                -- For DDR clocked out on rising edge of OUTPUT_CLK
                D_OUT_0 : in std_logic;
                -- For DDR clocked out on falling edge of OUTPUT_CLK
                D_OUT_1 : in std_logic;
                -- For DDR inputs clocked into device on rising edge of INPUT_CLK
                D_IN_0  : out std_logic;
                -- For DDR inputs clocked into device on falling edge of INPUT_CLK
                D_IN_1  : out std_logic
         );
    end component;



end package;