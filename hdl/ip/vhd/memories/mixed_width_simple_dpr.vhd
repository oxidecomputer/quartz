-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.calc_pkg.all;

-- Simple dual port ram supporting dual clocks with symmetric read and
-- write sizes. Addresses are in terms of `WIDTH` as a word
-- `NUM_WORDS` is the depth of the FIFO again in terms of entries
-- of `WIDTH` of the port
-- Note: a read from an address that is undergoing a write will
-- result in undefined behavior and needs to be avoided
-- Note2: This is an attempt at making a ram that can be inferred
-- by vivado wihout using shared variables. All of Xilinx's inferrence
-- examples use shared variables who's functionality was deprecated
-- technically by VHDL-2002, and a protected variable would be a more
-- proper model of it at this point but it is unclear if those would
-- compile or be recognized as and implemented in RAM.
-- You are limited to aspect ratios supported by the device/software:
-- Generally read:write ratios of 1:32, 1:16, 1:8, 1:4, 1:2, 1:1, 2:1, 
--   4:1, 8:1, 16:1, or 32:1
-- are supported, with no width being larger than 4096 bits

entity mixed_width_simple_dpr is
    generic (
        write_width : integer;
        read_width  : integer;
        write_num_words  : integer;
        reg_output : boolean := false
    );
    port (
        -- Write-side interface clock
        wclk : in    std_logic;
        -- Write address, sync'd to wclk domain
        waddr : in    std_logic_vector(log2ceil(write_num_words) - 1 downto 0);
        -- Write data, sync'd to wclk domain
        wdata : in    std_logic_vector(write_width - 1 downto 0);
        -- Write enable, sync'd to wclk domain
        wren : in    std_logic; -- wclk domain
        -- Read-side interface clock
        rclk : in    std_logic;
        -- read addrss size is going to be calculated based on the aspect ratio of the two sides
        raddr : in    std_logic_vector(log2ceil(write_num_words * write_width / read_width) - 1  downto 0);
        -- Read data, sync'd to rclk domain
        rdata : out   std_logic_vector(read_width - 1 downto 0)
    );
end entity;

architecture ram of mixed_width_simple_dpr is
    constant write_side_is_bigger : boolean := write_width > read_width;
    constant min_width : integer := minimum(write_width, read_width);
    constant max_width : integer := maximum(write_width, read_width);
    constant ratio : integer := max_width / min_width;
    -- the max size is going to be the biggest number of words we can have on either side
    constant max_size : integer := maximum(write_num_words, write_num_words * write_width / read_width);

    type ram_t is array (0 to max_size - 1) of std_logic_vector(min_width - 1 downto 0);
    signal ram : ram_t := (others => (others => '0'));
    signal rdata_int : std_logic_vector(rdata'range);

    begin


    write_bigger_gen: if write_side_is_bigger generate
        -- The unrolling works differently depending on which side is larger
        -- The write side is wider so we decode the read side as the native width and
        -- the write side address is expanded to get proper address.
        wbig_write_proc:process(wclk)
            variable addr: integer := 0;
        begin
            if rising_edge(wclk) then
                for i in 0 to RATIO - 1 loop
                    -- Set up the address by concatenating the ratio bits to the end since we're accessing
                    -- by min-width sizes.
                    addr := to_integer(waddr & to_std_logic_vector(i, log2ceil(RATIO)));
    
                    if wren = '1' then
                        ram(addr) <= wdata((i + 1) * min_width - 1 downto i * min_width);
                    end if;
                end loop;
            end if;
        end process;
    
        rd:process(all)
        begin
                rdata_int <= ram(to_integer(raddr));
        end process;

    else generate
        -- Write side is smaller so the decodes flip from above, write side writes to ram array natively
        -- and the read side has to expand the data out.

        wsmaller_write_proc:process(wclk)
        begin
            if rising_edge(wclk) then
                for i in 0 to RATIO - 1 loop
                    -- No address adjustment since this is the min-width side
                    if wren = '1' then
                        ram(to_integer(waddr)) <= wdata;
                    end if;
                end loop;
            end if;
        end process;

        rd_proc:process(all)
            variable addr: integer := 0;
        begin
            for i in 0 to RATIO - 1 loop
                -- Set up the address by concatenating the ratio bits to the end since we're accessing
                -- by min-width sizes.
                addr := to_integer(raddr & to_std_logic_vector(i, log2ceil(RATIO)));
                rdata_int((i + 1) * min_width - 1 downto i * min_width) <= ram(addr);
            end loop;
        end process;
    end generate;

    out_reg_gen: if reg_output generate
        out_reg: process(rclk)
        begin
            if rising_edge(rclk) then
                rdata <= rdata_int;
            end if;
        end process;
    else generate
        rdata <= rdata_int;
    end generate;


end ram;