-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ice40_pkg.all;

entity ignition_io is
    port(
        clk : in std_logic;
        -- design Serial interface
        sw0_serial_in : out std_logic;
        sw0_serial_out : in std_logic;
        sw1_serial_in : out std_logic;
        sw1_serial_out : in std_logic;

        rsw0_serial_in_p : inout std_logic;
        rsw0_serial_out_p : out std_logic;
        rsw0_serial_out_n : out std_logic;

        rsw1_serial_in_p : inout std_logic;
        rsw1_serial_out_p : out std_logic;
        rsw1_serial_out_n : out std_logic

    );
end entity;

architecture rtl of ignition_io is
    constant LVDS_OUTPUT_PIN_TYPE : std_logic_vector(5 downto 0) :=  OutputRegistered & InputRegistered;
    constant LVDS_OUTPUT_INV_PIN_TYPE : std_logic_vector(5 downto 0) :=  OutputRegisteredInverted & InputRegistered;
    constant LVDS_INPUT_PIN_TYPE : std_logic_vector(5 downto 0) := OutputDisabled & InputRegistered;

begin

    to_rsw0_p: SB_IO
     generic map(
        PIN_TYPE => LVDS_OUTPUT_PIN_TYPE,
        IO_STANDARD => "SB_LVCMOS"
    )
     port map(
        PACKAGE_PIN => rsw0_serial_out_p,
        OUTPUT_CLK => clk,
        OUTPUT_ENABLE => '1',
        D_OUT_0 => sw0_serial_out,
        D_OUT_1 => '0',
        D_IN_0 => open,
        D_IN_1 => open
    );

     to_rsw0_n: SB_IO
     generic map(
        PIN_TYPE => LVDS_OUTPUT_INV_PIN_TYPE,
        IO_STANDARD => "SB_LVCMOS"
    )
     port map(
        PACKAGE_PIN => rsw0_serial_out_n,
        OUTPUT_CLK => clk,
        OUTPUT_ENABLE => '1',
        D_OUT_0 => sw0_serial_out, -- inversion done in I/O block
        D_OUT_1 => '0',
        D_IN_0 => open,
        D_IN_1 => open
    );

    from_rsw0: SB_IO
     generic map(
        PIN_TYPE => LVDS_INPUT_PIN_TYPE,
        IO_STANDARD => "SB_LVDS_INPUT"
    )
     port map(
        PACKAGE_PIN => rsw0_serial_in_p,
        LATCH_INPUT_VALUE => '0',
        CLOCK_ENABLE => '1',
        INPUT_CLK => clk,
        OUTPUT_CLK => clk,
        OUTPUT_ENABLE => '0',
        D_OUT_0 => '0',
        D_OUT_1 => '0',
        D_IN_0 => sw0_serial_in,
        D_IN_1 => open
    );

    to_rsw1_p: SB_IO
     generic map(
        PIN_TYPE => LVDS_OUTPUT_PIN_TYPE,
        IO_STANDARD => "SB_LVCMOS"
    )
     port map(
        PACKAGE_PIN => rsw1_serial_out_p,
        OUTPUT_CLK => clk,
        OUTPUT_ENABLE => '1',
        D_OUT_0 => sw1_serial_out,
        D_OUT_1 => '0',
        D_IN_0 => open,
        D_IN_1 => open
    );

     to_rsw1_n: SB_IO
     generic map(
        PIN_TYPE => LVDS_OUTPUT_INV_PIN_TYPE,
        IO_STANDARD => "SB_LVCMOS"
    )
     port map(
        PACKAGE_PIN => rsw1_serial_out_n,
        OUTPUT_CLK => clk,
        OUTPUT_ENABLE => '1',
        D_OUT_0 => sw1_serial_out, -- inversion done in I/O block
        D_OUT_1 => '0',
        D_IN_0 => open,
        D_IN_1 => open
    );

    from_rsw1: SB_IO
     generic map(
        PIN_TYPE => LVDS_INPUT_PIN_TYPE,
        IO_STANDARD => "SB_LVDS_INPUT"
    )
     port map(
        PACKAGE_PIN => rsw1_serial_in_p,
        LATCH_INPUT_VALUE => '0',
        CLOCK_ENABLE => '1',
        INPUT_CLK => clk,
        OUTPUT_CLK => clk,
        OUTPUT_ENABLE => '0',
        D_OUT_0 => '0',
        D_OUT_1 => '0',
        D_IN_0 => sw1_serial_in,
        D_IN_1 => open
    );

end rtl;

