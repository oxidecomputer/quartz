-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Single-bit DDR input register. The incoming `q` pin is sampled on both edges
-- of `clk`; `d_rise` is the value captured on the rising edge, `d_fall` on the
-- falling edge.
--
-- TARGET selects the implementation:
--   "SIM"    - behavioral sampler. The sampling clock is delayed by CLK_DELAY to
--              model the RGMII clock-to-data skew (RGMII-ID style), placing the
--              sampling edges inside the data eye so behavioral loopback is
--              race-free.
--   "XILINX" - UltraScale+ IDDRE1 primitive (SAME_EDGE_PIPELINED). The required
--              clock-to-data skew is supplied upstream by delaying rxc (IDELAYE3
--              + IDELAYCTRL) before it reaches this register, not here.

library ieee;
    use ieee.std_logic_1164.all;

entity iddr_wrapper is
    generic (
        TARGET    : string := "SIM";
        CLK_DELAY : time   := 2 ns
    );
    port (
        clk    : in    std_logic;
        q      : in    std_logic;
        d_rise : out   std_logic;
        d_fall : out   std_logic
    );
end entity;

architecture rtl of iddr_wrapper is

    signal clk_d : std_logic;

    -- UltraScale+ DDR input register. Declared locally so the analyzer/LSP is
    -- happy; Vivado binds it to the UNISIM cell by name during synthesis. CB is
    -- driven from the same clock with IS_CB_INVERTED so it sees the inverted
    -- edge. This branch is never elaborated under the SIM target.
    component iddre1 is
        generic (
            ddr_clk_edge   : string := "SAME_EDGE_PIPELINED";
            is_c_inverted  : bit    := '0';
            is_cb_inverted : bit    := '1'
        );
        port (
            q1 : out   std_ulogic;
            q2 : out   std_ulogic;
            c  : in    std_ulogic;
            cb : in    std_ulogic;
            d  : in    std_ulogic;
            r  : in    std_ulogic
        );
    end component;

begin

    sim_gen: if TARGET = "SIM" generate
        clk_d <= transport clk after CLK_DELAY;

        sample: process (clk_d) is
        begin
            if rising_edge(clk_d) then
                d_rise <= q;
            elsif falling_edge(clk_d) then
                d_fall <= q;
            end if;
        end process;
    end generate;

    xilinx_gen: if TARGET = "XILINX" generate
        iddr_i: component iddre1
            generic map (
                ddr_clk_edge   => "SAME_EDGE_PIPELINED",
                is_cb_inverted => '1'
            )
            port map (
                q1 => d_rise,   -- captured on the rising edge of clk
                q2 => d_fall,   -- captured on the falling edge of clk
                c  => clk,
                cb => clk,      -- inverted internally via IS_CB_INVERTED
                d  => q,
                r  => '0'
            );
    end generate;

    -- lattice_gen: if TARGET = "LATTICE" generate
    --     IDDRX1F primitive instantiation
    -- end generate;

    assert TARGET = "SIM" or TARGET = "XILINX"
        report "iddr_wrapper: unsupported TARGET '" & TARGET & "'"
        severity failure;

end architecture;
