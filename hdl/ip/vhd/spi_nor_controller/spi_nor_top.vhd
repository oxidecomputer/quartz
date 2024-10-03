-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.spi_nor_pkg.all;
use work.spi_nor_regs_pkg.all;
use work.axil8x32_pkg.all;

entity spi_nor_top is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- Axilite interface
        axi_if : view axil_target;
        -- qspi interface
        cs_n  : out   std_logic;
        sclk  : out   std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0);
        sp5_owns_flash : out std_logic;
        -- eSPI transaction interface.
        -- FIFO the command, which is simply an 32bit address
        -- as the first word and the transaction length as the 
        -- second word
        espi_cmd_fifo_rdata: in std_logic_vector(31 downto 0);
        espi_cmd_fifo_rdack: out std_logic;
        espi_cmd_fifo_rempty: in std_logic;
        -- Flash data back to the espi block, just flash data from
        -- requested address
        espi_data_fifo_wdata : out std_logic_vector(7 downto 0);
        espi_data_fifo_write : out std_logic;

    );
end entity;

architecture rtl of spi_nor_top is

    constant div_val              : unsigned(15 downto 0) := to_unsigned(2, 16);
    signal   rx_byte_done         : boolean;
    signal   tx_byte_done         : boolean;
    signal   in_rx_phases         : boolean;
    signal   in_tx_phases         : boolean;
    signal   link_rx_byte         : std_logic_vector(7 downto 0);
    signal   link_tx_byte         : std_logic_vector(7 downto 0);
    signal   cur_io_mode          : io_mode;
    signal   rx_fifo_write8       : std_logic;
    signal   tx_fifo_read8        : std_logic;
    signal   tx_fifo_data8        : std_logic_vector(7 downto 0);
    signal   rx_fifo_wdat8        : std_logic_vector(7 downto 0);
    signal   tx_fifo_data32       : std_logic_vector(31 downto 0);
    signal   read_ack32           : std_logic;
    signal   rx_fifo_wdata32      : std_logic_vector(31 downto 0);
    signal   rx_fifo_write32      : std_logic;
    signal   rx_fifo_rdata_reg    : std_logic_vector(31 downto 0);
    signal   rx_fifo_read_ack_reg : std_logic;
    signal   tx_fifo_write_reg    : std_logic;
    signal   tx_fifo_wdata_reg    : std_logic_vector(31 downto 0);
    signal   addr_reg             : addr_type;
    signal   dummy_cycles_reg     : dummycycles_type;
    signal   data_bytes_reg       : databytes_type;
    signal   instr_reg            : instr_type;
    signal   spicr_reg            : spicr_type;
    signal   spisr_reg            : spisr_type;
    signal   go_strobe            : std_logic;
    signal   tx_fifo_reset        : std_logic;
    signal   rx_fifo_reset        : std_logic;
    signal espi_fifo_write_allowed : std_logic;
    signal reg_fifo_write_allowed : std_logic;
    signal espi_fifo_write : std_logic;
    signal reg_fifo_write : std_logic;
    signal sp5_flash_offset : sp5flashoffset_type;
    signal espi_cmd : spi_nor_cmd_t;
    signal hubris_cmd: spi_nor_cmd_t;
    signal spi_cmd_if : spi_nor_cmd_t;

begin

    -- Link layer here
    -- this does clock-gen, and has the serializer and
    -- deserializer that operate during tx and rx phases
    link: entity work.spi_link
        port map (
            clk   => clk,
            reset => reset,

            req_io_mode  => cur_io_mode,
            divisor      => div_val,
            in_tx_phases => in_tx_phases,
            in_rx_phases => in_rx_phases,
            rx_byte      => link_rx_byte,
            rx_byte_done => rx_byte_done,
            tx_byte      => link_tx_byte,
            tx_byte_done => tx_byte_done,
            sclk_redge   => open,
            sclk_fedge   => open,
            -- spi link signals
            sclk  => sclk,
            cs_n  => cs_n,
            io    => io,
            io_o  => io_o,
            io_oe => io_oe
        );

    -- Transaction manager controls chip select,
    -- feeds data to/from the serializer/deserializer
    -- to/from FIFOs
    spi_txn_mgr_inst: entity work.spi_txn_mgr
        port map (
            clk   => clk,
            reset => reset,
            -- registers i/f
            spi_cmd       => spi_cmd_if,
            -- link i/f
            cs_n          => cs_n,
            sclk          => sclk,
            rx_byte_done  => rx_byte_done,
            rx_link_byte  => link_rx_byte,
            tx_byte_done  => tx_byte_done,
            tx_link_byte  => link_tx_byte,
            in_rx_phases  => in_rx_phases,
            in_tx_phases  => in_tx_phases,
            cur_io_mode   => cur_io_mode,
            tx_fifo_ack   => tx_fifo_read8,
            tx_fifo_data  => tx_fifo_data8,
            rx_fifo_data  => rx_fifo_wdat8,
            rx_fifo_write => rx_fifo_write8
        );
    -- Hubris spi command intrface
    hubris_cmd.addr <= addr_reg.addr;
    hubris_cmd.data_bytes <= data_bytes_reg.count;
    hubris_cmd.dummy_cycles <= dummy_cycles_reg.count;
    hubris_cmd.instr <= instr_reg.opcode;
    hubris_cmd.go_flag <= go_strobe;
    -- Mux between espi and register interface for read data (rx fifos)
    reg_fifo_write_allowed <= '1' when spicr_reg.sp5_owns_flash = '0' else '0';
    espi_fifo_write_allowed <= '1' when spicr_reg.sp5_owns_flash = '1' else '0';
    reg_fifo_write <= reg_fifo_write_allowed and rx_fifo_write8;
    espi_fifo_write <= espi_fifo_write_allowed and rx_fifo_write8;

    spi_cmd_if <= hubris_cmd when spicr_reg.sp5_owns_flash = '0' else espi_cmd;
    
    sp5_owns_flash <= spicr_reg.sp5_owns_flash;
    -- TODO: this would be more simple with a mixed width fifo
    -- but this was faster than digging around making a new wrapper
    -- for now
    mixed_width_adaptor_inst: entity work.mixed_width_adaptor
        port map (
            clk          => clk,
            reset        => reset,
            txn_complete => cs_n,
            -- TX FIFO Interface
            read_data    => tx_fifo_data8,
            read_ack     => tx_fifo_read8,
            read_data32  => tx_fifo_data32,
            read_ack32   => read_ack32,
            write_data   => rx_fifo_wdat8,
            write_en     => rx_fifo_write8,
            write_data32 => rx_fifo_wdata32,
            write_en32   => rx_fifo_write32
        );

    tx_fifo_reset_gen: process(clk, reset)
    begin
        if reset = '1' then
            tx_fifo_reset <= '1';
        elsif rising_edge(clk) then
            tx_fifo_reset <= spicr_reg.tx_fifo_reset;
        end if;
    end process;

    tx_dcfifo_dut: entity work.dcfifo_xpm
        generic map (

            fifo_write_depth => 64,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            -- Write interface ()
            wclk => clk,
            -- Reset interface, sync to write clock domain
            reset    => tx_fifo_reset,
            write_en => tx_fifo_write_reg,
            wdata    => tx_fifo_wdata_reg,
            wfull    => spisr_reg.tx_full,
            wusedwds => spisr_reg.tx_used_wds,
            -- Read interface
            rclk     => clk,
            rdata    => tx_fifo_data32,
            rdreq    => read_ack32,
            rempty   => open,
            rusedwds => open
        );

    spisr_reg.tx_empty <= '1' when spisr_reg.tx_used_wds = 0 else '0';

    rx_fifo_reset_gen: process(clk, reset)
    begin
        if reset = '1' then
            rx_fifo_reset <= '1';
        elsif rising_edge(clk) then
            rx_fifo_reset <= spicr_reg.rx_fifo_reset;
        end if;
    end process;

    rx_dcfifo_dut: entity work.dcfifo_xpm
        generic map (

            fifo_write_depth => 64,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            -- Write interface ()
            wclk => clk,
            -- Reset interface, sync to write clock domain
            reset    => rx_fifo_reset,
            write_en => rx_fifo_write32,
            wdata    => rx_fifo_wdata32,
            wfull    => open,
            wusedwds => open,
            -- Read interface
            rclk     => clk,
            rdata    => rx_fifo_rdata_reg,
            rdreq    => rx_fifo_read_ack_reg,
            rempty   => spisr_reg.rx_empty,
            rusedwds => spisr_reg.rx_used_wds
        );

    spisr_reg.rx_full <= '1' when spisr_reg.rx_used_wds = 64 else '0';

    spisr_reg.busy <= '1' when cs_n = '0' else '0';

    -- Hubris-interactable registers for control and status
    spi_nor_regs_inst: entity work.spi_nor_regs
        port map (
            clk                => clk,
            reset              => reset,
            axi_if             => axi_if,
            spicr              => spicr_reg,
            spisr              => spisr_reg,
            addr               => addr_reg,
            instr              => instr_reg,
            dummy_cycles       => dummy_cycles_reg,
            data_bytes         => data_bytes_reg,
            go_strobe          => go_strobe,
            tx_fifo_write_data => tx_fifo_wdata_reg,
            tx_fifo_write      => tx_fifo_write_reg,
            rx_fifo_read_data  => rx_fifo_rdata_reg,
            rx_fifo_read_ack   => rx_fifo_read_ack_reg
        );

     -- Read transaction manager to/from the espi block
     espi_flash_txn_mgr_inst: entity work.espi_flash_txn_mgr
      port map(
         clk => clk,
         reset => reset,
         espi_cmd => espi_cmd,
         spi_hw_busy => spisr_reg.busy,
         espi_reads_allowed => spicr_reg.sp5_owns_flash,
         cur_flash_addr_offset => std_logic_vector(sp5_flash_offset.offset),
         espi_cmd_fifo_rdata => espi_cmd_fifo_rdata,
         espi_cmd_fifo_rdack => espi_cmd_fifo_rdack,
         espi_cmd_fifo_rempty => espi_cmd_fifo_rempty,
         espi_flash_data_byte => espi_data_fifo_wdata,
         flash_data_byte_write => espi_data_fifo_write,
         flash_rdata => rx_fifo_wdat8,
         flash_rdata_write => espi_fifo_write
     );

end rtl;