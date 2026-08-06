-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity spi_clk_gen is
    port (
        clk     : in    std_logic;
        reset   : in    std_logic;
        divisor : in    unsigned(15 downto 0);
        enable  : in    boolean;
        -- For internal consumers: edge detection, phase counting, debug
        sclk : out   std_logic;
        -- A second copy of the same flop, for the pin and nothing else. Both
        -- change on the same clk edge with the same value, so this costs no
        -- latency, but having no internal fanout is what lets it be packed into
        -- the IOB. Without that the launch flop lands wherever the placer likes,
        -- which measured 12ns of routing to the pin and put the read round trip
        -- outside every available sample point.
        sclk_pin : out   std_logic;
        -- True during the cycle whose clk edge will drive sclk low. Consumers
        -- use this to move data on the *same* edge sclk moves, rather than a
        -- cycle later after an edge detector has seen it. That distinction is
        -- what sets the maximum sclk rate: a cycle-late launch has to fit inside
        -- a half period, so it caps sclk at clk/4 rather than clk/2.
        sclk_fall_now : out   boolean
    );
end entity;

architecture rtl of spi_clk_gen is

    signal div_cnts        : unsigned(15 downto 0) := (others => '0');
    signal strobe          : boolean               := false;
    signal internal_enable : boolean               := false;
    signal enable_last     : boolean               := false;
    signal sclk_int        : std_logic             := '0';
    signal running         : boolean;

begin

    sclk <= sclk_int;

    -- internal_enable is registered, so on its own it lingers for a cycle after
    -- enable drops -- long enough to emit one more toggle. For a command that
    -- ends on an exact bit count, an erase or a program, that stray edge is a
    -- whole extra bit and the part throws the instruction away. Qualifying with
    -- the live enable stops the clock on the same edge the caller asked it to.
    running <= internal_enable and enable;

    -- strobe is registered, so it is already asserted during the cycle that
    -- precedes the toggling edge. That makes this safe to use as a synchronous
    -- enable by anything that needs to change state exactly when sclk does.
    sclk_fall_now <= running and strobe and sclk_int = '1';

    -- Pretty simple spi generator.
    -- start with a rising edge
    -- generate requested clock

    div_strobe: process(clk, reset)
    begin
        if reset then
            div_cnts <= (others => '0');
            strobe <= false;
        elsif rising_edge(clk) then
            strobe <= false;
            if internal_enable then
                div_cnts <= div_cnts - 1;
                if div_cnts = 0 then
                    strobe <= true;
                    div_cnts <= divisor;
                end if;
            else
                div_cnts <= divisor;
            end if;
        end if;
    end process;

    sclk_gen: process(clk, reset)
        variable nxt_sclk : std_logic;
    begin
        if reset then
            sclk_int <= '0';
            sclk_pin <= '0';
            internal_enable <= false;
            enable_last <= false;
        elsif rising_edge(clk) then
            enable_last <= enable;
            if enable  and not enable_last  then
                internal_enable <= true;
            elsif not enable then
                internal_enable <= false;
            end if;

            if running then
                nxt_sclk := sclk_int;
                if strobe then
                    nxt_sclk := not sclk_int;
                end if;
                sclk_int <= nxt_sclk;  -- assign value to output
                sclk_pin <= nxt_sclk;  -- IOB-resident duplicate, same edge
            else
                sclk_int <= '0';
                sclk_pin <= '0';
            end if;
        end if;
    end process;

end rtl;
