-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

entity countdown_th is
    generic (
        CLK_PER : time;
        SIZE    : positive
    );
end entity;

architecture th of countdown_th is

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';

    signal dut_count    : std_logic_vector(SIZE - 1 downto 0) := (others => '0');
    signal dut_load     : std_logic := '0';
    signal dut_decr     : std_logic := '0';
    signal dut_clear    : std_logic := '0';
    signal dut_done     : std_logic := '0';

begin

    clk   <= not clk after CLK_PER / 2;
    reset <= '0' after 200 ns;

    countdown_inst: entity work.countdown
     generic map(
        SIZE => SIZE
    )
     port map(
        clk     => clk,
        reset   => reset,
        count   => dut_count,
        load    => dut_load,
        decr    => dut_decr,
        clear   => dut_clear,
        done    => dut_done
    );

end th;