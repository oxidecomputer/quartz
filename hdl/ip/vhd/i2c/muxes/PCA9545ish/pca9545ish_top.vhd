-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- This provides the digital portion of a 4 channel i2c mux, based on the software interface
-- of a PCA9545.  Currently no interrupts are supported as we don't need them so those
-- registers will read as 0.  Also since the external mux chips only support 3 channels, each
-- of these muxes will only support 3 channels.  The fourth channel cannot be enabled.
-- Attempts to enable the forth channel will result in NACKs.
-- Attempts to enable more than one channel will result in no state change of the current mux
-- state and a NACK.
-- The analog mux is implemented outside the FPGA and is controlled by the sel signals.
-- For each TMUX:
-- CHB enabled results from sel = 00
-- CHC enabled results from sel = 01
-- CHA enabled results from sel = 10
-- No channels enabled results from sel = 11, the default state.
-- and we implement mux0 as the LSB of the control registers
-- so the control register looks like this:
-- 3   2    1    0
-- N/A CHC  CHB  CHA
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.i2c_base_types_pkg.all;

entity pca9545ish_top is
    generic(
        -- i2c address of the mux
        i2c_addr : std_logic_vector(6 downto 0);
        giltch_filter_cycles : integer := 5
    );
    port(
        clk : in std_logic;
        reset : in std_logic;

        -- Signal to reset the mux-state out of band if desired.
        mux_reset: in std_logic;
        allowed_to_enable: in std_logic;
        mux_is_active : out std_logic;
        -- I2C bus mux endpoint for control
        -- Does not support clock-stretching
        scl : in std_logic;
        scl_o : out std_logic;
        scl_oe : out std_logic;
        sda : in std_logic;
        sda_o : out std_logic;
        sda_oe : out std_logic;
        -- analog mux control
        -- 00: channel 0, 01: channel 1, 10: channel 2, 11: off
        mux_sel : out std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of pca9545ish_top is
    signal inst_data : std_logic_vector(7 downto 0);
    signal inst_valid : std_logic;
    signal inst_ready : std_logic;
    signal in_ack_phase : std_logic;
    signal ack_next : std_logic;
    signal txn_header : i2c_header;
    signal resp_data : std_logic_vector(7 downto 0);
    signal resp_valid : std_logic;
    signal resp_ready : std_logic;
    signal stop_condition : std_logic;

begin

    -- basic i2c state machine
    i2c_target_phy_inst: entity work.i2c_target_phy
     generic map(
        giltch_filter_cycles => giltch_filter_cycles
    )
     port map(
        clk => clk,
        reset => reset,
        scl => scl,
        scl_o => scl_o,
        scl_oe => scl_oe,
        sda => sda,
        sda_o => sda_o,
        sda_oe => sda_oe,
        inst_data => inst_data,
        inst_valid => inst_valid,
        inst_ready => inst_ready,
        in_ack_phase => in_ack_phase,
        do_ack => ack_next,
        txn_header => txn_header,
        resp_data => resp_data,
        resp_valid => resp_valid,
        resp_ready => resp_ready,
        stop_condition => stop_condition
    );

    -- mux functional logic
    i2c_mux_function_inst: entity work.pca9545ish_function
     generic map(
        i2c_addr => i2c_addr
    )
     port map(
        clk => clk,
        reset => reset,
        mux_reset => mux_reset,
        mux_sel => mux_sel,
        allowed_to_enable => allowed_to_enable,
        mux_is_active => mux_is_active,
        stop_condition => stop_condition,
        inst_data => inst_data,
        inst_valid => inst_valid,
        inst_ready => inst_ready,
        in_ack_phase => in_ack_phase,
        ack_next => ack_next,
        txn_header => txn_header,
        resp_data => resp_data,
        resp_valid => resp_valid,
        resp_ready => resp_ready
    );


end architecture rtl;