-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Test harness for the 8-bit additive scrambler. We wire two identical
-- instances back to back, the first scrambling and the second de-scrambling,
-- to show that scramble and de-scramble really are the same operation. Both
-- get the same reset and load controls so they stay in lock-step, which is
-- what a real link has to arrange for itself.
entity lfsr_th is
end entity;

architecture th of lfsr_th is

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '1';
    signal sync_reset : std_logic := '0';

    signal load_valid : std_logic                    := '0';
    signal load_data  : std_logic_vector(7 downto 0) := (others => '0');

    signal data_valid : std_logic                    := '0';
    signal plain_data : std_logic_vector(7 downto 0) := (others => '0');

    signal tx_state       : std_logic_vector(7 downto 0);
    signal rx_state       : std_logic_vector(7 downto 0);
    signal scrambled_data : std_logic_vector(7 downto 0);
    signal recovered_data : std_logic_vector(7 downto 0);

begin

    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    scrambler_inst: entity work.scrambler_lfsr8
        port map (
            clk        => clk,
            reset      => reset,
            sync_reset => sync_reset,
            load_valid => load_valid,
            load_data  => load_data,
            lfsr_state => tx_state,
            data_in    => plain_data,
            data_valid => data_valid,
            data_out   => scrambled_data
        );

    descrambler_inst: entity work.scrambler_lfsr8
        port map (
            clk        => clk,
            reset      => reset,
            sync_reset => sync_reset,
            load_valid => load_valid,
            load_data  => load_data,
            lfsr_state => rx_state,
            data_in    => scrambled_data,
            data_valid => data_valid,
            data_out   => recovered_data
        );

end th;
