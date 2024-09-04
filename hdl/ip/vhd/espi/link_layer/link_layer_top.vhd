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

entity link_layer_top is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        cs_n  : in    std_logic;
        sclk  : in    std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0);
        dbg_chan : view dbg_periph_if;
        -- set in registers, controls how the shifters
        -- sample per sclk
        qspi_mode : in    qspi_mode_t;
        -- Asserted by command processor during the
        -- transmission of the last command byte (the CRC)
        is_crc_byte : in    boolean;
        alert_needed : in boolean;
        response_done: in boolean;
        chip_sel_active : out boolean;
        -- "Streaming" data to serialize and transmit
        data_to_host       : view st_sink;
        -- "Streaming" bytes after receipt and deserialization
        data_from_host     : view st_source;
    );
end entity;
       
architecture rtl of link_layer_top is
    signal qspi_data_to_host : data_channel;
    signal qspi_data_from_host : data_channel;
    signal qspi_alert_needed : boolean;

    signal dbg_data_to_host : data_channel;
    signal dbg_data_from_host : data_channel;
    signal dbg_alert_needed : boolean;
    alias  debug_active is dbg_chan.enabled;
    signal dbg_chip_sel_active : boolean;
    
begin

    -- The "real" link layer
    qspi_link_layer: entity work.qspi_link_layer
        port map (
            clk => clk,
            reset => reset,
            cs_n => cs_n,
            sclk => sclk,
            io => io,
            io_o => io_o,
            io_oe => io_oe,
            qspi_mode => qspi_mode,
            is_crc_byte => is_crc_byte,
            alert_needed => qspi_alert_needed,
            data_to_host => qspi_data_to_host,
            data_from_host => qspi_data_from_host
        );

    -- a debug link layer for testing using fifos.
    debug_link_layer: entity work.dbg_link_faker
        port map (
            clk => clk,
            reset => reset,
            response_done => response_done,
            cs_active => dbg_chip_sel_active,
            alert_needed => dbg_alert_needed,
            data_to_host => dbg_data_to_host,
            data_from_host => dbg_data_from_host,
            dbg_chan => dbg_chan
            
        );

    -- Mux in the debug path.  We're going to mux off the ready/valid signals for inputs
    -- and just leave the datapath in place since it won't matter if the data transfers
    -- won't happen.
    -- system inputs- qspi shifters
    qspi_data_to_host.data <= data_to_host.data;
    qspi_data_to_host.valid <= data_to_host.valid when not debug_active else '0';
    qspi_data_from_host.ready <= data_from_host.ready when not debug_active else '0';
    qspi_alert_needed <= alert_needed when not debug_active else false;
    -- system inputs- debug "shifters"
    dbg_data_to_host.data <= data_to_host.data;
    dbg_data_to_host.valid <= data_to_host.valid when debug_active else '0';
    dbg_data_from_host.ready <= data_from_host.ready when debug_active else '0';
    dbg_alert_needed <= alert_needed when debug_active else false;
    
    -- system outputs
    data_to_host.ready <= qspi_data_to_host.ready when not debug_active else dbg_data_to_host.ready;
    data_from_host.data <= qspi_data_from_host.data when not debug_active else dbg_data_from_host.data;
    data_from_host.valid <= qspi_data_from_host.valid when not debug_active else dbg_data_from_host.valid;

    chip_sel_active <= cs_n = '0' when not debug_active else dbg_chip_sel_active;

end rtl;