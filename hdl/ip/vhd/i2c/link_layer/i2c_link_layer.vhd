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
    -- constant SDA_TRANSITION_TICKS   : positive :=
    --     to_integer(calc_ns())

    type sm_reg_t is record
        -- state machine
        state       : state_t;

        -- control
        scl_active  : std_logic;
        tbuf_met    : std_logic;
        sta_setup   : std_logic;
        sta_hold    : std_logic;
        sda_hold    : std_logic;

        -- interfaces
        tx_ready    : std_logic;
        data        : unsigned(7 downto 0); -- unsigned makes using shift functions cleaner
        rx_valid    : std_logic;
        sda_oe      : std_logic;
    end record;

    constant sm_reg_reset   : sm_reg_t := (
        IDLE,           -- state
        '0',            -- scl_active
        '0',            -- tbuf_met
        '0',            -- sta_setup
        '0',            -- sta_hold
        '0',            -- sda_hold
        '0',            -- tx_ready
        (others => '0'),-- data
        '0',            -- rx_valid
        '0'             -- sda_oe
    );

    signal sm_reg, sm_reg_next    : sm_reg_t;

    signal scl_toggle   : std_logic;
    signal scl_oe       : std_logic;
    signal scl_oe_last  : std_logic;
    signal scl_redge    : std_logic;
    signal scl_fedge    : std_logic;
    signal tbuf_en      : std_logic;
    signal tbuf_pulse   : std_logic;
    signal sta_en       : std_logic;
    signal sta_pulse    : std_logic;

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

    tbuf_en <= '1' when sda_if.i = '1' and 
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
            TICKS => START_SETUP_HOLD_TICKS
        )
        port map (
            clk => clk,
            reset => reset,
            enable => sta_en,
            strobe => sta_pulse
        );


    --
    -- Link State Machine
    --

    sm_next_state: process(all)
        variable v  : sm_reg_t;
    begin
        v   := sm_reg;

        -- catch the pulse once tbuf as elapsed
        if not sm_reg.tbuf_met then
            v.tbuf_met  := tbuf_pulse;
        end if;

        case sm_reg.state is

            -- Ready and awaiting the next transaction
            when IDLE =>
                v.sda_oe    := '0';
                v.tx_ready  := '1';

                if tx_st_if.valid then
                    v.state     := WAIT_BUF;
                    v.tx_ready  := '0';
                    v.data      := unsigned(tx_st_if.data);
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

                if sm_reg.sta_hold then
                    v.state         := TX_BYTE;
                    v.sta_setup     := '0';
                    v.sta_hold      := '0';
                    v.scl_active    := '1';
                end if;

            -- Clock out a byte and then wait for an ACK
            when TX_BYTE =>
                v.sda_oe    := sm_reg.data(0);

                -- shift data appropriately
                -- v.data  := shift_right(sm_reg.data, 1);

            -- See if the target ACKs
            when RX_ACK =>
                if scl_redge then
                    if scl_if.i then
                        -- NACK'd

                    else
                        -- ACK'd

                    end if;
                end if;

            -- Clock in a byte and then send an ACK
            when RX_BYTE =>
                

            -- ACK the target
            when TX_ACK =>

            -- Do the stop sequence to end the transaction
            when STOP =>


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

    -- I2C is open-drain, so we only ever drive low
    scl_if.o        <= '0';
    scl_if.oe       <= scl_oe;
    sda_if.o        <= '0';
    sda_if.oe       <= sm_reg.sda_oe;

    tx_st_if.ready  <= sm_reg.tx_ready;
    rx_st_if.data   <= std_logic_vector(sm_reg.data);
    rx_st_if.valid  <= sm_reg.rx_valid;

end rtl;