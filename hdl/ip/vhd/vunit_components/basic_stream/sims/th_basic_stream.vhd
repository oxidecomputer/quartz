-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;

entity th_basic_stream is
    generic (
        source  : basic_source_t;
        sink    : basic_sink_t
    );
end entity;

architecture th of th_basic_stream is
    signal clk   : std_logic := '0';
    signal valid : std_logic;
    signal ready : std_logic;
    signal data  : std_logic_vector(data_length(source)-1 downto 0);
begin
    clk   <= not clk after 4 ns;

    basic_source_vc : entity work.basic_source
        generic map (
            source  => source)
        port map (
            clk     => clk,
            valid   => valid,
            ready   => ready,
            data    => data
        );

    basic_sink_vc : entity work.basic_sink
        generic map (
            sink    => sink)
        port map (
            clk     => clk,
            valid   => valid,
            ready   => ready,
            data    => data
        );
end architecture;