-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2026 Oxide Computer Company


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
        -- SP-controlled absolute flash address for the desired host image base address.
        -- We have 2 image slots, SP choses which of these is the starting address. This is signed
        -- and the value is added directly to the incomming raw AMD addresses to get a physical flash address, mapped into
        -- the right image region.
        sp_host_image_flash_addr_offset: in signed(31 downto 0);
        -- APOB region moves around in a given host image. The location of this is pre-determined (and stored in metadata)
        -- the SP provides this absolute flash address for the start of the APOB region for the current image, 
        --and we use this to determine if a given transaction is targeting the APOB region or not so we can adjust addresses accordingly.
        amd_begin_apob_flash_addr: in std_logic_vector(31 downto 0);
        -- SP provides the length of the remapping window to cover the APOB region that AMD will be fetching.
        apob_window_len: in std_logic_vector(31 downto 0);
        -- Absolute address of the desired APOB region in flash, used for address translation. 
        -- This is the base address that corresponds to the start of the APOB region, which is what the SP provides to us, 
        -- and then we add offsets to it based on the incoming transaction addresses to figure out where in flash we're actually reading from.
        sp_apob_base_flash_addr: in std_logic_vector(31 downto 0);
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
        raw_addr : std_logic_vector(31 downto 0);
        apob_addr : std_logic_vector(31 downto 0);
        image_addr : std_logic_vector(31 downto 0);
        cur_flash_addr : std_logic_vector(31 downto 0);
        apob_end_addr : std_logic_vector(31 downto 0);
        next_flash_addr: std_logic_vector(31 downto 0);
        len: std_logic_vector(31 downto 0);
    end record;
    constant reg_reset : reg_t := (
        state => idle,
        cmd_rdack => '0',
        data_bytes => 0,
        dummy_cycles => 0,
        txn_bytes => 0,
        rem_bytes => 0,
        raw_addr => (others => '0'),
        apob_addr => (others => '0'),
        image_addr => (others => '0'),
        cur_flash_addr => (others => '0'),
        apob_end_addr => (others => '0'),
        next_flash_addr => (others => '0'),
        len => (others => '0')
    );

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
                    -- This is a show-ahead fifo so it's no problem, espi_cmd_fifo_rdata is valid
                    -- here. Thus, we take the opportunity to precompute a couple different
                    -- addresses before deciding which one to use next cycle.
                    v.raw_addr := espi_cmd_fifo_rdata;

                    -- Option 1: Host flash slot 0 or 1, where images are stored
                    -- We know the SP5 is only sending positive addresses, but cur_flash_addr_offset is signed so we need to cast the v.raw_addr
                    -- to unsigned also to do the math, so we add a leading zero bit, and then resize back down to 32bits.
                    -- normal flash address, just adjust by the offset
                    assert unsigned(v.raw_addr) < x"10000000" report "Address must be less than 256MB" severity failure;
                    v.image_addr := std_logic_vector(resize(signed('0' & v.raw_addr) + sp_host_image_flash_addr_offset, 32));

                    -- Option 2: APOB slot 0 or 1
                    v.apob_addr := std_logic_vector(
                        unsigned(sp_apob_base_flash_addr) + -- an absolute offset in flash
                        unsigned(v.raw_addr) - 
                        unsigned(amd_begin_apob_flash_addr)
                    );

                    -- pre-calculate the end address of the APOB region so we can check against it later (again for timing)
                    v.apob_end_addr := std_logic_vector((unsigned(amd_begin_apob_flash_addr) + unsigned(apob_window_len)));
                end if;
            when read_cmd_addr =>
                -- The SP5 only knows about one flash slot, and hubris controls which
                -- flash slot we're actually talking to so we adjust the commands from
                -- the SP5 right here one time so that we're in real flash addresses from there
                -- on out.
                -- Now check if the registered address lands in the active APOB region. If not,
                -- use the active image address.
                if unsigned(r.raw_addr) >= unsigned(amd_begin_apob_flash_addr) and
                   unsigned(r.raw_addr) <  unsigned(r.apob_end_addr)then
                    v.cur_flash_addr := r.apob_addr;
                   else
                    v.cur_flash_addr := r.image_addr;
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
