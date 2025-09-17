-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.spi_nor_regs_pkg.all;
use work.axil8x32_pkg.all;

entity spi_nor_regs is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- axi interface
        axi_if : view axil_target;

        -- system interface
        addr             : out   addr_type;
        spicr            : out   spicr_type;
        spisr            : in    spisr_type;
        dummy_cycles     : out   dummycycles_type;
        data_bytes       : out   databytes_type;
        instr            : out   instr_type;
        go_strobe        : out   std_logic;
        sp5_flash_offset : out   sp5flashoffset_type;
        apob_flash_addr  : out   apobflashaddr_type;
        apob_flash_len   : out   apobflashlen_type;
        apob_flash_offset: out   apobflashoffset_type;

        -- TX FIFO Interface
        tx_fifo_write_data : out   std_logic_vector(31 downto 0);
        tx_fifo_write      : out   std_logic;

        -- RX FIFO Interface
        rx_fifo_read_data : in    std_logic_vector(31 downto 0);
        rx_fifo_read_ack  : out   std_logic
    );
end entity;

architecture rtl of spi_nor_regs is

    signal   rdata              : std_logic_vector(31 downto 0);
    signal   rx_fifo_ack        : std_logic;
    signal active_write       : std_logic;
    signal active_read        : std_logic;

begin

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


-- vsg_off
write_logic: process(clk, reset)
begin
    if reset then
        spicr <= rec_reset;
        dummy_cycles <= rec_reset;
        data_bytes <= rec_reset;
        instr <= rec_reset;
        addr <= rec_reset;
        sp5_flash_offset <= rec_reset;
        apob_flash_addr <= rec_reset;
        apob_flash_len <= rec_reset;
        apob_flash_offset <= rec_reset;
        go_strobe <= '0';
    elsif rising_edge(clk) then
        go_strobe <= '0';  -- self clearing
        spicr.tx_fifo_reset <= '0';  -- self clearing
        spicr.rx_fifo_reset <= '0';  -- self clearing
        if active_write then
            case to_integer(axi_if.write_address.addr) is
                when SPICR_OFFSET => spicr <= unpack(axi_if.write_data.data);
                when DUMMYCYCLES_OFFSET => dummy_cycles <= unpack(axi_if.write_data.data);
                when INSTR_OFFSET =>
                    instr <= unpack(axi_if.write_data.data);
                    go_strobe <= '1';
                when DATABYTES_OFFSET => data_bytes <= unpack(axi_if.write_data.data);
                when ADDR_OFFSET => addr <= unpack(axi_if.write_data.data);
                when SP5FLASHOFFSET_OFFSET => sp5_flash_offset <= unpack(axi_if.write_data.data);
                when APOBFLASHADDR_OFFSET => apob_flash_addr <= unpack(axi_if.write_data.data);
                when APOBFLASHLEN_OFFSET => apob_flash_len <= unpack(axi_if.write_data.data);
                when APOBFLASHOFFSET_OFFSET => apob_flash_offset <= unpack(axi_if.write_data.data);
                when others => null;
            end case;
        end if;
    end if;
end process;
-- vsg_on

    tx_fifo_write_data <= axi_if.write_data.data;
    tx_fifo_write      <= '1' when active_write = '1' and to_integer(axi_if.write_address.addr) = TX_FIFO_WDATA_OFFSET else '0';

    rx_fifo_read_ack <= '1' when axi_if.read_data.ready = '1' and axi_if.read_data.valid = '1' and rx_fifo_ack = '1' else '0';
   

-- vsg_off
read_logic: process(clk, reset)
begin
    if reset then
        rdata <= (others => '0');
        rx_fifo_ack <= '0';
    elsif rising_edge(clk) then
        rx_fifo_ack <= '0';
        if active_read then
            case to_integer(axi_if.read_address.addr) is
                when SPICR_OFFSET => rdata <= pack(spicr);
                when SPISR_OFFSET => rdata <= pack(spisr);
                when DUMMYCYCLES_OFFSET => rdata <= pack(dummy_cycles);
                when DATABYTES_OFFSET => rdata <= pack(data_bytes);
                when INSTR_OFFSET => rdata <= pack(instr);
                when ADDR_OFFSET => rdata <= pack(addr);
                when RX_FIFO_RDATA_OFFSET => 
                    rdata <= rx_fifo_read_data;
                    rx_fifo_ack <= '1';
                when SP5FLASHOFFSET_OFFSET => rdata <= pack(sp5_flash_offset);
                when APOBFLASHADDR_OFFSET => rdata <= pack(apob_flash_addr);
                when APOBFLASHLEN_OFFSET => rdata <= pack(apob_flash_len);
                when APOBFLASHOFFSET_OFFSET => rdata <= pack(apob_flash_offset);
                when others => rdata <= (others => '0');
            end case;
        end if;
    end if;
end process;
-- vsg_on

end rtl;
