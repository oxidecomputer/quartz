-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Harness for eth_mgmt + mgmt_flash against a behavioral SPI flash. The
-- bench stands in for udp_endpoint: it drives the datagram RX interface and
-- consumes the TX interface directly. A small memory map keeps the flash
-- model tractable: identity sectors at 0x0000/0x1000, a fake 8 KiB
-- application region at 0x2000.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;
use work.eth_mgmt_pkg.all;

entity eth_mgmt_th is
end entity;

architecture th of eth_mgmt_th is

    constant TH_DEFAULT_MAC : mac_addr_t := X"020A0B0C0D0E";

    signal clk      : std_logic := '0';
    signal por      : std_logic := '1';
    signal tb_reset : std_logic := '0';
    signal reset    : std_logic;

    signal rx       : udp_st_t := UDP_ST_IDLE;
    signal rx_meta  : udp_rx_meta_t := (
        src_ip => (others => '0'), src_port => (others => '0'),
        dst_port => (others => '0'), length => (others => '0'));
    signal rx_ready : std_logic;
    signal tx       : udp_st_t;
    signal tx_meta  : udp_tx_meta_t;
    signal tx_ready : std_logic := '1';

    signal mac       : mac_addr_t;
    signal mac_valid : std_logic;
    signal mac_is_default : std_logic;

    -- what udp_endpoint would report in the real design
    signal endpoint_status : endpoint_status_t := (
        ip => link_local_from_mac(TH_DEFAULT_MAC), ip_valid => '1');

    signal f_req      : std_logic;
    signal f_op       : flash_op_t;
    signal f_addr     : std_logic_vector(31 downto 0);
    signal f_len      : unsigned(8 downto 0);
    signal f_busy     : std_logic;
    signal f_done     : std_logic;
    signal f_wr_data  : std_logic_vector(7 downto 0);
    signal f_wr_ack   : std_logic;
    signal f_rd_data  : std_logic_vector(7 downto 0);
    signal f_rd_valid : std_logic;

    signal cs_n  : std_logic;
    signal sclk  : std_logic;
    signal io    : std_logic_vector(3 downto 0);
    signal io_o  : std_logic_vector(3 downto 0);
    signal io_oe : std_logic_vector(3 downto 0);
    signal miso  : std_logic := '0';

begin

    clk <= not clk after 4 ns;
    por <= '0' after 200 ns;
    reset <= por or tb_reset;

    dut: entity work.eth_mgmt
        generic map (
            DEFAULT_MAC    => TH_DEFAULT_MAC,
            DEFAULT_SERIAL => (others => '0'),
            APP_IMAGE_BASE => X"00002000",
            APP_IMAGE_SIZE => X"00002000",
            IDENTITY_BASE  => X"00000000"
        )
        port map (
            clk             => clk,
            reset           => reset,
            fpga_version    => X"DEADBEEF",
            endpoint_status => endpoint_status,
            mac             => mac,
            mac_valid       => mac_valid,
            mac_is_default  => mac_is_default,
            rx              => rx,
            rx_meta         => rx_meta,
            rx_ready        => rx_ready,
            tx              => tx,
            tx_meta         => tx_meta,
            tx_ready        => tx_ready,
            f_req           => f_req,
            f_op            => f_op,
            f_addr          => f_addr,
            f_len           => f_len,
            f_busy          => f_busy,
            f_done          => f_done,
            f_wr_data       => f_wr_data,
            f_wr_ack        => f_wr_ack,
            f_rd_data       => f_rd_data,
            f_rd_valid      => f_rd_valid
        );

    flash_seq: entity work.mgmt_flash
        generic map (
            SCLK_DIVISOR => to_unsigned(2, 16)
        )
        port map (
            clk      => clk,
            reset    => reset,
            req      => f_req,
            op       => f_op,
            addr     => f_addr,
            len      => f_len,
            busy     => f_busy,
            done     => f_done,
            wr_data  => f_wr_data,
            wr_ack   => f_wr_ack,
            rd_data  => f_rd_data,
            rd_valid => f_rd_valid,
            cs_n     => cs_n,
            sclk     => sclk,
            io       => io,
            io_o     => io_o,
            io_oe    => io_oe
        );

    io <= "00" & miso & io_o(0);

    flash_model: entity work.sim_spi_flash
        generic map (
            MEM_BYTES => 16384,
            BUSY_TIME => 2 us
        )
        port map (
            cs_n => cs_n,
            sclk => sclk,
            mosi => io_o(0),
            miso => miso
        );

end th;
