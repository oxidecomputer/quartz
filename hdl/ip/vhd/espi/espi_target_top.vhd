-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Top level of the eSPI target block. This block is responsible for
-- basic synchronization of the eSPI signals, and instantiation of the
-- rest of the blocks

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.qspi_link_layer_pkg.all;
use work.espi_base_types_pkg.all;
use work.flash_channel_pkg.all;
use work.uart_channel_pkg.all;
use work.link_layer_pkg.all;

use work.axil8x32_pkg.all;

entity espi_target_top is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        clk_200m : in std_logic;
        reset_200m : in std_logic;
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
        flash_fifo_clear : out std_logic;
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
    signal chip_sel_active : std_logic;
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
    signal oob_free : std_logic;
    signal oob_avail : std_logic;
    signal host_to_sp_espi : st_uart_t;
    signal sp_to_host_espi : uart_resp_t;
    signal aborted_due_to_bad_crc : boolean;
    signal cs_n_syncd : std_logic;
    signal sclk_syncd : std_logic;
    signal vwire_if : vwire_if_type;
    signal vwire_avail : std_logic;
    signal qspi_cmd : byte_stream;
    signal qspi_resp : byte_stream;
    signal gen_cmd : byte_stream;
    signal gen_resp : byte_stream;
    signal gen_cs_n : std_logic;
    signal txn_cmd : byte_stream;
    signal txn_resp : byte_stream;
    signal txn_csn : std_logic;
    signal alert_needed_fast : std_logic;
    signal alert_needed_slow : std_logic;
    signal qspi_mode_vec_slow : std_logic_vector(1 downto 0);
    signal qspi_mode_vec_fast : std_logic_vector(1 downto 0);
    signal wait_states_fast: std_logic_vector(3 downto 0);
    signal wait_states_slow: std_logic_vector(3 downto 0);
    signal post_code : std_logic_vector(31 downto 0);
    signal post_code_valid : std_logic;
    signal espi_reset_strobe : std_logic;
    signal espi_reset_strobe_syncd : std_logic;
    signal oob_avail_last_byte : std_logic;

begin

    -- sync
    cs_meta_sync_inst: entity work.meta_sync
     generic map(
        stages => 1
    )
     port map(
        async_input => cs_n,
        clk => clk_200m,
        sycnd_output => cs_n_syncd
    );

    sclk_meta_sync_inst: entity work.meta_sync
     generic map(
        stages => 1
    )
     port map(
        async_input => sclk,
        clk => clk_200m,
        sycnd_output => sclk_syncd
    );

    wait_state_sync: entity work.bacd
     generic map(
        always_valid_in_b => true
    )
     port map(
        reset_launch => reset,
        clk_launch => clk,
        write_launch => '1',  -- always propagate
        bus_launch => wait_states_slow,
        write_allowed => open,
        reset_latch => reset_200m,
        clk_latch => clk_200m,
        datavalid_latch => open,
        bus_latch => wait_states_fast
    );

    qspi_mode_vec_slow <= decode(qspi_mode);
    qspi_mode_sync: entity work.bacd
    generic map(
       always_valid_in_b => true
   )
    port map(
       reset_launch => reset,
       clk_launch => clk,
       write_launch => '1',  -- always propagate
       bus_launch => qspi_mode_vec_slow,
       write_allowed => open,
       reset_latch => reset_200m,
       clk_latch => clk_200m,
       datavalid_latch => open,
       bus_latch => qspi_mode_vec_fast
   );

    qspi_link_layer_inst: entity work.link_layer
     port map(
        clk => clk_200m,
        reset => reset_200m,
        cs_n => cs_n_syncd,
        sclk => sclk_syncd,
        io => io,
        io_o => io_o,
        io_oe => io_oe,
        response_csn => response_csn,
        cmd_to_fifo => qspi_cmd,
        resp_from_fifo => qspi_resp,
        wait_states => wait_states_fast,
        qspi_mode => encode(qspi_mode_vec_fast),
        alert_needed => alert_needed_fast,
        espi_reset => espi_reset_strobe
    );

    -- debug_link_layer
    dbg_link_faker_inst: entity work.dbg_link_faker
     port map(
        clk => clk,
        reset => reset,
        response_done => response_done,
        aborted_due_to_bad_crc => aborted_due_to_bad_crc,
        cs_n => gen_cs_n,
        alert_needed => alert_needed,
        gen_resp => gen_resp,
        gen_cmd => gen_cmd,
        dbg_chan => dbg_chan
    );

    alert_needed_slow <= '1' when alert_needed else '0';
    alert_sync: entity work.meta_sync
    generic map(
       stages => 1
   )
    port map(
       async_input => alert_needed_slow,
       clk => clk_200m,
       sycnd_output => alert_needed_fast
   );

   espi_reset_pulse_sync:entity work.tacd
    port map(
       clk_launch => clk_200m,
       reset_launch => reset_200m,
       pulse_in_launch => espi_reset_strobe,
       clk_latch => clk,
       reset_latch => reset,
       pulse_out_latch => espi_reset_strobe_syncd
   );


   link_to_txn_bridge_inst: entity work.link_to_txn_bridge
    port map(
       clk_200m => clk_200m,
       reset_200m => reset_200m,
       clk => clk,
       reset => reset,
       espi_reset_fast => espi_reset_strobe,
       espi_reset_slow => espi_reset_strobe_syncd,
       txn_gen_enabled => dbg_chan.enabled,
       qspi_cmd => qspi_cmd,
       qspi_resp => qspi_resp,
       qspi_cs_n => cs_n_syncd,
       gen_cmd => gen_cmd,
       gen_resp => gen_resp,
       gen_cs_n => gen_cs_n,
       txn_cmd => txn_cmd,
       txn_resp => txn_resp,
       txn_csn => txn_csn
   );

   chip_sel_active <= not txn_csn;
    -- system (axi-lite) register block
   espi_sys_regs_inst: entity work.espi_regs
    port map(
       clk => clk,
       reset => reset,
       axi_if => axi_if,
       dbg_chan => dbg_chan,
       post_code => post_code,
       post_code_valid => post_code_valid,
       espi_reset => espi_reset_strobe_syncd
   );

    -- txn layer blocks
    transaction: entity work.txn_layer_top
        port map (
            clk             => clk,
            reset           => reset,
            espi_reset      => espi_reset_strobe_syncd,
            is_rx_crc_byte  => is_rx_crc_byte,
            is_tx_crc_byte  => is_tx_crc_byte,
            regs_if         => regs_if,
            post_code       => post_code,
            post_code_valid => post_code_valid,
            vwire_if        => vwire_if,
            chip_sel_active => chip_sel_active,
            data_to_host    => txn_resp,
            data_from_host  => txn_cmd,
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
            oob_free => oob_free,
            oob_avail => oob_avail,
            oob_avail_last_byte => oob_avail_last_byte,
            vwire_avail => vwire_avail
        );

    -- espi-internal register block
    espi_regs_inst: entity work.espi_spec_regs
        port map (
            clk            => clk,
            reset          => reset,
            espi_reset     => espi_reset_strobe_syncd,
            regs_if        => regs_if,
            qspi_mode      => qspi_mode,
            wait_states    => wait_states_slow,
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
       flash_fifo_clear => flash_fifo_clear,
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
       espi_reset => espi_reset_strobe_syncd,
       host_to_sp_espi => host_to_sp_espi,
       sp_to_host_espi => sp_to_host_espi,
       to_sp_uart_data => to_sp_uart_data,
       to_sp_uart_valid => to_sp_uart_valid,
       to_sp_uart_ready => to_sp_uart_ready,
       from_sp_uart_data => from_sp_uart_data,
       from_sp_uart_valid => from_sp_uart_valid,
       from_sp_uart_ready => from_sp_uart_ready,
       pc_free => pc_free,
       pc_avail => pc_avail,
       np_free => np_free,
       np_avail => np_avail,
       oob_avail => oob_avail,
       oob_free => oob_free,
       oob_avail_last_byte => oob_avail_last_byte
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
