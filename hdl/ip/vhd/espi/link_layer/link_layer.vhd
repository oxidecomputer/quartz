-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_base_types_pkg.all;
use work.espi_protocol_pkg.all;
use work.link_layer_pkg.all;

entity link_layer is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

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

architecture rtl of link_layer is
    signal sclk_cnts : std_logic_vector(15 downto 0);
    signal sclk_last : std_logic;
    signal in_command_phase : boolean;
    signal in_turnaround_phase : boolean;
    signal in_response_phase : boolean;
    signal completed_byte_cnt : std_logic_vector(sclk_cnts'range);
    signal rx_reg : std_logic_vector(8 downto 0);
    signal tx_reg : std_logic_vector(8 downto 0);
    signal qspi_shift_amt        : natural range 1 to 4 := 1;
    signal txn_qspi_mode        : qspi_mode_t;
    signal size_info : size_info_t;
    signal csn_last : std_logic;
    signal response_byte_ack : std_logic;
    signal send_waits : std_logic;
    signal rem_waits : std_logic_vector(3 downto 0);
    signal response_post_mux : byte_stream;
    signal cmd_from_host : byte_stream;
    signal active_alert : std_logic;
    signal ta_edge_vec : std_logic_vector(3 downto 0);
    signal in_response_phase_delayed : boolean;
    

begin

    -- Simple sclk counter for debug and response-phase tracking
    shared_status: process(clk, reset)
        variable sclk_redge : boolean := false;
    begin
        if reset then
            sclk_cnts <= (others => '0');
            sclk_last <= '0';
            csn_last <= '1';
        elsif rising_edge(clk) then
            sclk_redge := sclk = '1' and sclk_last = '0';
            sclk_last <= sclk;
            csn_last <= cs_n;
            -- count rising sclk edges when we're in a transaction
            if cs_n = '0' and sclk_redge then
                sclk_cnts <= sclk_cnts + 1;
            elsif cs_n = '1' then
                sclk_cnts <= (others => '0');
            end if;
            -- latch current qspi mode for this transaction
            if cs_n = '0' and csn_last = '1' then
                txn_qspi_mode <= qspi_mode;
            end if;
        end if;
    end process;


    -- Saleae is made decoding spi signals if they are not byte-aligned with the enable
    -- our responses are always shifted by 2 clocks due to the TA phase so this provides
    -- a fake enable that allows us to run a 2nd decoder for the response channel
    saleae_response_cs_gen: process(clk, reset)
        variable sclk_fedge : boolean := false;
    begin
        if reset then
            response_csn <= '1';
        elsif rising_edge(clk) then
            sclk_fedge := sclk = '0' and sclk_last = '1';
            if response_csn = '1' and in_response_phase and sclk_fedge then
                response_csn <= '0';
            elsif cs_n = '1' then
                response_csn <= '1';
            end if;

        end if;
    end process;

    process(clk, reset)
        variable sclk_any_edge : boolean := false;
    begin
        if reset then
            ta_edge_vec <= (0 => '1', others => '0');
        elsif rising_edge(clk) then
            sclk_any_edge := sclk /= sclk_last;
            if in_turnaround_phase and sclk_any_edge then
                ta_edge_vec <= shift_left(ta_edge_vec, 1);
            elsif cs_n = '1' then
                ta_edge_vec <= (0 => '1', others => '0');
            end if;
           
        end if;
    end process;

    -- Transaction tracking: We need to know where we are in the transaction so this stuff helps
    -- along with a light "parser" for the commands.
    -- There is no crc checking here, so if we never see a valid size in the parser we just don't
    -- run anything in the response phase.
    completed_byte_cnt <= shift_right(sclk_cnts, get_sclk_to_bytes_shift_amt_by_mode(txn_qspi_mode));
    in_command_phase <= true when cs_n = '0' and (size_info.valid = '0' or (size_info.valid = '1' and completed_byte_cnt < (size_info.size))) else false;
    -- note this starts 1/2 a cycle early so that we shift out on the last TA edge per spec
    in_turnaround_phase <= true when size_info.valid = '1' and (completed_byte_cnt = size_info.size and (not in_response_phase)) else false;
    in_response_phase <= true when ta_edge_vec(ta_edge_vec'left) else false;

    size_finder: entity work.cmd_sizer
     port map(
        clk => clk,
        reset => reset,
        cs_n => cs_n,
        cmd => cmd_from_host,
        size_info => size_info,
        espi_reset => espi_reset
    );

    cmd_from_host.data <= cmd_to_fifo.data;
    cmd_from_host.valid <= cmd_to_fifo.valid;
    cmd_from_host.ready <= cmd_to_fifo.ready;

    cmd_to_fifo.data <= rx_reg(7 downto 0);
    cmd_to_fifo.valid <= rx_reg(rx_reg'high);

    qspi_shift_amt <= get_qspi_shift_amt_by_mode(txn_qspi_mode);
    --- This is the main "command" deserializer. The internal 
    -- register is 9 bits wide using a sentinel value in the
    -- LSB so that we don't need bit counters here.
    -- We know we're done with a byte when the MSB is '1'
    -- This bit can also function as the valid flag
    cmd_deserializer : process (clk, reset)
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
            if in_command_phase and sclk_redge then
                -- Shift data by amount depending on mode
                rx_reg       <= shift_left(rx_reg, qspi_shift_amt);
                -- Sample new data into vacated locations
                if txn_qspi_mode = SINGLE then
                    rx_reg(0)    <= io(0);
                elsif txn_qspi_mode = DUAL then
                    rx_reg(0)    <= io(0);
                    rx_reg(1)    <= io(1);
                elsif txn_qspi_mode = QUAD then
                    rx_reg(0) <= io(0);
                    rx_reg(1) <= io(1);
                    rx_reg(2) <= io(2);
                    rx_reg(3) <= io(3);
                end if;
            elsif (cs_n = '1') or rx_reg(rx_reg'high) = '1' then
                -- Reset shifter to sentinel value when we become
                -- de-selected, or once we've strobed the valid
                rx_reg <= (rx_reg'low => '1', others => '0');
            end if;
        end if;
    end process;

    -- Due to the clock domain cross, we're going to send some wait states
    -- on every response so that the data exists when we send the response.
    -- The number of wait states is determined by the operating mode and
    -- operating frequency. This decision is made in the slower domain
    -- and the resulting number of wait states are set here. We send this
    -- many wait states immediately after the turn-around phase, then
    -- we pop the response from the FIFOs. Any time the fifo is empty
    -- we will send 0xFF which will deal with shoving the lines high
    -- at the end of the transaction.
    response_mux_ctrl: process(clk, reset)
        variable csn_fedge : boolean := false;
        variable response_xfr : boolean := false;
    begin
        if reset = '1' then
            rem_waits <= (others => '0');
            send_waits <= '1';
        elsif rising_edge(clk) then
            -- helper variables
            csn_fedge := cs_n = '0' and csn_last = '1';
            response_xfr := true when response_post_mux.valid and response_post_mux.ready else false;
            if csn_fedge then
                rem_waits <= wait_states - 1; -- 0 indexed
                send_waits <= '1';
            elsif rem_waits > 0 and response_xfr then
                rem_waits <= rem_waits - 1;
            elsif rem_waits = 0 and response_xfr then
                send_waits <= '0';
            end if;
        end if;
    end process;

    resp_mux: process(all)
    begin
        -- we're sending wait-states, don't pop the fifo
        if send_waits then
            response_post_mux.data <= wait_state_code;
            response_post_mux.valid <= '1';
            response_post_mux.ready <= response_byte_ack;
            resp_from_fifo.ready <= '0';
        elsif resp_from_fifo.valid then  -- data in fifo
            response_post_mux.data <= resp_from_fifo.data;
            response_post_mux.valid <= resp_from_fifo.valid;
            response_post_mux.ready <= response_byte_ack;  -- a don't care really
            resp_from_fifo.ready <= response_byte_ack;
        else  -- empty fifo send 1's to pull lines high
            response_post_mux.data <= (others => '1');
            response_post_mux.valid <= '1';
            response_post_mux.ready <= response_byte_ack;
            resp_from_fifo.ready <= '0';
        end if;
    end process;




    -- This is the main "response" serializer. The internal 
    -- register is 9 bits wide using a sentinel value in the
    -- LSB so that we don't need bit counters here.
    -- We know we're done with a byte when the MSB is '1'
    -- and all the other bits are '0' b/c we've shifted the
    -- sentinel up 8x
    response_serializer: process (clk, reset)
        variable sclk_fedge        : boolean := false;
        variable cs_fedge          : boolean := false;
    begin
        if reset then
            tx_reg <= (tx_reg'high => '1', tx_reg'high -1 => '1', others => '0');
            response_byte_ack <= '0';
        elsif rising_edge(clk) then
            sclk_fedge := sclk = '0' and sclk_last = '1';
            cs_fedge := cs_n = '0' and csn_last = '1';
            -- clear single-cycle flags
            response_byte_ack <= '0';
                -- Main serializer logic, shift out on sclk_fedge
            -- when we're chip-selected and not doing turnaround
            if cs_fedge then
                -- set sentinel value before we see sclks on a new transaction
                tx_reg <= (tx_reg'high => '1', tx_reg'high -1 => '1', others => '0');
            elsif cs_n = '0' and in_response_phase and sclk_fedge then
                -- if next-shift would be our sentinal value, load new data
                if shift_left(tx_reg, qspi_shift_amt) = "100000000" then
                    -- tx_register is "empty" load a new one
                    -- and the sentinal value
                        tx_reg(8 downto 1) <= response_post_mux.data;
                        tx_reg(tx_reg'low) <= '1';
                        -- strobe ready since we grabbed the value
                        response_byte_ack <= '1';
                -- mid-byte, shift
                else 
                    tx_reg       <= shift_left(tx_reg, qspi_shift_amt);
                end if;
            end if;
        end if;
    end process;


    alert_gen_inst: entity work.alert_gen
     port map(
        clk => clk,
        reset => reset,
        alert_needed => alert_needed,
        cs_n => cs_n,
        active_alert => active_alert
    );



    -- Based on state and qspi mode, deal with the tri-state controls
    -- of the spi pins
    oe_control: process(clk, reset)
    begin
        if reset then
            io_oe <= (others => '0');
        elsif rising_edge(clk) then
            if in_response_phase then
                case txn_qspi_mode is
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
    io_o(0) <= tx_reg(tx_reg'high-3) when txn_qspi_mode = QUAD else
        tx_reg(tx_reg'high-1) when txn_qspi_mode = DUAL else
        '1'; -- not used due to oe-gate

    io_o(1) <= '0' when active_alert else
            tx_reg(tx_reg'high) when txn_qspi_mode = SINGLE else
            tx_reg(tx_reg'high) when txn_qspi_mode = DUAL else
            tx_reg(tx_reg'high-2) when txn_qspi_mode = QUAD else
            '1'; -- not used due to oe-gate
    io_o(2) <= tx_reg(tx_reg'high - 1);
    io_o(3) <= tx_reg(tx_reg'high);



end architecture;