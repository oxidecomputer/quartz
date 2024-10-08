-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

use work.tristate_if_pkg;

use work.i2c_common_pkg;

entity i2c_core is
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
    );
end entity;

architecture rtl of i2c_core is

begin

    i2c_txn_layer_inst: entity work.i2c_txn_layer
     generic map(
        CLK_PER_NS => CLK_PER_NS,
        MODE => MODE
    )
     port map(
        clk => clk,
        reset => reset,
        scl_if => scl_if,
        sda_if => sda_if,
        cmd => cmd,
        cmd_valid => cmd_valid,
        core_ready => core_ready,
        tx_st_if => tx_st_if,
        rx_st_if => rx_st_if
    );

end architecture;