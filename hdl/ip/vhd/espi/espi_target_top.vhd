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
use work.uart_channel_pkg.all;

use work.axil8x32_pkg.all;

entity espi_target_top is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        axi_clk : in std_logic;
        axi_reset : in std_logic;
        -- Axilite interface
        axi_if : view axil_target;
        -- phy interface
        cs_n  : in    std_logic;
        sclk  : in    std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0);
        response_csn : out std_logic;
        -- Interface out to the flash block
        -- Read Command FIFO
        flash_cfifo_data : out std_logic_vector(31 downto 0);
        flash_cfifo_write: out std_logic;
        -- Read Data FIFO
        flash_rfifo_data : in std_logic_vector(7 downto 0);
        flash_rfifo_rdack : out std_logic;
        flash_rfifo_rempty: in std_logic;
        -- Interfaces to the UART block
        to_sp_uart_data : out std_logic_vector(7 downto 0);
        to_sp_uart_valid: out std_logic;
        to_sp_uart_ready: in std_logic;
        from_sp_uart_data : in std_logic_vector(7 downto 0);
        from_sp_uart_valid: in std_logic;
        from_sp_uart_ready: out std_logic
    );
end entity;

architecture rtl of espi_target_top is

    signal qspi_mode       : qspi_mode_t;
    signal is_rx_crc_byte     : boolean;
    signal is_tx_crc_byte     : boolean;
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
    signal dbg_chan : dbg_chan_t;
    signal response_done : boolean;
    signal pc_free : std_logic;
    signal pc_avail : std_logic;
    signal np_free : std_logic;
    signal np_avail : std_logic;
    signal host_to_sp_espi : st_uart_t;
    signal sp_to_host_espi : uart_resp_t;
    signal aborted_due_to_bad_crc : boolean;
    signal cs_n_syncd : std_logic;
    signal sclk_syncd : std_logic;
    signal vwire_if : vwire_if_type;
    signal vwire_avail : std_logic;
    signal msg_en : std_logic;

begin

    -- sync
    cs_meta_sync_inst: entity work.meta_sync
     generic map(
        stages => 1
    )
     port map(
        async_input => cs_n,
        clk => clk,
        sycnd_output => cs_n_syncd
    );

    sclk_meta_sync_inst: entity work.meta_sync
     generic map(
        stages => 1
    )
     port map(
        async_input => sclk,
        clk => clk,
        sycnd_output => sclk_syncd
    );

    -- link layer
    link_layer_top_inst: entity work.link_layer_top
     port map(
        clk => clk,
        reset => reset,
        axi_clk => axi_clk,
        axi_reset => axi_reset,
        cs_n => cs_n_syncd,
        sclk => sclk_syncd,
        io => io,
        io_o => io_o,
        io_oe => io_oe,
        response_csn => response_csn,
        dbg_chan => dbg_chan,
        qspi_mode => qspi_mode,
        is_rx_crc_byte => is_rx_crc_byte,
        is_tx_crc_byte => is_tx_crc_byte,
        response_done => response_done,
        aborted_due_to_bad_crc => aborted_due_to_bad_crc,
        chip_sel_active => chip_sel_active,
        alert_needed => alert_needed,
        data_to_host => data_to_host,
        data_from_host => data_from_host
    );

    -- system (axi-lite) register block
   espi_sys_regs_inst: entity work.espi_regs
    port map(
       clk => axi_clk,
       reset => axi_reset,
       axi_if => axi_if,
       msg_en => msg_en,
       dbg_chan => dbg_chan
   );

    -- txn layer blocks
    transaction: entity work.txn_layer_top
        port map (
            clk             => clk,
            reset           => reset,
            is_rx_crc_byte  => is_rx_crc_byte,
            is_tx_crc_byte  => is_tx_crc_byte,
            regs_if         => regs_if,
            vwire_if        => vwire_if,
            chip_sel_active => chip_sel_active,
            data_to_host    => data_to_host,
            data_from_host  => data_from_host,
            alert_needed    => alert_needed,
            flash_req       => flash_req,
            flash_resp      => flash_resp,
            response_done   => response_done,
            aborted_due_to_bad_crc => aborted_due_to_bad_crc,
             -- flash channel status
            flash_np_free => flash_np_free,
            flash_c_avail => flash_c_avail,
            host_to_sp_espi => host_to_sp_espi,
            sp_to_host_espi => sp_to_host_espi,
            pc_free => pc_free,
            pc_avail => pc_avail,
            np_free => np_free,
            np_avail => np_avail,
            vwire_avail => vwire_avail
        );

    -- espi-internal register block
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

   -- uart channel logic
   uart_channel_top_inst: entity work.uart_channel_top
    port map(
       clk => clk,
       reset => reset,
       host_to_sp_espi => host_to_sp_espi,
       sp_to_host_espi => sp_to_host_espi,
       to_sp_uart_data => to_sp_uart_data,
       to_sp_uart_valid => to_sp_uart_valid,
       to_sp_uart_ready => to_sp_uart_ready,
       from_sp_uart_data => from_sp_uart_data,
       from_sp_uart_valid => from_sp_uart_valid,
       from_sp_uart_ready => from_sp_uart_ready,
        msg_not_oob => msg_en,
       pc_free => pc_free,
       pc_avail => pc_avail,
       np_free => np_free,
       np_avail => np_avail
   );

   -- vwire channel logic
    vwire_block_inst: entity work.vwire_block
     port map(
        clk => clk,
        reset => reset,
        espi_reset_flag => '0',
        wire_tx_avail => vwire_avail,
        vwire_if => vwire_if
    );
end rtl;
