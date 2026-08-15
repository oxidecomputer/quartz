-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Flash sequencer for the Ethernet management block: turns one high-level
-- operation (read / page program / sector erase) into the SPI-NOR command
-- sequence the part actually needs -- WRITE ENABLE before anything that
-- alters the array, then the operation, then READ STATUS polling until WIP
-- clears. Reuses the spi_nor_controller engine (spi_txn_mgr + spi_link)
-- directly rather than spi_nor_top, which drags in registers and eSPI
-- plumbing this standalone device does not have.
--
-- Program data is pulled a byte at a time (wr_data/wr_ack) at SPI pace and
-- read data is pushed (rd_data/rd_valid), so the caller can serve bytes
-- straight out of its own buffers with no FIFO in between. One operation at
-- a time; req is ignored while busy. 4-byte-address opcodes throughout, so
-- parts larger than 128 Mbit need no mode switching.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.spi_nor_pkg.all;
use work.eth_mgmt_pkg.all;

entity mgmt_flash is
    generic (
        -- sclk divisor handed to spi_link; conservative default
        SCLK_DIVISOR : unsigned(15 downto 0) := to_unsigned(4, 16)
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- operation interface
        req  : in    std_logic;                       -- pulse
        op   : in    flash_op_t;
        addr : in    std_logic_vector(31 downto 0);
        len  : in    unsigned(8 downto 0);            -- 1..256 bytes
        busy : out   std_logic;
        done : out   std_logic;                       -- pulse

        -- program data pull
        wr_data : in    std_logic_vector(7 downto 0);
        wr_ack  : out   std_logic;

        -- read data push
        rd_data  : out   std_logic_vector(7 downto 0);
        rd_valid : out   std_logic;

        -- qspi pins
        cs_n  : out   std_logic;
        sclk  : out   std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of mgmt_flash is

    type state_t is (IDLE, S_WREN, S_OPER, S_POLL, S_DONE);
    type phase_t is (P_GO, P_WAIT_START, P_WAIT_END);

    signal state : state_t := IDLE;
    signal phase : phase_t := P_GO;

    signal op_r   : flash_op_t := FLASH_OP_READ;
    signal addr_r : std_logic_vector(31 downto 0) := (others => '0');
    signal len_r  : unsigned(8 downto 0) := (others => '0');

    signal spi_cmd : spi_nor_cmd_t := (
        addr => (others => '0'), data_bytes => (others => '0'),
        dummy_cycles => (others => '0'), instr => (others => '0'),
        go_flag => '0');

    signal status_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- engine interconnect. sclk and cs_n exist twice on purpose: the copies
    -- that leave the block are duplicate flops with no internal fanout so they
    -- can be packed into the IOBs, and the _int versions are what the phase
    -- logic looks at. The link owns sclk; the transaction manager owns cs_n.
    signal cs_n_int       : std_logic;
    signal sclk_int       : std_logic;
    signal rx_byte        : std_logic_vector(7 downto 0);
    signal rx_byte_done   : boolean;
    signal tx_link_byte   : std_logic_vector(7 downto 0);
    signal tx_link_mode   : io_mode;
    signal tx_byte_req    : boolean;
    signal in_rx_phases   : boolean;
    signal in_tx_phases   : boolean;
    signal sclk_running   : boolean;
    signal release_lanes  : std_logic_vector(3 downto 0);
    signal cur_io_mode    : io_mode;
    signal rx_fifo_data   : std_logic_vector(7 downto 0);
    signal rx_fifo_write  : std_logic;
    signal tx_fifo_ack    : std_logic;

begin

    txn_mgr: entity work.spi_txn_mgr
        port map (
            clk           => clk,
            reset         => reset,
            spi_cmd       => spi_cmd,
            cs_n          => cs_n_int,
            cs_n_pin      => cs_n,
            sclk          => sclk_int,
            rx_byte_done  => rx_byte_done,
            rx_link_byte  => rx_byte,
            tx_byte_req   => tx_byte_req,
            tx_link_byte  => tx_link_byte,
            tx_link_mode  => tx_link_mode,
            in_rx_phases  => in_rx_phases,
            in_tx_phases  => in_tx_phases,
            sclk_running  => sclk_running,
            release_lanes => release_lanes,
            cur_io_mode   => cur_io_mode,
            rx_fifo_data  => rx_fifo_data,
            rx_fifo_write => rx_fifo_write,
            tx_fifo_data  => wr_data,
            tx_fifo_ack   => tx_fifo_ack
        );

    -- Generics left at their defaults deliberately: rx_sample_taps = 2 is the
    -- one-clk-after-the-edge capture this block was written against, and the
    -- chip-select timings are in clk cycles, so neither moves with SCLK_DIVISOR.
    link: entity work.spi_link
        port map (
            clk           => clk,
            reset         => reset,
            req_io_mode   => cur_io_mode,
            divisor       => SCLK_DIVISOR,
            in_tx_phases  => in_tx_phases,
            in_rx_phases  => in_rx_phases,
            sclk_running  => sclk_running,
            release_lanes => release_lanes,
            rx_byte       => rx_byte,
            rx_byte_done  => rx_byte_done,
            tx_byte       => tx_link_byte,
            tx_byte_mode  => tx_link_mode,
            tx_byte_req   => tx_byte_req,
            sclk_redge    => open,
            sclk_fedge    => open,
            cs_n          => cs_n_int,
            sclk          => sclk_int,
            sclk_pin      => sclk,
            io            => io,
            io_o          => io_o,
            io_oe         => io_oe
        );

    busy <= '0' when state = IDLE else '1';

    -- program bytes are pulled straight through to the caller; read bytes
    -- push out only during the data operation, not while polling status
    wr_ack   <= tx_fifo_ack;
    rd_data  <= rx_fifo_data;
    rd_valid <= rx_fifo_write when state = S_OPER and op_r = FLASH_OP_READ else '0';

    ctrl: process (clk, reset) is
        -- one SPI transaction: pulse go, watch chip select wrap the frame
        procedure run_txn (
            constant instr : in std_logic_vector(7 downto 0);
            constant a     : in std_logic_vector(31 downto 0);
            constant nbyte : in unsigned(8 downto 0);
            constant nxt_state : in state_t
        ) is
        begin
            case phase is
                when P_GO =>
                    spi_cmd.instr      <= instr;
                    spi_cmd.addr       <= a;
                    spi_cmd.data_bytes <= std_logic_vector(nbyte);
                    spi_cmd.go_flag    <= '1';
                    phase <= P_WAIT_START;
                when P_WAIT_START =>
                    -- Hold go_flag until the frame actually starts rather than
                    -- pulsing it. The manager only samples go once its enforced
                    -- cs_n-high time has expired, so a one-cycle pulse issued
                    -- straight after the previous transaction is dropped and the
                    -- sequence stalls with no indication.
                    if cs_n_int = '0' then
                        spi_cmd.go_flag <= '0';
                        phase <= P_WAIT_END;
                    end if;
                when P_WAIT_END =>
                    if cs_n_int = '1' then
                        phase <= P_GO;
                        state <= nxt_state;
                    end if;
            end case;
        end procedure;
    begin
        if reset = '1' then
            state <= IDLE;
            phase <= P_GO;
            done  <= '0';
            spi_cmd.go_flag <= '0';
        elsif rising_edge(clk) then
            done <= '0';

            if rx_fifo_write = '1' and state = S_POLL then
                status_reg <= rx_fifo_data;
            end if;

            case state is
                when IDLE =>
                    phase <= P_GO;
                    if req = '1' then
                        op_r   <= op;
                        addr_r <= addr;
                        len_r  <= len;
                        if op = FLASH_OP_READ then
                            state <= S_OPER;
                        else
                            state <= S_WREN;
                        end if;
                    end if;

                when S_WREN =>
                    run_txn(WRITE_ENABLE_OP, (31 downto 0 => '0'),
                            (8 downto 0 => '0'), S_OPER);

                when S_OPER =>
                    case op_r is
                        when FLASH_OP_READ =>
                            run_txn(READ_DATA_4BYTE_OP, addr_r, len_r, S_DONE);
                        when FLASH_OP_PROGRAM =>
                            run_txn(PAGE_PROGRAM_4BYTE_OP, addr_r, len_r, S_POLL);
                        when FLASH_OP_ERASE =>
                            run_txn(SECTOR_ERASE_4BYTE_OP, addr_r,
                                    (8 downto 0 => '0'), S_POLL);
                    end case;

                when S_POLL =>
                    -- one-byte RDSR, repeated until WIP (bit 0) clears
                    run_txn(READ_STATUS_REG1_OP, (31 downto 0 => '0'),
                            to_unsigned(1, 9), S_POLL);
                    if phase = P_WAIT_END and cs_n_int = '1' and
                       status_reg(0) = '0' then
                        state <= S_DONE;
                    end if;

                when S_DONE =>
                    done  <= '1';
                    state <= IDLE;
            end case;
        end if;
    end process;

end architecture;
