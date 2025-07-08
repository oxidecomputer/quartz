-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

/*
 *The intent of this module is to provide a generic block that provides a ring buffer-like structure,
 *similar to the [`ringbuf`](https://github.com/oxidecomputer/hubris/tree/master/lib/ringbuf) in
 *Hubris.
 *
 *Parameters:
 * - GEN_WIDTH: the number of bits for the generation field of an entry
 * - DATA_WIDTH: the number of bits for the data field of an entry
 * - NUM_ENTRY: the number of entries in the ringbuf
 * - REG_OUTPUT: if rdata is registered at all
 *
 *The ringbuf stories entries which are comprised of a generation field and a data field. The
 *generation field is a counter which increments every time the internal buffer address rolls over,
 *while the data field is whatever is written in via the wdata port.
 */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.calc_pkg.log2ceil;

entity ringbuf is
    generic (
        GEN_WIDTH   : integer;
        DATA_WIDTH  : integer;
        NUM_ENTRIES : integer;
        REG_OUTPUT  : boolean
    );
    port (
        clk     : in std_logic;
        reset   : in std_logic;
        wdata   : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        wvalid  : in std_logic;
        raddr   : in std_logic_vector(log2ceil(NUM_ENTRIES) - 1 downto 0);
        rdata   : out std_logic_vector(GEN_WIDTH + DATA_WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of ringbuf is
    constant ENTRY_WIDTH    : integer := GEN_WIDTH + DATA_WIDTH;
    type ringbuf_t is array (0 to NUM_ENTRIES - 1) of std_logic_vector(ENTRY_WIDTH - 1 downto 0);

    signal ringbuf      : ringbuf_t := (others => (others => '0'));
    signal waddr        : unsigned(raddr'range);
    signal gen_cntr     : std_logic_vector(GEN_WIDTH - 1 downto 0);
    signal rdata_int    : std_logic_vector(ENTRY_WIDTH - 1 downto 0);
begin

    write_process: process(clk, reset)
    begin
        if reset = '1' then
            ringbuf     <= (others => (others => '0'));
            waddr       <= (others => '0');
            gen_cntr    <= (others => '0');
        elsif rising_edge(clk) then
            if wvalid then
                ringbuf(to_integer(waddr)) <= gen_cntr & wdata;
                waddr   <= waddr + 1;

                if waddr = NUM_ENTRIES - 1 then
                    gen_cntr <= gen_cntr + 1;
                end if;
            end if;
        end if;
    end process;

    read_process: process(all)
    begin
        rdata_int   <= ringbuf(to_integer(unsigned(raddr)));
    end process;

    rdata_gen: if REG_OUTPUT generate
        rdata_reg: process(clk)
        begin
            if rising_edge(clk) then
                rdata   <= rdata_int;
            end if;
        end process;
    else generate
        rdata <= rdata_int;
    end generate;

end rtl;