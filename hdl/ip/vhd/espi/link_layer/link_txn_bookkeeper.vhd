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

entity link_txn_bookkeeper is
    port (
        clk   : in    std_logic; -- 200MHz clock.
        reset : in    std_logic; -- 200Mhz reset.

        -- PHY signals (sync'd where applicable)
        cs_n  : in    std_logic;
        sclk  : in    std_logic;
        io_oe : out   std_logic_vector(3 downto 0);
        response_csn : out std_logic;  --  "Fake" chipselect to help saleae decoding
        phy_cmd : in std_logic_vector(8 downto 0);
        phy_resp : out std_logic_vector(8 downto 0);
        phy_resp_ack : in std_logic;

        -- System interface
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

architecture rtl of link_txn_bookkeeper is
    type state_t is (IDLE, CMD_PHASE, TA0, TA1, RESP_PHASE);
    type reg_t is record
        state : state_t;
        edge_cnts : std_logic_vector(1 downto 0);
    end record;
    signal r, rin: reg_t;
    constant rec_reset: reg_t := (
        state => IDLE,
        edge_cnts => (others => '0')
    );
    signal phy_cmd_syncd : std_logic_vector(8 downto 0);
    signal sclk_syncd : std_logic;
    signal cs_n_syncd : std_logic;
    signal sclk_cnts : std_logic_vector(15 downto 0);
    signal sclk_last : std_logic;
    signal sclk_redge : std_logic;
    signal sclk_fedge : std_logic;
    signal command_byte_cnt : std_logic_vector(15 downto 0);
    signal cmd_data : std_logic_vector(7 downto 0);
    signal cmd_valid : std_logic;
    signal cmd_phy_valid_last : std_logic;
    signal phy_resp_ack_syncd : std_logic;
    signal size_info : size_info_t;
    signal cmd_byte_done : std_logic;
    
    
begin

    tacd_inst: entity work.tacd
     port map(
        clk_launch => sclk_syncd,
        reset_launch => not cs_n,
        pulse_in_launch => phy_resp_ack,
        clk_latch => clk,
        reset_latch => reset,
        pulse_out_latch => phy_resp_ack_syncd
    );

    -- One or more pass-through registers from the SPI CLK domain
    sync_regs: process(clk, reset) begin
        if reset = '1' then
            phy_cmd_syncd <= (others => '0');
            sclk_syncd <= '0';
            cs_n_syncd <= '1';  -- Active low, so reset to high
        elsif rising_edge(clk) then
            phy_cmd_syncd <= phy_cmd;
            sclk_syncd <= sclk;
            cs_n_syncd <= cs_n;
        end if;
    end process sync_regs;

    -- sclk counter for sorting out transactions
    shared_state:process(clk, reset)
    begin
        if reset = '1' then
            sclk_last <= '0';
            sclk_cnts <= (others => '0');
        elsif rising_edge(clk) then
            sclk_last <= sclk_syncd;  -- Capture the last state of sclk
            if cs_n_syncd = '0' and sclk_redge = '1' then
            sclk_cnts <= sclk_cnts + 1;
        elsif cs_n_syncd = '1' then
            sclk_cnts <= (others => '0');
        end if;
    end if;
    end process;
    sclk_redge <= sclk_syncd and not sclk_last;  -- Rising edge detection
    sclk_fedge <= not sclk_syncd and sclk_last;  -- Falling edge detection
    -- Helpful to keep track of bytes completed in the transaction.  Note that this is for the command
    -- phase, and we'll be off by 2 sclk cycles due to the turnaround phase.
    command_byte_cnt <= shift_right(sclk_cnts, get_sclk_to_bytes_shift_amt_by_mode(qspi_mode));

    -- We're not hand-shaking across domains like a normal streaming interface.
    --
    -- On the data from the deserializer (incoming data from the host) it will assume
    -- we're always ready. We have to detect edges of the valid signal to know when
    -- a byte is ready. The PHY samples on the rising edge of the sclk so we can
    -- use our delayed sclk redge as part of the valid detection logic.
    --
    -- On the data to the serializer, we will always present valid data in the response phase and 
    -- we'll know when the PHY has sampled via
    -- a toggle sync. This happens "later" than the actual transfer but we can use it to fake an
    -- AXI interface and control the flow of data to the PHY.

    -- TODO: do we need sclk delayed 1 more clock to deal with cmd stability?
    phy_if:process(clk, reset)
    begin
        if reset = '1' then
            cmd_data <= (others => '0');
            cmd_valid <= '0';
            cmd_phy_valid_last <= '0';
        elsif rising_edge(clk) then
            -- CMD Side
            -- clear valid on transfer
            if cmd_valid = '1' and cmd_to_fifo.ready = '1' then
                cmd_valid <= '0';
            end if;
            if sclk_redge = '1' and cs_n_syncd = '0' then
                -- Every redge we store the "valid" bit to create a rising edge detector.
                -- the "valid" bit is already in the fast domain, so we can use it directly.
                cmd_phy_valid_last <= phy_cmd_syncd(8);
                -- We may have a new command byte ready from the phy
                if cmd_phy_valid_last = '0' and phy_cmd_syncd(8) = '1' then
                    -- We have a new command byte ready
                    cmd_data <= phy_cmd_syncd(7 downto 0);
                    cmd_valid <= '1';
                end if;
            end if;

        end if;
    end process;
    cmd_to_fifo.data <= cmd_data;
    cmd_to_fifo.valid <= cmd_valid;
    -- Feed directly out of the streaming interface from the FIFO
    phy_resp <= resp_from_fifo.valid & resp_from_fifo.data;
    resp_from_fifo.ready <= phy_resp_ack_syncd;  -- We can always accept data from the FIFO

    cmd_byte_done <= cmd_to_fifo.valid and cmd_to_fifo.ready;

    size_finder: entity work.cmd_sizer
     port map(
        clk => clk,
        reset => reset,
        cs_n => cs_n,
        cmd => cmd_to_fifo,
        size_info => size_info,
        espi_reset => espi_reset
    );

    next_state_logic: process(all)
        variable v : reg_t;
    begin
        v := r;
        case r.state is
            when IDLE =>
                if cs_n_syncd = '0' then
                    v.state := CMD_PHASE;
                end if;

            when CMD_PHASE =>
                -- We're in the command phase until we have a valid size, and we've finished size bytes.
                if size_info.valid = '1' and cmd_byte_done = '1' and command_byte_cnt = size_info.size - 1 then
                    v.state := TA0;
                end if;
                
            when TA0 =>
                -- Wait for turnaround phase 0
                if sclk_redge or sclk_fedge then
                    v.edge_cnts := r.edge_cnts + 1;
                end if;
                if v.edge_cnts = 2 then
                    -- We have 2 edges, so we can move to the next state
                    v.state := TA1;
                    v.edge_cnts := (others => '0');  -- Reset edge count
                end if;

            when TA1 =>
                -- Wait for turnaround phase 1
                if sclk_redge or sclk_fedge then
                    -- We can go 1/2 clock early into response phase by spec.
                    v.state := RESP_PHASE;
                end if;

            when RESP_PHASE =>
                null;  -- Stay in response phase until reset or cs_n goes high

        end case;

        -- always restart
        if cs_n_syncd = '1' then
            -- If we see a cs_n high, we reset the state machine
            v.state := IDLE;
            v.edge_cnts := (others => '0');  -- Reset edge count
        end if;

        rin <= v;
    end process;

    regs_proc: process(clk, reset)
    begin
        if reset = '1' then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;
end rtl;