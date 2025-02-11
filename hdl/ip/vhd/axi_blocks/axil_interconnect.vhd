-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil_common_pkg.all;
use work.axilite_if_2008_pkg.all;
use work.axil8x32_pkg;
use work.axil26x32_pkg;

-- This is a somewhat naive implementation of an parameterized AXI-lite interconnect.
-- It is intended to be function as an MVP implementation allowing for basic multi-responder
-- usecases. It is not currently a full cross-bar implementation, but may grow to be one in the future.

entity axil_interconnect is
    generic (
        config_array : axil_responder_cfg_array_t
    );
    port (
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        -- Responder I/F to the main initiator, which is a *target* interface
        initiator : view axil26x32_pkg.axil_target;

        -- Initiator I/Fs to the responder blocks, which is a *controller* interface
        responders : view (axil8x32_pkg.axil_controller) of axil8x32_pkg.axil_array_t(config_array'range)

    );
end entity;

architecture rtl of axil_interconnect is
    signal responders_write_address_valid : std_logic_vector(config_array'range);
    signal responders_write_address_ready : std_logic_vector(config_array'range);
    signal responders_write_address_addr : tgt_addr8_t(config_array'range);
    signal responders_write_data_valid : std_logic_vector(config_array'range);
    signal responders_write_data_ready : std_logic_vector(config_array'range);
    signal responders_write_data_data: tgt_dat32_t(config_array'range);
    signal responders_write_data_strb: tgt_strb_t(config_array'range);
    signal responders_write_response_ready : std_logic_vector(config_array'range);
    signal responders_read_address_valid : std_logic_vector(config_array'range);
    signal responders_read_address_addr : tgt_addr8_t(config_array'range);
    signal responders_read_data_ready : std_logic_vector(config_array'range);
    signal responders_write_response_resp : tgt_resp_t(config_array'range);
    signal responders_write_response_valid : std_logic_vector(config_array'range);
    signal responders_read_address_ready : std_logic_vector(config_array'range);
    signal responders_read_data_resp : tgt_resp_t(config_array'range);
    signal responders_read_data_valid : std_logic_vector(config_array'range);
    signal responders_read_data_data : tgt_dat32_t(config_array'range);
  
begin

    axil_interconnect_2k8_inst: entity work.axil_interconnect_2k8
     generic map(
        initiator_addr_width => 26,
        config_array => config_array
    )
     port map(
        clk => clk,
        reset => reset,
        initiator_write_address_addr => initiator.write_address.addr,
        initiator_write_address_valid => initiator.write_address.valid,
        initiator_write_address_ready => initiator.write_address.ready,
        initiator_write_data_data => initiator.write_data.data,
        initiator_write_data_strb => initiator.write_data.strb,
        initiator_write_data_ready => initiator.write_data.ready,
        initiator_write_data_valid => initiator.write_data.valid,
        initiator_write_response_valid => initiator.write_response.valid,
        initiator_write_response_resp => initiator.write_response.resp,
        initiator_write_response_ready => initiator.write_response.ready,
        initiator_read_address_addr => initiator.read_address.addr,
        initiator_read_address_ready => initiator.read_address.ready,
        initiator_read_address_valid => initiator.read_address.valid,
        initiator_read_data_valid => initiator.read_data.valid,
        initiator_read_data_ready => initiator.read_data.ready,
        initiator_read_data_resp => initiator.read_data.resp,
        initiator_read_data_data => initiator.read_data.data,
        responders_write_address_valid => responders_write_address_valid,
        responders_write_address_ready => responders_write_address_ready,
        responders_write_address_addr => responders_write_address_addr,
        responders_write_data_valid => responders_write_data_valid,
        responders_write_data_ready => responders_write_data_ready,
        responders_write_data_data => responders_write_data_data,
        responders_write_data_strb => responders_write_data_strb,
        responders_write_response_ready => responders_write_response_ready,
        responders_read_address_valid => responders_read_address_valid,
        responders_read_address_addr => responders_read_address_addr,
        responders_read_data_ready => responders_read_data_ready,
        responders_write_response_resp => responders_write_response_resp,
        responders_write_response_valid => responders_write_response_valid,
        responders_read_address_ready => responders_read_address_ready,
        responders_read_data_resp => responders_read_data_resp,
        responders_read_data_valid => responders_read_data_valid,
        responders_read_data_data => responders_read_data_data
    );

    resp_gen: for i in config_array'range generate
        -- Deal with stuff going into the responder blocks

        responders_write_address_ready(i) <= responders(i).write_address.ready;
        responders_write_data_ready(i) <= responders(i).write_data.ready;
        responders_write_response_resp(i) <= responders(i).write_response.resp;
        responders_write_response_valid(i) <= responders(i).write_response.valid;
        responders_read_address_ready(i) <= responders(i).read_address.ready;
        responders_read_data_resp(i) <= responders(i).read_data.resp;
        responders_read_data_valid(i) <= responders(i).read_data.valid;
        responders_read_data_data(i) <= responders(i).read_data.data;

        -- Deal with stuff coming out of the responder blocks
        responders(i).write_address.valid <= responders_write_address_valid(i);
        responders(i).write_address.addr <= responders_write_address_addr(i);
        responders(i).write_data.valid <= responders_write_data_valid (i);
        responders(i).write_data.data <= responders_write_data_data(i);
        responders(i).write_data.strb <= responders_write_data_strb(i);
        responders(i).write_response.ready <= responders_write_response_ready(i);
        responders(i).read_address.valid <= responders_read_address_valid(i);
        responders(i).read_address.addr <= responders_read_address_addr(i);
        responders(i).read_data.ready <= responders_read_data_ready(i);

    end generate;
end rtl;
