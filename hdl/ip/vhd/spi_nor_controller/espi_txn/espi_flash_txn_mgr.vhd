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

entity espi_flash_txn_mgr is
    port(
        clk : in std_logic;
        reset: in std_logic;
        -- From Hubris control
        espi_reads_allowed: in std_logic;
        cur_flash_addr_offset: in signed(31 downto 0);
        cur_apob_flash_addr: in std_logic_vector(31 downto 0);
        cur_apob_flash_len: in std_logic_vector(31 downto 0);
        -- espi cmd fifo interface
        espi_cmd_fifo_rdata: in std_logic_vector(31 downto 0);
        espi_cmd_fifo_rdack: out std_logic;
        espi_cmd_fifo_rempty: in std_logic;-- FIFO the command, which is simply an 32bit address
        -- espi command
        espi_cmd: out spi_nor_cmd_t;
        spi_hw_busy : in std_logic;
        -- espi data fifo interface
        espi_flash_data_byte : out std_logic_vector(7 downto 0);
        flash_data_byte_write : out std_logic;
        -- Raw flash read_data
        flash_rdata : in std_logic_vector(7 downto 0);
        flash_rdata_write : in std_logic;
        -- 
    );
end entity;

architecture rtl of espi_flash_txn_mgr is
    attribute mark_debug : string;

    constant max_flash_read_size : natural := 255;
    constant fast_read_dummy_cycles : natural := 8;
    type state_t is (idle, read_cmd_addr, read_cmd_len, issue_read, wait_for_data);

    type reg_t is record
        state : state_t;
        cmd_rdack: std_logic;
        data_bytes: natural range 0 to 256;
        dummy_cycles: natural range 0 to 256;
        txn_bytes : natural range 0 to 255;
        rem_bytes: natural range 0 to 4096;
        cur_flash_addr : std_logic_vector(31 downto 0);
        next_flash_addr: std_logic_vector(31 downto 0);
        len: std_logic_vector(31 downto 0);
    end record;
    constant reg_reset : reg_t := (idle, '0', 0, 0, 0, 0, (others => '0'), (others => '0'), (others => '0'));

    signal r, rin: reg_t;

    attribute mark_debug of r : signal is "TRUE";



begin

    espi_cmd.addr <=r.cur_flash_addr;
    espi_cmd.data_bytes <= To_Std_Logic_Vector(r.data_bytes, espi_cmd.data_bytes'length);
    espi_cmd.dummy_cycles <= To_Std_Logic_Vector(fast_read_dummy_cycles,  espi_cmd.dummy_cycles'length);
    espi_cmd.instr <= FAST_READ_4BYTE_QUAD_OP;
    espi_cmd.go_flag <= '1' when r.state = issue_read and spi_hw_busy = '0' else '0';

    -- Turn the flash data we read back around into the data fifo going to the espi,
    -- but only when we're expecting data going to the espi block and not hubris FIFOs.
    espi_flash_data_byte <= flash_rdata;
    flash_data_byte_write <= flash_rdata_write when r.state = wait_for_data else '0';
    espi_cmd_fifo_rdack <= r.cmd_rdack;

    -- state machine that will pull 2 words from the command fifo.
    -- Word1: is the 32bit SP5 address, which we'll adjust to be the flash address when we pop it
    -- Word2: is the transaction length in byte-count.
    -- We're going to do page reads, so we'll need to do this in 256byte chunks so long as we have room
    -- in the data fifo. When we get to rem_bytes < 256 we'll do a final read of the remaining bytes.
    sm: process(all)
        variable v: reg_t;
    begin
        v := r;
        -- single cycle flag(s)
        v.cmd_rdack := '0';
        
        case r.state is
            when idle =>
                if espi_cmd_fifo_rempty = '0' and espi_reads_allowed = '1' then
                    v.state := read_cmd_addr;
                end if;
            when read_cmd_addr =>
                -- The SP5 only knows about one flash location, hubris controls which
                -- flash location we're actually talking to so we adjust the commands from
                -- the SP5 right here one time so that we're in real flash addresses from there
                -- on out.
                --
                -- We know the SP5 is only sending positive addresses, but cur_flash_addr_offset is signed so we need to cast the espi_cmd_fifo_rdata
                -- to unsigned also to do the math, so we add a leading zero bit, and then resize back down to 32bits.
                -- normal flash address, just adjust by the offset
                assert unsigned(espi_cmd_fifo_rdata) < x"10000000" report "Address must be less than 256MB" severity failure;
                v.cur_flash_addr := std_logic_vector(resize(signed('0' & espi_cmd_fifo_rdata) + cur_flash_addr_offset, 32));
                -- Now check if the adjusted address (v.cur_flash_addr) lands in the APOB region
                if unsigned(v.cur_flash_addr) >= unsigned(cur_apob_flash_addr) and
                   unsigned(v.cur_flash_addr) < (unsigned(cur_apob_flash_addr) + unsigned(cur_apob_flash_len)) then
                    -- Remap to raw address space starting at 0x4000000; the bonus flash region
                    v.cur_flash_addr := std_logic_vector(
                        to_unsigned(16#4000000#, 32) +
                        unsigned(v.cur_flash_addr) -
                        unsigned(cur_apob_flash_addr)
                    );
                end if;
                v.state := read_cmd_len;

            when read_cmd_len =>
                -- This comes 1-indexed from the eSPI block, so we need to subtract 1 below
                v.rem_bytes := to_integer(espi_cmd_fifo_rdata(11 downto 0)) - 1;
                v.state := issue_read;
                -- We're either going to issue the max page size, or the 0-indexed remaining bytes
                -- which ever is smaller.
                v.txn_bytes := minimum(v.rem_bytes, max_flash_read_size);
                -- spi is 1-indexed still, so we need to add 1 here
                v.data_bytes := v.txn_bytes + 1;

            when issue_read =>
                if spi_hw_busy = '0' then
                    v.state := wait_for_data;
                    -- Adjust info for a potential next read or so we can decide we're done later
                    v.rem_bytes := r.rem_bytes - r.txn_bytes;
                    v.next_flash_addr := r.cur_flash_addr + (r.txn_bytes + 1);
                end if;
               
            when wait_for_data =>
                -- count down when we load data into the fifo
                if flash_rdata_write = '1' and r.txn_bytes > 0 then
                    v.txn_bytes := r.txn_bytes - 1;
                -- on final write decide where we're going
                elsif flash_rdata_write = '1' then
                    -- last data, no more parts of the full read to do
                    if r.rem_bytes = 0 then
                        v.state := idle;
                    -- last data for this part of the transaction
                    else
                        v.state := issue_read;
                        v.cur_flash_addr := r.next_flash_addr;
                        v.txn_bytes := minimum(v.rem_bytes, max_flash_read_size);
                        v.data_bytes := v.txn_bytes + 1;
                    end if;
                end if;

        end case;

        -- easier to set up the combo stuff here so that we
        -- read the fifo in these two states.
        if v.state = read_cmd_addr or v.state = read_cmd_len then
            v.cmd_rdack := '1';
        end if;

        rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset then
            r <= reg_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;
