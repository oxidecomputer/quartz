-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Block Description
--! A basic metastability and synchronization block
--! that runs the async signal through contfigurable `STAGES`
--! number of flipflops to synchronize. Latching domain
--! reset is optional and active high.
--!
--! Note: This is using Xilinx synthesis attributes to force
--! flip-flops instead of LUT-based shifters

entity meta_sync is
    generic (

        --! Number of sync stages
        stages : integer := 2
    );
    port (
        --! Async signal to sync
        async_input : in    std_logic;
        --! Latching clock input
        clk : in    std_logic;
        --! Output, sync'd to clk
        sycnd_output : out   std_logic
    );
end entity;

architecture rtl of meta_sync is

    --! Flip-flop based shift register(s)
    signal sr : unsigned(stages - 1 downto 0);
    -- Xilinx synth attributes:
    attribute shreg_extract : string;
    attribute async_reg     : string;
    attribute rloc          : string;
    -- We want flipflops, not LUT-based shift registers here
    attribute shreg_extract of sr : signal is "no";
    -- Guard against SRL16 inference in case reset is unused
    attribute async_reg of sr : signal is "TRUE";

begin

    multi_reg_gen : if stages > 1 generate

        sync_regs: process(clk)
        begin
            if rising_edge(clk) then
                sr    <= shift_right(sr, 1);
                sr(sr'left) <= async_input;
            end if;
        end process;

    else
    generate

        sync_regs: process(clk)
        begin
            if rising_edge(clk) then
                sr(sr'left) <= async_input;
            end if;
        end process;

    end generate;

    -- Output is the right-most shift register output
    -- since we're shifting right
    sycnd_output <= sr(sr'right);

end rtl;
