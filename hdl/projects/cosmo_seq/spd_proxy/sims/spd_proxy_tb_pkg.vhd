-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.i2c_cmd_vc_pkg.all;
use work.i2c_ctrl_vc_pkg.all;
use work.i2c_target_vc_pkg.all;
use work.basic_stream_pkg.all;

use work.i2c_common_pkg.all;

package spd_proxy_tb_pkg is
    -- Constants
    constant CLK_PER_NS : positive := 8;

    -- Verification Components
    constant I2C_CTRL_VC        : i2c_ctrl_vc_t     := new_i2c_ctrl_vc("cpu_i2c_vc");
    constant I2C_DIMM1_TGT_VC         : i2c_target_vc_t   := new_i2c_target_vc("dimm1_i2c_vc");
    constant I2C_DIMM2_TGT_VC         : i2c_target_vc_t   := new_i2c_target_vc("dimm2_i2c_vc");
    constant I2C_CMD_VC         : i2c_cmd_vc_t      := new_i2c_cmd_vc;
    constant TX_DATA_SOURCE_VC  : basic_source_t    := new_basic_source(8);
    constant RX_DATA_SINK_VC    : basic_sink_t      := new_basic_sink(8);

    -- AXI-Lite bus handle for the axi master in the testbench
    constant bus_handle : bus_master_t := new_bus(data_length => 32,
    address_length => 8);

    procedure issue_i2c_cmd (
        signal net  : inout network_t;
        constant command : cmd_t;
        constant tx_data : queue_t;
        constant i2c_target : i2c_target_vc_t := I2C_DIMM1_TGT_VC
    );

end package;

package body spd_proxy_tb_pkg is

    procedure issue_i2c_cmd (
        signal net  : inout network_t;
        constant command : cmd_t;
        constant tx_data : queue_t;
        constant i2c_target : i2c_target_vc_t := I2C_DIMM1_TGT_VC
    ) is
        variable ack    : boolean := FALSE;
    begin
        push_i2c_cmd(net, I2C_CMD_VC, command);
        start_byte_ack(net, i2c_target, ack);
        check_true(ack, "Peripheral did not ACK correct address");
        while not is_empty(tx_data) loop
            push_basic_stream(net, TX_DATA_SOURCE_VC, to_std_logic_vector(pop_byte(tx_data), 8));
        end loop;
    end procedure;

end package body;