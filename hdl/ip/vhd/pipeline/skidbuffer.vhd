-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- inspired by https://zipcpu.com/blog/2019/05/22/skidbuffer.html

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity skidbuffer is
    generic(
        WIDTH : integer
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        sink_valid    : in  std_logic;
        sink_data     : in  std_logic_vector(WIDTH - 1 downto 0);
        sink_ready    : out std_logic;
        source_valid   : out std_logic;
        source_data    : out std_logic_vector(WIDTH - 1 downto 0);
        source_ready   : in  std_logic
    );
end entity;

architecture rtl of skidbuffer is
 
    type reg_t is record
        valid : std_logic;
        data  : std_logic_vector(WIDTH - 1 downto 0);
    end record;

    signal reg : reg_t;

begin


    skid_buf_logic: process(clk, reset)
    begin
        if reset then
            reg <= (valid => '0', data => (others => '0'));
        elsif rising_edge(clk) then
            if sink_valid and sink_ready and (source_valid and not source_ready) then
                -- This is incoming data, but output is stalled
                reg.valid <= '1';
            elsif source_ready then
                -- This is outgoing data, so we can clear the register
                reg.valid <= '0';
            end if;
            if sink_ready then
                -- We can accept incoming data, copy to buffer whether we call it
                -- valid or not depends on whether we are stalled.
                reg.data <= sink_data;
            end if;
            
        end if;
    end process;

    -- can accept data anytime we have room in the internal buffer
    sink_ready <= not reg.valid;
    -- we have valid data any time our input is valid or we have valid data in the buffer
    source_valid <= sink_valid or reg.valid;

    -- shovel data out the output, pass-thru if we have nothing stored
    source_data <= reg.data when reg.valid else sink_data;

end rtl;
