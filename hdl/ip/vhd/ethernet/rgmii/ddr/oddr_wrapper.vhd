-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Single-bit DDR output register. `d_rise` is presented during the clock-high
-- phase (launched on the rising edge) and `d_fall` during the clock-low phase.
-- Only the behavioral SIM model is implemented today; the vendor generate
-- branches are reserved for Xilinx ODDR / Lattice ODDRX1F primitives so a board
-- target can be dropped in without touching the RGMII core.

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
begin

    sim_gen: if TARGET = "SIM" generate
        -- Edge-aligned DDR: q follows the selected phase. The companion
        -- iddr_wrapper applies the RGMII clock-to-data skew on capture.
        q <= d_rise when clk = '1' else d_fall;
    end generate;

    -- xilinx_gen: if TARGET = "XILINX" generate
    --     ODDR primitive (DDR_CLK_EDGE => "SAME_EDGE") instantiation
    -- end generate;
    -- lattice_gen: if TARGET = "LATTICE" generate
    --     ODDRX1F primitive instantiation
    -- end generate;

    assert TARGET = "SIM"
        report "oddr_wrapper: only the SIM TARGET is implemented"
        severity failure;

end architecture;
