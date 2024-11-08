-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.flash_channel_pkg.all;
use work.qspi_link_layer_pkg.all;
use work.espi_base_types_pkg.all;
use work.espi_protocol_pkg.all;
use work.uart_channel_pkg.all;
use work.link_layer_pkg.all;

entity txn_layer_top is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- register layer connections
        regs_if : view    bus_side;
        -- vwire channel connections
        vwire_if : view vwire_cmd_side;
        -- flash channel status
        flash_np_free : in    std_logic;
        flash_c_avail : in    std_logic;
        -- flash channel requests/responses
        flash_req  : view flash_chan_req_source;
        flash_resp : view flash_chan_resp_sink;
        -- uart channel requests/responses
        host_to_sp_espi : view uart_data_source;
        sp_to_host_espi : view uart_resp_sink;
        -- uart channel status
        pc_free : in std_logic;
        pc_avail : in std_logic;
        np_free : in std_logic;
        np_avail: in std_logic;
        vwire_avail : in std_logic;

        -- Link-layer connections
        is_rx_crc_byte     : out   boolean;
        is_tx_crc_byte     : out   boolean;
        chip_sel_active : in    std_logic;
        data_to_host    : view byte_source;
        alert_needed    : out   boolean;
        response_done   : out   boolean;
        aborted_due_to_bad_crc : out boolean;
        -- "Streaming" data to serialize and transmit
        data_from_host : view byte_sink
    );
end entity;

architecture rtl of txn_layer_top is

    signal txn_byte_count : unsigned(12 downto 0);
    signal rx_running_crc : std_logic_vector(7 downto 0);
    signal tx_running_crc : std_logic_vector(7 downto 0);
    signal clear_rx_crc   : std_logic;
    signal clear_tx_crc   : std_logic;
    signal live_status    : status_t;
    signal command_header : espi_cmd_header;
    signal resp_regs_if   : resp_reg_if;

begin

    -- Basic counter that counts bytes from the shifters
    -- The shifters deal with the QSPI mode so we will
    -- be able to use this as an index into the current
    -- transaction. The counter increments when the byte
    -- is valid, which will be just after the sampling
    -- (ie the rising edge of sclk)
    txn_byte_counter: process(clk, reset)
    begin
        if reset then
            txn_byte_count <= (others => '0');
        elsif rising_edge(clk) then
            if not chip_sel_active then
                txn_byte_count <= (others => '0');
            elsif data_from_host.valid = '1' then
                txn_byte_count <= txn_byte_count + 1;
            end if;
        end if;
    end process;

    -- TODO: consider sharing this block for both tx and rx flows
    -- the CRC is never used concurrently in both directions
    rx_crc_checker: entity work.crc8atm_8wide
        port map (
            clk     => clk,
            reset   => reset,
            data_in => data_from_host.data,
            enable  => data_from_host.valid and data_from_host.ready,
            clear   => clear_rx_crc,
            crc_out => rx_running_crc
        );

    tx_crc_checker: entity work.crc8atm_8wide
        port map (
            clk     => clk,
            reset   => reset,
            data_in => data_to_host.data,
            enable  => data_to_host.valid and data_to_host.ready,
            clear   => clear_tx_crc,
            crc_out => tx_running_crc
        );

    command_processor_inst: entity work.command_processor
        port map (
            clk             => clk,
            reset           => reset,
            regs_if         => regs_if,
            vwire_if        => vwire_if,
            flash_req       => flash_req,
            host_to_sp_espi => host_to_sp_espi,
            running_crc     => rx_running_crc,
            clear_rx_crc    => clear_rx_crc,
            command_header  => command_header,
            response_done   => response_done,
            aborted_due_to_bad_crc => aborted_due_to_bad_crc,
            is_rx_crc_byte  => is_rx_crc_byte,
            chip_sel_active => chip_sel_active,
            data_from_host  => data_from_host
        );

    response_processor_inst: entity work.response_processor
        port map (
            clk            => clk,
            reset          => reset,
            command_header => command_header,
            response_done  => response_done,
            regs_if        => resp_regs_if,
            chip_sel_active => chip_sel_active,
            is_tx_last_byte => is_tx_crc_byte,
            clear_tx_crc   => clear_tx_crc,
            data_to_host   => data_to_host,
            live_status    => live_status,
            response_crc   => tx_running_crc,
            flash_resp     => flash_resp,
            sp_to_host_espi => sp_to_host_espi,
            alert_needed   => alert_needed
        );

    resp_regs_if.write       <= regs_if.write;
    resp_regs_if.read        <= regs_if.read;
    resp_regs_if.addr        <= regs_if.addr;
    resp_regs_if.wdata       <= regs_if.wdata;
    resp_regs_if.rdata       <= regs_if.rdata;
    resp_regs_if.rdata_valid <= regs_if.rdata_valid;

    process(all)
    begin
        -- default to reset, override with other status bits
        live_status <= rec_reset;
        live_status.vwire_avail <= vwire_avail;
        live_status.flash_c_avail <= flash_c_avail;
        live_status.flash_np_free <= flash_np_free;
        live_status.pc_avail <= pc_avail;
        live_status.pc_free <= pc_free;
        live_status.np_avail <= np_avail;
        live_status.np_free <= np_free;
    end process;

end rtl;
