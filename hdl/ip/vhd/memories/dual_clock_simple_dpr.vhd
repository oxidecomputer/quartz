-- Simple Dual-Port Block RAM with Two Clocks
-- Correct Modelization with a Shared Variable
-- File: simple_dual_two_clocks.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.calc_pkg.log2ceil;

--! Simple dual port ram supporting dual clocks with symmetric read and
--! write sizes. Addresses are in terms of `DATA_WIDTH` as a word
--! `NUM_WORDS` is the depth of the FIFO again in terms of entries
--! of `DATA_WIDTH` size
--! Note: a read from an address that is undergoing a write will
--! result in undefined behavior and needs to be avoided
--! Note2: This is an attempt at making a ram that can be inferred
--! by vivado wihout using shared variables. All of Xilinx's inferrence
--! examples use shared variables who's functionality was deprecated
--! technically by VHDL-2002, and a protected variable would be a more
--! proper model of it at this point but it is unclear if those would
--! compile or be recognized as and implemented in RAM.

entity dual_clock_simple_dpr is
    generic (
        data_width : integer;
        num_words  : integer;
        reg_output : boolean := false
    );
    port (
        --! Write-side interface clock
        wclk : in    std_logic;
        --! Write address, sync'd to wclk domain
        waddr : in    std_logic_vector(log2ceil(num_words) - 1 downto 0);
        --! Write data, sync'd to wclk domain
        wdata : in    std_logic_vector(data_width - 1 downto 0);
        --! Write enable, sync'd to wclk domain
        wren : in    std_logic := '0'; -- wclk domain

        --! Read-side interface clock
        rclk : in    std_logic;
        --! Read address, sync'd to rclk domain
        raddr : in    std_logic_vector(log2ceil(num_words) - 1 downto 0);
        --! Read data, sync'd to rclk domain
        rdata : out   std_logic_vector(data_width - 1 downto 0)
    );
end entity;

architecture rtl of dual_clock_simple_dpr is

    type   ram_type is array (num_words - 1 downto 0) of std_logic_vector(wdata'range);
    signal ram : ram_type;

begin

    -- Write side interface
    wr: process(wclk)
    begin
        if rising_edge(wclk) then
            if wren = '1' then
                ram(to_integer(unsigned(waddr))) <= wdata;
            end if;
        end if;
    end process;

    -- Read-side interface

    out_reg : if reg_output = true generate

        rd: process(rclk)
        begin
            if rising_edge(rclk) then
                rdata <= ram(to_integer(unsigned(raddr)));
            end if;
        end process;

    else generate
        rdata <= ram(to_integer(unsigned(raddr)));
    end generate;

end rtl;
