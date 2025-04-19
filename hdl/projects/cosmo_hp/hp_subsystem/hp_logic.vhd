-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cem_hp_io_pkg.all;

-- Functional logic mapping between the I/O expander and the CEM
-- with any additional logic also.
-- Everything is already sync'd upstream, so we don't need to worry about
-- it here.
entity hp_logic is
    port(
        clk : in std_logic;
        reset : in std_logic;

        cem_led_pwm : in std_logic;
        cem_led_force : in std_logic;

        from_cem : in cem_to_fpga_io_t;
        to_cem : out fpga_to_cem_io_t;
        cem_perst_l : out std_logic;
        cem_clk_en_l : out std_logic;

        from_sp5 : in hp_to_fpga_io_t;
        to_sp5 : out fpga_to_hp_io_t
    );
end entity;

architecture rtl of hp_logic is


begin

    -- Most of the functional logic is in the package, but we'll register them here
    -- since it's going off-chip
    -- None of this stuff is required to be tri-stated.
    output_registers: process(clk, reset)
    begin
        if reset = '1' then
            to_cem <= (others => '0');
            to_sp5 <= (others => '0');
        elsif rising_edge(clk) then
            to_cem <= to_cem_pins_from_hp(from_sp5);
            to_cem.attnled <= cem_led_pwm and (from_sp5.atnled or cem_led_force);

            to_sp5 <= to_sp5_in_pins_from_cem(from_cem);
        end if;
    end process;


    perst_l: process(clk, reset)
    begin
        if reset = '1' then
            cem_perst_l <= '0';
        elsif rising_edge(clk) then
            -- Follow the SP5's power control signal
            -- one-shot on sharkfins
            cem_perst_l <=  not from_sp5.pwren_l;
        end if;
    end process;

    clk_en: process(clk, reset)
    begin
        if reset = '1' then
            cem_clk_en_l <= '1';
        elsif rising_edge(clk) then
            -- Follow the CEM's power good signal
            -- turn clock on when CEM is powered/present
            -- TODO: we can be smarter about this if we want to
            -- right now if you pop a U.2 the clock stays on.
            cem_clk_en_l <= from_cem.pg_l;
        end if;
    end process;

end rtl;