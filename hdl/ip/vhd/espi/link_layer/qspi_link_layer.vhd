-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.qspi_link_layer_pkg.all;

use work.espi_spec_regs_pkg.all;

-- This block provides a relatively simple qspi shifter primative
-- that shifts data in/out byte-byte.  eSPI has the concept of
-- a "turnaround" cycle which is a 2 sclk period to allow the
-- bus to turn-around. This is detected by the command processor
-- but handled in this block by no shifting for 2 sclks to preserve
-- byte alignment. This block otherwise just shifts bytes in and out
-- and exptects there to be no backpressure on recieve and always
-- valid data to shift out.
entity qspi_link_layer is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        cs_n  : in    std_logic;
        sclk  : in    std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0);
        -- set in registers, controls how the shifters
        -- sample per sclk
        qspi_mode : in    qspi_mode_t;
        -- Asserted by command processor during the
        -- transmission of the last command byte (the CRC)
        is_crc_byte : in    boolean;
        alert_needed : in boolean;
        -- "Streaming" data to serialize and transmit
        data_to_host       : view st_sink;
        -- "Streaming" bytes after receipt and deserialization
        data_from_host     : view st_source;
    );
end entity;

architecture rtl of qspi_link_layer is

    signal sclk_last        : std_logic;
    signal cs_n_last        : std_logic;
    signal selected         : boolean;
    signal cur_qspi_mode    : qspi_mode_t;
    signal shift_amt        : natural range 1 to 4 := 1;

    -- The ranges are odd here because we have an extra bit
    -- for a sentinel value
    signal tx_reg            : std_logic_vector(8 downto 0);
    signal rx_reg            : std_logic_vector(8 downto 0);
    signal in_turnaround     : boolean;
    signal ta_cnts    : integer range 0 to 2 := 0;
    signal response_phase    : boolean;
    signal data_ready_to_host : std_logic;
    type cs_monitor_t is (no_alert_allowed, alert_allowed);
    signal cs_monitor_state : cs_monitor_t;
    type alert_state_t is (idle, wait_for_allowed, alert);
    signal alert_state : alert_state_t;
    signal cs_cntr : natural range 0 to 3 := 0;
    constant cs_deassert_delay : natural := 2;

begin

    -- We have some fairly slow minimum delay timings for the alert pin
    -- this block monitors the chip select and provides an alert_allowed
    -- window for the alert processor.
    cs_mon:process(clk, reset)
    begin
        if reset then
            cs_monitor_state <= no_alert_allowed;
            cs_cntr <= 0;
        elsif rising_edge(clk) then
            case cs_monitor_state is 
                when no_alert_allowed =>
                    if cs_n = '1' then
                        cs_cntr <= cs_cntr + 1;
                    else 
                        cs_cntr <= 0;
                    end if;
                    if cs_cntr >= cs_deassert_delay then
                        cs_monitor_state <= alert_allowed;
                    end if;
                when alert_allowed =>
                    if cs_n = '0' then
                        cs_monitor_state <= no_alert_allowed;
                        cs_cntr <= 0;
                    end if;
            end case;
        end if;
    end process;


    alert_processor: process(clk, reset)
    begin
        if reset then
            alert_state <= idle;
        elsif rising_edge(clk) then
            -- If we have an alert to send, we can send it by pulling
            --io[1] low, but only when cs is not asserted.
            case alert_state is
                when idle =>
                    if alert_needed and cs_monitor_state = alert_allowed then
                        alert_state <= alert;
                    elsif alert_needed then
                        alert_state <= wait_for_allowed;
                    end if;
                when wait_for_allowed =>
                    if cs_monitor_state = alert_allowed then
                        alert_state <= alert;
                    end if;
                when alert =>
                    if cs_n = '0' or cs_monitor_state = no_alert_allowed then
                        alert_state <= idle;
                    end if;
            end case;
           
        end if;
    end process;


    -- Simple book-keeping for the transaction
    transaction_regs : process (clk, reset)
        variable begin_txn  : boolean;
        variable end_txn    : boolean;
        variable sclk_fedge : boolean;
        variable sclk_redge : boolean;
        variable rx_byte_done : boolean;
    begin
        if reset then
            cur_qspi_mode <= single;
            cs_n_last <= '1';
            selected <= false;
            sclk_last <= '0';
            in_turnaround <= false;
            response_phase <= false;
        elsif rising_edge(clk) then
            -- basic flops
            sclk_last <= sclk;
            cs_n_last <= cs_n;

            -- set up combo variables
            begin_txn := cs_n = '0' and cs_n_last = '1';
            end_txn := cs_n = '1' and cs_n_last = '0';
            sclk_fedge := sclk_last = '1' and sclk = '0';
            sclk_redge := sclk_last = '0' and sclk = '1';
            rx_byte_done := rx_reg(rx_reg'high) = '1';

            if begin_txn then
                -- cur_qspi_mode is latched at beginning
                -- of transaction since it could be adjusted
                -- in transaction by this transaction if it writes
                -- to the gen_cap registers. These writes only take
                -- affect at the *next* chip select
                cur_qspi_mode <= qspi_mode;
                response_phase <= false;
                selected <= true;
            end if;
            -- Turn around detection
            -- command processor will assert is_crc while we're catching the crc byte
            -- once this byte has been stored (sclk fedge), there are two sclk cycles
            -- of turn-around. We're allowed to start drivng the bus at the 2nd rising
            -- edge of the turn around.
            if is_crc_byte and rx_byte_done then
                in_turnaround <= true;
            elsif in_turnaround and ta_cnts < 2 and sclk_redge then
                ta_cnts <= ta_cnts + 1;
            elsif ta_cnts = 2 then
                in_turnaround <= false;
                response_phase <= true;
                ta_cnts <= 0;
            end if;

            -- always clean up if we're de-selected
            if end_txn then
                response_phase <= false;
                ta_cnts <= 0;
                in_turnaround <= false;
                selected <= false;
            end if;
           
        end if;
    end process;

    -- Based on state and qspi mode, deal with the tri-state controls
    -- of the spi pins
    oe_control: process(clk, reset)
    begin
        if reset then
            io_oe <= (others => '0');
        elsif rising_edge(clk) then
            if response_phase then
                case cur_qspi_mode is
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
                if alert_state = alert then
                    -- we want to issue an alert now so we need to drive the alert pin
                    io_oe <= (1 => '1', others => '0');
                end if;

            end if;
        end if;
    end process;

    -- This is the main "output" serializer. The internal 
    -- register is 9 bits wide using a sentinel value in the
    -- LSB so that we don't need bit counters here.
    -- We know we're done with a byte when the MSB is '1'
    -- and all the other bits are '0' b/c we've shifted the
    -- sentinel up 8x
    serializer : process (clk, reset)
        variable sclk_fedge        : boolean := false;
    begin
        if reset then
            tx_reg <= (tx_reg'high -1 => '1', others => '0');
            data_ready_to_host <= '0';
        elsif rising_edge(clk) then
            sclk_fedge := sclk = '0' and sclk_last = '1';
            -- clear single-cycle flags
            data_ready_to_host <= '0';

            -- Main serializer logic, shift out on sclk_fedge
            -- when we're chip-selected and not doing turnaround
            if selected and response_phase and sclk_fedge then
                -- if next-shift would be our sentinal value, load new data
                if shift_left(tx_reg, shift_amt) = "100000000" then
                    -- tx_register is "empty" load a new one
                    -- and the sentinal value
                    tx_reg(8 downto 1) <= data_to_host.data;
                    tx_reg(tx_reg'low) <= '1';
                    -- strobe ready since we grabbed the value
                    data_ready_to_host <= '1';
                -- mid-byte, shift
                else
                    tx_reg       <= shift_left(tx_reg, shift_amt);
                end if;
            elsif not selected then
                tx_reg <= (tx_reg'high -1 => '1', others => '0');
            end if;
        end if;
    end process;

    data_to_host.ready <= data_ready_to_host;

    --- This is the main "input" deserializer. The internal 
    -- register is 9 bits wide using a sentinel value in the
    -- LSB so that we don't need bit counters here.
    -- We know we're done with a byte when the MSB is '1'
    -- This bit can also function as the valid flag
    deserializer : process (clk, reset)
        variable sclk_redge : boolean := false;
    begin
        if reset then
            -- Uses a 9 bit shift register with a sentinel
            -- value of 1 in the lsb. We're done shifting when
            -- this bit makes it to the msb (ie we've shifted in
            -- a byte)
            rx_reg <= (rx_reg'low => '1', others => '0');
        elsif rising_edge(clk) then
            -- build up a couple of combo variables used to make the
            -- code read better below
            sclk_redge := sclk = '1' and sclk_last = '0';

            -- Do the sample/shift when requested and flag the
            -- valid bytes once we have them
            if selected and (not in_turnaround) and sclk_redge then
                -- Shift data by amount depending on mode
                rx_reg       <= shift_left(rx_reg, shift_amt);
                -- Sample new data into vacated locations
                if cur_qspi_mode = SINGLE then
                    rx_reg(0)    <= io(0);
                elsif cur_qspi_mode = DUAL then
                    rx_reg(0)    <= io(0);
                    rx_reg(1)    <= io(1);
                elsif cur_qspi_mode = QUAD then
                    rx_reg(0) <= io(0);
                    rx_reg(1) <= io(1);
                    rx_reg(2) <= io(2);
                    rx_reg(3) <= io(3);
                end if;
            elsif (not selected) or rx_reg(rx_reg'high) = '1' then
                -- Reset shifter to sentinel value when we become
                -- de-selected, or once we've strobed the valid
                rx_reg <= (rx_reg'low => '1', others => '0');
            end if;
        end if;
    end process;

    data_from_host.valid <= rx_reg(rx_reg'high);
    data_from_host.data <= rx_reg(7 downto 0);

    -- Deal with output logic for the different modes
    io_o(0) <= tx_reg(tx_reg'high-3) when cur_qspi_mode = QUAD else
               tx_reg(tx_reg'high-1) when cur_qspi_mode = DUAL else
               '1'; -- not used due to oe-gate

    io_o(1) <= '0' when alert_state = alert else
               tx_reg(tx_reg'high) when cur_qspi_mode = SINGLE else
               tx_reg(tx_reg'high) when cur_qspi_mode = DUAL else
               tx_reg(tx_reg'high-2) when cur_qspi_mode = QUAD else
               '1'; -- not used due to oe-gate
    io_o(2) <= tx_reg(tx_reg'high - 1);
    io_o(3) <= tx_reg(tx_reg'high);

end rtl;
