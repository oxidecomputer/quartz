-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.uart_channel_pkg.all;

use work.calc_pkg.all;

entity uart_channel_top is
    port(
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;
        
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
        pc_free : out std_logic;
        pc_avail: out std_logic;
        np_free : out std_logic;
        np_avail: out std_logic;
    );

end entity;

architecture rtl of uart_channel_top is 
   constant fifo_depth : natural := 4096;
   constant max_msg_size : natural := 1024;
   signal rx_wusedwds : std_logic_vector(log2ceil(fifo_depth) downto 0);
   signal tx_rusedwds : std_logic_vector(log2ceil(fifo_depth) downto 0);
   signal tx_wfull : std_logic;
   signal rx_wfull : std_logic;
   signal tx_rempty : std_logic;
   signal rx_rempty : std_logic;

begin

    -- Not going to support any Non-posted transactions
    -- on this interface
    np_free <= '0';
    np_avail <= '0';
    pc_free <= '1' when fifo_depth - rx_wusedwds >= max_msg_size else '0';
    pc_avail <= not tx_rempty;

    host_to_sp_espi.ready <= not rx_wfull;
    sp_to_host_espi.st.valid <= not tx_rempty;
    sp_to_host_espi.avail_bytes <= resize(tx_rusedwds, sp_to_host_espi.avail_bytes'length);
    to_sp_uart_valid <= not rx_rempty;


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