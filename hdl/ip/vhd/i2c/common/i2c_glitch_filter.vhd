-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Simple i2c glitch filtering for targets  I2C spec
-- This block incurs a delay of 1 sync cycle and n filter cycles
-- on both of these lines.
-- This filter is implemented as a pipeline of n register stages
-- with the output registers only being toggled when all n register
-- outputs are the same.
-- we also provide some edge detection signals since we already
-- have the last value of each of the lines.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity i2c_glitch_filter is
    generic(
        -- number of register stages the n filter pipeline
        filter_cycles : integer := 5
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        -- raw i2c signals needing to be filtered
        raw_scl : in std_logic;
        raw_sda : in std_logic;
        -- scl outputs post-filtering
        filtered_scl : out std_logic;
        scl_fedge : out std_logic;
        scl_redge : out std_logic;
        -- sda outputs post-filtering
        filtered_sda : out std_logic;
        sda_fedge : out std_logic;
        sda_redge : out std_logic
    );
end entity i2c_glitch_filter;

architecture rtl of i2c_glitch_filter is
    constant ones : std_logic_vector(filter_cycles - 1 downto 0) := (others => '1');
    constant zeros : std_logic_vector(filter_cycles - 1 downto 0) := (others => '0');
    signal sda_syncd : std_logic;
    signal scl_syncd : std_logic;
    signal scl_pipe : std_logic_vector(filter_cycles - 1 downto 0);
    signal sda_pipe : std_logic_vector(filter_cycles - 1 downto 0);
    signal last_scl : std_logic;
    signal last_sda : std_logic;
begin

    scl_meta:entity work.meta_sync
    generic map(
       stages => 1
   )
    port map(
       async_input => raw_scl,
       clk => clk,
       sycnd_output => scl_syncd
   );
   sda_meta:entity work.meta_sync
    generic map(
       stages => 1
   )
    port map(
       async_input => raw_sda,
       clk => clk,
       sycnd_output => sda_syncd
   );

    process(clk, reset)
        variable nxt_scl_pipe : std_logic_vector(filter_cycles - 1 downto 0);
        variable nxt_sda_pipe : std_logic_vector(filter_cycles - 1 downto 0);
    begin
        if reset = '1' then
            scl_pipe <= (others => '1');
            sda_pipe <= (others => '1');
            filtered_scl <= '1';
            filtered_sda <= '1';
            last_scl <= '1';
            last_sda <= '1';
        elsif rising_edge(clk) then
            last_scl <= filtered_scl;
            last_sda <= filtered_sda;
            -- Using variables here to make the filtered outputs
            -- simultaneous more easily
            nxt_scl_pipe := shift_left(scl_pipe, 1);
            nxt_scl_pipe(0) := scl_syncd;
            scl_pipe <= nxt_scl_pipe;  -- do the register assignment
            nxt_sda_pipe := shift_left(sda_pipe, 1);
            nxt_sda_pipe(0) := sda_syncd;
            sda_pipe <= nxt_sda_pipe;  -- do the register assignment

            -- we use the variables set above here to make the filtered outputs
            -- toggle simultaneously with the pipe filling and not incur
            -- an additional cycle of delay;
            filtered_scl <= '1' when nxt_scl_pipe = ones else
                           '0' when nxt_scl_pipe = zeros else
                           filtered_scl;
            filtered_sda <= '1' when nxt_sda_pipe = ones else
                           '0' when nxt_sda_pipe = zeros else
                           filtered_sda;
        end if;

    end process;
    sda_fedge <= not filtered_sda and last_sda;
    sda_redge <= filtered_sda and not last_sda;

    scl_fedge <= not filtered_scl and last_scl;
    scl_redge <= filtered_scl and not last_scl;

end architecture rtl;