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

entity spi_txn_mgr is
    port(
        clk : in std_logic;
        reset: in std_logic;
        -- system register interface
        address : in unsigned(31 downto 0);
        dummy_cycles   : in unsigned(7 downto 0);
        data_bytes : in unsigned(8 downto 0);
        instr: in std_logic_vector(7 downto 0);
        go_flag: in std_logic;
        -- link interface
        cs_n  : out    std_logic;
        sclk  : in     std_logic;
        rx_byte_done : in boolean;
        rx_link_byte : in std_logic_vector(7 downto 0);
        tx_byte_done : in boolean;
        tx_link_byte : out std_logic_vector(7 downto 0);
        in_rx_phases : out boolean;
        in_tx_phases : out boolean;
        cur_io_mode  : out io_mode;
        -- fifo interface
        rx_fifo_data : out std_logic_vector(7 downto 0);
        rx_fifo_write: out std_logic;
        tx_fifo_data : in std_logic_vector(7 downto 0);
        tx_fifo_ack : out std_logic
    );
end entity;

architecture rtl of spi_txn_mgr is
    attribute MARK_DEBUG : string;
constant BYTES_24BIT_ADDR : integer := 3;
constant BYTES_32BIT_ADDR : integer := 4;
constant CS_CLK_DELAY_CNTS : integer := 2;
type state_t is (idle, cs_assert, instruction, addr, dummy, wdata, rdata, cs_deassert);


type reg_type is record
    state : state_t;
    txn : txn_info_t;
    csn : std_logic;
    counter : integer range 0 to 512;
end record;
constant r_reset : reg_type := (idle, txn_info_t_reset, '1', 0);

signal r, rin : reg_type;
attribute MARK_DEBUG of r : signal is "TRUE";
signal sclk_last : std_logic;
-- Some helper functions
-- This block gets the expected IO mode given the state and the transaction we're running
function get_cur_io_mode(txn: txn_info_t; state: state_t ) return io_mode is
begin
    if state = idle or 
       state = instruction or
       state = addr or 
       state = dummy then
        -- no matter what the transaction moves to, we're in single mode
        -- for these phases
        return single;
    else
        -- otherwise use the mode specified by the opcode
        return txn.data_mode;
    end if;
end;

-- This function takes the state and returns if we're driving data lines
-- currently
function is_in_tx_phases(state: state_t) return boolean is
begin
    return state = cs_assert or state = wdata or state = dummy or state = addr or state = instruction;
end function;
-- This function takes the state and returns if we're sampling data lines
-- currently
function is_in_rx_phases(state: state_t) return boolean is
begin
    return state = rdata;
end function;

begin
    -- "Simple outputs"
    cs_n <= r.csn;
    -- rx fifo is just a pass through here, no need for any muxing
    rx_fifo_data <= rx_link_byte;
    rx_fifo_write <= '1' when rx_byte_done else '0';
    in_rx_phases <= is_in_rx_phases(r.state);
    in_tx_phases <= is_in_tx_phases(r.state);

    -- more complicated outputs

     -- based on the current state, current transaction info, we get the current io mode
     process(all)
     begin
         cur_io_mode <= get_cur_io_mode(r.txn, r.state);
     end process;

    -- Set up a bunch of muxes, and other signals that are used in the modules below
    -- mux into the serializer: we are sending static data sometimes, and fifo data sometimes
    tx_link_byte <= instr when (r.state = instruction or r.state = cs_assert) else
                    std_logic_vector(address(8 * r.counter + 7 downto 8 * r.counter)) when r.state = addr else
                    tx_fifo_data when r.state = wdata else
                    (others => '1');
    -- we only want to FIFO ack when we were reading from the fifo, not the static data
    tx_fifo_ack <= '1' when tx_byte_done and r.state = wdata else '0';

    -- main controller state machine
    controller: process(all)
        variable v : reg_type;
        variable slk_redge : boolean := false;
    begin
        v := r;
        slk_redge := sclk = '1' and sclk_last = '0';

        case r.state is
            when idle =>
                if go_flag then
                    v.state := cs_assert;
                    -- build up transaction info based on opcode
                    v.txn := get_txn_info(instr);
                    v.counter := CS_CLK_DELAY_CNTS;
                end if;
            when cs_assert =>
                if r.counter = 0 then
                    v.state := instruction;
                else
                    v.counter := r.counter - 1;
                end if;
            when instruction =>
                -- After the instruction, we could go to
                -- address phase, or issue dummy clocks,
                -- or go directly to a read/write phase
                -- so we check all the options here
                if tx_byte_done then
                    case r.txn.addr_kind is
                        when bit24 =>
                            v.counter := BYTES_24BIT_ADDR - 1; -- zero indexed
                            v.state := addr;
                        when bit32 =>
                            v.counter := BYTES_32BIT_ADDR - 1; -- zero indexed
                            v.state := addr;
                        when none =>
                            if r.txn.uses_dummys then
                                v.state := dummy;
                                v.counter := to_integer(dummy_cycles);
                            else
                                v.counter := to_integer(data_bytes);
                                case r.txn.data_kind is
                                    when read =>
                                        v.state := rdata;
                                    when write =>
                                        v.state := wdata;
                                    when none =>
                                        v.state := cs_deassert;
                                        v.counter := CS_CLK_DELAY_CNTS;
                                end case;
                            end if;
                    end case;
                end if;

            when addr =>
                -- After the address phase, we could go to a
                -- data phase immediately, or we could issue
                -- dummy clocks. I don't think there are commands
                -- that issue an address and then do nothing but
                -- we added the de-assert state for completeness
                if tx_byte_done and r.counter = 0 then
                    if r.txn.uses_dummys then
                        v.state := dummy;
                        v.counter := to_integer(dummy_cycles);
                    elsif r.txn.data_kind = write then
                        v.state := wdata;
                        v.counter := to_integer(data_bytes);
                    elsif r.txn.data_kind = read then
                        v.state := rdata;
                        v.counter := to_integer(data_bytes);
                    else
                        v.state := cs_deassert;
                        v.counter := CS_CLK_DELAY_CNTS;
                    end if;
                elsif tx_byte_done then
                    v.counter := r.counter - 1;
                end if;

            when dummy =>
               -- after a dummy phase, we're going to be reading
               -- as that's the only reason to issue dummy cycles
               -- for anything else we'll just terminate the transaction
               if slk_redge and r.counter = 1 then
                    if r.txn.data_kind = read then
                        v.state := rdata;
                        v.counter := to_integer(data_bytes);
                    else
                        v.state := cs_deassert;
                        v.counter := CS_CLK_DELAY_CNTS;
                    end if;
                elsif slk_redge then
                    v.counter := r.counter - 1;
                end if;

            when wdata =>
                -- Data counter is 1 indexded to better align
                -- with sw expectations so we're done when 
                -- r.counter = 1
                if tx_byte_done and r.counter = 1 then
                    -- We're done with the transaction
                    v.state := cs_deassert;
                    v.counter := CS_CLK_DELAY_CNTS;
                elsif tx_byte_done then
                    v.counter := r.counter - 1;
                end if;

            when rdata =>
                -- Data counter is 1 indexded to better align
                -- with sw expectations so we're done when 
                -- r.counter = 1
                if rx_byte_done and r.counter = 1 then
                    -- We're done with the transaction
                    v.state := cs_deassert;
                    v.counter := CS_CLK_DELAY_CNTS;
                elsif rx_byte_done then
                    v.counter := r.counter - 1;
                end if;

            when cs_deassert =>
                if r.counter = 0 then
                    v.state := idle;
                else
                    v.counter := r.counter - 1;
                end if;
        end case;

        -- Deal with the chip selects once we've figured
        -- out what state we're going to be in next
        if v.state = cs_assert then
            v.csn := '0';
        elsif v.state = cs_deassert and v.counter = 1 then
            v.csn := '1';
        end if;

        rin <= v;
    end process;


    sm_reg : process (clk, reset)
    begin
        if reset then
            r <= r_reset;
            sclk_last <= '0';
        elsif rising_edge(clk) then
            sclk_last <= sclk;
            r <= rin;
        end if;
    end process;

end;