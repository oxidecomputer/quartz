-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

use work.i2c_link_layer_pkg.all;

entity i2c_top is
    port (
        clk         :   in  std_logic;
        reset       :   in  std_logic;

        -- Tri-state signals to I2C interface
        scl_if      : view tristate_if;
        sda_if      : view tristate_if;

        -- Transmit data stream
        tx_st_if    : view stream8_pkg.st_sink_if;

        -- Received data stream
        rx_st_if    : view stream8_pkg.st_source_if;
    );
end entity;

architecture rtl of i2c_top is

begin

end rtl;