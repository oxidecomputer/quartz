-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

use work.i2c_common_pkg.mode_t;
use work.tristate_if_pkg.all;

entity spd_proxy_top is
    generic (
        CLK_PER_NS: positive;
        I2C_MODE: mode_t;
    )
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- SP5 <-> FPGA
        sp5_scl_if : view tristate_if;
        sp5_sda_if : view tristate_if;

        -- FPGA <-> DIMMs
        dimm_scl : view tristate_if;
        dimm_sda : view tristate_if;
    );
end entity;

architecture rtl of spd_proxy_top is
    signal scl_filt     : std_logic;
    signal sda_fedge    : std_logic;
    signal start_detected : std_logic;

    signal fpga_scl : tristate;
    signal fpga_sda : tristate;
begin
    --
    -- SP5 bus monitoring
    --

    i2c_glitch_filter_inst: entity work.i2c_glitch_filter
        generic map(
            filter_cycles => 5
        )
        port map(
            clk             => clk,
            reset           => reset,
            raw_scl         => sp5_scl_if.i,
            raw_sda         => sp5_sda_if.i,
            filtered_scl    => scl_filt,
            scl_redge       => open,
            scl_fedge       => open,
            filtered_sda    => open,
            sda_redge       => open,
            sda_fedge       => sda_fedge
        );

    -- watch for a START on the SP5 interface so we can take action accordingly
    -- TODO: this likely needs knowledge of if a transaction is going on or not?
    start_detected  <= '1' when scl_filt = '1' and sda_fedge = '1' else '0';

    --
    -- Our I2C controller
    --

    i2c_ctrl_txn_layer_inst: entity work.i2c_ctrl_txn_layer
     generic map(
        CLK_PER_NS  => CLK_PER_NS,
        MODE        => FAST_PLUS
    )
     port map(
        clk         => clk,
        reset       => reset,
        scl_if      => fpga_scl,
        sda_if      => fpga_sda,
        cmd         => cmd,
        cmd_valid   => cmd_valid,
        abort       => start_detected,
        core_ready  => open,
        tx_st_if    => tx_st_if,
        rx_st_if    => rx_st_if
    );

end architecture;