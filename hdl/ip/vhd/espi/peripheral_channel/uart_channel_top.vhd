-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- This block provides the transaction queueing and management for the peripheral
-- channel. It is responsible for queueing up transactions, issuing bytes to
-- the IPCC SP UART and providing UART response data to the transaction
-- layer.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.uart_channel_pkg.all;

use work.calc_pkg.all;
use work.time_pkg.all;

entity uart_channel_top is
    generic(
        fifo_depth : natural := 4096;
    );
    port(
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        espi_reset : in std_logic;
        enabled : in std_logic;
        stuff_fifo : in std_logic;
        stuff_wds : in std_logic_vector(15 downto 0);
        
        -- eSPI Transaction interface
        host_to_sp_espi : view uart_data_sink;
        sp_to_host_espi : view uart_resp_src;

        -- Interfaces to the UART block
        to_sp_uart_data : out std_logic_vector(7 downto 0);
        to_sp_uart_valid: out std_logic;
        to_sp_uart_ready: in std_logic;
        from_sp_uart_data : in std_logic_vector(7 downto 0);
        from_sp_uart_valid: in std_logic;
        from_sp_uart_ready: out std_logic;

        
        -- eSPI Status interface
        oob_free : out std_logic;
        oob_avail : out std_logic;
        pc_free : out std_logic;
        pc_avail: out std_logic;
        np_free : out std_logic;
        np_avail: out std_logic;
        to_host_tx_fifo_usedwds : out std_logic_vector(log2ceil(fifo_depth) downto 0);
        ipcc_to_host_byte_cntr : out std_logic_vector(31 downto 0);
        host_to_sp_fifo_usedwds : out std_logic_vector(log2ceil(fifo_depth) downto 0);
        -- Sticky: set when oob_free goes low, cleared only by espi_reset
        oob_free_saw_full : out std_logic
    );

end entity;

architecture rtl of uart_channel_top is 
   constant max_msg_size : natural := 64;
   signal rx_wusedwds : std_logic_vector(log2ceil(fifo_depth) downto 0);
   signal tx_rusedwds : std_logic_vector(log2ceil(fifo_depth) downto 0);
   signal tx_wfull : std_logic;
   signal rx_wfull : std_logic;
   signal tx_rempty : std_logic;
   signal rx_rempty : std_logic;
   signal fifo_thresh_timer : std_logic_vector(32 downto 0);
   constant delay_time : std_logic_vector(fifo_thresh_timer'range) := calc_ms(1, 5, fifo_thresh_timer'length);
   signal fifo_read_by_espi : std_logic;
   constant hold_thresh: natural := 32;
   type orphan_state_t is (MASKED, NOT_MASKED);
   signal orphan_state: orphan_state_t;
   constant MAX_CNTS : std_logic_vector(31 downto 0) := (others => '1');
   signal rx_fifo_bleed : std_logic;
   signal tx_fifo_bleed : std_logic;
   signal bleeding : std_logic;
   signal enabled_last : std_logic;
   signal stuff_write : std_logic;
   signal stuff_cntr : std_logic_vector(15 downto 0);

begin

    to_host_tx_fifo_usedwds <= tx_rusedwds;
    host_to_sp_fifo_usedwds <= rx_wusedwds;

    -- Not going to support any Non-posted transactions
    -- on this interface
    np_free <= '0';
    np_avail <= '0';
    pc_free <= '1' when (fifo_depth - rx_wusedwds) >= max_msg_size else '0';
    pc_avail <= '0';
    oob_free <= '1' when (fifo_depth - rx_wusedwds) >= max_msg_size else '0';
    oob_avail <= '1' when orphan_state = NOT_MASKED else '0';

    host_to_sp_espi.ready <= not rx_wfull;
    -- tx_rusedwds is potentially cycles behind the empty flag due to fifo latencies.
    -- since we're using it in the avail bytes, we need to ensure we're at least > 0
    sp_to_host_espi.st.valid <= '1' when tx_rempty /= '1' and tx_rusedwds > 0 else '0';
    sp_to_host_espi.avail_bytes <= resize(tx_rusedwds, sp_to_host_espi.avail_bytes'length);
    to_sp_uart_valid <= not rx_rempty;

    fifo_read_by_espi <= sp_to_host_espi.st.valid and sp_to_host_espi.st.ready;

    -- We want to hold some data to let the bytes accumulate
    -- so that we're not doing multiple transactions (which are multi-byte)
    -- not avail:
    --   when we're below the used words threshold, but not empty run a timer
    --   timer expires, move to avail
    --   cross the threshold, move to avail
    --  avail:
    --   if we read down to empty, move to not avail
    
    orphan_timer: process(clk, reset)
    begin
        if reset then
            fifo_thresh_timer <= (others => '0');
            orphan_state <= MASKED;
        elsif rising_edge(clk) then
            case orphan_state is
                when MASKED =>
                    if tx_rempty = '1' then
                        -- nothing going on, clear the timer
                        fifo_thresh_timer <= (others => '0');
                    elsif tx_rusedwds < hold_thresh and fifo_thresh_timer < delay_time then
                        -- count when not empty but below the threshold
                        fifo_thresh_timer <= fifo_thresh_timer + 1;
                    elsif tx_rusedwds >= hold_thresh or fifo_thresh_timer >= delay_time then
                        -- we're above the threshold or the timer expired
                        orphan_state <= NOT_MASKED;
                    end if;

                when NOT_MASKED =>
                    if tx_rempty = '1' then
                        -- we've emptied the fifo, go back to masked
                        fifo_thresh_timer <= (others => '0');
                        orphan_state <= MASKED;
                    end if;
            end case;

            if espi_reset then
                fifo_thresh_timer <= (others => '0');
                orphan_state <= MASKED;
            end if;
        end if;
    end process;

    dbg_rx_bytes_cntr: process(clk, reset)
    begin
        if reset = '1' then
            ipcc_to_host_byte_cntr <= (others => '0');
        elsif rising_edge(clk) then
            if espi_reset then
                ipcc_to_host_byte_cntr <= (others => '0');
            elsif ((from_sp_uart_valid = '1' and from_sp_uart_ready = '1') or stuff_write = '1') and ipcc_to_host_byte_cntr < MAX_CNTS then
                ipcc_to_host_byte_cntr <= ipcc_to_host_byte_cntr + 1;
            end if;

        end if;
    end process;

    dummy_stuffer: process(clk, reset)
        variable enabled_redge: std_logic;
    begin
        if reset then
            enabled_last <= '1';
            stuff_cntr <= (others => '0');
            stuff_write <= '0';
        elsif rising_edge(clk) then
            enabled_last <= enabled;
            enabled_redge := enabled and not enabled_last;   
            if stuff_fifo = '1' and enabled_redge = '1' then
                stuff_cntr <= stuff_wds;
            end if;
            if stuff_cntr > 0 then
                stuff_write <= '1';
                stuff_cntr <= stuff_cntr - 1;
            else
                stuff_write <= '0';
            end if;
        end if;
    end process;

    -- Accept UART data any time we have space and are enabled
    from_sp_uart_ready <= not tx_wfull and enabled;

    -- XPM FIFOs have annoying reset limitations. Rather than fight this, here's a simple state machine
    -- that will bleed them empty on an espi reset. This takes cycles depending on how full the FIFOs are,
    -- but we don't expect UART data to begin until we're booted so we have plenty of time.
    fifo_drain_sm: process(clk, reset)
    begin
        if reset = '1' then
            rx_fifo_bleed <= '0';
            tx_fifo_bleed <= '0';
            bleeding <= '0';
        elsif rising_edge(clk) then
            if espi_reset then
                rx_fifo_bleed <= '1';
                tx_fifo_bleed <= '1';
                bleeding <= '1';
            elsif bleeding then
                rx_fifo_bleed <= not rx_rempty;
                tx_fifo_bleed <= not tx_rempty;
                if rx_rempty = '1' and tx_rempty = '1' then
                    bleeding <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Sticky detector: captures if oob_free ever went low since last espi_reset
    oob_free_sticky: process(clk, reset)
    begin
        if reset then
            oob_free_saw_full <= '0';
        elsif rising_edge(clk) then
            if espi_reset then
                oob_free_saw_full <= '0';
            elsif oob_free = '0' and enabled = '1' then
                oob_free_saw_full <= '1';
            end if;
        end if;
    end process;

    from_host_rx_fifo: entity work.dcfifo_xpm
     generic map(
        fifo_write_depth => fifo_depth,
        data_width => 8,
        showahead_mode => true
    )
     port map(
        wclk => clk,
        reset => reset,
        write_en => host_to_sp_espi.ready and host_to_sp_espi.valid,
        wdata => host_to_sp_espi.data,
        wfull => rx_wfull,
        wusedwds => rx_wusedwds,
        rclk => clk,
        rdata => to_sp_uart_data,
        rdreq => (to_sp_uart_valid and to_sp_uart_ready) or rx_fifo_bleed,
        rempty => rx_rempty,
        rusedwds => open
    );

    to_host_tx_fifo: entity work.dcfifo_xpm
     generic map(
        fifo_write_depth => fifo_depth,
        data_width => 8,
        showahead_mode => true
    )
     port map(
        wclk => clk,
        reset => reset,
        write_en => (from_sp_uart_valid and from_sp_uart_ready) or stuff_write,
        wdata => from_sp_uart_data,
        wfull => tx_wfull,
        wusedwds => open,
        rclk => clk,
        rdata => sp_to_host_espi.st.data,
        rdreq => fifo_read_by_espi or tx_fifo_bleed,
        rempty => tx_rempty,
        rusedwds => tx_rusedwds
    );

end architecture;