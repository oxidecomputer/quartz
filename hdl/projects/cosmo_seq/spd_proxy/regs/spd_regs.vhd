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
use work.spd_proxy_pkg.all;
use work.spd_proxy_regs_pkg.all;

entity spd_regs is
    port(
        clk : in std_logic;
        reset : in std_logic;
        -- AXI-Lite interface
        axi_if : view axil8x32_pkg.axil_target;

        -- FPGA I2C Interface
        bus0 : view reg_side;
        bus1 : view reg_side
    );
end entity;

architecture rtl of spd_regs is
    signal active_read : std_logic;
    signal active_write : std_logic;
    signal spd_ctrl : spd_ctrl_type;
    signal cmd0 : cmd_type;
    signal cmd1 : cmd_type;
    signal spd_present : spd_present_type;
    signal fifo_ctrl : fifo_ctrl_type;
    signal cmd0_valid_flag : std_logic;
    signal cmd1_valid_flag : std_logic;
    signal ch0_fifo_write_flag : std_logic;
    signal ch1_fifo_write_flag : std_logic;
    signal ch0_fifo_wdata : std_logic_vector(31 downto 0);
    signal ch1_fifo_wdata : std_logic_vector(31 downto 0);
    signal rdata : std_logic_vector(31 downto 0);
    signal buffer0_if : txn_buf_ctrl_t;
    signal buffer1_if : txn_buf_ctrl_t;
    signal ch0_rx_dpr_pop : std_logic;
    signal ch1_rx_dpr_pop : std_logic;
    signal spd_select : spd_select_type;
    signal spd_rd_ptr : spd_rd_ptr_type;
    signal spd_fifo_pop : std_logic;



    function mk_op(cmd : cmd_type) return op_t is
    begin
        if to_integer(cmd.op) <= 2 then
            return op_t'val(to_integer(cmd.op));
        else
            assert false report "Invalid command type" severity error;
            return op_t'val(0);
        end if;
    end function;

begin

    bus0.i2c_cmd <= ( 
        op => mk_op(cmd0),
        addr => cmd0.bus_addr,
        reg => cmd0.reg_addr,
        len => cmd0.len
    );
    bus0.start_prefetch <= spd_ctrl.start;
    bus0.i2c_cmd_valid <= cmd0_valid_flag;
    bus0.req <= '0';
    bus0.selected_dimm <= 4x"0" & spd_select.idx(3 downto 0);
    bus0.rd_addr <= spd_rd_ptr.addr;

    bus1.i2c_cmd <= ( 
        op => mk_op(cmd1),
        addr => cmd1.bus_addr,
        reg => cmd1.reg_addr,
        len => cmd1.len
    );
    bus1.start_prefetch <= spd_ctrl.start;
    bus1.i2c_cmd_valid <= cmd1_valid_flag;
    bus1.req <= '0';
    bus1.selected_dimm <= 4x"0" & spd_select.idx(7 downto 4);
    bus1.rd_addr <= spd_rd_ptr.addr;
    
    buffer0_if.rx_fifo_pop <= ch0_rx_dpr_pop;
    buffer0_if.rx_fifo_reset <= fifo_ctrl.rx_fifo_reset;
    buffer0_if.rx_fifo_auto_inc <= fifo_ctrl.rx_fifo_auto_inc;
    buffer0_if.txn_start <= cmd0_valid_flag;
    buffer0_if.tx_wdata <= ch0_fifo_wdata;
    buffer0_if.tx_wen <= ch0_fifo_write_flag;
    buffer0_if.tx_fifo_reset <= fifo_ctrl.tx_fifo_reset;

    txn_buffer_ch0: entity work.txn_buffer
    port map(
       clk => clk,
       reset => reset,
       regs_if => buffer0_if,
       i2c_rx_st_if => bus0.i2c_rx_st_if,
       i2c_tx_st_if => bus0.i2c_tx_st_if
    );

    buffer1_if.rx_fifo_pop <= ch1_rx_dpr_pop;
    buffer1_if.rx_fifo_reset <= fifo_ctrl.rx_fifo_reset;
    buffer1_if.rx_fifo_auto_inc <= fifo_ctrl.rx_fifo_auto_inc;
    buffer1_if.txn_start <= cmd1_valid_flag;
    buffer1_if.tx_wdata <= ch1_fifo_wdata;
    buffer1_if.tx_wen <= ch1_fifo_write_flag;
    buffer1_if.tx_fifo_reset <= fifo_ctrl.tx_fifo_reset;

    txn_buffer_ch1: entity work.txn_buffer
    port map(
       clk => clk,
       reset => reset,
       regs_if => buffer1_if,
       i2c_rx_st_if => bus1.i2c_rx_st_if,
       i2c_tx_st_if => bus1.i2c_tx_st_if
   );

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

   
   write_logic: process(clk, reset)
    begin
        if reset then
            cmd0 <= rec_reset;
            cmd1 <= rec_reset;
            fifo_ctrl <= rec_reset;
            ch0_fifo_write_flag <= '0';
            ch1_fifo_write_flag <= '0';
            ch0_fifo_wdata <= (others => '0');
            ch1_fifo_wdata <= (others => '0');
            cmd0_valid_flag <= '0';
            cmd1_valid_flag <= '0';
            spd_ctrl <= rec_reset;
            spd_select <= rec_reset;
            spd_rd_ptr <= rec_reset;

        elsif rising_edge(clk) then
            cmd0_valid_flag <= '0';
            cmd1_valid_flag <= '0';
            spd_ctrl <= rec_reset;
            ch0_fifo_write_flag <= '0';
            ch1_fifo_write_flag <= '0';
            fifo_ctrl.rx_fifo_reset <= '0'; -- flags so these clear after set also
            fifo_ctrl.tx_fifo_reset <= '0'; -- flags so these clear after set also

            if spd_fifo_pop then
                spd_rd_ptr.addr <= spd_rd_ptr.addr + 1;
            end if; 

            if active_write then
                case to_integer(axi_if.write_address.addr) is
                    when SPD_CTRL_OFFSET => 
                       spd_ctrl <= unpack(axi_if.write_data.data);
                    when FIFO_CTRL_OFFSET => fifo_ctrl <= unpack(axi_if.write_data.data);
                    when SPD_SELECT_OFFSET => spd_select <= unpack(axi_if.write_data.data);
                    when SPD_RD_PTR_OFFSET => spd_rd_ptr <= unpack(axi_if.write_data.data);

                    when BUS0_CMD_OFFSET => 
                        cmd0 <= unpack(axi_if.write_data.data);
                        cmd0_valid_flag <= '1';
                    when BUS0_TX_WDATA_OFFSET => 
                        ch0_fifo_wdata <= axi_if.write_data.data;
                        ch0_fifo_write_flag <= '1';

                    when BUS1_CMD_OFFSET => 
                        cmd1 <= unpack(axi_if.write_data.data);
                        cmd1_valid_flag <= '1';
                    when BUS1_TX_WDATA_OFFSET => 
                        ch1_fifo_wdata <= axi_if.write_data.data;
                        ch1_fifo_write_flag <= '1';
                    when others => null;
                end case;
            end if;

        end if;
    end process;

    read_logic: process(clk, reset)
    begin
        if reset then
            ch0_rx_dpr_pop <= '0';
            ch1_rx_dpr_pop <= '0';
            rdata <= (others => '0');
            spd_fifo_pop <= '0';
            spd_present <= rec_reset;

        elsif rising_edge(clk) then
            ch0_rx_dpr_pop <= '0';
            ch1_rx_dpr_pop <= '0';
            spd_fifo_pop <= '0';

            spd_present.bus0 <= resize(bus0.spd_present, spd_present.bus0'length);
            spd_present.bus1 <= resize(bus1.spd_present, spd_present.bus1'length);

            if active_read then
                case to_integer(unsigned(axi_if.read_address.addr)) is
                    when FIFO_CTRL_OFFSET => rdata <= pack(fifo_ctrl);
                    when SPD_PRESENT_OFFSET => rdata <= pack(spd_present);
                    when SPD_SELECT_OFFSET => rdata <= pack(spd_select);
                    when SPD_RD_PTR_OFFSET => rdata <= pack(spd_rd_ptr);
                    when SPD_RDATA_OFFSET =>
                        spd_fifo_pop <= '1';
                        if spd_select.idx < 8 then
                            rdata <= bus0.rd_data;
                        else
                            rdata <= bus1.rd_data;
                        end if;
                    when BUS0_CMD_OFFSET => rdata <= pack(cmd0);
                    when BUS0_TX_WADDR_OFFSET => rdata <= resize(buffer0_if.tx_waddr,rdata'length);
                    when BUS0_RX_RADDR_OFFSET => rdata <= resize(buffer0_if.rx_raddr,rdata'length);
                    when BUS0_RX_BYTE_COUNT_OFFSET=> rdata <= resize(buffer0_if.rx_waddr,rdata'length);
                    when BUS0_RX_RDATA_OFFSET => 
                        rdata <= buffer0_if.rx_rdata;
                        ch0_rx_dpr_pop <= '1';
                    when BUS1_CMD_OFFSET => rdata <= pack(cmd1);
                    when BUS1_TX_WADDR_OFFSET => rdata <= resize(buffer1_if.tx_waddr,rdata'length);
                    when BUS1_RX_RADDR_OFFSET => rdata <= resize(buffer1_if.rx_raddr,rdata'length);
                    when BUS1_RX_BYTE_COUNT_OFFSET=> rdata <= resize(buffer1_if.rx_waddr,rdata'length);
                    when BUS1_RX_RDATA_OFFSET => 
                        rdata <= buffer1_if.rx_rdata;
                        ch1_rx_dpr_pop <= '1';
                    when others => rdata <= (others => '1');
                end case;
            end if;

        end if;
    end process;
end rtl;