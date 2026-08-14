-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Single-bit DDR output register. `d_rise` is presented during the clock-high
-- phase (launched on the rising edge) and `d_fall` during the clock-low phase.
--
-- TARGET selects the implementation:
--   "SIM"    - behavioral DDR mux, for simulation/loopback.
--   "XILINX" - UltraScale+ ODDRE1 primitive (d_rise -> D1, d_fall -> D2).
-- The Lattice ODDRX1F branch is left as a stub for a future board target.

library ieee;
    use ieee.std_logic_1164.all;

entity oddr_wrapper is
    generic (
        TARGET : string := "SIM"
    );
    port (
        clk    : in    std_logic;
        d_rise : in    std_logic;
        d_fall : in    std_logic;
        q      : out   std_logic
    );
end entity;

architecture rtl of oddr_wrapper is

    -- UltraScale+ DDR output register. Declared locally so the analyzer/LSP is
    -- happy; Vivado binds it to the UNISIM cell by name during synthesis. This
    -- branch is never elaborated under the SIM target the testbenches use.
    component oddre1 is
        generic (
            is_c_inverted  : bit    := '0';
            is_d1_inverted : bit    := '0';
            is_d2_inverted : bit    := '0';
            srval          : bit    := '0'
        );
        port (
            q  : out   std_ulogic;
            c  : in    std_ulogic;
            d1 : in    std_ulogic;
            d2 : in    std_ulogic;
            sr : in    std_ulogic
        );
    end component;

begin

    sim_gen: if TARGET = "SIM" generate
        -- Edge-aligned DDR: q follows the selected phase. The companion
        -- iddr_wrapper applies the RGMII clock-to-data skew on capture.
        -- The 1 ps inertial delay swallows delta-cycle glitches when an input
        -- changes in the same instant clk rises (the registered ODDRE1 cannot
        -- glitch, so the mux model must not either -- a zero-width pulse here
        -- reads as a spurious clock edge to anything waiting on q).
        q <= d_rise after 1 ps when clk = '1' else d_fall after 1 ps;
    end generate;

    xilinx_gen: if TARGET = "XILINX" generate
        oddr_i: component oddre1
            generic map (
                srval => '0'
            )
            port map (
                q  => q,
                c  => clk,
                d1 => d_rise,   -- launched on the rising edge of clk
                d2 => d_fall,   -- launched on the falling edge of clk
                sr => '0'
            );
    end generate;

    -- lattice_gen: if TARGET = "LATTICE" generate
    --     ODDRX1F primitive instantiation
    -- end generate;

    assert TARGET = "SIM" or TARGET = "XILINX"
        report "oddr_wrapper: unsupported TARGET '" & TARGET & "'"
        severity failure;

end architecture;
