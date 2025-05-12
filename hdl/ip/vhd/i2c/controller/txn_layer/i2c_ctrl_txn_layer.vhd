-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- I2C Controller Transaction Layer
--
-- This block orchestrates the actions to complete a supplied I2C command (`cmd`).
--
-- Notes:
-- - For write transactions data is expected to be streamed in via `tx_st_if`
-- - For read transactions data is expected to be streamed in via `rx_st_if`
-- - A pulse of the `abort` signal will result in an I2C transaction being ended as fast as possible

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.axi_st8_pkg;
use work.tristate_if_pkg.all;

use work.i2c_common_pkg.all;

entity i2c_ctrl_txn_layer is
    generic (
        CLK_PER_NS  : positive;
        MODE        : mode_t;
    );
    port (
        clk         :   in  std_logic;
        reset       :   in  std_logic;

        -- Tri-state signals to I2C interface
        scl_if      : view tristate_if;
        sda_if      : view tristate_if;

        -- I2C command interface
        cmd         : in cmd_t;
        cmd_valid   : in std_logic;
        abort       : in std_logic;
        core_ready  : out std_logic;
        -- I2C status
        txn_status : out txn_status_t;

        -- Transmit data stream
        tx_st_if    : view axi_st8_pkg.axi_st_sink;

        -- Received data stream
        rx_st_if    : view axi_st8_pkg.axi_st_source;
    );
end entity;

architecture rtl of i2c_ctrl_txn_layer is

    type state_t is (
        IDLE,
        START,
        WAIT_START,
        WAIT_ADDR_ACK,
        READ,
        WRITE,
        WAIT_WRITE_ACK,
        STOP,
        WAIT_STOP
    );

    type sm_reg_t is record
        state           : state_t;
        cmd             : cmd_t;
        in_random_read  : boolean;
        cnts            : std_logic_vector(15 downto 0);
        bytes_done      : std_logic_vector(7 downto 0);
        do_start        : std_logic;
        do_ack          : std_logic;
        do_stop         : std_logic;
        tx_byte         : std_logic_vector(7 downto 0);
        tx_byte_valid   : std_logic;
        next_valid      : std_logic;
        txd             : std_logic_vector(7 downto 0);
        txd_valid       : std_logic;
        status          : txn_status_t;
    end record;

    constant SM_REG_RESET : sm_reg_t := (
        state => IDLE,
        cmd => CMD_RESET,
        in_random_read => false,
        cnts => (others => '0'),
        bytes_done => (others => '0'),
        do_start => '0',
        do_ack => '0',
        do_stop => '0',
        tx_byte => (others => '0'),
        tx_byte_valid => '0',
        next_valid => '0',
        txd => (others => '0'),
        txd_valid => '0',
        status => (SUCCESS, '0', '0')
    );

    signal sm_reg, sm_reg_next    : sm_reg_t;

    signal ll_ready         : std_logic;
    signal ll_ackd          : std_logic;
    signal ll_ackd_valid    : std_logic;
    signal ll_rx_data       : std_logic_vector(7 downto 0);
    signal ll_rx_data_valid : std_logic;
begin

    txn_status <= sm_reg.status;

    -- The block that handles the link layer of the protocol
    i2c_ctrl_link_layer_inst: entity work.i2c_ctrl_link_layer
     generic map(
        CLK_PER_NS  => CLK_PER_NS,
        MODE        => MODE
    )
     port map(
        clk             => clk,
        reset           => reset,
        scl_if          => scl_if,
        sda_if          => sda_if,
        tx_start        => sm_reg.do_start,
        tx_ack          => sm_reg.do_ack,
        tx_stop         => sm_reg.do_stop,
        txn_next_valid  => sm_reg.next_valid,
        ready           => ll_ready,
        tx_data         => sm_reg.tx_byte,
        tx_data_valid   => sm_reg.tx_byte_valid,
        tx_ackd         => ll_ackd,
        tx_ackd_valid   => ll_ackd_valid,
        rx_data         => ll_rx_data,
        rx_data_valid   => ll_rx_data_valid
    );

    reg_sm_next: process(all)
        variable v          : sm_reg_t;
        variable is_read    : std_logic;
    begin
        v           := sm_reg;
        is_read     := '1' when sm_reg.cmd.op = READ or sm_reg.in_random_read else '0';

        -- single cycle pulses
        v.next_valid    := '0';
        v.txd_valid     := '0';

        case sm_reg.state is

            -- watch for a new command to arrive then kick off a START
            when IDLE =>
                if cmd_valid = '1' and ll_ready = '1' and abort = '0' then
                    v.state     := START;
                    v.cmd       := cmd;
                    v.cnts      := (others => '0');
                    v.status    := (code => SUCCESS, code_valid => '0', busy => '1');
                end if;

            -- single cycle state to initiate a START
            when START =>
                v.state     := WAIT_START;

            -- wait for link layer to finish START sequence and load up the address byte
            when WAIT_START =>
                v.txd       := sm_reg.cmd.addr & is_read;
                v.txd_valid := '1';
                if ll_ready then
                    v.next_valid    := '1';
                    v.state         := WAIT_ADDR_ACK;
                end if;

            -- wait for address byte to have been sent and for the peripheral to ACK
            when WAIT_ADDR_ACK =>
                if ll_ready = '1' and ll_ackd_valid = '1' then
                    v.cnts := sm_reg.cnts + 1;
                    v.next_valid    := '1';
                    if ll_ackd then
                        v.bytes_done := (others => '0');
                        if sm_reg.cmd.op = Read or sm_reg.in_random_read then
                            v.state     := READ;
                            -- nack after the first byte when only reading one byte
                            v.do_ack    := '0' when sm_reg.cmd.len = 1 else '1';
                        else
                            v.state     := WAIT_WRITE_ACK;
                            -- load up the register address
                            v.txd       := sm_reg.cmd.reg;
                            v.txd_valid := '1';
                        end if;
                    else
                        v.status.code := NACK_BUS_ADDR;
                        v.state         := STOP;
                    end if;
                end if;

            -- read as many bytes as requested and ack them
            -- nacking and transitioning to STOP when done
            when READ =>
                v.next_valid    := ll_ready;

                if sm_reg.cmd.len = sm_reg.bytes_done and ll_ready = '1' then
                    v.state         := STOP;
                elsif ll_rx_data_valid then
                    v.bytes_done    := sm_reg.bytes_done + 1;
                    -- nack the next byte if it is the last
                    v.do_ack        := '0' when sm_reg.cmd.len = v.bytes_done else '1';
                end if;

            -- transmit the next byte
            when WRITE =>
                if tx_st_if.valid then
                    v.next_valid    := '1';
                    v.state         := WAIT_WRITE_ACK;
                end if;

            -- take action based off of the operation type and the ACK
            when WAIT_WRITE_ACK =>
                if ll_ackd_valid then
                    v.next_valid    := '1';
                    if ll_ackd then
                        v.bytes_done    := sm_reg.bytes_done + 1;

                        -- The register address was written, now go restart for a read
                        if sm_reg.cmd.op = RANDOM_READ then
                            v.state             := START;
                            v.in_random_read    := true;
                        elsif sm_reg.cmd.len = sm_reg.bytes_done then
                            v.state             := STOP;
                        else
                            v.state             := WRITE;
                        end if;
                    else
                        v.status.code := NACK_DURING_WRITE;
                        v.state         := STOP;
                    end if;
                end if;

            -- initiate a STOP and clear state
            when STOP =>
                v.state             := WAIT_STOP;
                v.bytes_done        := (others => '0');
                v.in_random_read    := false;

            -- once STOP has finished move back to IDLE
            when WAIT_STOP =>
                if ll_ready then
                    v.status    := (code =>  sm_reg.status.code, code_valid => '1', busy => '0');
                    v.state := IDLE;
                end if;
        end case;

        -- if a transaction is in progress and abort is asserted we should immediately STOP
        if abort = '1' and sm_reg.state /= IDLE and sm_reg.state /= STOP
                and sm_reg.state /= WAIT_STOP then
            v.state         := STOP;
            v.next_valid    := '1';
            v.status.code   := ABORTED;
        end if;

        -- next state logic
        v.do_start  := '1' when v.state = START else '0';
        v.do_stop   := '1' when v.state = STOP else '0';

        v.tx_byte       := v.txd when sm_reg.state = WAIT_START or sm_reg.state = WAIT_ADDR_ACK
                            else tx_st_if.data;
        -- Due to the way the link-layer works it decides whether it is transmitting or receiving
        -- based on the tx_byte_valid signal. Given that normal streaming sources expect to be able to
        -- assert valid any time data is available, we gate this from the link layer here since we
        -- know whether we're  tx'ing or rx'ing at this layer.  The ready below was already
        -- gated this way but the link-layer would start transmitting when it should have been rx'ing
        -- if this was set and not gated.
        -- I don't love this fix and it feels fragile but it works for now.
        v.tx_byte_valid := v.txd_valid when sm_reg.state = WAIT_START or sm_reg.state = WAIT_ADDR_ACK
                            else tx_st_if.valid when sm_reg.state = WRITE or sm_reg.state = WAIT_WRITE_ACK else '0';

        sm_reg_next <= v;
    end process;

    reg_sm: process(clk, reset)
    begin
        if reset then
            sm_reg <= SM_REG_RESET;
        elsif rising_edge(clk) then
            sm_reg <= sm_reg_next;
        end if;
    end process;

    core_ready      <= '1' when sm_reg.state = IDLE else '0';
    tx_st_if.ready  <= '1' when sm_reg.state = WRITE else '0';
    rx_st_if.valid  <= ll_rx_data_valid when sm_reg.state = READ else '0';
    rx_st_if.data   <= ll_rx_data;

end rtl;