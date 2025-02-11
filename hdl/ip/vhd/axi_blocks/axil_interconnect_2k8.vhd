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

-- This is a somewhat naive implementation of an parameterized AXI-lite interconnect.
-- It is intended to be function as an MVP implementation allowing for basic multi-responder
-- usecases. It is not currently a full cross-bar implementation, but may grow to be one in the future.
-- This is the VHDL 2k8 version which does not use interface views.

entity axil_interconnect_2k8 is
    generic (
        initiator_addr_width : integer;
        config_array : axil_responder_cfg_array_t
    );
    port (
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        -- Responder I/F to the main initiator, which is a *target* interface
        initiator_write_address_addr : in std_logic_vector(initiator_addr_width - 1 downto 0);
        initiator_write_address_valid : in std_logic;
        initiator_write_address_ready : out std_logic;

        initiator_write_data_data : in std_logic_vector(31 downto 0);
        initiator_write_data_strb : in std_logic_vector(3 downto 0);
        initiator_write_data_ready : out std_logic;
        initiator_write_data_valid : in std_logic;
        
        initiator_write_response_valid : out std_logic;
        initiator_write_response_resp : out std_logic_vector(1 downto 0);
        initiator_write_response_ready : in std_logic;

        initiator_read_address_addr : in std_logic_vector(initiator_addr_width - 1 downto 0);
        initiator_read_address_ready : out std_logic;
        initiator_read_address_valid : in std_logic;

        initiator_read_data_valid : out std_logic;
        initiator_read_data_ready : in std_logic;
        initiator_read_data_resp : out std_logic_vector(1 downto 0);
        initiator_read_data_data : out std_logic_vector(31 downto 0);

        -- Initiator I/Fs to the responder blocks, which is a *controller* interface
        --responders : view (axil8x32_pkg.axil_controller) of axil8x32_pkg.axil_array_t(config_array'range)
        responders_write_address_valid : out std_logic_vector(config_array'range);
        responders_write_address_ready : in std_logic_vector(config_array'range);
        responders_write_address_addr : out tgt_addr8_t(config_array'range);
        
        responders_write_data_valid : out std_logic_vector(config_array'range);
        responders_write_data_ready : in std_logic_vector(config_array'range);
        responders_write_data_data: out tgt_dat32_t(config_array'range);
        responders_write_data_strb: out tgt_strb_t(config_array'range);
        
        responders_write_response_ready : out std_logic_vector(config_array'range);
        responders_write_response_resp : in tgt_resp_t(config_array'range);
        responders_write_response_valid : in std_logic_vector(config_array'range);

        responders_read_address_valid : out std_logic_vector(config_array'range);
        responders_read_address_addr : out tgt_addr8_t(config_array'range);
        responders_read_address_ready : in std_logic_vector(config_array'range);

        responders_read_data_ready : out std_logic_vector(config_array'range);
        responders_read_data_resp : in tgt_resp_t(config_array'range);
        responders_read_data_valid : in std_logic_vector(config_array'range);
        responders_read_data_data : in tgt_dat32_t(config_array'range)

    );
end entity;

architecture rtl of axil_interconnect_2k8 is

    constant default_idx : integer := config_array'length;
    -- We implement a catch-all responder that will respond with an error if no other responder does
    -- so this signal is one larger than the number of responders
    signal responder_sel : integer range 0 to config_array'length := default_idx;
    signal write_done : std_logic;
    signal read_done : std_logic;
    signal in_txn : boolean;

begin

    write_done <= '1' when initiator_write_response_valid = '1' and initiator_write_response_ready = '1' else
                 '0';
    read_done <= '1' when initiator_read_data_valid = '1' and initiator_read_data_ready = '1' else
                '0';

    -- we're going to stall all the transactions until we have decoded and selected a responder,
    -- flipped the muxes and then we can let the txn_through, and we keep the responder selected until
    -- the txn is done.
    -- There's a lot of combo logic here, we'll see how this goes.
    decode: process(clk, reset)
    begin
        if reset = '1' then
            responder_sel <= default_idx;
            in_txn <= false;
        elsif rising_edge(clk) then
            if initiator_write_address_valid = '1' then
                for i in 0 to config_array'length - 1 loop
                    if (initiator_write_address_addr >= config_array(i).base_addr) and
                       (initiator_write_address_addr < config_array(i).base_addr + 2**config_array(i).addr_span_bits) then
                        responder_sel <= i;
                    end if;
                end loop;
                in_txn <= true;
            elsif initiator_read_address_valid = '1' then
                for i in 0 to config_array'length - 1 loop
                    if (initiator_read_address_addr >= config_array(i).base_addr) and
                       (initiator_read_address_addr < config_array(i).base_addr + 2**config_array(i).addr_span_bits) then
                        responder_sel <= i;
                    end if;
                end loop;
                in_txn <= true;
            elsif write_done or read_done then
                responder_sel <= default_idx;
                in_txn <= false;
            end if;
        end if;
    end process;

    mux: process(all)
    begin
        -- default no transaction state for all responders
        for i in 0 to config_array'length - 1 loop
            responders_write_address_valid(i) <= '0';
            responders_write_address_addr(i) <= initiator_write_address_addr(responders_write_address_addr(i)'length - 1 downto 0);
            responders_write_data_valid(i) <= '0';
            responders_write_data_data(i) <= initiator_write_data_data;
            responders_write_data_strb(i) <= initiator_write_data_strb;
            responders_write_response_ready(i) <= '0';

            responders_read_address_valid(i) <= '0';
            responders_read_address_addr(i) <= initiator_read_address_addr(responders_read_address_addr(i)'length - 1 downto 0);
            responders_read_data_ready(i) <= '0';

        end loop;

        -- deal with in-txn muxing
        if in_txn and responder_sel < default_idx then
            -- responder mux
            responders_write_address_valid(responder_sel) <= initiator_write_address_valid;
            responders_write_address_addr(responder_sel) <= initiator_write_address_addr(responders_write_address_addr(responder_sel)'length - 1 downto 0);
            responders_write_data_valid(responder_sel) <= initiator_write_data_valid;
            responders_write_data_data(responder_sel) <= initiator_write_data_data;
            responders_write_data_strb(responder_sel) <= initiator_write_data_strb;
            responders_write_response_ready(responder_sel) <= initiator_write_response_ready;

            responders_read_address_valid(responder_sel) <= initiator_read_address_valid;
            responders_read_address_addr(responder_sel) <= initiator_read_address_addr(responders_read_address_addr(responder_sel)'length - 1 downto 0);
            responders_read_data_ready(responder_sel) <= initiator_read_data_ready;
            -- initiator mux
            initiator_write_address_ready <= responders_write_address_ready(responder_sel);
            initiator_write_data_ready <= responders_write_data_ready(responder_sel);
            initiator_write_response_resp <= responders_write_response_resp(responder_sel);
            initiator_write_response_valid <= responders_write_response_valid(responder_sel);
            initiator_read_address_ready <= responders_read_address_ready(responder_sel);
            initiator_read_data_resp <= responders_read_data_resp(responder_sel);
            initiator_read_data_valid <= responders_read_data_valid(responder_sel);
            initiator_read_data_data <= responders_read_data_data(responder_sel);

        elsif in_txn then
            -- default response to not hang bus
            initiator_write_address_ready <= '1';
            initiator_write_data_ready <= '1';
            initiator_write_response_resp <= SLVERR;
            initiator_write_response_valid <= '1';
            initiator_read_address_ready <= '1';
            initiator_read_data_resp <= SLVERR;
            initiator_read_data_valid <= '1';
            initiator_read_data_data <= X"DEADBEEF";

        else
            -- hold for decode
            -- default response to not hang bus
            initiator_write_address_ready <= '0';
            initiator_write_data_ready <= '0';
            initiator_write_response_resp <= SLVERR;
            initiator_write_response_valid <= '0';
            initiator_read_address_ready <= '0';
            initiator_read_data_resp <= SLVERR;
            initiator_read_data_valid <= '0';
            initiator_read_data_data <= (others => '0');
        end if;
    end process;
    
end rtl;