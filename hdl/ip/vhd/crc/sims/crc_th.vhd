-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Test harness for the byte-wide CRC registers. Both engines get their own
-- control signals so the testbench can feed them independently.
entity crc_th is
end entity;

architecture th of crc_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal crc8_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal crc8_enable : std_logic := '0';
    signal crc8_clear  : std_logic := '0';
    signal crc8_out    : std_logic_vector(7 downto 0);

    signal crc16_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal crc16_enable : std_logic := '0';
    signal crc16_clear  : std_logic := '0';
    signal crc16_out    : std_logic_vector(15 downto 0);

begin

    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    crc8atm_8wide_inst: entity work.crc8atm_8wide
        port map (
            clk     => clk,
            reset   => reset,
            data_in => crc8_data,
            enable  => crc8_enable,
            clear   => crc8_clear,
            crc_out => crc8_out
        );

    crc16ccitt_8wide_inst: entity work.crc16ccitt_8wide
        port map (
            clk     => clk,
            reset   => reset,
            data_in => crc16_data,
            enable  => crc16_enable,
            clear   => crc16_clear,
            crc_out => crc16_out
        );

end th;
