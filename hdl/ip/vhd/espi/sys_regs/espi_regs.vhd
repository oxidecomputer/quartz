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
        msg_en : out std_logic;
        -- debug interface
        dbg_chan : view dbg_regs_if


    );
end entity;

architecture rtl of espi_regs is

    constant OKAY               : std_logic_vector(1 downto 0) := "00";
    signal   axi_int_read_ready : std_logic;
    signal   awready            : std_logic;
    signal   wready             : std_logic;
    signal   bvalid             : std_logic;
    signal   bready             : std_logic;
    signal   arready            : std_logic;
    signal   rvalid             : std_logic;
    signal   rdata              : std_logic_vector(31 downto 0);
    signal   control_reg        : control_type;
    signal   status_reg         : status_type;
    signal   fifo_status_reg    : fifo_status_type;
    signal   flags_reg          : flags_type;
    signal   resp_fifo_ack      : std_logic;

begin
    fifo_status_reg.cmd_used_wds <= dbg_chan.wstatus.usedwds;
    fifo_status_reg.resp_used_wds <= dbg_chan.rdstatus.usedwds;
    status_reg.busy <= dbg_chan.busy;
    flags_reg.alert <= dbg_chan.alert_pending;
    msg_en <= control_reg.msg_en;

    -- unpack the record
    axi_if.write_response.resp  <= OKAY;
    axi_if.write_response.valid <= bvalid;
    axi_if.read_data.resp       <= OKAY;
    axi_if.write_data.ready     <= wready;
    axi_if.write_address.ready  <= awready;
    axi_if.read_address.ready   <= arready;
    axi_if.read_data.data       <= rdata;
    axi_if.read_data.valid      <= rvalid;
    bready                      <= axi_if.write_response.ready;

    wready  <= awready;
    arready <= not rvalid;

    axi_int_read_ready <= axi_if.read_address.valid and arready;

    -- axi transaction mgmt
    axi_txn: process(clk, reset)
    begin
        if reset then
            awready <= '0';
            bvalid <= '0';
            rvalid <= '0';
        elsif rising_edge(clk) then
            -- bvalid set on every write,
            -- The tranfer occurs when bvalid && bready
            -- but we can simplify the clearing logic to only
            -- look at bready since we don't care if we set bvalid to 0
            -- if it was already a 0
            if awready then
                bvalid <= '1';
            elsif bready then
                bvalid <= '0';
            end if;

            if axi_int_read_ready then
                rvalid <= '1';
            elsif axi_if.read_data.ready then
                rvalid <= '0';
            end if;

            -- can accept a new write if we're not
            -- responding to write already or
            -- the write is not in progress
            awready <= not awready and
                       (axi_if.write_address.valid and axi_if.write_data.valid) and
                       (not bvalid or bready);
        end if;
    end process;

    write_logic: process(clk, reset)
    begin
        if reset then
            control_reg <= rec_reset;
        elsif rising_edge(clk) then
            control_reg.cmd_fifo_reset <= '0';  -- self clearing
            control_reg.cmd_size_fifo_reset <= '0';  -- self clearing
            control_reg.resp_fifo_reset <= '0';  -- self clearing
            if wready then
                case to_integer(axi_if.write_address.addr) is
                    when CONTROL_OFFSET => control_reg <= unpack(axi_if.write_data.data);
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    dbg_chan.wr.data <= axi_if.write_data.data;
    dbg_chan.wr.write <= '1' when wready = '1' and to_integer(axi_if.write_address.addr) = CMD_FIFO_WDATA_OFFSET else '0';
    dbg_chan.size.data <= axi_if.write_data.data;
    dbg_chan.size.write <= '1' when wready = '1' and to_integer(axi_if.write_address.addr) = CMD_SIZE_FIFO_WDATA_OFFSET else '0';

    dbg_chan.rd.rdack <= '1' when axi_if.read_data.ready = '1' and rvalid = '1' and resp_fifo_ack = '1' else '0';

    read_logic: process(clk, reset)
    begin
        if reset then
            rdata <= (others => '0');
        elsif rising_edge(clk) then
            resp_fifo_ack <= '0';
            if axi_int_read_ready then
                case to_integer(axi_if.read_address.addr) is
                    when FLAGS_OFFSET => rdata <= pack(flags_reg);
                    when CONTROL_OFFSET => rdata <= pack(control_reg);
                    when STATUS_OFFSET => rdata <= pack(status_reg);
                    when FIFO_STATUS_OFFSET => rdata <= pack(fifo_status_reg);
                    when RESP_FIFO_RDATA_OFFSET => 
                        rdata <= dbg_chan.rd.data;
                        resp_fifo_ack <= '1';
                    when others =>
                        rdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

    dbg_chan.enabled <= control_reg.dbg_mode_en;

end rtl;
