-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- SP-accessible registers for the eSPI block

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.espi_regs_pkg.all;
use work.qspi_link_layer_pkg.all;
use work.axil8x32_pkg.all;

entity espi_regs is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- axi interface
        axi_if : view axil_target;
        post_code      : in std_logic_vector(31 downto 0);
        post_code_valid : in std_logic;
        espi_reset : in std_logic;
        -- debug interface
        dbg_chan : view dbg_regs_if
    );
end entity;

architecture rtl of espi_regs is

    signal   rdata              : std_logic_vector(31 downto 0);
    signal   control_reg        : control_type;
    signal   status_reg         : status_type;
    signal   fifo_status_reg    : fifo_status_type;
    signal   flags_reg          : flags_type;
    signal   resp_fifo_ack      : std_logic;
    signal active_read        : std_logic;
    signal active_write       : std_logic;
    signal last_post_code_reg : last_post_code_type;
    signal post_code_count_reg : post_code_count_type;

begin
    fifo_status_reg.cmd_used_wds <= dbg_chan.wstatus.usedwds;
    fifo_status_reg.resp_used_wds <= dbg_chan.rdstatus.usedwds;
    status_reg.busy <= dbg_chan.busy;
    flags_reg.alert <= dbg_chan.alert_pending;

    axi_if.read_data.data <= rdata;

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

    write_logic: process(clk, reset)
    begin
        if reset then
            control_reg <= rec_reset;
            last_post_code_reg <= rec_reset;
            post_code_count_reg <= rec_reset;
        elsif rising_edge(clk) then
            control_reg.cmd_fifo_reset <= '0';  -- self clearing
            control_reg.cmd_size_fifo_reset <= '0';  -- self clearing
            control_reg.resp_fifo_reset <= '0';  -- self clearing
            if  axi_if.write_address.ready then
                case to_integer(axi_if.write_address.addr) is
                    when CONTROL_OFFSET => control_reg <= unpack(axi_if.write_data.data);
                    when others => null;
                end case;
            end if;
            if espi_reset then
                last_post_code_reg <= rec_reset;
                post_code_count_reg <= rec_reset;
            elsif post_code_valid then
               last_post_code_reg <= unpack(post_code);
               post_code_count_reg <= unpack(post_code_count_reg.count + 1);
            end if;
        end if;
    end process;

    dbg_chan.wr.data <= axi_if.write_data.data;
    dbg_chan.wr.write <= '1' when axi_if.write_address.ready = '1' and to_integer(axi_if.write_address.addr) = CMD_FIFO_WDATA_OFFSET else '0';
    dbg_chan.size.data <= axi_if.write_data.data;
    dbg_chan.size.write <= '1' when axi_if.write_address.ready = '1' and to_integer(axi_if.write_address.addr) = CMD_SIZE_FIFO_WDATA_OFFSET else '0';

    dbg_chan.rd.rdack <= '1' when axi_if.read_data.ready = '1' and axi_if.read_data.valid = '1' and resp_fifo_ack = '1' else '0';

    read_logic: process(clk, reset)
    begin
        if reset then
            rdata <= (others => '0');
        elsif rising_edge(clk) then
            resp_fifo_ack <= '0';
            if active_read then
                case to_integer(axi_if.read_address.addr) is
                    when FLAGS_OFFSET => rdata <= pack(flags_reg);
                    when CONTROL_OFFSET => rdata <= pack(control_reg);
                    when STATUS_OFFSET => rdata <= pack(status_reg);
                    when FIFO_STATUS_OFFSET => rdata <= pack(fifo_status_reg);
                    when RESP_FIFO_RDATA_OFFSET => 
                        rdata <= dbg_chan.rd.data;
                        resp_fifo_ack <= '1';
                    when LAST_POST_CODE_OFFSET => rdata <= pack(last_post_code_reg);
                    when POST_CODE_COUNT_OFFSET => rdata <= pack(post_code_count_reg);
                    when others =>
                        rdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    dbg_chan.enabled <= control_reg.dbg_mode_en;

end rtl;
