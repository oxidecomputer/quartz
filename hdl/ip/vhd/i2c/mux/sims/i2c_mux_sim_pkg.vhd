-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.i2c_ctrl_vc_pkg.all;

package i2c_mux_sim_pkg is

    constant i2c_ctrl_vc : i2c_ctrl_vc_t := new_i2c_ctrl_vc("i2c_ctrl_vc");

end package;