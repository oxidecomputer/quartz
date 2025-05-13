-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axi_st8_pkg;
use work.spd_proxy_pkg.all;

entity txn_buffer is
    port(
        clk        : in std_logic;
        reset      : in std_logic;

        regs_if : view regs_buf_buf_side;

        i2c_rx_st_if        : view axi_st8_pkg.axi_st_sink;
        i2c_tx_st_if        : view axi_st8_pkg.axi_st_source;
    );
end entity;

architecture rtl of txn_buffer is
    signal rx_dpr_raddr : std_logic_vector(5 downto 0);
    signal rx_dpr_waddr : std_logic_vector(7 downto 0);
    signal rx_dpr_wen : std_logic;

    signal tx_dpr_raddr : std_logic_vector(7 downto 0);
    signal tx_dpr_waddr : std_logic_vector(5 downto 0);
    signal addr_delay : std_logic;

begin

    -- Write any time we get valid data from the i2c controller
    rx_dpr_wen <= i2c_rx_st_if.valid and i2c_rx_st_if.ready;
    i2c_rx_st_if.ready <= '1';  -- No reason to back pressure

    -- outputs 
    regs_if.rx_waddr <= rx_dpr_waddr;
    regs_if.rx_raddr <= rx_dpr_raddr;
    regs_if.rx_bytes <= rx_dpr_waddr;

    -- We're going to have tx and rx FIFO pointer here.
    -- RX is "easy" at the start of a transaction we 0 the write address
    -- pointer and any data that is rx'd goes into the FIFO.
    -- We also allow the SP to reset the FIFO pointers
     -- management of the FIFO pointers
    rx_fifo_ptrs: process(clk, reset)
     begin
        if reset then
            rx_dpr_raddr <= (others => '0');
            rx_dpr_waddr <= (others => '0');
        elsif rising_edge(clk) then

            -- fifo pointer reset on txn start or by request
            if regs_if.rx_fifo_reset = '1' or regs_if.txn_start = '1' then
                rx_dpr_waddr <= (others => '0');
            elsif rx_dpr_wen = '1' then
                rx_dpr_waddr <= rx_dpr_waddr + 1;
            end if;

            -- fifo pointer reset
            if regs_if.rx_fifo_reset = '1' or regs_if.txn_start = '1' then
                rx_dpr_raddr <= (others => '0');
            -- fifo pointer read and auto-increment
            elsif regs_if.rx_fifo_pop = '1' and regs_if.rx_fifo_auto_inc = '1' then
                rx_dpr_raddr <= rx_dpr_raddr + 1;
            end if;
        end if;
    end process;


    rx_dpr: entity work.mixed_width_simple_dpr
     generic map(
        write_width => 8,
        read_width => 32,
        write_num_words => 256
    )
     port map(
        wclk => clk,
        waddr => rx_dpr_waddr,
        wdata => i2c_rx_st_if.data,
        wren => rx_dpr_wen,
        rclk => clk,
        raddr => rx_dpr_raddr,
        rdata => regs_if.rx_rdata
    );


    tx_fifo_ptrs: process(clk, reset)
     begin
        if reset then
            tx_dpr_raddr <= (others => '0');
            tx_dpr_waddr <= (others => '0');
            addr_delay <= '0';
        elsif rising_edge(clk) then
            addr_delay <= '0';
            -- fifo pointer reset
            if regs_if.tx_fifo_reset = '1' then
                tx_dpr_waddr <= (others => '0');
            elsif regs_if.tx_wen = '1' then
                tx_dpr_waddr <= tx_dpr_waddr + 1;
            end if;

            -- fifo pointer reset
            if regs_if.tx_fifo_reset = '1' or regs_if.txn_start = '1' then
                tx_dpr_raddr <= (others => '0');
            -- fifo pointer read and auto-increment
            elsif i2c_tx_st_if.ready = '1' and i2c_tx_st_if.valid = '1' then
                addr_delay <= '1';
                tx_dpr_raddr <= tx_dpr_raddr + 1;
            end if;
        end if;
    end process;

    tx_dpr: entity work.mixed_width_simple_dpr
     generic map(
        write_width => 32,
        read_width => 8,
        write_num_words => 64,
        reg_output => true

    )
     port map(
        wclk => clk,
        waddr => tx_dpr_waddr,
        wdata => regs_if.tx_wdata,
        wren => regs_if.tx_wen,
        rclk => clk,
        raddr => tx_dpr_raddr,
        rdata => i2c_tx_st_if.data
    );

    -- We register the DPR here so we need a 1 cycle delay after every read addr change
    -- to let the DPR catch up.s
    i2c_tx_st_if.valid <= '1' when addr_delay = '0' else '0';
end rtl;