-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package qspi_link_layer_pkg is

    -- This is relying on the VHDL 2019 feature
    -- for "interfaces"
    type data_channel is record
        data  : std_logic_vector(7 downto 0);
        valid : std_logic;
        ready: std_logic;

    end record;

    view st_source of data_channel is  -- the mode view of the record
        valid, data : out;
        ready       : in;
    end view;

    alias st_sink is st_source'converse;

    -- debug interfaces
    -- FIFO write interface
    type fifo_wr is record
        data : std_logic_vector(31 downto 0);
        write: std_logic;
        reset: std_logic;
    end record;
    view fifo_wr_source of fifo_wr is
        data : out;
        write : out;
        reset : out;
    end view;
    alias fifo_wr_sink is fifo_wr_source'converse;

    -- FIFO status interface
    type fifo_status is record
        usedwds: std_logic_vector(15 downto 0);
    end record;
    view fifo_status_source of fifo_status is
       usedwds : out;
    end view;
    alias fifo_status_sink is fifo_status_source'converse;

    -- FIFO read interface
    type fifo_rd is record
        data : std_logic_vector(31 downto 0);
        rdack: std_logic;
    end record;
    view fifo_rd_source of fifo_rd is
        data : in;
        rdack: out;
     end view;
     alias fifo_rd_sink is fifo_rd_source'converse;

    -- Whole wrapped up debug channel
    type dbg_chan_t is record
        wr : fifo_wr;
        wstatus: fifo_status;
        rd : fifo_rd;
        size: fifo_wr;
        rdstatus: fifo_status;
        enabled: std_logic;
        alert_pending: std_logic;
        busy: std_logic;
        espi_reset : std_logic;
    end record;

    view dbg_regs_if of dbg_chan_t is  -- the mode view of the record
        wr: view fifo_wr_source;
        wstatus: view fifo_status_sink;
        rd: view fifo_rd_source;
        size: view fifo_wr_source;
        rdstatus: view fifo_status_sink;
        enabled: out;
        alert_pending : in;
        busy: in;
        espi_reset: out;
    end view;
    alias dbg_periph_if is dbg_regs_if'converse;



  

end package;
