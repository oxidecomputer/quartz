-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.i2c_common_pkg.all;
use work.axi_st8_pkg;
use work.axil8x32_pkg;
use work.time_pkg.all;
use work.tristate_if_pkg.all;
use work.spd_proxy_regs_pkg.all;

entity fpga_spd_ctrl is
    port(
        clk : in std_logic;
        reset : in std_logic;
        -- AXI-Lite interface
        axi_if : view axil8x32_pkg.axil_target;

        -- FPGA I2C Interface
        i2c_command         : out cmd_t;
        i2c_command_valid   : out std_logic;
        i2c_ctrlr_idle      : in std_logic;
        i2c_tx_st_if        : view axi_st8_pkg.axi_st_source;
        i2c_rx_st_if        : view axi_st8_pkg.axi_st_sink;
    );
end entity;

architecture rtl of fpga_spd_ctrl is
    signal active_read : std_logic;
    signal active_write : std_logic;
    signal cmd : spd_cmd_type;
    signal fifo_ctrl : fifo_ctrl_type;
    signal valid_flag : std_logic;
    signal fifo_write_flag : std_logic;
    signal fifo_wdata : std_logic_vector(31 downto 0);
    signal rdata : std_logic_vector(31 downto 0);
    signal rx_dpr_raddr : std_logic_vector(5 downto 0);
    signal rx_dpr_rdata : std_logic_vector(31 downto 0);
    signal rx_dpr_waddr : std_logic_vector(7 downto 0);
    signal rx_dpr_wen : std_logic;
    signal rx_dpr_pop : std_logic;
    signal rx_fifo_waddr : rx_fifo_waddr_type;
    signal rx_fifo_raddr : rx_fifo_raddr_type;
    signal rx_fifo_data_avail : rx_fifo_data_avail_type;



    function mk_op(cmd : spd_cmd_type) return op_t is
    begin
        if to_integer(cmd.op) <= 2 then
            return op_t'val(to_integer(cmd.op));
        else
            assert false report "Invalid command type" severity error;
            return op_t'val(0);
        end if;
    end function;

begin

    i2c_command <= ( 
        op => mk_op(cmd),
        addr => cmd.bus_addr,
        reg => cmd.reg_addr,
        len => cmd.len
    );
    i2c_command_valid <= valid_flag;
    i2c_tx_st_if.data <= (others => '0');
    i2c_tx_st_if.valid <= '0';
    i2c_rx_st_if.ready <= '1'; -- No back-pressure for now

    mixed_width_simple_dpr_inst: entity work.mixed_width_simple_dpr
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
        rdata => rx_dpr_rdata
    );
    rx_fifo_waddr.addr <= resize(rx_dpr_waddr, rx_fifo_waddr.addr'length);
    rx_fifo_raddr.addr <= resize(rx_dpr_raddr, rx_fifo_raddr.addr'length);
    rx_fifo_data_avail.data <= resize(rx_dpr_raddr, rx_fifo_data_avail.data'length);


    rx_dpr_wen <= i2c_rx_st_if.ready and i2c_rx_st_if.valid;
    
    -- management of the FIFO pointers
    rx_fifo_ptrs: process(clk, reset)
     begin
        if reset then
            rx_dpr_raddr <= (others => '0');
            rx_dpr_waddr <= (others => '0');
        elsif rising_edge(clk) then

            -- fifo pointer reset
            if fifo_ctrl.rx_fifo_reset = '1' then
                rx_dpr_waddr <= (others => '0');
            elsif rx_dpr_wen = '1' then
                rx_dpr_waddr <= rx_dpr_waddr + 1;
            end if;

            -- fifo pointer reset
            if fifo_ctrl.rx_fifo_reset = '1' then
                rx_dpr_raddr <= (others => '0');
            -- TODO: fifo pointer adjustment
            --elsif rx_dpr_raddr_write = '1' then
            --    rx_dpr_raddr <= (others => '0');
            -- fifo pointer read and auto-increment
            elsif rx_dpr_pop = '1' and fifo_ctrl.rx_fifo_auto_inc = '1' then
                rx_dpr_raddr <= rx_dpr_raddr + 1;
            end if;
            
            

        end if;
    end process;

    axil_target_txn_inst: entity work.axil_target_txn
    port map(
       clk => clk,
       reset => reset,
       arvalid => axi_if.read_address.valid,
       arready => axi_if.read_address.ready,
       awvalid => axi_if.write_address.valid,
       awready => axi_if.write_address.ready,
       wvalid => axi_if.write_data.valid,
       wready => axi_if.write_data.ready,
       bvalid => axi_if.write_response.valid,
       bready => axi_if.write_response.ready,
       bresp => axi_if.write_response.resp,
       rvalid => axi_if.read_data.valid,
       rready => axi_if.read_data.ready,
       rresp => axi_if.read_data.resp,
       active_read => active_read,
       active_write => active_write
   );
   axi_if.read_data.data <= rdata;

   

   -- rather than a FIFO here, we're going to do ram with byte enables

   write_logic: process(clk, reset)
    begin
        if reset then
            cmd <= rec_reset;
            fifo_ctrl <= rec_reset;
            valid_flag <= '0';
            fifo_write_flag <= '0';
            fifo_wdata <= (others => '0');

        elsif rising_edge(clk) then
            valid_flag <= '0';
            fifo_write_flag <= '0';
            fifo_ctrl.rx_fifo_reset <= '0'; -- flags so these clear after set also
            fifo_ctrl.tx_fifo_reset <= '0'; -- flags so these clear after set also

            if active_write then
                case to_integer(axi_if.write_address.addr) is
                    when SPD_CMD_OFFSET => 
                        cmd <= unpack(axi_if.write_data.data);
                        valid_flag <= '1';
                    when FIFO_CTRL_OFFSET => fifo_ctrl <= unpack(axi_if.write_data.data);
                    when TX_FIFO_WDATA_OFFSET => 
                        fifo_wdata <= axi_if.write_data.data;
                        fifo_write_flag <= '1';
                    when others => null;
                end case;
            end if;

        end if;
    end process;

    read_logic: process(clk, reset)
    begin
        if reset then
            rx_dpr_pop <= '0';
            rdata <= (others => '0');
        elsif rising_edge(clk) then
            rx_dpr_pop <= '0';

            if active_read then
                case to_integer(axi_if.write_address.addr) is
                    when SPD_CMD_OFFSET => rdata <= pack(cmd);
                    when FIFO_CTRL_OFFSET => rdata <= pack(fifo_ctrl);
                    when RX_FIFO_WADDR_OFFSET => rdata <= pack(rx_fifo_waddr);
                    when RX_FIFO_RADDR_OFFSET => rdata <= pack(rx_fifo_raddr);
                    when RX_FIFO_DATA_AVAIL_OFFSET=> rdata <= pack(rx_fifo_data_avail);
                    when RX_FIFO_RDATA_OFFSET => 
                        rdata <= rx_dpr_rdata;
                        rx_dpr_pop <= '1';
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;
end rtl;