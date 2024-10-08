-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

package i2c_link_layer_pkg is

    type state_t is (IDLE, START, TX_BYTE, RX_BYTE, TX_ACK, RX_ACK, STOP);

end package;