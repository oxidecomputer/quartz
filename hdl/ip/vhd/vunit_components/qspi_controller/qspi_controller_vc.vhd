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

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;
use work.qspi_vc_pkg.all;

entity qspi_controller_vc is
    generic (
        qspi_vc : qspi_vc_t
    );
    port (
        ss_n : out   std_logic_vector(7 downto 0) := (others => '1');
        sclk : out   std_logic                    := '0';
        io   : inout std_logic_vector(3 downto 0)
    );
end entity;

architecture model of qspi_controller_vc is

    signal sclk_enable : boolean              := false;
    signal clk_period  : time                 := 100 ns;
    signal mode        : qspi_mode_t          := SINGLE;
    signal tx_reg      : unsigned(7 downto 0) := (others => '0');
    signal rx_reg      : unsigned(8 downto 0) := (others => '0');

    type state_t is (idle, tx_phase, tar1, tar2, rx_phase);

    signal state     : state_t := idle;
    signal shift_amt : natural := 1;

    constant tx_byte_queue : queue_t := new_queue;
    constant rx_byte_queue : queue_t := new_queue;

    signal tx_shifter_busy : boolean              := false;
    signal txn_go          : boolean              := false;
    signal tx_bytes_txn    : natural              := 0;
    signal rx_bytes_txn    : natural              := 0;
    signal tx_rem_bytes    : natural              := 0;
    signal rx_rem_bytes    : natural              := 0;
    signal debug_rx_byte   : unsigned(7 downto 0) := (others => '0');
    signal alert_pending   : boolean              := false;
    signal sclk_cnts       : natural              := 0;

begin

    -- Generate a clock when enabled otherwise make it low
    sclk <= not sclk after clk_period / 2 when sclk_enable else '0';

    sclk_cntr: process(sclk, ss_n)
    begin
        if falling_edge(ss_n(0)) then
            sclk_cnts <= 0;
        elsif rising_edge(sclk) then
            sclk_cnts <= sclk_cnts + 1;
        end if;
    end process;


    messages: process
        variable msg_type               : msg_type_t;
        variable request_msg, reply_msg : msg_t;
        variable a_byte                 : unsigned(7 downto 0);
        variable int_byte               : integer;
        variable txn_tx_bytes           : natural;
        variable txn_rx_bytes           : natural;
    begin
        receive(net, qspi_vc.p_actor, request_msg);
        msg_type := message_type(request_msg);

        if msg_type = enqueue_txn then
            -- Assume we have any tx-bytes loaded already
            -- pop transaction
            txn_tx_bytes := pop(request_msg);
            tx_bytes_txn <= txn_tx_bytes;
            txn_rx_bytes := pop(request_msg);
            rx_bytes_txn <= txn_rx_bytes;
            txn_go <= true;
            wait until rising_edge(sclk);
            txn_go <= false;
        elsif msg_type = ensure_start then
            -- Ensure we're out of the idle state
            while state = idle loop
                wait on state;
            end loop;
            acknowledge(net, request_msg, true);
        elsif msg_type = enqueue_tx_bytes then
            txn_tx_bytes := pop(request_msg);
            if txn_tx_bytes > 0 then
                for i in 1 to txn_tx_bytes loop
                    a_byte := to_unsigned(pop(request_msg), a_byte'length);
                    push(tx_byte_queue, a_byte);
                end loop;
            end if;
        elsif msg_type = set_period then
            -- Control the sclk period via the api
            -- note that this takes effect immediately
            -- which may or may not be what is intended
            -- by the user!!!
            clk_period <= pop(request_msg);
        elsif msg_type = set_qspi_mode then
            mode <= decode(pop(request_msg));
        elsif msg_type = wait_until_idle_msg then
            -- Not idle while we're shifting
            while state /= idle loop
                wait on state;
            end loop;
            handle_wait_until_idle(net, msg_type, request_msg);
        elsif msg_type = get_rx_bytes then
            -- Finish the current transaction
            while state /= idle loop
                wait on state;
            end loop;
            reply_msg := new_msg;
            push(reply_msg, txn_rx_bytes);  -- size
            for i in 1 to txn_rx_bytes loop
                int_byte := pop_byte(rx_byte_queue);
                push(reply_msg, int_byte);
            end loop;
            assert is_empty(rx_byte_queue)
                report "rx_byte_queue not empty"
                severity failure;
            reply(net, request_msg, reply_msg);
        elsif msg_type = alert_status then
            reply_msg := new_msg;
            push(reply_msg, alert_pending);
            reply(net, request_msg, reply_msg);
        else
            unexpected_msg_type(msg_type);
        end if;
    end process;

    -- Monitor here, and clear after every transaction
    -- Alerts are represented by IO(1) going low when not
    -- chip selected and should be cleared after every transaction
    -- since the status is reported in each transaction
    alert_monitor: process(all)
    begin
        if ss_n(0) = '1' and io(1) = '0' then
            alert_pending <= true;
        elsif state = rx_phase and rx_rem_bytes = 0 then
            alert_pending <= false;
        end if;
    end process;

    transaction_sm: process
    begin
        wait on txn_go;
        -- assert cs
        ss_n(0) <= '0';
        wait for 100 ns;
        -- enable the sclk
        sclk_enable <= true;
        -- put data in tx_queue (if any)
        state <= tx_phase;
        -- finish transmit phase
        wait until tx_rem_bytes = 0;
        if rx_bytes_txn /= 0 then
            -- do the 2 cycle turn-around
            state <= tar1;
            wait until falling_edge(sclk);
            state <= tar2;
            wait until falling_edge(sclk);
            -- finish the rx phase
            state <= rx_phase;
            wait until rx_rem_bytes = 0;
            wait until falling_edge(sclk);
        end if;
        sclk_enable <= false;
        wait for 100 ns;
        -- de-assert cs
        ss_n(0) <= '1';
        wait for clk_period;
        state <= idle;
    end process;

    tx_shifter: process
        variable tx_bytes_remaining : natural := 0;
        variable tx_bit_count       : natural := 0;
    begin
        -- get byte from tx_queue
        if state /= tx_phase then
            tx_reg          <= (others => '0');
            tx_bit_count    := 0;
            tx_shifter_busy <= false;
        else
            tx_bytes_remaining := tx_bytes_txn;
            tx_rem_bytes <= tx_bytes_remaining;
            while tx_bytes_remaining > 0 loop
                if tx_bit_count = 0 then
                    tx_shifter_busy <= true;
                    tx_reg          <= pop(tx_byte_queue);
                    tx_bit_count    := 8;
                end if;
                while tx_bit_count > 0 loop
                    wait until falling_edge(sclk);
                    tx_reg       <= shift_left(tx_reg, shift_amt);
                    tx_bit_count := tx_bit_count - shift_amt;
                end loop;
                tx_rem_bytes <= tx_bytes_remaining - 1;
                tx_bytes_remaining := tx_bytes_remaining - 1;
            end loop;
        end if;
        wait on state;
    end process;

    rx_shifter: process
        variable rx_nxt : unsigned(8 downto 0);
    begin
        if state /= rx_phase then
            rx_reg          <= (0 => '1', others => '0');
            rx_rem_bytes <= rx_bytes_txn;
        else
            -- we use the variable rx_bytes_remaining for
            -- process-local flow control where we want instant
            -- changes to be reflected but some other processes
            -- want to follow things also so we also provide signal
            -- version of rx_rem_byes for inter-process communication
            while rx_rem_bytes > 0 loop
                wait until rising_edge(sclk);
                rx_nxt := rx_reg;
                rx_nxt       := shift_left(rx_nxt, shift_amt);
                if mode = SINGLE then
                    rx_nxt(0)    := io(1);
                elsif mode = DUAL then
                    rx_nxt(0)    := io(0);
                    rx_nxt(1)    := io(1);
                elsif mode = QUAD then
                    rx_nxt(0) := io(0);
                    rx_nxt(1) := io(1);
                    rx_nxt(2) := io(2);
                    rx_nxt(3) := io(3);
                end if;
                if rx_nxt(rx_nxt'left) = '1' then
                    push_byte(rx_byte_queue, to_integer(rx_nxt(7 downto 0)));
                    -- open tooling doesn't have a great way to see variable state changes
                    -- so I'm leaving this signal here for trace visibility even though it's
                    -- not used in the design
                    debug_rx_byte <= rx_nxt(7 downto 0);
                    rx_rem_bytes <= rx_rem_bytes - 1;
                    rx_nxt       := (0 => '1', others => '0');
                end if;
                rx_reg <= rx_nxt;
            end loop;
        end if;
        wait on state;
    end process;

    shift_amt <= 1 when mode = SINGLE else
                 2 when mode = DUAL else
                 4 when mode = QUAD;

    io(0) <= tx_reg(7) when (mode = SINGLE) and state = tx_phase else
             tx_reg(6) when (mode = DUAL) and state = tx_phase else
             tx_reg(4) when (mode = QUAD) and state = tx_phase else
             '1' when state = tar1 else
             'Z';
    io(1) <= tx_reg(7) when (mode = DUAL) and state = tx_phase else
             tx_reg(5) when (mode = QUAD) and state = tx_phase else
             '1' when state = tar1 else
             'Z';
    io(2) <= tx_reg(6) when (mode = QUAD) and state = tx_phase else
             '1' when state = tar1 else
             'Z';
    io(3) <= tx_reg(7) when (mode = QUAD) and state = tx_phase else
             '1' when state = tar1 else
             'Z';

end model;
