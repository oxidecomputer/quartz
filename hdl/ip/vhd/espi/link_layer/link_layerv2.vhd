-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- The main qspi link layer block for this target, including the 
-- link-layer transaction management and FIFO interfaces to/from
-- the transaction layer.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_base_types_pkg.all;
use work.espi_protocol_pkg.all;
use work.link_layer_pkg.all;

entity link_layerv2 is
    port (
        clk   : in    std_logic; -- 200MHz clock.
        reset : in    std_logic; -- 200Mhz reset.

        -- PHY signals (sync'd where applicable)
        cs_n  : in    std_logic;
        sclk  : in    std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0);
        response_csn : out std_logic;  --  "Fake" chipselect to help saleae decoding

        -- CMD FIFO interface, data from host goes into this fifo
        cmd_to_fifo: view byte_source;
        
        -- Response FIFO interface, data to host goes into this fifo
        resp_from_fifo: view byte_sink;

        -- System interface (from slow domain, already sync'd)
        wait_states : in std_logic_vector(3 downto 0);
        qspi_mode : in   qspi_mode_t;
        alert_needed : in std_logic;
        -- system interface (to slow domain, sync'd externally needs registered output here)
        espi_reset : out std_logic
    );
end entity;

architecture rtl of link_layerv2 is
    signal rx_reg : std_logic_vector(8 downto 0);
    signal tx_reg : std_logic_vector(8 downto 0);
    signal qspi_shift_amt        : natural range 1 to 4; 

begin
    -- RX clock domain
    -- Up to 66MHz, comes and goes with the sclk
    deserializer: process(sclk, cs_n)
        variable nxt_rx_reg : std_logic_vector(8 downto 0);
    begin
        if cs_n = '1' then
            -- out of command phase reset to sentinel
            nxt_rx_reg := (others => '0', 0 => '1');
        elsif rising_edge(sclk) then
            -- cs is guaranteed by protocol to be stable here so we can skip
            -- synchronization, same with the serial input signals
            -- we were already at a byte boundary, so reset
            if rx_reg(8) = '1' then
                nxt_rx_reg := shift_left("00000001", qspi_shift_amt);
            else
                nxt_rx_reg := shift_left(rx_reg, qspi_shift_amt);
            end if;
            -- Shift in the new bit(s)
            if qspi_mode = SINGLE then
                rx_reg(0)    <= io(0);
            elsif qspi_mode = DUAL then
                rx_reg(0)    <= io(0);
                rx_reg(1)    <= io(1);
            elsif qspi_mode = QUAD then
                rx_reg(0) <= io(0);
                rx_reg(1) <= io(1);
                rx_reg(2) <= io(2);
                rx_reg(3) <= io(3);
            end if;
        end if;
    end process;

    -- TX clock domain
    -- Up to 66MHz, comes and goes with the sclk
    serializer: process(sclk, cs_n)
        variable nxt_tx_reg : std_logic_vector(8 downto 0);
    begin
        if cs_n = '1' then
            nxt_tx_reg := (others => '0', 0 => '1');
        elsif falling_edge(sclk) then
            -- cs is guaranteed by protocol to be stable here so we can skip
            -- synchronization, and there's guaranteed to be setup time
            if (not in_command_phase) then
                -- we were already at a byte boundary, so reset
                if tx_reg = "10000000" then
                    nxt_tx_reg := tx_data & '1';
                else
                    nxt_tx_reg := shift_right(tx_reg, qspi_shift_amt);
                end if;
                 
            end if;
        end if;
    end process;

    -- Based on state and qspi mode, deal with the tri-state controls
    -- of the spi pins, in fast domain since we need to alert when no sclk is running.
    oe_control: process(clk, reset)
    begin
        if reset then
            io_oe <= (others => '0');
        elsif rising_edge(clk) then
            if in_response_phase then
                case qspi_mode is
                    when single =>
                        io_oe <= (1 => '1', others => '0');
                    when dual =>
                        io_oe <= (1 downto 0 => '1', others => '0');
                    when quad =>
                        io_oe <= (others => '1');
                end case;
            else
                -- default to not driving unless there's an alert
                io_oe <= (others => '0');
                if active_alert then
                    -- we want to issue an alert now so we need to drive the alert pin
                    io_oe <= (1 => '1', others => '0');
                end if;

            end if;
        end if;
    end process;

    -- Deal with output logic for the different modes
    io_o(0) <= tx_reg(tx_reg'high-3) when qspi_mode = QUAD else
        tx_reg(tx_reg'high-1) when qspi_mode = DUAL else
        '1'; -- not used due to oe-gate

    io_o(1) <= '0' when active_alert else
            tx_reg(tx_reg'high) when qspi_mode = SINGLE else
            tx_reg(tx_reg'high) when qspi_mode = DUAL else
            tx_reg(tx_reg'high-2) when qspi_mode = QUAD else
            '1'; -- not used due to oe-gate
    io_o(2) <= tx_reg(tx_reg'high - 1);
    io_o(3) <= tx_reg(tx_reg'high);


    qspi_shift_amt <= get_qspi_shift_amt_by_mode(txn_qspi_mode);

    -- Take the sclk into the "fast" domain, we'll set multi-cycles up for the crosses.

    -- RX side, when we see sample a valid bit set after the cross, we can accept the byte.

    -- TX side, we need to sort out the ack.


end rtl;