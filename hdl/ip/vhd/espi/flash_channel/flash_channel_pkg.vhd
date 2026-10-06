-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


use work.espi_base_types_pkg.all;

package flash_channel_pkg is
    constant num_descriptors : integer := 4;

    -- What a queued flash request is. "refused" is a write or erase that
    -- arrived while writes were not permitted: it still occupies a
    -- descriptor so that the host gets a completion, an unsuccessful one,
    -- rather than waiting forever.
    type flash_kind_t is (flash_rd, flash_wr, flash_er, flash_refused);

    -- Encoding of the kind in the top nibble of the length word handed to
    -- the flash controller. Reads encode as zero so a controller that only
    -- understands the original two-word read command sees nothing new.
    function to_kind_bits(kind : flash_kind_t) return std_logic_vector;

    type descriptor_t is record
        kind : flash_kind_t;
        sp5_addr : std_logic_vector(31 downto 0);
        xfr_size_bytes : std_logic_vector(11 downto 0);
        ready_bytes: std_logic_vector(11 downto 0);
        tag: std_logic_vector(3 downto 0);
        active: boolean;  -- valid waiting for processing or being processed
        flash_issued: boolean;
        done: boolean;
        -- set once the flash controller reported the write or erase failed
        failed: boolean;
    end record;

    constant descriptor_init : descriptor_t := (
        kind => flash_rd,
        sp5_addr => (others => '0'),
        xfr_size_bytes => (others => '0'),
        ready_bytes => (others => '0'),
        tag => (others => '0'),
        active => false,
        flash_issued => false,
        done => false,
        failed => false
    );
    type command_queue_t is array(0 to num_descriptors - 1) of descriptor_t;



    type flash_channel_req_t is record
        espi_hdr : espi_cmd_header;
        sp5_flash_address : std_logic_vector(31 downto 0);
        kind : flash_kind_t;
        flash_np_enqueue_req : boolean;
        flash_get_req : boolean;
        -- Write payload, streamed as the command is parsed, ahead of the
        -- enqueue that follows a good CRC.
        wdata : std_logic_vector(7 downto 0);
        wdata_valid : std_logic;
        wdata_idx : std_logic_vector(11 downto 0);
    end record;
    view flash_chan_req_sink of flash_channel_req_t is
        espi_hdr, sp5_flash_address, kind, flash_np_enqueue_req, flash_get_req,
        wdata, wdata_valid, wdata_idx : in;
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

package body flash_channel_pkg is

    function to_kind_bits(kind : flash_kind_t) return std_logic_vector is
    begin
        case kind is
            when flash_rd => return x"0";
            when flash_wr => return x"1";
            when flash_er => return x"2";
            when flash_refused => return x"0";
        end case;
    end function;

end package body;