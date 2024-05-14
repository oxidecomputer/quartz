-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/

--! This block implements a reset synchronizer or reset bridge for crossing
--! clock domains with resets. Reset clock crossings are especially tricky
--! because reset signals can go into the async reset or preset ports
--! on flipflops, or be used as a synchronous reset, and can be asserted
--! before clocks are settled or even started in some cases.
--!
--! Many best practices exist, and this module implements a synchronizer
--! that will assert reset without a clock (async), ensures a minimum
--! reset duration of multiple clock periods, and will not de-assert
--! until the clock is actually running.
--!
--! **Note**: Care is warranted for cases where you expect the reset to assert
--! during normal operation and where the output of this block drives
--! a synchronous flipflop port. Because the reset may assert asynchronously,
--! but is run to a synchronous port, metastability could occur during reset
--! assert. This is, in my opinion, an under-appreciated nuance to the widespread
--! "use a reset bridge" advice when combined with the "use synchronous resets"
--! advice. Most of the literature avoids dealing with this specific case directly.
--! In most cases, if the reset is held long enough to allow the metastability to
--! settle out, and any downstream logic is either also reset or is not glitch-prone
--! (ie pipeline registers) this is acceptable without additional treatment.
--! If, however, there are concerns around this behavior, an additional sync stage
--! may be added at the cost of losing reset if your clock is not running, or you
--! must revert to using async reset ports on the concerning flipflops, in which
--! case you then have to deal with the fact that ouputs from these flops can change
--! asynchronously when reset asserts, and repeat the analysis.  My, aren't resets fun?

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity async_reset_bridge is
    generic (
        --! Overridable reset polarity for the `reset_async` port.
        --! In general we want active high resets in FPGAs, but not
        --! all IP behaves this way
        async_reset_active_level : std_logic := '1'
    );
    port (
        --! Latching clock domain
        clk : in    std_logic;
        --! Reset async to `clk` with polarity set by `ASYNC_RESET_ACTIVE_LEVEL`
        reset_async : in    std_logic;
        --! Reset output, active high. Async asserts, sync de-asserts. See description
        --! above for cautions
        reset_sync : out   std_logic
    );
end entity;

architecture rtl of async_reset_bridge is

    signal reset_flops : unsigned(2 downto 0);

begin

    -- Since we're using async reset here, this can't turn into an SRL16 so we
    -- don't need any special control attributes here
    reset_reg : process (clk, reset_async)
    begin
        if reset_async = async_reset_active_level then
            reset_flops <= (others => '0');
        elsif rising_edge(clk) then
            reset_flops                   <= shift_right(reset_flops, 1);
            reset_flops(reset_flops'left) <= '0';
        end if;
    end process;

    reset_sync <= reset_flops(0);

end rtl;
