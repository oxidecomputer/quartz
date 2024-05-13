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

--! This is a module that synchronizes a rising edge between
--! two clock domains. This is implemented with flipflops, and
--! no RAM usage. The incoming edges must be much slower than
--! the slowest frequency of either clock domain and as such,
--! this block is not intended for near line-rate edges in
--! either clock domain. The propagation delay through this
--! block is generally 2 launch-side clocks (one to edge detect)
--! and one to transition the pulse, and 3 latch side clocks,
--! 2 for synchronization and 1 for registered output, pluse any
--! metastability settling time.
--! This is effectively a toggle synchronizer, no handshaking
--! The initalism tacd stands for toggle-across-clock-domains.
--!
--! **Reset considerations**:
--! No reset inputs are provided here because we'd have to synchronize
--! the resets into both domains to provide a consistent view, or be
--! very selective about which flops are reset. Because this is a
--! toggle synchronizer, the actual state of the line going between
--! domains doesn't matter and changes on every rising edge, where

--! in the catching domain, any line toggle generates a pulse out.
--! Spurious edges in the output domain could be issued if resets
--! in the sending domain are asserted and change the state of the
--! toggle, so we avoid that completely by not providing any resets.
--!
--! Note: Uses Xilinx synthesis atttributes to force use of flip
--! flops vs LUT-based shifters for synchronization.

entity tacd is
    port (
        --! "Sending" clock domain
        clk_launch : in    std_logic;
        --! Input for edge detector, must be sync'd
        --! to `clk_launch` domain already else we could sample a glitch
        pulse_in_launch : in    std_logic;
        --! "Receiving" clock domain
        clk_latch : in    std_logic;
        --! Single clock-cycle pulse out in `clk_latch` domain for
        --! every rising edge on `pulse_a_in` from the `clk_launch` domain
        --! subject to the frequency limitations described above.
        --! this signal is not registered to prevent additional delay.
        pulse_out_latch : out   std_logic
    );
end entity;

architecture rtl of tacd is

    --! holds registered value used for edge detect
    signal pulse_in_launch_last : std_logic;
    --! cobinatorial rising edge on pulse a
    signal pulse_in_launch_redge : std_logic;
    --! This line toggles in the `clk_launch` domain on every rising edge of `pulse_in_launch`
    signal toggle_launch : std_logic := '0';
    --! sync and shift register in `clk_latch` domain
    signal b_sr : unsigned(2 downto 0) := (others => '0');

    -- Xilinx synth attributes:
    attribute shreg_extract : string;
    attribute async_reg     : string;
    attribute rloc          : string;
    -- We want flipflops, not LUT-based shift registers here
    attribute shreg_extract of b_sr : signal is "no";
    -- Guard against SRL16 inference in case Reset is unused
    attribute async_reg of b_sr : signal is "TRUE";

begin

    --! Input edge detector and toggled line registers in the
    --! `clk_launch` domain
    clk_launch_regs : process (clk_launch)
    begin
        if rising_edge(clk_launch) then
            pulse_in_launch_last <= pulse_in_launch;
            -- Toggle the line going between the designs on every rising edge of the input
            if pulse_in_launch_redge = '1' then
                toggle_launch <= not toggle_launch;
            end if;
        end if;
    end process;

    pulse_in_launch_redge <= '1' when pulse_in_launch = '1' and pulse_in_launch_last = '0' else
                             '0';

    --! 2 flipflops to sync the toggling line into `clk_latch` then run
    --! that into a final flipflop for the `clk_latch` domain edge detector
    clk_latch_sync_reg : process (clk_latch)
    begin
        if rising_edge(clk_latch) then
            b_sr    <= SHIFT_RIGHT(b_sr, 1);
            b_sr(2) <= toggle_launch;
        end if;
    end process;

    -- Any toggle out of the synchronizer becomes a pulse out
    pulse_out_latch <= b_sr(1) xor b_sr(0);

end rtl;
