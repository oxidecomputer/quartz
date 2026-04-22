-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- BRAM-backed version ROM for post-P&R stamping.
--
-- A 256x8 block RAM initialized with sentinel values. After place
-- and route, icebram/ecpbram (Yosys flows) or TCL init (Vivado)
-- replaces the sentinel pattern with real git version and SHA data.
--
-- Memory layout (big-endian byte order):
--   [0:3]   - Version (commit count), sentinel: DE AD BE EF
--   [4:7]   - SHA (short git hash), sentinel: CA FE BA BE
--   [8:255] - Reserved (zeros)
--
-- On startup, a small FSM reads bytes 4-7 from the BRAM and latches
-- them into the short_sha output register. The output is valid after
-- 9 clock cycles.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity version_rom is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        short_sha : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of version_rom is

    type rom_type is array (0 to 255) of std_logic_vector(7 downto 0);

    signal rom : rom_type := (
        -- Version sentinel
        0 => x"DE", 1 => x"AD", 2 => x"BE", 3 => x"EF",
        -- SHA sentinel
        4 => x"CA", 5 => x"FE", 6 => x"BA", 7 => x"BE",
        others => x"00"
    );
    attribute ram_style : string;
    attribute ram_style of rom : signal is "block";

    signal cnt      : unsigned(3 downto 0) := x"0";
    signal rom_rdata : std_logic_vector(7 downto 0) := x"00";
    signal sha_r    : std_logic_vector(31 downto 0) := (others => '0');
    signal ready    : std_logic := '0';

begin

    -- BRAM read: address driven by counter, data available next cycle
    bram_read : process(clk)
    begin
        if rising_edge(clk) then
            rom_rdata <= rom(to_integer(cnt(2 downto 0)));
        end if;
    end process;

    -- Latch SHA bytes from BRAM into output register.
    -- Bytes 4-7 of the ROM contain the SHA in big-endian order.
    -- At cnt=5, rom_rdata holds mem[4] (from previous cycle's read).
    latch : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt   <= x"0";
                sha_r <= (others => '0');
                ready <= '0';
            elsif ready = '0' then
                case to_integer(cnt) is
                    when 5 => sha_r(31 downto 24) <= rom_rdata;
                    when 6 => sha_r(23 downto 16) <= rom_rdata;
                    when 7 => sha_r(15 downto 8)  <= rom_rdata;
                    when 8 =>
                        sha_r(7 downto 0) <= rom_rdata;
                        ready <= '1';
                    when others => null;
                end case;
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    short_sha <= sha_r;

end rtl;
