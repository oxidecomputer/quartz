-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.qspi_target_pkg.all;
use work.espi_protocol_pkg.all;

entity qspi_target is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        cs_n  : in    std_logic;
        sclk  : in    std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0);

        qspi_mode : in    qspi_mode_t;

        data_in       : in    std_logic_vector(7 downto 0);
        data_in_valid : in    std_logic;
        data_in_ready : out   std_logic;

        alert : in    std_logic;

        data_out       : out   std_logic_vector(7 downto 0);
        data_out_valid : out   std_logic;
        data_out_ready : in    std_logic
    );
end entity;

architecture rtl of qspi_target is

    type phase_t is (
        idle,
        wait_for_opcode,
        wait_for_length,
        finish_cmd,
        turnaround1,
        turnaround2,
        response
    );

    signal phase : phase_t;

    signal rx_bit_count   : natural range 0 to 8    := 8;
    signal tx_bit_count   : natural range 0 to 8    := 8;
    signal txn_byte_count : natural range 0 to 4095 := 0;
    signal rem_cmd_bytes  : natural range 0 to 4095 := 0;
    signal turn_known_by  : natural range 0 to 4    := 0;
    signal cmd_length     : std_logic_vector(11 downto 0);
    signal cur_opcode     : std_logic_vector(7 downto 0);

    signal rx_data_byte_valid : boolean;
    signal rx_data_byte       : std_logic_vector(7 downto 0);
    signal sclk_last          : std_logic;
    signal in_command_phase   : boolean;
    signal cur_qspi_mode      : qspi_mode_t;
    signal shift_amt          : natural range 1 to 4 := 1;

    signal tx_reg            : std_logic_vector(7 downto 0);
    signal tx_data_byte_done : boolean;

begin

    misc_regs : process (clk, reset)
    begin
        if reset then
            sclk_last <= '0';
            txn_byte_count <= 0;
        elsif rising_edge(clk) then
            sclk_last <= sclk;
            if phase = idle then
                txn_byte_count <= 0;
            elsif rx_data_byte_valid or tx_data_byte_done then
                txn_byte_count <= txn_byte_count + 1;
            end if;
        end if;
    end process;

    alerts : process (clk, reset)
    begin
    end process;

    link_layer_sm : process (clk, reset)
        variable opcode_valid   : boolean := false;
        variable length_h_valid : boolean := false;
        variable length_l_valid : boolean := false;
        variable cs_selected    : boolean := false;
        variable sclk_fedge     : boolean := false;
    begin
        if reset then
            in_command_phase <= false;
            phase <= idle;
            cur_opcode <= (others => '0');
            cmd_length <= (others => '0');
            turn_known_by <= 0;
            rem_cmd_bytes <= 0;
            cur_qspi_mode <= single;
            shift_amt <= 1;
        elsif rising_edge(clk) then
            -- combo flags for cleaner code below
            -- Note that the byte-count updates on the valid flag, so the
            -- counts here are n-1 since they're about to update
            opcode_valid := txn_byte_count = 0 and rx_data_byte_valid;
            length_h_valid := txn_byte_count = 2 and rx_data_byte_valid;
            length_l_valid := txn_byte_count = 3 and rx_data_byte_valid;
            sclk_fedge := sclk = '0' and sclk_last = '1';
            cs_selected := cs_n = '0';
            -- Monitor for turnaround cycles:
            -- Wait for opcode, and get bytes before TA
            case phase is
                when idle =>
                    cur_opcode <= (others => '0');
                    cmd_length <= (others => '0');
                    turn_known_by <= 0;
                    rem_cmd_bytes <= 0;
                    if cs_selected then
                        -- since this transaction could change qspi_mode
                        -- we latch it here for the duration
                        cur_qspi_mode <= qspi_mode;
                        shift_amt <= get_shift_amt_by_mode(cur_qspi_mode);
                        in_command_phase <= true;
                        phase <= wait_for_opcode;
                    end if;
                when wait_for_opcode =>
                    if opcode_valid then
                        -- valid opcode store it for use later
                        cur_opcode <= rx_data_byte;
                        -- figure out based on opcode when we can know the turn
                        -- around position. This varies by opcode and in some
                        -- cases the length of the payload;
                        turn_known_by <= bytes_until_turn_known_by_opcode(rx_data_byte);
                    end if;
                    if turn_known_by = 1 and turn_known_by <= txn_byte_count then
                        rem_cmd_bytes <= bytes_until_turn(cur_opcode, cmd_length);
                        phase <= finish_cmd;
                    elsif turn_known_by = 4 then
                        phase <= wait_for_length;
                    end if;
                when wait_for_length =>
                    if length_h_valid then
                        cmd_length(11 downto 8) <= rx_data_byte(3 downto 0);
                    end if;
                    if length_l_valid then
                        cmd_length(7 downto 0) <= rx_data_byte;
                        rem_cmd_bytes <= bytes_until_turn(cur_opcode, cmd_length);
                        phase <= finish_cmd;
                    end if;
                when finish_cmd =>
                    if not cs_selected then
                        in_command_phase <= false;
                        phase <= idle;
                    elsif txn_byte_count = rem_cmd_bytes and sclk_fedge then
                        in_command_phase <= false;
                        phase <= turnaround1;
                    end if;
                when turnaround1 =>
                    if sclk_fedge then
                        phase <= turnaround2;
                    end if;
                when turnaround2 =>
                    if sclk_fedge then
                        phase <= response;
                    end if;
                when response =>
                    if not cs_selected then
                        phase <= idle;
                        cur_opcode <= (others => '0');
                        cmd_length <= (others => '0');
                        turn_known_by <= 0;
                        rem_cmd_bytes <= 0;
                    end if;
            end case;

        end if;
    end process;

    output_shifter : process (clk, reset)
        variable sclk_fedge        : boolean := false;
        variable in_response_phase : boolean := false;
        variable rem_bits          : natural;
    begin
        if reset then
            tx_bit_count <= 0;
            data_in_ready <= '0';
            tx_reg <= (others => '0');
            tx_data_byte_done <= false;
        elsif rising_edge(clk) then
            sclk_fedge := sclk = '0' and sclk_last = '1';
            in_response_phase := phase = response;

            -- clear single cycle flags
            data_in_ready <= '0';
            tx_data_byte_done <= false;

            -- We need to shift something out
            if in_response_phase and sclk_fedge then
                -- no byte pending, so load a new one
                if tx_bit_count = 0 then
                    if data_in_valid = '1' then
                        tx_reg <= data_in;
                        data_in_ready <= '1';
                        tx_bit_count <= 8;
                    end if;
                -- TODO: if we don't have valid data here... what should we do?
                -- mid-byte, shift and subtract
                else
                    tx_reg       <= shift_left(tx_reg, shift_amt);
                    rem_bits := tx_bit_count - shift_amt;
                    tx_bit_count <= rem_bits;
                    if rem_bits = 0 then
                        tx_data_byte_done <= true;
                    end if;
                end if;
            elsif not in_response_phase then
                tx_bit_count <= 0;
                data_in_ready <= '0';
                tx_reg <= (others => '0');
                tx_data_byte_done <= false;
            end if;
        end if;
    end process;

    -- Fairly simple qspi input shifter and sampler
    -- only shifts data in during command phase since
    -- this protocol is not full duplex even in
    -- single-spi mode
    input_shifter : process (clk, reset)
        variable sclk_redge : boolean := false;
        variable rem_bits   : natural range 0 to 8;
    begin
        if reset then
            rx_bit_count <= 8;
            rx_data_byte <= (others => '0');
            rx_data_byte_valid <= false;
        elsif rising_edge(clk) then
            -- build up a couple of combo variables used to make the
            -- code read better below
            sclk_redge := sclk = '1' and sclk_last = '0';

            -- clear any single-cycle flags
            rx_data_byte_valid <= false;

            -- Do the sample/shift when requested and flag the
            -- valid bytes once we have them
            if in_command_phase and sclk_redge then
                -- Shift data by amount depending on mode
                rx_data_byte       <= shift_left(rx_data_byte, shift_amt);
                -- Sample new data into vacated locations
                if cur_qspi_mode = SINGLE then
                    rx_data_byte(0)    <= io(0);
                elsif cur_qspi_mode = DUAL then
                    rx_data_byte(0)    <= io(0);
                    rx_data_byte(1)    <= io(1);
                elsif cur_qspi_mode = QUAD then
                    rx_data_byte(0) <= io(0);
                    rx_data_byte(1) <= io(1);
                    rx_data_byte(2) <= io(2);
                    rx_data_byte(3) <= io(3);
                end if;
                rem_bits := rx_bit_count - shift_amt;
                rx_bit_count <= rem_bits;
                if rem_bits = 0 then
                    rx_data_byte_valid <= true;
                    rx_bit_count <= 8;
                end if;
            end if;
        end if;
    end process;

    -- Deal with output logic for the different modes
    io_o(0) <= tx_reg(4) when cur_qspi_mode = QUAD else
               tx_reg(6) when cur_qspi_mode = DUAL else
               '1'; -- not used due to oe-gate

    io_o(1) <= tx_reg(7) when cur_qspi_mode = SINGLE else
               tx_reg(7) when cur_qspi_mode = DUAL else
               tx_reg(5) when cur_qspi_mode = QUAD else
               '1'; -- not used due to oe-gate
    io_o(2) <= tx_reg(6) when cur_qspi_mode = QUAD else
               '1'; -- not used due to oe-gate
    io_o(3) <= tx_reg(7) when cur_qspi_mode = QUAD else
               '1'; -- not used due to oe-gate

    -- Only used during a quad response
    -- If we need to register these, we can do that in the state machine
    -- above, let's see how this works first
    io_oe(3) <= '1' when cur_qspi_mode = QUAD and phase = response else
                '0';
    -- Only used during a quad response
    io_oe(2) <= '1' when cur_qspi_mode = QUAD and phase = response else
                '0';
    -- Only used during a response, but in all modes
    io_oe(1) <= '1' when phase = response else -- used in *all* modes
                '0';
    -- Only used during a response, but in all modes except single
    io_oe(0) <= '1' when cur_qspi_mode /= SINGLE and phase = response else
                '0';

end rtl;
