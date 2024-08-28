-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.qspi_link_layer_pkg.all;
use work.espi_base_types_pkg.all;
use work.flash_channel_pkg.all;

entity espi_target_top is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        cs_n  : in    std_logic;
        sclk  : in    std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0);
        -- Interface out to the flash block
        -- Read Command FIFO
        flash_cfifo_data : out std_logic_vector(31 downto 0);
        flash_cfifo_write: out std_logic;
        -- Read Data FIFO
        flash_rfifo_data : in std_logic_vector(7 downto 0);
        flash_rfifo_rdack : out std_logic;
        flash_rfifo_rempty: in std_logic;
    );
end entity;

architecture rtl of espi_target_top is

    signal qspi_mode       : qspi_mode_t;
    signal is_crc_byte     : boolean;
    signal chip_sel_active : boolean;
    signal data_to_host    : data_channel;
    signal data_from_host  : data_channel;
    signal regs_if         : cmd_reg_if;
    signal flash_req       : flash_channel_req_t;
    signal flash_resp      : flash_channel_resp_t;
    signal alert_needed    : boolean;
    signal flash_np_free  : std_logic;
    signal flash_c_avail : std_logic;
    signal flash_channel_enable : boolean;

begin

    chip_sel_active <= cs_n = '0';

    -- link layer
    link_layer_top_inst: entity work.link_layer_top
     port map(
        clk => clk,
        reset => reset,
        cs_n => cs_n,
        sclk => sclk,
        io => io,
        io_o => io_o,
        io_oe => io_oe,
        debug_active => false,
        qspi_mode => qspi_mode,
        is_crc_byte => is_crc_byte,
        alert_needed => alert_needed,
        data_to_host => data_to_host,
        data_from_host => data_from_host
    );
    -- TODO: think about more robust in-system testbench for all of this.
    -- Ideally, I'd like to use the SP to simulate the SP5 transactions.
    -- The easiest way here is to insert/inject into the post-serialized
    -- data stream with FIFOs and a mux. This would allow us to send
    -- arbitrary data and get arbitrary responses and do fancier stuff in software.
    -- I'd also like to put a DPR as a packet logger here to capture espi data
    -- for debugging/analysis.

    -- txn layer blocks
    transaction: entity work.txn_layer_top
        port map (
            clk             => clk,
            reset           => reset,
            is_crc_byte     => is_crc_byte,
            regs_if         => regs_if,
            chip_sel_active => chip_sel_active,
            data_to_host    => data_to_host,
            data_from_host  => data_from_host,
            alert_needed    => alert_needed,
            flash_req       => flash_req,
            flash_resp      => flash_resp,
             -- flash channel status
            flash_np_free => flash_np_free,
            flash_c_avail => flash_c_avail
        );

    -- register blocks
    espi_regs_inst: entity work.espi_spec_regs
        port map (
            clk            => clk,
            reset          => reset,
            regs_if        => regs_if,
            qspi_mode      => qspi_mode,
            flash_channel_enable => flash_channel_enable
        );

    -- flash access channel logic
   flash_channel_inst: entity work.flash_channel
    port map(
       clk => clk,
       reset => reset,
       request => flash_req,
       response => flash_resp,
       enabled => flash_channel_enable,
       flash_np_free => flash_np_free,
       flash_c_avail => flash_c_avail,
       flash_cfifo_data => flash_cfifo_data,
       flash_cfifo_write => flash_cfifo_write,
       flash_rfifo_data => flash_rfifo_data,
       flash_rfifo_rdack => flash_rfifo_rdack,
       flash_rfifo_rempty => flash_rfifo_rempty
   );

end rtl;
