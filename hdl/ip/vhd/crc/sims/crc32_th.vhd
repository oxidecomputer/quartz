-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity crc32_th is
end entity;

architecture th of crc32_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal data_in : std_logic_vector(7 downto 0) := (others => '0');
    signal enable  : std_logic                    := '0';
    signal clear   : std_logic                    := '0';
    signal crc_out : std_logic_vector(31 downto 0);

begin

    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    dut: entity work.crc32_8wide
        port map (
            clk     => clk,
            reset   => reset,
            data_in => data_in,
            enable  => enable,
            clear   => clear,
            crc_out => crc_out
        );

end th;
