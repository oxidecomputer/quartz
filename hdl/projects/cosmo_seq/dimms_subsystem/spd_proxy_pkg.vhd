-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.i2c_common_pkg.all;
use work.axi_st8_pkg;
package spd_proxy_pkg is

    type proxy_chan_reg_t is record
        i2c_cmd : cmd_t;
        i2c_cmd_valid : std_logic;
        start_prefetch : std_logic;
        done_prefetch : std_logic;
        req : std_logic;
        grant : std_logic;
        i2c_tx_st_if : axi_st8_pkg.axi_st_t;
        i2c_rx_st_if : axi_st8_pkg.axi_st_t;
        spd_present : std_logic_vector(7 downto 0);
        rd_addr : std_logic_vector(7 downto 0);
        rd_data : std_logic_vector(31 downto 0);
        selected_dimm: std_logic_vector(7 downto 0);
        i2c_done : std_logic;
        i2c_aborted : std_logic;
    end record;
    view channel_side of proxy_chan_reg_t is
        i2c_cmd : in;
        i2c_cmd_valid : in;
        start_prefetch : in;
        done_prefetch : out;
        req : in;
        grant : out;
        spd_present : out;
        rd_addr : in;
        rd_data :out;
        selected_dimm: in;
        i2c_done  : out;
        i2c_aborted : out;
        i2c_tx_st_if : view axi_st8_pkg.axi_st_sink;
        i2c_rx_st_if : view axi_st8_pkg.axi_st_source;
    end view;
    alias reg_side is channel_side'converse;

    type txn_buf_ctrl_t is  record
        rx_fifo_reset : std_logic;
        rx_fifo_pop : std_logic;
        rx_fifo_auto_inc : std_logic;
        rx_waddr : std_logic_vector(7 downto 0);
        rx_raddr : std_logic_vector(5 downto 0);
        rx_bytes : std_logic_vector(7 downto 0);
        rx_rdata : std_logic_vector(31 downto 0);
        txn_start : std_logic;
        tx_fifo_reset : std_logic;
        tx_waddr : std_logic_vector(7 downto 0);
        tx_wdata : std_logic_vector(31 downto 0);
        tx_wen : std_logic;
    end  record;

    view regs_buf_buf_side of txn_buf_ctrl_t is
        rx_fifo_reset : in;
        rx_fifo_pop : in;
        rx_fifo_auto_inc : in;
        rx_waddr : out;
        rx_raddr : out;
        rx_bytes : out;
        rx_rdata : out;
        txn_start : in;
        tx_fifo_reset : in;
        tx_waddr : out;
        tx_wdata :in;
        tx_wen : in;

    end view;

end package;