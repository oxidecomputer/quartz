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
    port(
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;
        
        -- eSPI Transaction interface
        host_to_sp_espi : view uart_data_sink;
        sp_to_host_espi : view uart_resp_src;

        -- registers
        msg_not_oob: in std_logic;

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
    );

end entity;

architecture rtl of uart_channel_top is 
   constant fifo_depth : natural := 4096;
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
   signal  pc_avail_not_masked : std_logic;
   signal msg_not_oob_syncd : std_logic;
   constant hold_thresh: natural := 32;

begin

    meta_sync_inst: entity work.meta_sync
     port map(
        async_input => msg_not_oob,
        clk => clk,
        sycnd_output => msg_not_oob_syncd
    );

    -- Not going to support any Non-posted transactions
    -- on this interface
    np_free <= '0';
    np_avail <= '0';
    pc_free <= '1' when (fifo_depth - rx_wusedwds) >= max_msg_size else '0';
    pc_avail <= (not tx_rempty) and pc_avail_not_masked and msg_not_oob_syncd;
    oob_free <= '1' when (fifo_depth - rx_wusedwds) >= max_msg_size else '0';
    oob_avail <= (not tx_rempty) and pc_avail_not_masked and (not msg_not_oob_syncd);

    host_to_sp_espi.ready <= not rx_wfull;
    -- tx_rusedwds is potentailly cycles behind the empty flag due to fifo latencies.
    -- since we're using it in the avail bytes, we need to ensure we're at least > 0
    sp_to_host_espi.st.valid <= '1' when tx_rempty /= '1' and tx_rusedwds > 0 else '0';
    sp_to_host_espi.avail_bytes <= resize(tx_rusedwds, sp_to_host_espi.avail_bytes'length);
    to_sp_uart_valid <= not rx_rempty;

    fifo_read_by_espi <= sp_to_host_espi.st.valid and sp_to_host_espi.st.ready;

    -- We want to hold some data to let the bytes accumulate
    -- so that we're not doing multiple transactions (which are multi-byte)
    -- but just transferring 1-2 bytes at a time.
    -- above the threshold, let it run
    -- below the threshold timer runs
    -- read resets the timer
    -- empty timer doesn't run, masked
    orphan_timer: process(clk)
    begin
        if reset then
            fifo_thresh_timer <= (others => '0');
            pc_avail_not_masked <= '0';
        elsif rising_edge(clk) then
            pc_avail_not_masked <= '0';  -- 
            -- Any read or empty fifo resets the timer
            if fifo_read_by_espi = '1' or tx_rempty = '1' then
                fifo_thresh_timer <= (others => '0');
            -- below the threshold, timer runs
            elsif tx_rusedwds < hold_thresh and fifo_thresh_timer < delay_time then
                fifo_thresh_timer <= fifo_thresh_timer + 1;
            elsif tx_rusedwds >= hold_thresh or fifo_thresh_timer = delay_time then
                pc_avail_not_masked <= '1';
            end if;
        end if;
    end process;

    -- Accept UART data any time we have space
    from_sp_uart_ready <= not tx_wfull;

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
        rdreq => to_sp_uart_valid and to_sp_uart_ready,
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
        write_en => from_sp_uart_valid and from_sp_uart_ready,
        wdata => from_sp_uart_data,
        wfull => tx_wfull,
        wusedwds => open,
        rclk => clk,
        rdata => sp_to_host_espi.st.data,
        rdreq => sp_to_host_espi.st.valid and sp_to_host_espi.st.ready,
        rempty => tx_rempty,
        rusedwds => tx_rusedwds
    );

end architecture;