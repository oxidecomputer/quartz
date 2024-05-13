-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

--! Bus master model based on ST's RM0433
--! figures 115 and 116

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

package fmc_tb_pkg is

    constant rd_logger       : logger_t    := get_logger("axi_rd");
    constant rmemory         : memory_t    := new_memory;
    constant axi_read_target : axi_slave_t := new_axi_slave(address_fifo_depth => 1,
                                                            memory => rmemory,
                                                            logger => rd_logger);

    constant wmemory          : memory_t    := new_memory;
    constant axi_write_target : axi_slave_t := new_axi_slave(memory => wmemory);

end package;
