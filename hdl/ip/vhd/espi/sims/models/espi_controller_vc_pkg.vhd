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

package espi_controller_vc_pkg is

    constant tx_queue : queue_t := new_queue;
    constant rx_queue : queue_t := new_queue;

    impure function crc8 (
        data: queue_t
    ) return std_logic_vector;

    procedure get_status(
        variable response_code : inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure get_config(
        constant address : in natural;
        variable data : inout std_logic_vector(31 downto 0);
        variable response_code : inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure set_config(
        constant address : in natural;
        constant data : in std_logic_vector(31 downto 0);
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure put_flash_read(
        constant address : in std_logic_vector(31 downto 0);
        constant num_bytes: in integer;
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure get_flash_c(
        constant num_bytes : in integer;
        variable data_queue: out queue_t;
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    );

    procedure get_any_pending_alert(
        variable alert : out boolean
    );

    procedure wait_for_alert;

    impure function get_status_from_queue_and_flush(
        queue: queue_t;
    ) return std_logic_vector;

    

    impure function check_queue_crc (
        data: queue_t
    ) return boolean;

    -- function lsb_to_msb(
    --     data: std_logic_vector
    -- ) return std_logic_vector;
end package;

package body espi_controller_vc_pkg is

    -- The non-parallel version of the crc from the datasheet
    -- used to check our parallel hw implementation with a "known-good"
    -- and alternately implemented algo.
    impure function crc8 (
        data: queue_t
    ) return std_logic_vector is

        -- create a copy so we don't destry the queue here
        constant  crc_queue : queue_t                  := copy(data);
        variable d : std_logic_vector(7 downto 0)      := (others => '0');
        variable next_q : std_logic_vector(7 downto 0) := (others => '0');
        variable last_q : std_logic_vector(7 downto 0) := (others => '0');

    begin
        while not is_empty(crc_queue) loop
            d := To_StdLogicVector(pop_byte(crc_queue), 8);
            for i in 0 to 7 loop
                next_q(0) := last_q(7) xor d(7);
                next_q(1) := last_q(7) xor d(7) xor last_q(0);
                next_q(2) := last_q(7) xor d(7) xor last_q(1);
                next_q(7 downto 3) := last_q(6 downto 2);
                last_q := next_q;
                d := shift_left(d, 1);
            end loop;
        end loop;
        return last_q;
    end;

    impure function get_status_from_queue_and_flush(
        queue: queue_t;
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

    procedure get_status(
        variable response_code : inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean;
        ) is

        variable tx_bytes : integer   := 2;
        variable rx_bytes : integer   := 4;
        variable msg_target : actor_t := find("espi_vc");
        variable rx_queue : queue_t := new_queue;

    begin
        -- Build and send a GET STATUS message
        -- OPCODE_GET_STATUS  (1 byte)
        push_byte(tx_queue, to_integer(OPCODE_GET_STATUS));
        -- CRC (1 byte)
        push_byte(tx_queue, to_integer(crc8(tx_queue)));
        -- Turn around
        -- RESPONSE (no append) (1 byte)
        -- STATUS (2 bytes)
        -- CRC (1 byte)
        enqueue_tx_data_bytes(net, msg_target,  tx_bytes, tx_queue);
        enqueue_transaction(net, msg_target, tx_bytes, rx_bytes);
        get_rx_queue(net, msg_target, rx_queue);
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        status := get_status_from_queue_and_flush(rx_queue);

    end;

    procedure get_config(
        constant address : in natural;
        variable data : inout std_logic_vector(31 downto 0);
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
    
            variable tmp_address : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(address, 16));
            variable tx_bytes : integer   := 4;
            variable rx_bytes : integer   := 8;
            variable msg_target : actor_t := find("espi_vc");
            variable rx_queue : queue_t := new_queue;
    begin
        -- Build and send a get config message
        -- OPCODE_GET_CONFIG (1 byte)
        push_byte(tx_queue, to_integer(opcode_get_configuration));
        -- ADDRESS (2 bytes), MSB 1st
        push_byte(tx_queue, to_integer(tmp_address(15 downto 8)));
        push_byte(tx_queue, to_integer(tmp_address(7 downto 0)));
        -- CRC (1 byte)
        push_byte(tx_queue, to_integer(crc8(tx_queue)));
        -- send transaction
        enqueue_tx_data_bytes(net, msg_target,  tx_bytes, tx_queue);
        enqueue_transaction(net, msg_target, tx_bytes, rx_bytes);
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
        constant address : in natural;
        constant data : in std_logic_vector(31 downto 0);
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
    
            variable tmp_address : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(address, 16));
            variable tx_bytes : integer   := 8;  -- 1 opcode, 2 address, 4 data, 1 crc
            variable rx_bytes : integer   := 4;  -- response, 16bit status, 1 crc
            variable msg_target : actor_t := find("espi_vc");
            variable rx_queue : queue_t := new_queue;
    begin
        -- Build and send a get config message
        -- OPCODE_SET_CONFIG (1 byte)
        push_byte(tx_queue, to_integer(opcode_set_configuration));
        -- ADDRESS (2 bytes), MSB 1st
        push_byte(tx_queue, to_integer(tmp_address(15 downto 8)));
        push_byte(tx_queue, to_integer(tmp_address(7 downto 0)));
        -- DATA (4 bytes), LSB 1st
        push_byte(tx_queue, to_integer(data(7 downto 0)));
        push_byte(tx_queue, to_integer(data(15 downto 8)));
        push_byte(tx_queue, to_integer(data(23 downto 16)));
        push_byte(tx_queue, to_integer(data(31 downto 24)));
        -- CRC (1 byte)
        push_byte(tx_queue, to_integer(crc8(tx_queue)));
        -- send transaction
        enqueue_tx_data_bytes(net, msg_target,  tx_bytes, tx_queue);
        enqueue_transaction(net, msg_target, tx_bytes, rx_bytes);
        get_rx_queue(net, msg_target, rx_queue);
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        status := get_status_from_queue_and_flush(rx_queue);
    end;
        

    procedure put_flash_read(
        constant address : in std_logic_vector(31 downto 0);
        constant num_bytes: in integer;
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
        variable payload_len : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(num_bytes, 12));
        variable tx_bytes : integer   := 9;  -- 1 opcode, 7 hdr, 1 crc
        variable rx_bytes : integer   := 4;  -- response, 16bit status, 1 crc
        variable msg_target : actor_t := find("espi_vc");
        variable rx_queue : queue_t := new_queue;
    begin
        -- Build and send a flash read message
        -- OPCODE_PUT_FLASH_NP (1 byte)
        push_byte(tx_queue, to_integer(opcode_put_flash_np));
        -- cycle type (1 byte)
        push_byte(tx_queue, to_integer(flash_read));
        -- tag/length high
        push_byte(tx_queue, to_integer("0000" & payload_len(11 downto 8)));
        -- length low
        push_byte(tx_queue, to_integer(payload_len(7 downto 0)));
        -- ADDRESS (4 bytes), MSB 1st
        push_byte(tx_queue, to_integer(address(31 downto 24)));
        push_byte(tx_queue, to_integer(address(23 downto 16)));
        push_byte(tx_queue, to_integer(address(15 downto 8)));
        push_byte(tx_queue, to_integer(address(7 downto 0)));
        -- CRC (1 byte)
        push_byte(tx_queue, to_integer(crc8(tx_queue)));
        -- send transaction
        enqueue_tx_data_bytes(net, msg_target,  tx_bytes, tx_queue);
        enqueue_transaction(net, msg_target, tx_bytes, rx_bytes);
        get_rx_queue(net, msg_target, rx_queue);
        crc_ok := check_queue_crc(rx_queue); -- non-destructive to queue
        response_code := std_logic_vector(to_unsigned(pop_byte(rx_queue), 8));
        status := get_status_from_queue_and_flush(rx_queue);
        
    end;

    procedure get_flash_c(
        constant num_bytes : in integer;
        variable data_queue: out queue_t;
        variable response_code: inout std_logic_vector(7 downto 0);
        variable status : inout std_logic_vector(15 downto 0);
        variable crc_ok : inout boolean
    ) is
        variable dummy_data : std_logic_vector(7 downto 0) := (others => '0');
        variable tx_bytes : integer   := 2;  -- 1 opcode, 1 crc
        variable rx_bytes : integer   := 4 + num_bytes + 3;  -- response, 16bit status, 1 crc, num_bytes, 3 bytes header
        variable msg_target : actor_t := find("espi_vc");
        variable rx_queue : queue_t := new_queue;
    begin
        -- Build and send a flash read message
        -- OPCODE_GET_FLASH_C(1 byte)
        push_byte(tx_queue, to_integer(opcode_get_flash_c));
        -- CRC (1 byte)
        push_byte(tx_queue, to_integer(crc8(tx_queue)));
        -- send transaction
        enqueue_tx_data_bytes(net, msg_target,  tx_bytes, tx_queue);
        enqueue_transaction(net, msg_target, tx_bytes, rx_bytes);
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
    
    procedure get_any_pending_alert(
        variable alert : out boolean
    ) is
        variable msg_target : actor_t := find("espi_vc");
    begin
        has_pending_alert(net, msg_target, alert);
    end;

    procedure wait_for_alert is
        variable msg_target : actor_t := find("espi_vc");
        variable alert : boolean := false;
    begin
        loop
            has_pending_alert(net, msg_target, alert);
            exit when alert;
            wait for 100 ns;
        end loop;

    end;


    impure function check_queue_crc (
        data: queue_t
    ) return boolean is
        -- create a copy so we don't destry the queue here
        constant  copy_queue : queue_t                  := copy(data);
        constant crc_queue: queue_t                  := new_queue;
        variable cur_byte : std_logic_vector(7 downto 0);
        variable crc_byte : std_logic_vector(7 downto 0);
    begin
        while true loop
            cur_byte := To_StdLogicVector(pop_byte(copy_queue), 8);
            report "Data Byte: " & to_hstring(cur_byte);
            -- Last element in queue is the CRC
            if is_empty(copy_queue) then
                crc_byte := crc8(crc_queue);
                report "CRC Byte: " & to_hstring(crc_byte);
                return crc_byte = cur_byte;
            else
                push_byte(crc_queue, to_integer(cur_byte));
            end if;
        end loop;
    end;

end package body;