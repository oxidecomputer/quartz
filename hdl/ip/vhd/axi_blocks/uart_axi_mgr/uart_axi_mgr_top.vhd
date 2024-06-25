-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_axi_mgr_top is
    port (
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        -- AXI lite manager interface
        -- Write addr channel
        awvalid : out   std_logic;
        awready : in    std_logic;
        awaddr  : out   std_logic_vector(25 downto 0);
        awprot  : out   std_logic_vector(2 downto 0);
        -- Write data channel
        wvalid : out   std_logic;
        wready : in    std_logic;
        wstrb  : out   std_logic_vector(3 downto 0);
        wdata  : out   std_logic_vector(31 downto 0);
        -- Write response channel
        bvalid : in    std_logic;
        bready : out   std_logic;
        -- Read address channel
        arvalid : out   std_logic;
        araddr  : out   std_logic_vector(25 downto 0);
        arready : in    std_logic;
        -- Read data channel
        rvalid : in    std_logic;
        rready : out   std_logic;
        rdata  : in    std_logic_vector(31 downto 0);

        -- UART interface
        tx_pin : out std_logic;
        rx_pin : in std_logic;

    );
end entity;

architecture rtl of uart_axi_mgr is
    signal uart_st_byte_rx_data : std_logic_vector(7 downto 0);
    signal uart_st_byte_rx_valid : std_logic;
    signal uart_st_byte_tx_data : std_logic_vector(7 downto 0);
    signal uart_st_byte_tx_valid : std_logic;
    signal uart_st_byte_tx_ready : std_logic;


begin

    axi_st_uart_inst: entity work.axi_st_uart
     generic map(
        CLK_DIV => CLK_DIV,
        parity => false
    )
     port map(
        clk => clk,
        reset => reset,
        rx_pin => rx_pin,
        tx_pin => tx_pin,
        rx_data => uart_st_byte_rx_data,
        rx_valid => uart_st_byte_rx_valid,
        tx_data => uart_st_byte_tx_data,
        tx_valid => uart_st_byte_tx_valid,
        tx_ready => uart_st_byte_tx_ready
    );

    -- From UART byte-wise to AXI stream packets
    axi_st_bytes_to_packets_inst: entity work.axi_st_bytes_to_packets
     port map(
        clk => clk,
        reset => reset,
        byte_tdata => uart_st_byte_rx_data,
        byte_tvalid => uart_st_byte_rx_valid,
        byte_tready => open,  -- No backpressure supported right now at UART
        pkt_tdata => pkt_tdata,
        pkt_tvalid => pkt_tvalid,
        pkt_tready => pkt_tready,
        pkt_tlast => pkt_tlast
    );

    -- From AXI stream packets to UART byte-wise
    axi_st_packets_to_bytes_inst: entity work.axi_st_packets_to_bytes
     port map(
        clk => clk,
        reset => reset,
        byte_tdata => uart_st_byte_tx_data,
        byte_tvalid => uart_st_byte_tx_valid,
        byte_tready => uart_st_byte_tx_ready,
        pkt_tdata => pkt_tdata,
        pkt_tvalid => pkt_tvalid,
        pkt_tready => pkt_tready,
        pkt_tlast => pkt_tlast
    );

end rtl;