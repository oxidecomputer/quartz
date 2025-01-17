-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

use work.axil8x32_pkg.all;
use work.stream8_pkg;
use work.tristate_if_pkg.all;

use work.i2c_common_pkg.all;

entity i2c_ctrl_top is
    generic (
        CLK_PER_NS  : positive;
        MODE        : mode_t;
    );
    port (
        clk         :   in  std_logic;
        reset       :   in  std_logic;

        -- Tri-state signals to I2C interface
        scl_if      : view tristate_if;
        sda_if      : view tristate_if;

        -- AXI register interface
        -- axi_if      : view axil_target;
    );
end entity;

architecture rtl of i2c_ctrl_top is
    signal start_command    : std_logic;
    signal command          : cmd_t;

    -- stubs
    signal tx_st_if         : stream8_pkg.data_channel;
    signal rx_st_if         : stream8_pkg.data_channel;
begin

    i2c_ctrl_txn_layer_inst: entity work.i2c_txn_layer
        generic map(
            CLK_PER_NS  => CLK_PER_NS,
            MODE        => MODE
        )
        port map(
            clk         => clk,
            reset       => reset,
            scl_if      => scl_if,
            sda_if      => sda_if,
            cmd         => command,
            cmd_valid   => start_command,
            core_ready  => open,
            tx_st_if    => tx_st_if,
            rx_st_if    => rx_st_if
        );

    i2c_ctrl_regs_inst: entity work.i2c_ctrl_regs
     port map(
        clk     => clk,
        reset   => reset,
        -- axi_if  => axi_if,
        start   => start_command,
        command => command,
        txd     => open,
        rxd     => (others => '0')
    );

end architecture;