-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- This is a fake flash transaction manager used to test the ESPI interface.
-- Rather than pulling in a whole flash controller for sim, we just mock the
-- interface.

-- The interface is simple: we have a 32bit wide FIFO for commands, and get 2
-- words there: First word is the 32bit flash address from SP5's perspective
-- and the second word is the byte count, with the request kind in its top
-- nibble (0 read, 1 write, 2 erase) as flash_channel_pkg encodes it.
-- Read data is pushed back byte-by-byte into an 8bit wide FIFO. Note that
-- This fifo is not necessarily deep enough to hold a whole transaction read
-- (which may be many sets of 256byte blocks), but the espi block should
-- generally be able to keep up so we may not have to model that here.
-- Writes take their payload from the byte stream the flash channel pushes
-- ahead of the command, and writes and erases answer with one status byte,
-- zero for success, the way the real client in spi_nor_top does.
--
-- Behind it is a 64kB window of NOR-like memory, initialised to
-- fake_flash_pattern so reads can be checked, with clear-only programming
-- and erase-to-ones so writes and erases can be checked back through reads.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

use work.espi_tb_pkg.all;

entity fake_flash_txn_mgr is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- espi cmd fifo interface
        espi_cmd_fifo_data  : in    std_logic_vector(31 downto 0);
        espi_cmd_fifo_write : in    std_logic;
        -- write payload, host to flash
        espi_wfifo_data  : in    std_logic_vector(7 downto 0) := (others => '0');
        espi_wfifo_write : in    std_logic := '0';

        -- Raw flash read_data
        flash_rdata       : out   std_logic_vector(7 downto 0);
        flash_rdata_empty : out   std_logic;
        flash_rdata_rdack : in    std_logic
    );
end entity;

architecture model of fake_flash_txn_mgr is

    constant window_bytes : natural := 16#10000#;
    constant cmd_queue : queue_t              := new_queue;
    constant wqueue : queue_t                 := new_queue;
    signal   addr      : std_logic_vector(31 downto 0);
    signal   cmd_idx   : natural range 0 to 1 := 0;
    signal write_en : std_logic;
    signal wdata : std_logic_vector(7 downto 0);

    -- SAFS erase size codes
    constant erase_4k : std_logic_vector(11 downto 0) := x"001";
    constant erase_64k : std_logic_vector(11 downto 0) := x"003";

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
                push(cmd_queue, espi_cmd_fifo_data);  -- kind and txn size
                cmd_idx <= 0;
            end if;
        end if;
    end process;

    capture_payload: process
    begin
        wait until rising_edge(clk);
        if espi_wfifo_write = '1' then
            push(wqueue, espi_wfifo_data);
        end if;
    end process;

    fake_flash: process
        type mem_t is array (0 to window_bytes - 1) of std_logic_vector(7 downto 0);
        variable mem  : mem_t;
        variable addr : std_logic_vector(31 downto 0);
        variable word : std_logic_vector(31 downto 0);
        variable len  : natural;
        variable idx  : natural;
        variable erase_bytes : natural;
        variable status : std_logic_vector(7 downto 0);

        -- Push one byte back with a few cycles of stall after it, so the
        -- downstream logic is seen to cope with data that is not
        -- clock-over-clock. The delay is somewhat arbitrary but has to be
        -- more than the fifo latency for the stall to be visible.
        procedure push_byte(constant b : std_logic_vector(7 downto 0)) is
        begin
            wdata <= b;
            write_en <= '1';
            wait until rising_edge(clk);
            write_en <= '0';
            for i in 0 to 5 loop
                wait until rising_edge(clk);
            end loop;
        end procedure;
    begin
        for i in mem'range loop
            mem(i) := fake_flash_pattern(i);
        end loop;
        write_en <= '0';
        loop
            loop
                exit when not is_empty(cmd_queue);
                wait until falling_edge(clk);
            end loop;
            addr := pop_std_ulogic_vector(cmd_queue);
            word := pop_std_ulogic_vector(cmd_queue);
            len := to_integer(word(11 downto 0));
            status := x"00";
            case word(31 downto 28) is
                when x"1" =>
                    -- the flash channel pushes the whole payload before the
                    -- command, so waiting here is only ever a fifo latency
                    while length(wqueue) < len loop
                        wait until rising_edge(clk);
                    end loop;
                    for i in 0 to len - 1 loop
                        idx := (to_integer(addr) + i) mod window_bytes;
                        mem(idx) := mem(idx) and pop_std_ulogic_vector(wqueue);
                    end loop;
                    push_byte(status);
                when x"2" =>
                    case word(11 downto 0) is
                        when erase_4k => erase_bytes := 4096;
                        when erase_64k => erase_bytes := 65536;
                        when others => erase_bytes := 0;
                    end case;
                    if erase_bytes = 0 then
                        status := x"01";
                    else
                        for i in 0 to erase_bytes - 1 loop
                            idx := ((to_integer(addr) / erase_bytes) * erase_bytes + i) mod window_bytes;
                            mem(idx) := x"FF";
                        end loop;
                    end if;
                    push_byte(status);
                when others =>
                    for i in 0 to len - 1 loop
                        push_byte(mem((to_integer(addr) + i) mod window_bytes));
                    end loop;
            end case;
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
