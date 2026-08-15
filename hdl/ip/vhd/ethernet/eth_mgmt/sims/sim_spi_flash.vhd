-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Minimal behavioral SPI-NOR flash for simulation: single-IO, mode 0,
-- 4-byte-address opcodes only, exactly the subset mgmt_flash issues.
-- Enforces the real part's write rules: WRITE ENABLE required before
-- program/erase (and cleared by them), programming only clears bits, and
-- WIP stays set in the status register for BUSY_TIME after a program or
-- erase so the caller's polling actually gets exercised. Memory powers up
-- erased (all 0xFF).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity sim_spi_flash is
    generic (
        MEM_BYTES : positive := 16384;
        BUSY_TIME : time := 2 us
    );
    port (
        cs_n : in    std_logic;
        sclk : in    std_logic;
        mosi : in    std_logic;    -- io0
        miso : out   std_logic     -- io1
    );
end entity;

architecture model of sim_spi_flash is

    type mem_t is array (0 to MEM_BYTES - 1) of std_logic_vector(7 downto 0);
    signal mem : mem_t := (others => (others => '1'));

    constant OP_WREN    : std_logic_vector(7 downto 0) := X"06";
    constant OP_RDSR    : std_logic_vector(7 downto 0) := X"05";
    constant OP_READ4   : std_logic_vector(7 downto 0) := X"13";
    constant OP_PROG4   : std_logic_vector(7 downto 0) := X"12";
    constant OP_ERASE4  : std_logic_vector(7 downto 0) := X"21";

begin

    flash: process (sclk, cs_n) is
        variable shift_in  : std_logic_vector(7 downto 0) := (others => '0');
        variable bitcnt    : natural := 0;
        variable bytecnt   : natural := 0;
        variable opcode    : std_logic_vector(7 downto 0) := (others => '0');
        variable addr      : unsigned(31 downto 0) := (others => '0');
        variable out_reg   : std_logic_vector(7 downto 0) := (others => '0');
        variable obit      : natural := 0;
        variable wel        : boolean := false;
        variable busy_until : time := 0 ns;
        variable sector     : natural;

        impure function status_byte return std_logic_vector is
            variable s : std_logic_vector(7 downto 0) := (others => '0');
        begin
            if now < busy_until then
                s(0) := '1';
            end if;
            if wel then
                s(1) := '1';
            end if;
            return s;
        end function;

        impure function midx (a : unsigned(31 downto 0)) return natural is
        begin
            return to_integer(a) mod MEM_BYTES;
        end function;
    begin
        if falling_edge(cs_n) then
            bitcnt  := 0;
            bytecnt := 0;
            obit    := 0;
            opcode  := (others => '0');
        end if;

        if cs_n = '0' and rising_edge(sclk) then
            shift_in := shift_in(6 downto 0) & mosi;
            bitcnt   := bitcnt + 1;
            if bitcnt = 8 then
                bitcnt := 0;
                if bytecnt = 0 then
                    opcode := shift_in;
                elsif bytecnt <= 4 then
                    addr := addr(23 downto 0) & unsigned(shift_in);
                elsif opcode = OP_PROG4 then
                    if wel and now >= busy_until then
                        -- programming can only clear bits
                        mem(midx(addr)) <= mem(midx(addr)) and shift_in;
                        addr := addr + 1;
                    end if;
                end if;
                bytecnt := bytecnt + 1;
            end if;
        end if;

        if cs_n = '0' and falling_edge(sclk) then
            -- mode 0: present the next output bit after the falling edge so
            -- the controller samples it on the next rising edge
            if opcode = OP_RDSR and bytecnt >= 1 then
                if obit = 0 then
                    out_reg := status_byte;
                end if;
                miso <= out_reg(7);
                out_reg := out_reg(6 downto 0) & '0';
                obit := (obit + 1) mod 8;
            elsif opcode = OP_READ4 and bytecnt >= 5 then
                if obit = 0 then
                    out_reg := mem(midx(addr));
                    addr := addr + 1;
                end if;
                miso <= out_reg(7);
                out_reg := out_reg(6 downto 0) & '0';
                obit := (obit + 1) mod 8;
            end if;
        end if;

        if rising_edge(cs_n) then
            -- side effects commit when the frame closes
            if opcode = OP_WREN then
                wel := true;
            elsif opcode = OP_ERASE4 and bytecnt >= 5 then
                if wel and now >= busy_until then
                    sector := (midx(addr(31 downto 12) & X"000")) / 4096;
                    for i in 0 to 4095 loop
                        mem(sector * 4096 + i) <= (others => '1');
                    end loop;
                    busy_until := now + BUSY_TIME;
                end if;
                wel := false;
            elsif opcode = OP_PROG4 and bytecnt >= 5 then
                if wel then
                    busy_until := now + BUSY_TIME;
                end if;
                wel := false;
            end if;
        end if;
    end process;

end model;
