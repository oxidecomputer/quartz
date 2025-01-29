-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use vunit_lib.spi_pkg.all;

package spi_axi_tb_pkg is

    constant rd_logger       : logger_t    := get_logger("axi_rd");
    constant rmemory         : memory_t    := new_memory;
    constant axi_read_target : axi_slave_t := new_axi_slave(address_fifo_depth => 1,
                                                            memory => rmemory,
                                                            logger => rd_logger);

    constant wr_logger       : logger_t    := get_logger("axi_wr");
    constant wmemory          : memory_t    := new_memory;
    constant axi_write_target : axi_slave_t := new_axi_slave(address_fifo_depth => 1,
                                                             memory => wmemory,
                                                             logger => wr_logger);


    constant master_spi : spi_master_t := new_spi_master;
    constant master_wstream : stream_master_t := as_stream(master_spi);
    constant master_rstream : stream_slave_t := as_stream(master_spi);

    procedure spi_send_byte(
        signal net: inout network_t; 
        constant opcode: in std_logic_vector(3 downto 0);
        constant addr: in std_logic_vector(15 downto 0);
        constant byte: in std_logic_vector(7 downto 0);
        signal csn : out std_logic
    );

    procedure spi_send_stream(
        signal net: inout network_t; 
        constant opcode: in std_logic_vector(3 downto 0);
        constant addr: in std_logic_vector(15 downto 0);
        constant payload_queue: in queue_t;
        signal csn : out std_logic;
        constant cs_abort_after : in natural := 0
    );

end package;

package body spi_axi_tb_pkg is
    procedure spi_send_byte(
        signal net: inout network_t; 
        constant opcode: in std_logic_vector(3 downto 0);
        constant addr: in std_logic_vector(15 downto 0);
        constant byte: in std_logic_vector(7 downto 0);
        signal csn : out std_logic
    ) is
        alias addr_h : std_logic_vector(7 downto 0) is addr(15 downto 8);
        alias addr_l : std_logic_vector(7 downto 0) is addr(7 downto 0);
    begin
        csn <= '0';
        -- read opcode
        push_stream(net, master_wstream, resize(opcode, 8));
        -- addr h
        push_stream(net, master_wstream, addr_h);
        -- addr l
        push_stream(net, master_wstream, addr_l);
        -- data
        push_stream(net, master_wstream, byte);
        wait_until_idle(net, as_sync(master_spi));
        csn <= '1';
    end procedure;

    procedure spi_send_stream(
        signal net: inout network_t; 
        constant opcode: in std_logic_vector(3 downto 0);
        constant addr: in std_logic_vector(15 downto 0);
        constant payload_queue: in queue_t;
        signal csn : out std_logic;
        constant cs_abort_after : in natural := 0
    ) is
        alias addr_h : std_logic_vector(7 downto 0) is addr(15 downto 8);
        alias addr_l : std_logic_vector(7 downto 0) is addr(7 downto 0);
        variable byte_count : natural := 0;
    begin
        csn <= '0';
        -- read opcode
        push_stream(net, master_wstream, resize(opcode, 8));
        -- addr h
        push_stream(net, master_wstream, addr_h);
        -- addr l
        push_stream(net, master_wstream, addr_l);
        -- data
        while not is_empty(payload_queue) loop
            -- allow for early abort if requested
            if cs_abort_after > 0 and byte_count = cs_abort_after then
                flush(payload_queue);
                csn <= '1';
                exit;
            end if;
            -- otherwise send the next byte and count it
            push_stream(net, master_wstream, to_std_logic_vector(pop_byte(payload_queue), 8));
            byte_count := byte_count + 1;
        end loop;
        wait_until_idle(net, as_sync(master_spi));
        csn <= '1';
    end procedure;

end package body;