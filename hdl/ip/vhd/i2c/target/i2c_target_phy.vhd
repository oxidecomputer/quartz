-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- This block provides an i2c-compliant "phy" for use with additional logic
-- to create i2c target functions. It is intended to be generic and shareable
-- across multiple target functions, with the target function logic being
-- implemented in other modules.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.i2c_base_types_pkg.all;

entity i2c_target_phy is 
    generic(
        giltch_filter_cycles : integer := 5
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        scl : in std_logic;
        scl_o : out std_logic;
        scl_oe : out std_logic;
        sda : in std_logic;
        sda_o : out std_logic;
        sda_oe : out std_logic;
        -- instruction interface
        inst_data : out std_logic_vector(7 downto 0);
        inst_valid : out std_logic;
        inst_ready : in std_logic;
        in_ack_phase: out std_logic;
        do_ack : in std_logic;
        txn_header : out i2c_header;
        stop_condition : out std_logic;
        start_condition : out std_logic;

        -- response interface
        resp_data : in std_logic_vector(7 downto 0);
        resp_valid : in std_logic;
        resp_ready : out std_logic

    );
end entity i2c_target_phy;

architecture rtl of i2c_target_phy is
    type state_type is (IDLE, TARGET_ADDR, RX_DATA, TX_DATA, SEND_ACK_NACK, GET_ACKNACK);

    type reg_type is record
        state : state_type;
        post_ack_nxt_state : state_type;
        cntr: std_logic_vector(15 downto 0);
        txn_hdr: i2c_header;
        rx_reg : std_logic_vector(7 downto 0);
        tx_reg : std_logic_vector(7 downto 0);
        tx_ready: std_logic;
        inst_data_buf : std_logic_vector(7 downto 0);
        inst_data_valid : std_logic;
        start_seen : std_logic;
        selected : std_logic;
        got_ack : std_logic;
        got_nack : std_logic;
    end record;
    constant rec_reset : reg_type := (
        IDLE, 
        IDLE, 
        (others => '0'), 
        ((others => '0'), '0', '0'), 
        (others => '0'), 
        (others => '0'), 
        '0', 
        (others => '0'), 
        '0', 
        '0', 
        '0',
        '0',
        '0'
    );

    constant BYTE_DONE : integer := 8;

    signal sda_redge : std_logic;
    signal sda_fedge : std_logic;
    signal scl_fedge : std_logic;
    signal scl_redge : std_logic;
    signal filtered_scl : std_logic;
    signal filtered_sda : std_logic;

    signal r, rin : reg_type;

begin

    -- wire up the outputs
    inst_data <= r.inst_data_buf;
    inst_valid <= r.inst_data_valid;
    txn_header <= r.txn_hdr;

    scl_o <= '0';  -- Only pull bus low, enable will control tristate
    scl_oe <= '0'; -- no clock stretching

    sda_o <= '0';  -- Only pull bus low, enable will control tristate
    -- enable becomes bit inversion of msb of tx reg when we're transmitting
    -- or acking
    sda_oe <= '1' when (r.state = TX_DATA or r.state = SEND_ACK_NACK) and r.tx_reg(r.tx_reg'high) = '0' and r.selected = '1' else '0';
    i2c_glitch_filter_inst: entity work.i2c_glitch_filter
     generic map(
        filter_cycles => giltch_filter_cycles
    )
     port map(
        clk => clk,
        reset => reset,
        raw_scl => scl,
        raw_sda => sda,
        filtered_scl => filtered_scl,
        scl_redge => scl_redge,
        scl_fedge => scl_fedge,
        filtered_sda => filtered_sda,
        sda_redge => sda_redge,
        sda_fedge => sda_fedge
    );

    -- Start condition is when SDA goes low while SCL is high
    start_condition <= filtered_scl and sda_fedge;
    -- Stop condition is when SDA goes high while SCL is high
    stop_condition <= filtered_scl and sda_redge;

    in_ack_phase <= '1' when r.state = SEND_ACK_NACK and filtered_scl = '0' else '0';

    resp_ready <= r.tx_ready;


    -- We can only change sda state when scl is low as a target
    -- so generally all of our state transitions should be on, or shortly
    -- following the falling edge of scl
    sm: process(all)
        variable v : reg_type;
    begin
        v := r;

        case r.state is
            when IDLE =>
                v.rx_reg := (others => '0');
                v.tx_reg := (others => '0');
                v.txn_hdr.valid := '0';
                v.cntr := (others => '0');
                if r.start_seen = '1' and scl_fedge = '1' then
                    v.state := TARGET_ADDR;
                    v.start_seen := '0';
                end if;
            when TARGET_ADDR | RX_DATA =>
                -- shift in 8 bits
                if scl_redge = '1' and r.cntr <= BYTE_DONE then
                    v.rx_reg := shift_left(r.rx_reg, 1);
                    v.rx_reg(0) := filtered_sda;
                    v.cntr := r.cntr + 1;
                end if;

                -- deal with finished byte, either data or target addr
                if r.cntr = BYTE_DONE and scl_fedge = '1' then
                    v.state := SEND_ACK_NACK;  -- need to ack or nack
                    v.cntr := (others => '0');
                    if r.state = TARGET_ADDR then
                        v.txn_hdr.tgt_addr := r.rx_reg(7 downto 1);
                        v.txn_hdr.read_write_n := r.rx_reg(0);
                        v.txn_hdr.valid := '1';
                    else
                        v.inst_data_buf := r.rx_reg;
                        v.inst_data_valid := '1';
                        
                    end if;
                    -- decide what the post-ack/nack state is
                    -- this uses the combo signals so it is valid before
                    -- the registers are updated
                    if v.txn_hdr.valid = '1' and v.txn_hdr.read_write_n = '1' then
                        v.post_ack_nxt_state := TX_DATA;
                    else
                        v.post_ack_nxt_state := RX_DATA;
                    end if;
                end if;
                
            when TX_DATA =>
                -- wait for 8 bits to be shifted out
                -- we're coming in here on an sclk low
                if r.cntr = 0 and resp_valid = '1' and resp_ready = '1' then
                    v.tx_reg := resp_data;
                    v.tx_ready := '0';
                end if;
                if scl_fedge then
                    v.tx_reg := shift_left(r.tx_reg, 1);
                    v.cntr := r.cntr + 1;
                end if;
                -- deal with stop or ack/nack 
                if r.cntr = BYTE_DONE then
                    v.tx_reg := shift_left(r.tx_reg, 1);
                    -- ack if upstream allows, else nack
                    v.state := GET_ACKNACK;
                end if;

            when SEND_ACK_NACK =>
                if do_ack and in_ack_phase then
                    v.tx_reg := (others => '0');
                    v.selected := '1';
                elsif in_ack_phase then
                    v.tx_reg := (others => '1');  --NACK
                end if;
                if scl_fedge and r.selected then
                    v.state := r.post_ack_nxt_state;
                    if r.post_ack_nxt_state = TX_DATA then
                        v.tx_ready := '1';
                    end if;
                elsif scl_fedge then
                    -- we were not selected b/c we didn't ack
                    -- so go back to idle and wait for another txn
                    v.state := IDLE;
                    v.txn_hdr.valid := '0';
                    v.start_seen := '0';
                    v.cntr := (others => '0');
                    v.selected := '0';
                end if;

            when GET_ACKNACK =>
                if scl_redge then
                    if filtered_sda = '1' then
                        v.got_nack := '1';
                    else
                        v.got_ack := '1';
                    end if;
                end if;
                if scl_fedge and r.got_ack then
                    v.tx_reg := (others => '0');
                    v.state := TX_DATA;
                    v.tx_ready := '1';
                    v.cntr := (others => '0');
                elsif scl_fedge and r.got_nack then
                    v.tx_reg := (others => '0');
                    v.state := IDLE;
                    v.cntr := (others => '0');

                end if;
        end case;

        -- common logic to transition to appropriate state
        -- on any start or stop conditions
        if  stop_condition then
            v.state := IDLE;
            v.txn_hdr.valid := '0';
            v.start_seen := '0';
            v.cntr := (others => '0');
            v.selected := '0';
        elsif start_condition then
            v.start_seen := '1';
            v.txn_hdr.valid := '0';
            v.state := IDLE;
            v.selected := '0';
        end if;

        -- deal with handshake all the time
        if inst_ready = '1' and inst_valid = '1' then
            v.inst_data_valid := '0';
        end if;

        rin <= v;
    end process;

    reg: process(clk, reset)
        begin
        if reset = '1' then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end architecture rtl;