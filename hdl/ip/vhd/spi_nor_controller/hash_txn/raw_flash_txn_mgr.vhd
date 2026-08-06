-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.spi_nor_pkg.all;

-- A second flash read client with the same command/response FIFO shape as
-- espi_flash_txn_mgr, but reading raw addresses.
--
-- Two differences from the eSPI flavour, both deliberate:
--
--   * No address translation. The eSPI manager remaps the host's view onto the
--     active image slot and the APOB window, which is exactly wrong for a client
--     that was handed a physical flash address to hash.
--   * A 32 bit length rather than the eSPI 12 bit one, so a whole flash image is
--     expressible in a single command. Chunking into <= 256 byte reads still
--     happens here and is invisible to the requester.
--
-- It also does not look at sp5_owns_flash. Ownership is settled by the req/grant
-- handshake in spi_nor_top instead, so a read can proceed whether or not the host
-- currently owns the flash.
entity raw_flash_txn_mgr is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- Command FIFO: word 0 is a byte address, word 1 a byte count
        cmd_fifo_rdata  : in    std_logic_vector(31 downto 0);
        cmd_fifo_rdack  : out   std_logic;
        cmd_fifo_rempty : in    std_logic;

        -- Ownership of the shared SPI engine. req is held for the whole command,
        -- chunking included, so the engine is not handed to anyone else part way
        -- through a multi chunk read.
        req   : out   std_logic;
        grant : in    std_logic;

        -- Command to the SPI transaction manager
        cmd         : out   spi_nor_cmd_t;
        spi_hw_busy : in    std_logic;

        -- Bytes back out to the requester's response FIFO
        data_byte  : out   std_logic_vector(7 downto 0);
        data_write : out   std_logic;

        -- Raw read data from the SPI link
        flash_rdata       : in    std_logic_vector(7 downto 0);
        flash_rdata_write : in    std_logic
    );
end entity;

architecture rtl of raw_flash_txn_mgr is

    attribute mark_debug : string;

    -- Actual bytes, not a zero indexed count. spi_txn_mgr loads data_bytes
    -- straight into its counter and finishes when that reaches one, so it
    -- transfers exactly data_bytes bytes.
    constant max_chunk_bytes        : natural := 256;
    constant fast_read_dummy_cycles : natural := 8;

    type state_t is (idle, read_cmd_addr, read_cmd_len, size_chunk, wait_idle,
                     issue_read, wait_for_data);

    -- Everything here counts real bytes. The eSPI manager this was derived from
    -- mixes zero indexed and one indexed counts, and decrements its remaining
    -- count by the zero indexed chunk size rather than by the number of bytes
    -- the chunk actually moves, so it over-fetches by one byte per extra chunk.
    -- That is invisible over there because an eSPI flash read never needs more
    -- than one chunk, but this client's reads are routinely megabytes.
    type reg_t is record
        state     : state_t;
        cmd_rdack : std_logic;
        -- Address of the transaction in flight. This has to hold still for the
        -- whole of it: spi_txn_mgr shifts spi_cmd.addr out during the address
        -- phase and re-reads spi_cmd.data_bytes when it moves into the data
        -- phase, so neither may be advanced at go_flag. The next chunk's address
        -- is parked in next_addr until the current one retires.
        cur_addr  : std_logic_vector(31 downto 0);
        next_addr : std_logic_vector(31 downto 0);
        -- Bytes of the whole command still to be asked for
        rem_bytes : unsigned(31 downto 0);
        -- Bytes in the chunk currently being issued, and how many of them are
        -- still to come back
        chunk     : natural range 0 to max_chunk_bytes;
        left      : natural range 0 to max_chunk_bytes;
    end record;

    constant reg_reset : reg_t := (
        state     => idle,
        cmd_rdack => '0',
        cur_addr  => (others => '0'),
        next_addr => (others => '0'),
        rem_bytes => (others => '0'),
        chunk     => 0,
        left      => 0
    );

    signal r, rin : reg_t;

    attribute mark_debug of r : signal is "TRUE";

begin

    cmd.addr         <= r.cur_addr;
    cmd.data_bytes   <= To_Std_Logic_Vector(r.chunk, cmd.data_bytes'length);
    cmd.dummy_cycles <= To_Std_Logic_Vector(fast_read_dummy_cycles, cmd.dummy_cycles'length);
    cmd.instr        <= FAST_READ_4BYTE_QUAD_OP;
    -- Held for as long as we are in issue_read, and dropped only once the
    -- controller has actually taken it. See the state for why that matters.
    cmd.go_flag      <= '1' when r.state = issue_read else '0';

    data_byte  <= flash_rdata;
    data_write <= flash_rdata_write when r.state = wait_for_data else '0';

    cmd_fifo_rdack <= r.cmd_rdack;

    -- Ask for the engine as soon as there is a command waiting, and keep asking
    -- until the whole thing has been serviced.
    req <= '1' when r.state /= idle or cmd_fifo_rempty = '0' else '0';

    sm: process(all)

        variable v : reg_t;

    begin
        v := r;

        v.cmd_rdack := '0';

        case r.state is

            when idle =>
                -- Show-ahead FIFO, so the address word is already on rdata.
                if cmd_fifo_rempty = '0' and grant = '1' then
                    v.cur_addr := cmd_fifo_rdata;
                    v.state    := read_cmd_addr;
                end if;

            when read_cmd_addr =>
                v.state := read_cmd_len;

            when read_cmd_len =>
                -- A real byte count, taken as-is.
                v.rem_bytes := unsigned(cmd_fifo_rdata);
                v.state     := size_chunk;

            when size_chunk =>
                -- One cycle of arithmetic, shared by the first chunk and every
                -- one after it so the two cannot drift apart.
                if r.rem_bytes = 0 then
                    v.state := idle;
                else
                    if r.rem_bytes > max_chunk_bytes then
                        v.chunk := max_chunk_bytes;
                    else
                        v.chunk := to_integer(r.rem_bytes);
                    end if;

                    v.state := wait_idle;
                end if;

            when wait_idle =>
                -- The previous chunk's transaction has to be completely finished
                -- before we start asking for the next one, otherwise the busy
                -- rise we wait on below would be its cs_n, not ours.
                if spi_hw_busy = '0' then
                    v.state := issue_read;
                end if;

            when issue_read =>
                -- Leave only once the controller has actually started the
                -- transaction, ie once it pulls cs_n low.
                --
                -- Leaving on "not busy" instead looks right and is not: the
                -- controller enforces a minimum cs_n high time between
                -- transactions and ignores go_flag until it expires, while
                -- spi_hw_busy goes low the moment cs_n rises. Exiting on that
                -- turns go_flag into a single cycle pulse inside the dead window
                -- and the command is quietly dropped, which strands every chunk
                -- after the first. The first chunk of a command survives because
                -- the controller has been idle long enough for the window to have
                -- expired already.
                if spi_hw_busy = '1' then
                    v.left      := r.chunk;
                    v.rem_bytes := r.rem_bytes - r.chunk;
                    -- Parked, not applied: cur_addr is still being shifted out.
                    v.next_addr := r.cur_addr + r.chunk;
                    v.state     := wait_for_data;
                end if;

            when wait_for_data =>
                if flash_rdata_write = '1' then
                    if r.left = 1 then
                        -- Last byte of this chunk, so the transaction is done
                        -- with cur_addr and the next one can have it.
                        v.cur_addr := r.next_addr;
                        v.state    := size_chunk;
                    else
                        v.left := r.left - 1;
                    end if;
                end if;

        end case;

        -- Pop one command word in each of these two states.
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
