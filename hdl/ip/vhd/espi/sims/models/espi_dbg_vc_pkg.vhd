-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_regs_pkg.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.espi_regs_pkg.all;
use work.espi_tb_pkg.all;

package espi_dbg_vc_pkg is

    type byte_ar_t is array (0 to 2) of std_logic_vector(7 downto 0);

    procedure enable_debug_mode(
        signal net : inout network_t
    );
    procedure cmd_fifo_reset(
        signal net : inout network_t
    );
    procedure cmd_size_fifo_reset(
        signal net : inout network_t
    );
    procedure resp_fifo_reset(
        signal net : inout network_t
    );
    procedure all_fifo_reset(
        signal net : inout network_t
    );
    procedure dbg_send_cmd(
        signal net : inout network_t;
        cmd : cmd_t
    );
    procedure dbg_send_get_status_cmd(
        signal net : inout network_t;
        constant bad_crc : boolean := false
    );
    procedure dbg_get_response(
        signal net : inout network_t;
        constant expected_resp_bytes : integer;
        variable resp  : inout resp_t
    );
    procedure dbg_get_response_size(
        signal net : inout network_t;
        variable size  : inout integer
    );
    procedure dbg_send_uart_msg_w_data_cmd(
        signal net : inout network_t;
        payload : queue_t
    );
    procedure dbg_send_uart_oob_no_pec_cmd(
        signal net : inout network_t;
        payload : queue_t
    );

    procedure dbg_get_uart_msg_w_data_cmd(
        signal net : inout network_t;
    );
    procedure dbg_get_uart_oob_no_pec_cmd(
        signal net : inout network_t;
    );

    procedure dbg_pop_resp_fifo(
        signal net : inout network_t;
        constant num_reads : natural
    );
    procedure dbg_wait_for_start(
        signal net : inout network_t
    );
    procedure dbg_wait_for_done(
        signal net : inout network_t
    );
    procedure dbg_wait_for_alert(
        signal net : inout network_t
    );

end package;

package body espi_dbg_vc_pkg is

    procedure enable_debug_mode(
        signal net : inout network_t
    ) is
        variable readdata : std_logic_vector(31 downto 0) := (others => '0');
        variable control_reg : control_type := rec_reset;
    begin
        read_bus(net, bus_handle, To_StdLogicVector(RESP_FIFO_RDATA_OFFSET, bus_handle.p_address_length), readdata);
        control_reg.dbg_mode_en := '1';
        write_bus(net, bus_handle, To_StdLogicVector(CONTROL_OFFSET, bus_handle.p_address_length), pack(control_reg) or readdata);
    end procedure;

    procedure cmd_fifo_reset(
        signal net : inout network_t
    ) is
        variable control_reg : control_type := rec_reset;
    begin
        control_reg.cmd_fifo_reset := '1';
        write_bus(net, bus_handle, To_StdLogicVector(CONTROL_OFFSET, bus_handle.p_address_length), pack(control_reg));
    end procedure;

    procedure cmd_size_fifo_reset(
        signal net : inout network_t
    ) is
        variable control_reg : control_type := rec_reset;
    begin
        control_reg.cmd_size_fifo_reset := '1';
        write_bus(net, bus_handle, To_StdLogicVector(CONTROL_OFFSET, bus_handle.p_address_length), pack(control_reg));
    end procedure;

    procedure resp_fifo_reset(
        signal net : inout network_t
    )is
        variable control_reg : control_type := rec_reset;
    begin
        control_reg.resp_fifo_reset := '1';
        write_bus(net, bus_handle, To_StdLogicVector(CONTROL_OFFSET, bus_handle.p_address_length), pack(control_reg));
    end procedure;

    procedure all_fifo_reset(
        signal net : inout network_t
    ) is
        variable control_reg : control_type := rec_reset;
    begin
        control_reg.cmd_fifo_reset := '1';
        control_reg.cmd_size_fifo_reset := '1';
        control_reg.resp_fifo_reset := '1';
        write_bus(net, bus_handle, To_StdLogicVector(CONTROL_OFFSET, bus_handle.p_address_length), pack(control_reg));
    end procedure;

    procedure dbg_send_cmd(
        signal net : inout network_t;
        cmd : cmd_t
    ) is
        variable data : std_logic_vector(31 downto 0) := (others => '0');
        variable rem_bytes : integer := cmd.num_bytes;
        variable byte_idx : integer range 0 to 4 := 0;
    begin
        loop

            data(7 + byte_idx * 8 downto byte_idx * 8) := To_Std_Logic_Vector(pop_byte(cmd.queue), 8);
            rem_bytes := rem_bytes - 1;
            byte_idx := byte_idx + 1;
            if byte_idx = 4 and rem_bytes > 0 then
                write_bus(net, bus_handle, To_StdLogicVector(CMD_FIFO_WDATA_OFFSET, bus_handle.p_address_length), data);
                data := (others => '0');
                byte_idx := 0;
            elsif byte_idx = 4 or rem_bytes = 0 then -- last byte so push what we have
                write_bus(net, bus_handle, To_StdLogicVector(CMD_FIFO_WDATA_OFFSET, bus_handle.p_address_length), data);
                write_bus(net, bus_handle, To_StdLogicVector(CMD_SIZE_FIFO_WDATA_OFFSET, bus_handle.p_address_length),  To_StdLogicVector(cmd.num_bytes, 32)); -- push a second time to trigger the command
                exit;
            end if;
        end loop;

    end procedure;

    procedure dbg_send_get_status_cmd(
        signal net : inout network_t;
        constant bad_crc : boolean := false
    ) is
        variable cmd : cmd_t := build_get_status_cmd(bad_crc);
    begin
        dbg_send_cmd(net, cmd);
    end procedure;


    procedure dbg_get_response(
        signal net : inout network_t;
        constant expected_resp_bytes : integer;
        variable resp  : inout resp_t
        
    ) is
        variable rem_bytes : integer := expected_resp_bytes;
        variable readdata : std_logic_vector(31 downto 0) := (others => '0');
        variable response : std_logic_vector(7 downto 0) := (others => 'X');
        variable last_3_bytes : byte_ar_t := (others => (others => '0'));
    begin
        -- this is being passed in, we don't know what is or isn't in it so clear it out
        flush(resp.queue);
        outer: loop
            read_bus(net, bus_handle, To_StdLogicVector(RESP_FIFO_RDATA_OFFSET, bus_handle.p_address_length), readdata);
            -- loop over the up-to 4 bytes, exit early
            inner: for i in 0 to 3 loop
                last_3_bytes(1 to 2) := last_3_bytes(0 to 1);
                last_3_bytes(0) := readdata(7 + 8*i downto 8*i);
                if is_X(response) then
                    response := last_3_bytes(0);
                end if;
                push_byte(resp.queue, to_integer(readdata(7 + 8*i downto 8*i)));
                rem_bytes := rem_bytes - 1;
                exit outer when rem_bytes = 0;
            end loop;
        end loop;
        resp.num_bytes := expected_resp_bytes;
        resp.crc_ok := check_queue_crc(resp.queue); -- non-destructive to queue
        resp.response_code := response;
        -- Status comes LSB first, so older is lower.  very last byte is crc
        resp.status := last_3_bytes(1) & last_3_bytes(2);
    end procedure;

    procedure dbg_get_response_size(
        signal net : inout network_t;
        variable size  : inout integer
    ) is
        variable readdata : std_logic_vector(31 downto 0) := (others => '0');
        variable fifo_status : fifo_status_type := rec_reset;
    begin
        read_bus(net, bus_handle, To_StdLogicVector(FIFO_STATUS_OFFSET, bus_handle.p_address_length), readdata);
        fifo_status := unpack(readdata);
        size := to_integer(fifo_status.resp_used_wds);
    end procedure;

    procedure dbg_send_uart_msg_w_data_cmd(
        signal net : inout network_t;
        payload : queue_t
    ) is
        variable cmd : cmd_t := build_put_msg_w_data_cmd(payload);
    begin
        dbg_send_cmd(net, cmd);
    end procedure;

    procedure dbg_get_uart_msg_w_data_cmd(
        signal net : inout network_t;
    ) is
        variable cmd : cmd_t := build_get_msg_w_data_cmd;
    begin
        dbg_send_cmd(net, cmd);
    end procedure;

    procedure dbg_send_uart_oob_no_pec_cmd(
        signal net : inout network_t;
        payload : queue_t
    ) is
        variable cmd : cmd_t := build_put_oob_no_pec_cmd(payload);
    begin
        dbg_send_cmd(net, cmd);
    end procedure;

    procedure dbg_get_uart_oob_no_pec_cmd(
        signal net : inout network_t;
    ) is
        variable cmd : cmd_t := build_get_oob_no_pec_cmd;
    begin
        dbg_send_cmd(net, cmd);
    end procedure;

    procedure dbg_pop_resp_fifo(
        signal net : inout network_t;
        constant num_reads : natural
    ) is
        variable readdata: std_logic_vector(31 downto 0) := (others => '0');
    begin
        for i in 0 to num_reads - 1 loop
            read_bus(net, bus_handle, To_StdLogicVector(RESP_FIFO_RDATA_OFFSET, bus_handle.p_address_length), readdata);
        end loop;
    end procedure;

    procedure dbg_wait_for_start(
        signal net : inout network_t
    ) is
        variable readdata : std_logic_vector(31 downto 0) := (others => '0');
        variable status_reg : status_type := rec_reset;
    begin
        loop
            read_bus(net, bus_handle, To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length), readdata);
            status_reg := unpack(readdata);
            exit when status_reg.busy = '1';
        end loop;
    end procedure;

    procedure dbg_wait_for_done(
        signal net : inout network_t
    ) is
        variable readdata : std_logic_vector(31 downto 0) := (others => '0');
        variable status_reg : status_type := rec_reset;
    begin
        -- We want to call this immediately after sending a command but it's possible nothing has
        -- started yet so if we're not running already we wait for the system to start, and then wait for
        -- it to finish.
        dbg_wait_for_start(net);
        loop
            read_bus(net, bus_handle, To_StdLogicVector(STATUS_OFFSET, bus_handle.p_address_length), readdata);
            status_reg := unpack(readdata);
            exit when status_reg.busy = '0';
        end loop;
    end procedure;

    procedure dbg_wait_for_alert(
        signal net : inout network_t
    ) is
        variable readdata : std_logic_vector(31 downto 0) := (others => '0');
        variable flags_reg : flags_type := rec_reset;
    begin
        loop
            read_bus(net, bus_handle, To_StdLogicVector(FLAGS_OFFSET, bus_handle.p_address_length), readdata);
            flags_reg := unpack(readdata);
            exit when flags_reg.alert = '1';
        end loop;
    end procedure;


end package body;