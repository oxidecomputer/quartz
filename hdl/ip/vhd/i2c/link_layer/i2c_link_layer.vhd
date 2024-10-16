-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.stream8_pkg;
use work.tristate_if_pkg.all;
use work.time_pkg.all;

use work.i2c_link_layer_pkg.all;

entity i2c_link_layer is
    generic (
        CLK_PER_NS  : positive;
        MODE        : mode_t
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;

        -- Tri-state signals to I2C interface
        scl_if      : view tristate_if;
        sda_if      : view tristate_if;

        -- I2C framing
        tx_start    : in std_logic; -- send a start
        tx_ack      : in std_logic; -- send an ACK
        tx_stop     : in std_logic; -- send a stop
        got_ack      : out std_logic; -- received an ACK

        -- Transmit data stream
        tx_st_if    : view stream8_pkg.st_sink_if;

        -- Received data stream
        rx_st_if    : view stream8_pkg.st_source_if;
    );
end entity;

architecture rtl of i2c_link_layer is
    constant SETTINGS               : settings_t := get_i2c_settings(MODE);
    constant SCL_HALF_PER_TICKS     : positive :=
        to_integer(calc_ns(SETTINGS.fscl_period_ns, CLK_PER_NS, 10));
    constant START_SETUP_HOLD_TICKS : positive :=
        to_integer(calc_ns(SETTINGS.sta_su_hd_ns, CLK_PER_NS, 8));
    constant STO_TO_STA_BUF_TICKS   : positive :=
        to_integer(calc_ns(SETTINGS.sto_sta_buf_ns, CLK_PER_NS, 8));

    -- The number of ticks after SCL falls until SDA should be transitioned. FastMode+ has the
    -- tightest requirement here (obviously) at 450ns, so by design we will always transition well
    -- prior to that since we don't have a reason not to. 
    constant SDA_TRANSITION_TICKS   : positive :=
        to_integer(calc_ns(300, CLK_PER_NS, 5));

    -- The state machine's counter to enforce timing around various events
    constant SM_COUNTER_SIZE_BITS   : positive := 10;

    type sm_reg_t is record
        -- state
        state           : state_t;
        bits_shifted    : natural range 0 to 7;

        -- control
        scl_active  : std_logic;
        tbuf_met    : std_logic;
        sta_setup   : std_logic;
        sta_hold    : std_logic;
        sda_hold    : std_logic;
        counter     : unsigned(SM_COUNTER_SIZE_BITS - 1 downto 0);
        count_load  : std_logic;
        count_decr  : std_logic;
        count_clr   : std_logic;
        sda_change  : std_logic;

        -- interfaces
        tx_ready    : std_logic;
        data        : std_logic_vector(7 downto 0);
        rx_valid    : std_logic;
        sda_oe      : std_logic;
        got_ack     : std_logic;
    end record;

    constant sm_reg_reset   : sm_reg_t := (
        IDLE,           -- state
        0,              -- bits_shifted
        '0',            -- scl_active
        '0',            -- tbuf_met
        '0',            -- sta_setup
        '0',            -- sta_hold
        '0',            -- sda_hold
        (others => '0'),-- counter
        '0',            -- count_load
        '0',            -- count_decr
        '0',            -- count_clr
        '0',            -- sda_change
        '0',            -- tx_ready
        (others => '0'),-- data
        '0',            -- rx_valid
        '0',            -- sda_oe
        '0'             -- got_ack
    );

    signal sm_reg, sm_reg_next    : sm_reg_t;

    signal sm_count_done    : std_logic;

    signal scl_toggle   : std_logic;
    signal scl_oe       : std_logic;
    signal scl_oe_last  : std_logic;
    signal scl_redge    : std_logic;
    signal scl_fedge    : std_logic;
    signal tbuf_en      : std_logic;
    signal tbuf_pulse   : std_logic;
    signal sta_en       : std_logic;
    signal sta_pulse    : std_logic;

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
        variable v_scl_oe_next : std_logic := '0';
    begin
        if reset then
            scl_oe      <= '0';
            scl_redge   <= '0';
            scl_fedge   <= '0';
        elsif rising_edge(clk) then
            scl_oe_last     <= scl_oe;
            v_scl_oe_next   := not scl_oe;

            if not sm_reg.scl_active then
                scl_oe  <= '0';
            elsif scl_toggle = '1' or sm_reg.sta_hold = '1' then
                scl_oe  <= v_scl_oe_next;
            end if;
        end if;
    end process;

    scl_redge   <= '1' when scl_oe = '0' and scl_oe_last = '1' else '0';
    scl_fedge   <= '1' when scl_oe = '1' and scl_oe_last = '0' else '0';

    --
    -- SDA Control
    --

    sda_in_sync: entity work.meta_sync
        port map(
          async_input   => sda_if.i,
          clk           => clk,
          sycnd_output  => sda_in_syncd
        );

    tbuf_en <= '1' when sda_in_syncd = '1' and 
                        (sm_reg.state = IDLE or sm_reg.state = WAIT_BUF)
                    else '0';

    tbuf_strobe: entity work.strobe
        generic map (
            TICKS   => STO_TO_STA_BUF_TICKS
        )
        port map (
            clk     => clk,
            reset   => reset,
            enable  => tbuf_en,
            strobe  => tbuf_pulse
        );

    sta_en <= '1' when sm_reg.state = START else '0';

    start_strobe: entity work.strobe
        generic map (
            TICKS   => START_SETUP_HOLD_TICKS
        )
        port map (
            clk     => clk,
            reset   => reset,
            enable  => sta_en,
            strobe  => sta_pulse
        );

    sda_transition: entity work.strobe
        generic map (
            TICKS   => SDA_TRANSITION_TICKS
        )
        port map (
            clk     => clk,
            reset   => reset,
            enable  => sm_reg.sda_change,
            strobe  => transition_sda
        );

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
        variable v  : sm_reg_t;
    begin
        v   := sm_reg;

        -- default to single cycle pulses to counter control
        v.count_load    := '0';
        v.count_decr    := '0';
        v.count_clr     := '0';

        -- single-cycle pulses
        v.got_ack   := '0';
        v.rx_valid  := '0';

        -- catch the pulse once tbuf as elapsed
        if not sm_reg.tbuf_met then
            v.tbuf_met  := tbuf_pulse;
        end if;

        -- after a scl fedge sda should be updated
        if scl_fedge then
            v.sda_change := '1';
        end if;

        case sm_reg.state is

            -- Ready and awaiting the next transaction
            when IDLE =>
                v.sda_oe    := '0';
                v.tx_ready  := '1';

                -- only begin a transaction once the address byte is valid
                if tx_st_if.valid = '1' then
                    v.state     := WAIT_BUF;
                    v.data      := tx_st_if.data;
                    v.tx_ready  := '0';
                end if;

            -- Wait out tbuf to ensure STOP/START spacing
            when WAIT_BUF =>
                if sm_reg.tbuf_met then
                    v.state     := START;
                    v.tbuf_met  := '0';
                    -- tbuf is always greater than or equal to the START setup requirement
                    v.sta_setup := '1';
                end if;

            -- Before sending the address byte, do the start sequence
            when START =>
                v.sda_oe    := sm_reg.sta_setup and not sm_reg.sta_hold;

                -- address byte has to be send after a start
                if sm_reg.sta_hold then
                    v.state         := BYTE_TX;
                    v.sta_setup     := '0';
                    v.sta_hold      := '0';
                    v.scl_active    := '1';
                end if;

            when AWAIT_STREAM =>
                v.tx_ready  := '1';

                if tx_start then
                    -- A repeated start was issued mid-transaction
                    v.state     := START;
                elsif tx_st_if.valid then
                    -- more data to transmit
                    v.state     := BYTE_TX;
                    v.data      := tx_st_if.data;
                    v.tx_ready  := '0';
                elsif rx_st_if.ready then
                    -- more data to read
                    v.state     := BYTE_RX;
                    v.tx_ready  := '0';
                end if;

            -- Clock out a byte and then wait for an ACK
            when BYTE_TX =>
                v.sda_oe    := not sm_reg.data(0);

                if transition_sda = '1' and sm_reg.sda_change = '1' then
                    v.data          := '1' & sm_reg.data(7 downto 1);
                    v.sda_change    := '0';

                    if sm_reg.bits_shifted = 7 then
                        v.state         := ACK_RX;
                        v.bits_shifted  := 0;
                    else
                        v.bits_shifted  := sm_reg.bits_shifted + 1;
                    end if;
                end if;

            -- See if the target ACKs
            when ACK_RX =>
                v.sda_oe    := '0';

                if scl_redge then
                    v.state     := AWAIT_STREAM;
                    v.got_ack   := not sda_in_syncd;
                end if;

            -- Clock in a byte and then send an ACK
            when BYTE_RX =>
                v.sda_oe    := '0';

                if scl_redge then
                    v.data  := sda_in_syncd & sm_reg.data(7 downto 1);

                    if sm_reg.bits_shifted = 7 then
                        v.state         := ACK_TX;
                        v.rx_valid      := '1';
                        v.bits_shifted  := 0;
                    else
                        v.bits_shifted  := sm_reg.bits_shifted + 1;
                    end if;
                end if;

            -- ACK the target
            when ACK_TX =>
                if transition_sda = '1' and sm_reg.sda_change = '1' then
                    v.sda_oe    := tx_ack;
                    v.state     := AWAIT_STREAM when tx_ack else STOP;
                end if;

            -- Do the stop sequence to end the transaction
            when STOP =>
                if scl_redge then
                    v.scl_active    := '0';
                end if;



        end case;

        sm_reg_next <= v;
    end process;

    reg_sm: process(clk, reset)
    begin
        if reset then
            sm_reg <= sm_reg_reset;
        elsif rising_edge(clk) then
            sm_reg <= sm_reg_next;
        end if;
    end process;

    --
    -- Interface connections
    --
    got_ack         <= sm_reg.got_ack;

    -- I2C is open-drain, so we only ever drive low
    scl_if.o        <= '0';
    scl_if.oe       <= scl_oe;
    sda_if.o        <= '0';
    sda_if.oe       <= sm_reg.sda_oe;

    tx_st_if.ready  <= sm_reg.tx_ready;
    rx_st_if.data   <= std_logic_vector(sm_reg.data);
    rx_st_if.valid  <= sm_reg.rx_valid;

end rtl;