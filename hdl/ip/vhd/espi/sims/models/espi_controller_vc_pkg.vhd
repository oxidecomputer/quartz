-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/

--! A verification component that acts as a qspi controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
use work.qspi_vc_pkg.all;
use work.espi_protocol_pkg.all;
use work.espi_tb_pkg.all;

package espi_controller_vc_pkg is

    constant tx_queue : queue_t := new_queue;
    constant rx_queue : queue_t := new_queue;


    procedure send_reset(
        signal net : inout network_t
    );
    
    procedure get_status(
        signal net : inout network_t;
        variable response_code : inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure get_config(
        signal net : inout network_t;
        constant address : in natural;
        variable data : inout std_logic_vector(31 downto 0);
        variable response_code : inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure set_config(
        signal net : inout network_t;
        constant address : in natural;
        constant data : in std_logic_vector(31 downto 0);
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure put_flash_read(
        signal net : inout network_t;
        constant address : in std_logic_vector(31 downto 0);
        constant num_bytes: in integer;
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure get_flash_c(
        signal net : inout network_t;
        constant num_bytes : in integer;
        variable data_queue: out queue_t;
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure put_iowr_short4(
        signal net : inout network_t;
        constant address : in std_logic_vector(15 downto 0);
        constant data : in std_logic_vector(31 downto 0);
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure get_any_pending_alert(
        signal net : inout network_t;
        variable alert : out boolean
    );

    procedure wait_for_alert(signal net : inout network_t);

    impure function get_status_from_queue_and_flush(
        queue: queue_t
    ) return std_logic_vector;

end package;

package body espi_controller_vc_pkg is

    impure function get_status_from_queue_and_flush(
        queue: queue_t
    ) return std_logic_vector is
        variable status : std_logic_vector(15 downto 0);
    begin
        -- Status comes LSB first
        status(7 downto 0) := To_Std_Logic_Vector(pop_byte(queue), 8);
        status(15 downto 8) := To_Std_Logic_Vector(pop_byte(queue), 8);
        --done, empty the queue (crc byte wasn't popped since we checked it above via queue copy)
        flush(queue);
        return status;
    end;

    procedure send_reset(
        signal net : inout network_t
    ) is
        variable msg_target : actor_t := find("espi_vc");
        variable cmd : cmd_t := (new_queue, 0);
    begin
        cmd := build_reset_cmd;
        enqueue_tx_data_bytes(net, msg_target,  cmd.num_bytes, cmd.queue);
        enqueue_transaction(net, msg_target, cmd.num_bytes, 0);
    end;

    procedure get_status(
        signal net : inout network_t;
        variable response_code : inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
        ) is

        variable cmd : cmd_t := (new_queue, 0);
        variable rx_bytes : integer   := 4;
        variable msg_target : actor_t := find("espi_vc");
        variable rx_queue : queue_t := new_queue;

    begin
        -- Build and send a GET STATUS message
        cmd := build_get_status_cmd;
        -- Turn around
        -- RESPONSE (no append) (1 byte)
        -- STATUS (2 bytes)
        -- CRC (1 byte)
        enqueue_tx_data_bytes(net, msg_target,  cmd.num_bytes, cmd.queue);
        enqueue_transaction(net, msg_target, cmd.num_bytes, rx_bytes);
        get_rx_queue(net, msg_target, rx_queue);
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        status := get_status_from_queue_and_flush(rx_queue);

    end;

    procedure get_config(
        signal net : inout network_t;
        constant address : in natural;
        variable data : inout std_logic_vector(31 downto 0);
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
            variable cmd : cmd_t := (new_queue, 0);
            variable rx_bytes : integer   := 8;
            variable msg_target : actor_t := find("espi_vc");
            variable rx_queue : queue_t := new_queue;
    begin
        -- Build and send a get config message
        cmd := build_get_config_cmd(address);
        enqueue_tx_data_bytes(net, msg_target,  cmd.num_bytes, cmd.queue);
        enqueue_transaction(net, msg_target, cmd.num_bytes, rx_bytes);
        get_rx_queue(net, msg_target, rx_queue);
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        -- Response comes in 4 bytes, LSB first
        for i in 0 to data'length / 8 - 1 loop
            data(7 + i*8 downto i*8) := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        end loop;
        status := get_status_from_queue_and_flush(rx_queue);

    end;

    procedure set_config(
        signal net : inout network_t;
        constant address : in natural;
        constant data : in std_logic_vector(31 downto 0);
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
            variable cmd : cmd_t := (new_queue, 0);
            variable rx_bytes : integer   := 4;  -- response, 16bit status, 1 crc
            variable msg_target : actor_t := find("espi_vc");
            variable rx_queue : queue_t := new_queue;
    begin
        -- Build and send a get config message
        cmd := build_set_config_cmd(address, data);
        -- send transaction
        enqueue_tx_data_bytes(net, msg_target,  cmd.num_bytes, cmd.queue);
        enqueue_transaction(net, msg_target, cmd.num_bytes, rx_bytes);
        get_rx_queue(net, msg_target, rx_queue);
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        status := get_status_from_queue_and_flush(rx_queue);
    end;
        

    procedure put_flash_read(
        signal net : inout network_t;
        constant address : in std_logic_vector(31 downto 0);
        constant num_bytes: in integer;
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
        variable cmd : cmd_t := (new_queue, 0);
        variable rx_bytes : integer   := 4;  -- response, 16bit status, 1 crc
        variable msg_target : actor_t := find("espi_vc");
        variable rx_queue : queue_t := new_queue;
    begin
        -- Build and send a flash read message
        cmd := build_put_flash_np_cmd(address, num_bytes);
        -- send transaction
        enqueue_tx_data_bytes(net, msg_target,  cmd.num_bytes, cmd.queue);
        enqueue_transaction(net, msg_target, cmd.num_bytes, rx_bytes);
        wait for 10 us;
        report "Here1";
        get_rx_queue(net, msg_target, rx_queue);
        report "Here";
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        status := get_status_from_queue_and_flush(rx_queue);
        
        
    end;

    procedure get_flash_c(
        signal net : inout network_t;
        constant num_bytes : in integer;
        variable data_queue: out queue_t;
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
        variable cmd : cmd_t := (new_queue, 0);
        variable rx_bytes : integer   := 3 + num_bytes + 4;  -- 3 bytes header, num_bytes, response, 16bit status, 1 crc, 
        variable msg_target : actor_t := find("espi_vc");
        variable rx_queue : queue_t := new_queue;
        variable dummy_data : std_logic_vector(7 downto 0);
    begin

        cmd := build_get_flash_c_cmd;
        -- Build and send a flash read message
        enqueue_tx_data_bytes(net, msg_target,  cmd.num_bytes, cmd.queue);
        enqueue_transaction(net, msg_target, cmd.num_bytes, rx_bytes);
        get_rx_queue(net, msg_target, rx_queue);
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        -- pop headers
        dummy_data := To_Std_Logic_Vector(pop_byte(rx_queue), 8);
        dummy_data := To_Std_Logic_Vector(pop_byte(rx_queue), 8);
        dummy_data := To_Std_Logic_Vector(pop_byte(rx_queue), 8);

        for i in 0 to num_bytes -1 loop
                push_byte(data_queue, pop_byte(rx_queue));
        end loop;
        status := get_status_from_queue_and_flush(rx_queue);
        
    end;

    procedure put_iowr_short4(
        signal net : inout network_t;
        constant address : in std_logic_vector(15 downto 0);
        constant data : in std_logic_vector(31 downto 0);
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
        variable cmd : cmd_t := (new_queue, 0);
        variable rx_bytes : integer   := 4;  -- response, 16bit status, 1 crc, 
        variable msg_target : actor_t := find("espi_vc");
        variable rx_queue : queue_t := new_queue;
    begin
        cmd := build_iowr_short(address, data);
        -- Build and send a flash read message
        enqueue_tx_data_bytes(net, msg_target,  cmd.num_bytes, cmd.queue);
        enqueue_transaction(net, msg_target, cmd.num_bytes, rx_bytes);
        get_rx_queue(net, msg_target, rx_queue);
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        status := get_status_from_queue_and_flush(rx_queue);
    end procedure;
    
    procedure get_any_pending_alert(
        signal net : inout network_t;
        variable alert : out boolean
    ) is
        variable msg_target : actor_t := find("espi_vc");
    begin
        has_pending_alert(net, msg_target, alert);
    end;

    procedure wait_for_alert(
        signal net : inout network_t
    ) is
        variable msg_target : actor_t := find("espi_vc");
        variable alert : boolean := false;
    begin
        loop
            has_pending_alert(net, msg_target, alert);
            exit when alert;
            wait for 100 ns;
        end loop;

    end;

end package body;