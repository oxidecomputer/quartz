-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.spi_nor_pkg.all;

entity spi_link is
    port (
        clk : in std_logic;
        reset : in std_logic;
        -- system interface
        cur_io_mode  : in io_mode;
        divisor : in unsigned(15 downto 0);
        in_tx_phases : in boolean;
        in_rx_phases : in boolean;
        rx_byte      : out std_logic_vector(7 downto 0);
        rx_byte_done : out boolean;
        tx_byte      : in std_logic_vector(7 downto 0);
        tx_byte_done : out boolean;
        sclk_redge   : out boolean;
        sclk_fedge   : out boolean;

        -- qspi interface
        cs_n  : in    std_logic;
        sclk  : out   std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0)
    );
end spi_link;

architecture rtl of spi_link is

signal tx_reg            : std_logic_vector(8 downto 0);
signal rx_reg            : std_logic_vector(8 downto 0);
signal tx_byte_ack       : boolean;
signal sclk_last         : std_logic;
signal shift_amt         : integer range 1 to 4;
signal csn_last          : std_logic;
signal is_last_bit       : boolean;

begin

    shift_amt <= 1 when cur_io_mode = SINGLE else
        2 when cur_io_mode = DUAL else
        4 when cur_io_mode = QUAD else
        1;

    rx_byte_done <= rx_reg(rx_reg'high) = '1';
    rx_byte <= rx_reg(7 downto 0);

    clk_edge: process(clk, reset)
    begin
        if reset then
            sclk_last <= '0';
        elsif rising_edge(clk) then
            sclk_last <= sclk;
        end if;
    end process;

    sclk_redge <= sclk = '1' and sclk_last = '0';
    sclk_fedge <= sclk = '0' and sclk_last = '1';

    -- spi clock gen block
    clk_gen: entity work.spi_clk_gen
        port map (
            clk => clk,
            reset => reset,
            divisor => divisor,
            enable => in_tx_phases or in_rx_phases,
            sclk => sclk
        );

    -- This is the main "output" serializer. The internal 
    -- register is 9 bits wide using a sentinel value in the
    -- LSB so that we don't need bit counters here.
    -- We know we're done with a byte when the MSB is '1'
    -- and all the other bits are '0' b/c we've shifted the
    -- sentinel up 8x
    -- There are two key indications that we need and we need them
    -- at different times:
    -- 1) We need to ack bytes from fifos/other data inputs. This happens
    -- *before* the byte-shifting is done.
    -- 2) We need to know when the last bit of the byte has been shifted
    serializer : process (clk, reset)
        variable cs_n_assert_edge  : boolean := false;
    begin
        if reset then
            tx_reg <= (others => '0');
            tx_byte_ack <= false;
            csn_last <= '1';
            is_last_bit <= false;
        elsif rising_edge(clk) then
            csn_last <= cs_n;
            cs_n_assert_edge := cs_n = '0' and csn_last = '1';
            -- clear single-cycle flags
            tx_byte_ack <= false;
            is_last_bit <= false;

            if cs_n_assert_edge then
                -- as the controller here, we need to pre-load data before the first
                -- clock
                tx_reg(8 downto 1) <= tx_byte;
                tx_reg(tx_reg'low) <= '1';
                tx_byte_ack <= true;
                is_last_bit <= false;

            -- Main serializer logic, shift out on sclk_fedge
            -- when we're chip-selected and not doing turnaround
            elsif in_tx_phases and sclk_redge then
                if shift_left(tx_reg, shift_amt) = "100000000" then
                    is_last_bit <= true;
                end if;
            elsif in_tx_phases and sclk_fedge then
                -- if next-shift would be our sentinal value, load new data
                if shift_left(tx_reg, shift_amt) = "100000000" then
                    -- tx_register is "empty" load a new one
                    -- and the sentinal value
                    tx_reg(8 downto 1) <= tx_byte;
                    tx_reg(tx_reg'low) <= '1';
                    tx_byte_ack <= true;
                -- mid-byte, shift
                else
                    tx_reg       <= shift_left(tx_reg, shift_amt);
                end if;
            elsif not in_tx_phases then
                tx_reg <= (others => '0');
                is_last_bit <= false;
            end if;
        end if;
    end process;
    tx_byte_done <= is_last_bit;

     -- Based on state and qspi mode, deal with the tri-state controls
    -- of the spi pins
    oe_control: process(clk, reset)
    begin
        if reset then
            io_oe <= (others => '0');
        elsif rising_edge(clk) then
            if in_tx_phases then
                case cur_io_mode is
                    when single =>
                        -- data going out 0 port, but need 3 port to be high so
                        -- chip doesn't see a HOLD operation
                        io_oe <= (0 => '1', 3 => '1', others => '0');
                    when dual =>
                        -- data going out 0 port, but need 3 port to be high so
                        -- chip doesn't see a HOLD operation
                        io_oe <= (1 downto 0 => '1', 3 => '1', others => '0');
                    when quad =>
                        io_oe <= (others => '1');
                end case;
            else  -- rx only in all rx phases
                case cur_io_mode is
                    when single =>
                        -- data coming in 1 port, but need 3 port to be high so
                        -- chip doesn't see a HOLD operation
                        io_oe <= (3 => '1', others => '0');
                    when dual =>
                        -- data coming in 0, 1 ports, but need 3 port to be high so
                        -- chip doesn't see a HOLD operation
                        io_oe <= ( 3 => '1', others => '0');
                    when quad =>
                        -- data coming in all ports, no outputs
                        io_oe <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    -- Deal with output logic for the different modes
    io_o(0) <= tx_reg(tx_reg'high-3) when cur_io_mode = QUAD else
               tx_reg(tx_reg'high-1) when cur_io_mode = DUAL else
               tx_reg(tx_reg'high);

    io_o(1) <= tx_reg(tx_reg'high) when cur_io_mode = DUAL else
               tx_reg(tx_reg'high-2) when cur_io_mode = QUAD else
               '1'; -- not used due to oe-gate
    io_o(2) <= tx_reg(tx_reg'high - 1); -- only used in quad mode
    io_o(3) <= tx_reg(tx_reg'high) when cur_io_mode = QUAD else
              '1'; -- only used in quad mode, but need to not be 0 in 
              -- single or dual modes to not act as a HOLD


    -- This is the main "input" deserializer. The internal 
    -- register is 9 bits wide using a sentinel value in the
    -- LSB so that we don't need bit counters here.
    -- We know we're done with a byte when the MSB is '1'
    -- This bit can also function as the valid flag
    deserializer : process (clk, reset)
    begin
        if reset then
            -- Uses a 9 bit shift register with a sentinel
            -- value of 1 in the lsb. We're done shifting when
            -- this bit makes it to the msb (ie we've shifted in
            -- a byte)
            rx_reg <= (rx_reg'low => '1', others => '0');
        elsif rising_edge(clk) then

            -- Do the sample/shift when requested and flag the
            -- valid bytes once we have them
            if in_rx_phases and sclk_redge then
                -- Shift data by amount depending on mode
                rx_reg       <= shift_left(rx_reg, shift_amt);
                -- Sample new data into vacated locations
                if cur_io_mode = SINGLE then
                    rx_reg(0)    <= io(1);
                elsif cur_io_mode = DUAL then
                    rx_reg(0)    <= io(0);
                    rx_reg(1)    <= io(1);
                elsif cur_io_mode = QUAD then
                    rx_reg(0) <= io(0);
                    rx_reg(1) <= io(1);
                    rx_reg(2) <= io(2);
                    rx_reg(3) <= io(3);
                end if;
            elsif not in_rx_phases or rx_reg(rx_reg'high) = '1' then
                -- Reset shifter to sentinel value when we become
                -- de-selected, or once we've strobed the valid
                rx_reg <= (rx_reg'low => '1', others => '0');
            end if;
        end if;
    end process;
end rtl;