-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;


package uart_tb_pkg is

    constant rx_uart_bfm : uart_slave_t := new_uart_slave(initial_baud_rate => 3125000,
    data_length => 8);

    constant tx_uart_bfm : uart_master_t := new_uart_master(initial_baud_rate => 3125000);

end package;