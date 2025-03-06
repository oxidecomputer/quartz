-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Grapefruit is meant to serve as a BMC replacement in AMD's Ruby
-- reference platform for cosmo dev.  As such, there are some functions
-- we need to implement on grapefruit that we're not going to implement
-- on Cosmo.  One of these is the SGPIO interface. It appears that some
-- functionality here is required for the Ruby to come out of standby
-- power.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil8x32_pkg.all;

use work.gfruit_sgpio_regs_pkg.all;

entity gfruit_sgpio is
    port (
        clk: in std_logic;
        reset: in std_logic;

        axi_if : view axil_target;

        sclk: out std_logic;
        sgpio0_do : out std_logic;
        sgpio0_di : in std_logic;
        sgpio0_ld : out std_logic;

        sgpio1_do : out std_logic;
        sgpio1_di : in std_logic;
        sgpio1_ld : out std_logic;
        
    );
end entity;

architecture rtl of gfruit_sgpio is
    signal gpio0_to_host : out0_type;
    signal gpio0_from_host : in0_type;
    signal gpio1_to_host : out1_type;
    signal gpio1_from_host : in1_type;
    signal gpio0_temp : std_logic_vector(15 downto 0);
    signal gpio1_temp : std_logic_vector(15 downto 0);

begin

    sgpio_regs_inst: entity work.sgpio_regs
     port map(
        clk => clk,
        reset => reset,
        out0 => gpio0_to_host,
        out1 => gpio1_to_host,
        in0 => gpio0_from_host,
        in1 => gpio1_from_host,
        axi_if => axi_if
    );
    gpio0_from_host <= unpack(resize(gpio0_temp, 32));
    gpio1_from_host <= unpack(resize(gpio1_temp, 32));


    sgpio_ch0: entity work.sgpio_top
        generic map (
            GPIO_WIDTH => 16,
            CLK_DIV => 12
        )
        port map (
            clk => clk,
            reset => reset,
            gpio_in => resize(compress(gpio0_to_host), 16),
            gpio_out => gpio0_temp,
            sclk => sclk,
            do => sgpio0_do,
            di => sgpio0_di,
            load => sgpio0_ld
        );

    sgpio_ch1: entity work.sgpio_top
        generic map (
            GPIO_WIDTH => 16,
            CLK_DIV => 12
        )
        port map (
            clk => clk,
            reset => reset,
            gpio_in => resize(compress(gpio1_to_host), 16),
            gpio_out => gpio1_temp,
            sclk => open,
            do => sgpio1_do,
            di => sgpio1_di,
            load => sgpio1_ld
        );

end rtl;