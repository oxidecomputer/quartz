-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Single-bit DDR input register. The incoming `q` pin is sampled on both edges
-- of `clk`; `d_rise` is the value captured on the rising edge, `d_fall` on the
-- falling edge. In the SIM model the sampling clock is delayed by CLK_DELAY to
-- model the RGMII clock-to-data skew (RGMII-ID style internal delay), placing
-- the sampling edges inside the data eye so behavioral loopback is race-free.
-- Vendor builds supply this skew via IDELAY / clock routing instead.

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

    -- xilinx_gen: if TARGET = "XILINX" generate
    --     IDDR primitive (DDR_CLK_EDGE => "SAME_EDGE_PIPELINED") instantiation
    -- end generate;
    -- lattice_gen: if TARGET = "LATTICE" generate
    --     IDDRX1F primitive instantiation
    -- end generate;

    assert TARGET = "SIM"
        report "iddr_wrapper: only the SIM TARGET is implemented"
        severity failure;

end architecture;
