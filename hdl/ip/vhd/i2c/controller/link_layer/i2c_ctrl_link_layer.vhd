-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- I2C Control Link Layer
--
-- This block handles the bit-level details of an I2C transaction. It requires higher order logic
-- to actually orchestrate the transaction and is designed for use with i2c_ctrl_txn_layer. This
-- block is written such that the tristate interfaces are push-pull, but that is trivial to change
-- to open-drain at a higher level if desired.
--
-- Notes:
-- - This block currently does not support block stretching.
-- - This block currently does not do ackknowledge-polling after a write.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.tristate_if_pkg.all;
use work.time_pkg.all;

use work.i2c_common_pkg.all;

entity i2c_ctrl_link_layer is
    generic (
        CLK_PER_NS  : positive;
        MODE        : mode_t
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;

        -- Tri-state signals to I2C interface
        scl_if          : view tristate_if;
        sda_if          : view tristate_if;

        txn_next_valid  : in std_logic; -- qualify transition to next action 
        ready           : out std_logic; -- ready for next action

        -- I2C framing
        tx_start        : in std_logic; -- send a start
        tx_ack          : in std_logic; -- send an ACK
        tx_stop         : in std_logic; -- send a stop

        -- transmit data
        tx_data         : in std_logic_vector(7 downto 0);
        tx_data_valid   : in std_logic;
        tx_ackd         : out std_logic; -- received an ACK
        tx_ackd_valid   : out std_logic;

        -- receive data
        rx_data         : out std_logic_vector(7 downto 0);
        rx_data_valid   : out std_logic;
    );
end entity;

architecture rtl of i2c_ctrl_link_layer is
    -- fetch the settings for the desired I2C mode
    constant SETTINGS               : settings_t := get_i2c_settings(MODE);
    constant SCL_HALF_PER_TICKS     : positive :=
        to_integer(calc_ns(SETTINGS.fscl_period_ns / 2, CLK_PER_NS, 10));

    -- The state machine's counter to enforce timing around various events
    constant SM_COUNTER_SIZE_BITS   : positive := 8;
    constant START_SETUP_HOLD_TICKS : std_logic_vector(7 downto 0) :=
        calc_ns(SETTINGS.sta_su_hd_ns, CLK_PER_NS, SM_COUNTER_SIZE_BITS);
    constant STOP_SETUP_TICKS       : std_logic_vector(7 downto 0) :=
        calc_ns(SETTINGS.sto_su_ns, CLK_PER_NS, SM_COUNTER_SIZE_BITS);
    constant STO_TO_STA_BUF_TICKS   : std_logic_vector(7 downto 0) :=
        calc_ns(SETTINGS.sto_sta_buf_ns, CLK_PER_NS, SM_COUNTER_SIZE_BITS);

    -- The number of ticks after SCL falls until SDA should be transitioned. FastMode+ has the
    -- tightest requirement here (obviously) at 450ns, so by design we will always transition well
    -- prior to that since we don't have a reason not to. 
    constant SDA_TRANSITION_TICKS   : positive :=
        to_integer(calc_ns(300, CLK_PER_NS, 5));

    constant TSP_TICKS : positive := to_integer(calc_ns(SETTINGS.tsp_ns, CLK_PER_NS, 8));

    type state_t is (
        IDLE,
        WAIT_TBUF,
        START_SETUP,
        START_HOLD,
        WAIT_REPEAT_START,
        HANDLE_NEXT,
        BYTE_TX,
        BYTE_RX,
        ACK_TX,
        ACK_RX,
        STOP_SDA,
        STOP_SCL,
        STOP_SETUP
    );

    type sm_reg_t is record
        -- state
        state           : state_t;
        bits_shifted    : natural range 0 to 9;

        -- control
        ready                   : std_logic;
        scl_start               : std_logic;
        scl_active              : std_logic;
        sda_hold                : std_logic;
        counter                 : std_logic_vector(SM_COUNTER_SIZE_BITS - 1 downto 0);
        count_load              : std_logic;
        count_decr              : std_logic;
        count_clr               : std_logic;
        transition_sda_cntr_en  : std_logic;
        ack_sending             : std_logic;
        sr_scl_fedge_seen       : std_logic;
        stop_requested          : std_logic;

        -- interfaces
        rx_data         : std_logic_vector(7 downto 0);
        rx_data_valid   : std_logic;
        tx_data         : std_logic_vector(7 downto 0);
        rx_ack          : std_logic;
        rx_ack_valid    : std_logic;
        sda_o           : std_logic;
        sda_oe          : std_logic;
    end record;

    constant SM_REG_RESET   : sm_reg_t := (
        state => IDLE,
        bits_shifted => 0,
        ready => '0',
        scl_start => '0',
        scl_active => '0',
        sda_hold => '0',
        counter => (others => '0'),
        count_load => '0',
        count_decr => '0',
        count_clr => '0',
        transition_sda_cntr_en => '0',
        ack_sending => '0',
        sr_scl_fedge_seen => '0',
        stop_requested => '0',
        rx_data => (others => '0'),
        rx_data_valid => '0',
        tx_data => (others => '0'),
        rx_ack => '0',
        rx_ack_valid =>'0',
        sda_o => '1',
        sda_oe => '1'
    );

    signal sm_reg, sm_reg_next    : sm_reg_t;

    signal sm_count_done    : std_logic;

    signal scl_toggle   : std_logic;
    signal scl_o        : std_logic;
    signal scl_o_last   : std_logic;
    signal scl_redge    : std_logic;
    signal scl_fedge    : std_logic;

    signal transition_sda   : std_logic;
    signal sda_in_syncd     : std_logic;
begin

    --
    -- SCL Control
    --

    scl_strobe: entity work.strobe
        generic map (
            TICKS => SCL_HALF_PER_TICKS
        )
        port map (
            clk     => clk,
            reset   => reset,
            enable  => sm_reg.scl_active,
            strobe  => scl_toggle
        );

    scl_reg: process(clk, reset)
    begin
        if reset then
            scl_o       <= '1';
            scl_o_last  <= '1';
        elsif rising_edge(clk) then
            scl_o_last  <= scl_o;

            if not sm_reg.scl_active then
                scl_o   <= '1';
            elsif scl_toggle = '1' or sm_reg.scl_start = '1' then
                scl_o   <= not scl_o;
            end if;
        end if;
    end process;

    scl_redge   <= '1' when scl_o = '1' and scl_o_last = '0' else '0';
    scl_fedge   <= '1' when scl_o = '0' and scl_o_last = '1' else '0';

    --
    -- SDA Control
    --

    -- Right now the controller doesn't need much of what this block offers aside from SDA filtering
    i2c_glitch_filter_inst: entity work.i2c_glitch_filter
        generic map(
            filter_cycles   => TSP_TICKS
        )
        port map(
            clk             => clk,
            reset           => reset,
            raw_scl         => '1',
            raw_sda         => sda_if.i,
            filtered_scl    => open,
            scl_fedge       => open,
            scl_redge       => open,
            filtered_sda    => sda_in_syncd,
            sda_fedge       => open,
            sda_redge       => open
        );

    -- This counter enforces `tvd` per the spec, ensuring we transition SDA only after an
    -- appropriate amount of time after a SCL falling edge.
    sda_transition: entity work.strobe
        generic map (
            TICKS   => SDA_TRANSITION_TICKS
        )
        port map (
            clk     => clk,
            reset   => reset,
            enable  => sm_reg.transition_sda_cntr_en,
            strobe  => transition_sda
        );

    -- This is a counter which can be loaded by the state machine to meet various timing
    -- requirements per the specification.
    sm_countdown: entity work.countdown
        generic map (
            SIZE    => SM_COUNTER_SIZE_BITS
        )
        port map (
            clk     => clk,
            reset   => reset,
            count   => sm_reg.counter,
            load    => sm_reg.count_load,
            decr    => sm_reg.count_decr,
            clear   => sm_reg.count_clr,
            done    => sm_count_done
        );

    --
    -- Link State Machine
    --

    sm_next_state: process(all)
        variable v : sm_reg_t;
        variable counter_done : boolean;
    begin
        v   := sm_reg;

        -- Single-cycle pulsed control signals
        v.count_load    := '0';
        v.count_decr    := '0';
        v.count_clr     := '0';
        v.scl_start     := '0';
        v.rx_data_valid := '0';

        -- Every time we see a falling edge on SCL we count the number of cycles until we should
        -- transition SDA accordingly, indicated by the transition_sda pulse. The state machine pays
        -- attention to transition_sda during states when the controller believes it has control of
        -- the bus, otherwise ignoring the pulse.
        if scl_fedge then
            v.transition_sda_cntr_en := '1';
        elsif transition_sda then
            v.transition_sda_cntr_en := '0';
        end if;

        -- Set if a stop is requested to handle the case when it may need to happen before the end
        -- of the transaction. This is then cleared as transition out of the STOP_SETUP state.
        -- The combinatorial value of this signal is read elsewhere in the state machine in an
        -- effort to accommodate making the stop happen as quickly as possible. The intention is
        -- to transition to a STOP during a normal transition point for I2C which is not necessarily
        -- any cycle of the FPGA clk. At slower operating modes this does not matter much, but at
        -- FAST_MODE_PLUS (1MHz) it starts to matter more.
        if sm_reg.stop_requested = '0' then
            v.stop_requested := '1' when tx_stop = '1' and txn_next_valid = '1' else '0';
        end if;

        -- It takes a cycle for load to propagate and the counter to reflect the new value.
        counter_done := sm_count_done = '1' and sm_reg.count_load = '0';

        case sm_reg.state is

            -- Ready and awaiting the next transaction
            when IDLE =>
                v.sda_o     := '1';
                v.sda_oe    := '1';

                if tx_start then
                    -- Coming back to IDLE after a transaction means we've waited out tbuf, and tbuf
                    -- is always greater than or equal to the START setup requirement, skip to hold
                    v.state         := START_HOLD;
                    v.counter       := START_SETUP_HOLD_TICKS;
                    v.count_load    := '1';
                end if;

            when WAIT_REPEAT_START =>
                if not sm_reg.sr_scl_fedge_seen then
                    v.sr_scl_fedge_seen := scl_fedge;
                elsif scl_redge then
                    v.state             := START_SETUP;
                    v.scl_active        := '0';
                    v.sr_scl_fedge_seen := '0';
                end if;

            -- In the event of a repeated START account for setup requirements
            when START_SETUP =>
                v.sda_o         := '1';
                v.sda_oe        := '1';
                v.count_decr    := '1';

                if counter_done then
                    v.state         := START_HOLD;
                    v.counter       := START_SETUP_HOLD_TICKS;
                    v.count_load    := '1';
                end if;

            when START_HOLD =>
                v.sda_o         := '0';
                v.sda_oe        := '1';
                v.count_decr    := '1';
                if counter_done then
                    v.state         := HANDLE_NEXT;
                    v.scl_start     := '1'; -- drop SCL to finish START condition
                    v.scl_active    := '1'; -- begin free running counter for SCL transitions
                end if;

            when HANDLE_NEXT =>
                v.rx_ack_valid  := '0';
                if v.stop_requested then
                    v.state := STOP_SDA;
                elsif txn_next_valid then
                    if tx_start then
                        -- A repeated start was issued mid-transaction
                        v.state         := WAIT_REPEAT_START;
                        v.counter       := START_SETUP_HOLD_TICKS;
                        v.count_load    := '1';
                    elsif tx_stop then
                        v.state         := STOP_SDA;
                    elsif tx_data_valid then
                        -- data to transmit
                        v.state         := BYTE_TX;
                        v.tx_data       := tx_data;
                    else
                        -- if nothing else, read
                        v.state         := BYTE_RX;
                    end if;
                end if;

            -- Clock out a byte and then wait for an ACK
            when BYTE_TX =>
                v.sda_oe    := '1';

                if transition_sda then
                    if sm_reg.bits_shifted = 8 then
                        v.state         := ACK_RX;
                        v.bits_shifted  := 0;
                    elsif v.stop_requested then
                        -- this is a valid SDA transition cycle so drive SDA low and skip STOP_SDA
                        v.state     := STOP_SCL;
                        v.sda_o     := '0';
                    else
                        v.sda_o         := sm_reg.tx_data(7);
                        v.tx_data       := sm_reg.tx_data(sm_reg.tx_data'high-1 downto sm_reg.tx_data'low) & '1';
                        v.bits_shifted  := sm_reg.bits_shifted + 1;
                    end if;
                end if;

            -- See if the target ACKs
            when ACK_RX =>
                v.sda_oe    := '0';

                if scl_redge then
                    v.rx_ack        := not sda_in_syncd;
                elsif scl_fedge then
                    v.state         := STOP_SDA when v.stop_requested else HANDLE_NEXT;
                    v.rx_ack_valid  := '1';
                end if;

            -- Clock in a byte and then send an ACK
            when BYTE_RX =>
                v.sda_oe    := '0';

                if sm_reg.bits_shifted = 8 and scl_fedge = '1' then
                    v.state         := ACK_TX;
                    v.rx_data_valid := '1';
                    v.bits_shifted  := 0;
                elsif scl_redge then
                    v.rx_data       := sm_reg.rx_data(sm_reg.rx_data'high-1 downto sm_reg.rx_data'low) & sda_in_syncd;
                    v.bits_shifted  := sm_reg.bits_shifted + 1;
                end if;

            -- ACK the target
            when ACK_TX =>
                v.sda_oe := '1';
                -- at the first transition_sda pulse start sending the (N)ACK
                if transition_sda then
                    if sm_reg.ack_sending = '0' then
                        v.sda_o         := '0' when (tx_ack = '1' and v.stop_requested = '0')
                                            else '1';
                        v.ack_sending   := '1';
                    else
                        -- at the next transition point release the bus
                        v.sda_oe        := '0';
                        v.ack_sending   := '0';
                        v.state         := STOP_SDA when v.stop_requested else HANDLE_NEXT;
                    end if;
                end if;

            -- drive SDA through final SCL cycle
            when STOP_SDA =>
                if transition_sda then
                    v.state     := STOP_SCL;
                    v.sda_o     := '0';
                    v.sda_oe    := '1';
                end if;

            when STOP_SCL =>
                if scl_redge then
                    v.state         := STOP_SETUP;
                    v.scl_active    := '0';
                    v.counter       := STOP_SETUP_TICKS;
                    v.count_load    := '1';
                end if;

            when STOP_SETUP =>
                v.count_decr    := '1';
                if counter_done then
                    v.state         := WAIT_TBUF;
                    v.counter       := STO_TO_STA_BUF_TICKS;
                    v.count_load    := '1';
                    v.sda_o         := '1';
                    v.sda_oe        := '1';
                end if;

            -- Wait out tbuf to ensure STOP/START spacing
            when WAIT_TBUF =>
                v.count_decr    := '1';
                if counter_done then
                    v   := SM_REG_RESET;
                end if;
        end case;

        v.ready := '1' when v.state = IDLE or
                            (v.state = HANDLE_NEXT and v.stop_requested = '0')
                    else '0';

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

    ready           <= sm_reg.ready;
    tx_ackd         <= sm_reg.rx_ack;
    tx_ackd_valid   <= sm_reg.rx_ack_valid;
    rx_data         <= sm_reg.rx_data;
    rx_data_valid   <= sm_reg.rx_data_valid;

    -- I2C is open-drain, so we only ever drive low
    scl_if.o        <= scl_o;
    scl_if.oe       <= '1'; -- SCL stretching is not currently supported
    sda_if.o        <= sm_reg.sda_o;
    sda_if.oe       <= sm_reg.sda_oe;

end rtl;