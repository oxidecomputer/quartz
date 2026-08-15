-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A byte-wide CRC32 for the Ethernet FCS (IEEE 802.3): polynomial 0x04C11DB7,
-- seed 0xFFFFFFFF, input and output bit-reflected, final value complemented.
-- The reflection is baked in by shifting toward bit 0 with the reversed
-- polynomial, so bytes are applied in wire order with no reversal at the
-- boundary.
--
-- Feed one octet per enable, covering destination MAC through the last data
-- byte (no preamble/SFD). To transmit an FCS: send not crc_out(7 downto 0)
-- first, then successive bytes upward. To check a received frame: also feed
-- the four FCS octets; the register ends at the CRC32 residue x"DEBB20E3"
-- for a good frame.

entity crc32_8wide is
    port (
        clk     : in    std_logic;
        reset   : in    std_logic;
        data_in : in    std_logic_vector(7 downto 0);
        enable  : in    std_logic;
        clear   : in    std_logic;
        crc_out : out   std_logic_vector(31 downto 0);
        -- combinational: crc_out as it will be after data_in is absorbed at
        -- the next enabled edge. Lets a consumer form the first FCS byte in
        -- the same cycle the last data byte is presented (needed when the
        -- byte rate equals the clock rate). May be left open.
        crc_next : out  std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of crc32_8wide is

    -- 0x04C11DB7 bit-reversed
    constant POLY_REFLECTED : std_logic_vector(31 downto 0) := X"EDB88320";
    constant SEED           : std_logic_vector(31 downto 0) := X"FFFFFFFF";

    -- One byte of the reflected LFSR, unrolled by the synthesizer into a
    -- flat XOR tree (same structure the hand-written 8-bit CRCs encode
    -- explicitly, but far less error-prone at 32 bits).
    function crc32_update (
        crc  : std_logic_vector(31 downto 0);
        data : std_logic_vector(7 downto 0)
    ) return std_logic_vector is
        variable c        : std_logic_vector(31 downto 0) := crc;
        variable feedback : std_logic;
    begin
        for i in 0 to 7 loop
            feedback := c(0) xor data(i);
            c        := '0' & c(31 downto 1);
            if feedback = '1' then
                c := c xor POLY_REFLECTED;
            end if;
        end loop;
        return c;
    end function;

begin

    crc_next <= crc32_update(crc_out, data_in);

    crc_reg: process(clk, reset)
    begin
        if reset then
            crc_out <= SEED;
        elsif rising_edge(clk) then
            -- clear/enable let external logic run this on a faster clock
            -- than the byte rate, same contract as the 8-bit CRCs
            if clear then
                crc_out <= SEED;
            elsif enable then
                crc_out <= crc32_update(crc_out, data_in);
            end if;
        end if;
    end process;

end rtl;
