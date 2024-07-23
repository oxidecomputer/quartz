-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity mixed_width_adaptor is
    port (
        clk : in std_logic;
        reset : in std_logic;

        txn_complete : in std_logic;
        -- TX FIFO Interface
        -- 8bit read interface
        read_data : out std_logic_vector(7 downto 0);
        read_ack  : in  std_logic;
        -- 32bit read interface
        read_data32 : in std_logic_vector(31 downto 0);
        read_ack32  : out std_logic;

        -- RX FIFO interface
        -- 8bit write interface
        write_data : in std_logic_vector(7 downto 0);
        write_en   : in std_logic;
        -- 32bit write interface
        write_data32 : out std_logic_vector(31 downto 0);
        write_en32   : out std_logic

    );
end entity;

architecture rtl of mixed_width_adaptor is
    signal read_idx : unsigned(1 downto 0) := (others => '0');
    signal write_idx : unsigned(1 downto 0) := (others => '0');
    signal do_write : std_logic;


begin

    read_ack32 <= '1' when read_ack = '1' and read_idx = 3 else 
                  '1' when txn_complete = '1' and read_idx /= 0 else
                  '0';
    read_data <= read_data32(7 downto 0) when read_idx = 0 else
                 read_data32(15 downto 8) when read_idx = 1 else
                 read_data32(23 downto 16) when read_idx = 2 else
                 read_data32(31 downto 24);
    -- read fifo, only ack on last word or if we're done and
    -- haven't popped the last word
    rd_proc:process(clk, reset)
    begin
        if reset then
            read_idx <= (others => '0');
        elsif rising_edge(clk) then
            if txn_complete = '1' then
                read_idx <= (others => '0');
            elsif read_ack = '1' then
                read_idx <= read_idx + 1;
            end if;
        end if;
    end process;

    write_en32 <= '1' when do_write = '1' else 
        '1' when txn_complete = '1' and write_idx /= 0 else
        '0';
    wr_proc:process(clk, reset)
    begin
        if reset then
            write_idx <= (others => '0');
            write_data32 <= (others => '0');
            do_write <= '0';
        elsif rising_edge(clk) then
            do_write <= '0';
            if txn_complete = '1' then
                write_idx <= (others => '0');
            elsif write_en = '1' then
                case write_idx is
                    when "00" =>
                    write_data32(7 downto 0) <= write_data;
                    when "01" =>
                    write_data32(15 downto 8) <= write_data;
                    when "10" =>
                    write_data32(23 downto 16) <= write_data;
                    when "11" =>
                    write_data32(31 downto 24) <= write_data;
                    do_write <= '1';
                    when others =>
                        null;
                end case;
                write_idx <= write_idx + 1;
            end if;
        end if;
    end process;


end;