-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.crc16_pkg.all;

-- Byte-wide CRC-16/CCITT-FALSE register, same port shape as crc8atm_8wide so
-- the two can be used side by side. The arithmetic is in crc16_pkg.
entity crc16ccitt_8wide is
    port (
        clk     : in    std_logic;
        reset   : in    std_logic;
        data_in : in    std_logic_vector(7 downto 0);
        -- Advance over data_in. Held low for control characters and anything
        -- else the CRC does not cover.
        enable  : in    std_logic;
        -- Restore the seed. Beats enable in the same cycle.
        clear   : in    std_logic;
        crc_out : out   std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of crc16ccitt_8wide is

begin

    crc_reg: process(clk, reset)
    begin
        if reset then
            crc_out <= crc16_init;
        elsif rising_edge(clk) then
            if clear then
                crc_out <= crc16_init;
            elsif enable then
                crc_out <= crc16_next(crc_out, data_in);
            end if;
        end if;
    end process;

end rtl;
