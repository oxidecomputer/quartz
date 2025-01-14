-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- This provides an I/O expander sw-compatible with the PCA9506 memory map
-- upper level logic will decide whether or not to use the tri-state signals
-- and wether the individual pins are inputs or outputs.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.i2c_base_types_pkg.all;
use work.pca9506_pkg.all;

entity pca9506_top is
    generic(
        -- i2c address of the mux
        i2c_addr : std_logic_vector(6 downto 0);
        giltch_filter_cycles : integer := 5
    );
    port(
        clk : in std_logic;
        reset : in std_logic;

        -- I2C bus mux endpoint for control
        -- Does not support clock-stretching
        scl : in std_logic;
        scl_o : out std_logic;
        scl_oe : out std_logic;
        sda : in std_logic;
        sda_o : out std_logic;
        sda_oe : out std_logic;

        -- Ports (5x 1 byte array, from pca9506_pkg)
        io : in pca9506_pin_t;
        io_oe : out pca9506_pin_t;
        io_o : out pca9506_pin_t;

        int_n: out std_logic  --can tri-state at top if desired using 1='Z'

    );

end entity;

architecture rtl of pca9506_top is
    signal inst_data : std_logic_vector(7 downto 0);
    signal inst_valid : std_logic;
    signal inst_ready : std_logic;
    signal in_ack_phase : std_logic;
    signal ack_next : std_logic;
    signal txn_header : i2c_header;
    signal start_condition : std_logic;
    signal stop_condition : std_logic;
    signal resp_data : std_logic_vector(7 downto 0);
    signal resp_valid : std_logic;
    signal resp_ready : std_logic;
    signal read_strobe : std_logic;
    signal write_strobe : std_logic;
    signal cmd_ptr : cmd_t;
    signal read_data : std_logic_vector(7 downto 0);
    signal write_data : std_logic_vector(7 downto 0);


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
        start_condition => start_condition,
        stop_condition => stop_condition,
        txn_header => txn_header,
        resp_data => resp_data,
        resp_valid => resp_valid,
        resp_ready => resp_ready
    );

    -- pca9506 functional block
    pca9506ish_function_inst: entity work.pca9506ish_function
     generic map(
        i2c_addr => i2c_addr
    )
     port map(
        clk => clk,
        reset => reset,
        inst_data => inst_data,
        inst_valid => inst_valid,
        inst_ready => inst_ready,
        in_ack_phase => in_ack_phase,
        ack_next => ack_next,
        txn_header => txn_header,
        start_condition => start_condition,
        stop_condition => stop_condition,
        resp_data => resp_data,
        resp_valid => resp_valid,
        resp_ready => resp_ready,
        read_strobe => read_strobe,
        write_strobe => write_strobe,
        read_data => read_data,
        write_data => write_data,
        cmd_ptr => cmd_ptr
    );

    -- registers block
    pca9506_regs_inst: entity work.pca9506_regs
     port map(
        clk => clk,
        reset => reset,
        cmd_ptr => cmd_ptr,
        write_strobe => write_strobe,
        read_strobe => read_strobe,
        data_in => write_data,
        data_out => read_data,
        output_disable => '0',
        io => io,
        io_oe => io_oe,
        io_o => io_o,
        int_n => int_n
    );


end rtl;