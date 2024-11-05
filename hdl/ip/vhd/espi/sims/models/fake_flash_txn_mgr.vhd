-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- This is a fake flash transaction manager used to test the ESPI interface.
-- Rather than pulling in a whole flash controller for sim, we just mock the
-- interface.

-- The interface is simple: we have a 32bit wide FIFO for commands, and get 2
-- words there: First word is the 32bit flash address from SP5's perspective
-- and the second word is the number of bytes to read.
-- The read data is pushed back byte-by-byte into an 8bit wide FIFO. Note that
-- This fifo is not necessarily deep enough to hold a whole transaction read
-- (which may be many sets of 256byte blocks), but the espi block should
-- generally be able to keep up so we may not have to model that here.
-- To simplify the model, we're just going to put a counting pattern back
-- into the FIFO as the "read data" which may facilitate debugging.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

entity fake_flash_txn_mgr is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- espi cmd fifo interface
        espi_cmd_fifo_data  : in    std_logic_vector(31 downto 0);
        espi_cmd_fifo_write : in    std_logic;

        -- Raw flash read_data
        flash_rdata       : out   std_logic_vector(7 downto 0);
        flash_rdata_empty : out   std_logic;
        flash_rdata_rdack : in    std_logic
    );
end entity;

architecture model of fake_flash_txn_mgr is

    constant cmd_queue : queue_t              := new_queue;
    signal   addr      : std_logic_vector(31 downto 0);
    signal   cmd_idx   : natural range 0 to 1 := 0;
    signal write_en : std_logic;
    signal wdata : std_logic_vector(7 downto 0);

begin

    -- take in two words from the command fifo, (allow queueing more)
    -- pop from command fifo , store the return counter and show
    -- not empty until we've counted all the way down to 0

    enqueue_cmd: process
    begin
        wait until rising_edge(clk);
        if espi_cmd_fifo_write = '1' then
            -- We need 2 cycles to get the info but we want to leave the queue
            -- empty until we have both words so we only queue push 2x once the
            -- second word is in
            if cmd_idx = 0 then
                cmd_idx <= cmd_idx + 1;
                addr <= espi_cmd_fifo_data;
            else
                -- push both parts of the command into the fifo
                push(cmd_queue, addr); -- full address
                push(cmd_queue, espi_cmd_fifo_data(11 downto 0));  -- txn size
                cmd_idx <= 0;
            end if;
        end if;
    end process;

    fake_flash_reads: process
        variable addr : std_logic_vector(31 downto 0);
        variable len  : std_logic_vector(11 downto 0);
        variable top  : std_logic_vector(11 downto 0);
        variable data : std_logic_vector(11 downto 0);
    begin
        write_en <= '0';
        loop
            exit when not is_empty(cmd_queue);
            wait until falling_edge(clk);
        end loop;
        addr := pop(cmd_queue);
        len := pop(cmd_queue);
        top := len;
        -- push some data into the fifo
        while len > 0 loop
            data := top - len;
            wdata <= resize(data, wdata'length);
            write_en <= '1';
            if rising_edge(clk)then
                len := len - 1;
                wait on clk;
                write_en <= '0';
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
            end if;
            wait on clk;
        end loop;
        
    end process;


    dcfifo_xpm_inst: entity work.dcfifo_xpm
     generic map(
        fifo_write_depth => 4096,
        data_width => 8,
        showahead_mode => true
    )
     port map(
        wclk => clk,
        reset => reset,
        write_en => write_en,
        wdata => wdata,
        wfull => open,
        wusedwds => open,
        rclk => clk,
        rdata => flash_rdata,
        rdreq => flash_rdata_rdack,
        rempty => flash_rdata_empty,
        rusedwds => open
    );

end model;
