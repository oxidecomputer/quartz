-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

use work.interfaces_pkg.all;
use work.time_pkg.all;

use work.i2c_link_layer_pkg.all;

entity i2c_link_layer is
    port (
        clk     :   in  std_logic;
        reset   :   in  std_logic;

        -- Tri-state signals to I2C interface
        scl_i   :   in  std_logic;
        scl_o   :   out std_logic;
        scl_oe  :   out std_logic;
        sda_i   :   in  std_logic;
        sda_o   :   out std_logic;
        sda_oe  :   out std_logic;

        -- Transmit data stream
        tx_st   : view st_sink;

        -- Received data stream
        rx_st   : view st_source;
    );
end entity;

architecture rtl of i2c_link_layer is
    constant 

    type reg_t is record
        state       : state_t;
        tx_ready    : std_logic;
        data        : std_logic_vector(7 downto 0);
        rx_valid    : std_logic;
    end record;
    constant reg_reset  : reg_t := (IDLE, '0', (others => '0'), '0');

    signal reg, reg_next    : reg_t;

begin

    sm_next_state : process(all)
        variable v  : reg_t;
    begin
        v   := reg;

        case reg.state is

            -- Ready and awaiting the next transaction
            when IDLE =>
                v.tx_ready  := '1';
                if tx_st.valid = '1' then
                    v.state     := START;
                    v.tx_ready  := '0';
                    v.data      := tx_st.data;
                end if;

            -- Before sending the address byte, do the start sequence
            when START =>

            -- Clock out a byte and then wait for an ACK
            when TX_BYTE =>

            -- See if the target ACKs
            when RX_ACK =>

            -- Clock in a byte and then send an ACK
            when RX_BYTE =>

            -- ACK the target
            when TX_ACK =>

            -- Do the stop sequence to end the transaction
            when STOP =>
                

        end case;

        reg_next <= v;
    end process;

    sm_reg: process(clk, reset)
    begin
        if reset = '1' then
            reg <= reg_reset;
        elsif rising_edge(clk) then
            reg <= reg_next;
        end if;
    end process;

    tx_st.ready <= reg.tx_ready;
    rx_st.data  <= reg.data;
    rx_st.valid <= reg.rx_valid;

end rtl;