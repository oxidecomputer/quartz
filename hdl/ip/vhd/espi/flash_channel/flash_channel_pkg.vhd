-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


use work.espi_base_types_pkg.all;

package flash_channel_pkg is
    constant num_descriptors : integer := 4;

    type descriptor_t is record
        sp5_addr : std_logic_vector(31 downto 0);
        xfr_size_bytes : std_logic_vector(11 downto 0);
        ready_bytes: std_logic_vector(11 downto 0);
        tag: std_logic_vector(3 downto 0);
        active: boolean;  -- valid waiting for processing or being processed
        flash_issued: boolean;
        done: boolean;
    end record;

    constant descriptor_init : descriptor_t := (
        sp5_addr => (others => '0'),
        xfr_size_bytes => (others => '0'),
        ready_bytes => (others => '0'),
        tag => (others => '0'),
        active => false,
        flash_issued => false,
        done => false
    );
    type command_queue_t is array(0 to num_descriptors - 1) of descriptor_t;



    type flash_channel_req_t is record
        espi_hdr : espi_cmd_header;
        sp5_flash_address : std_logic_vector(31 downto 0);
        flash_np_enqueue_req : boolean;
        flash_get_req : boolean;
    end record;
    view flash_chan_req_sink of flash_channel_req_t is
        espi_hdr, sp5_flash_address, flash_np_enqueue_req, flash_get_req : in;
    end view;
    alias flash_chan_req_source is flash_chan_req_sink'converse;

    type flash_channel_resp_t is record
        cycle_type: std_logic_vector(7 downto 0);
        tag: std_logic_vector(3 downto 0);
        length: std_logic_vector(11 downto 0);
        data  : std_logic_vector(7 downto 0);
        valid : std_logic;
        ready: std_logic;
    end record;
    view flash_chan_resp_source of flash_channel_resp_t is
        cycle_type  : out;
        tag         : out;
        length      : out;
        valid, data : out;
        ready       : in;
    end view;
    alias flash_chan_resp_sink is flash_chan_resp_source'converse;

end package;