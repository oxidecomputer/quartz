-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.qspi_link_layer_pkg.all;
use work.espi_base_types_pkg.all;

entity espi_target_top is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        cs_n  : in    std_logic;
        sclk  : in    std_logic;
        io    : in    std_logic_vector(3 downto 0);
        io_o  : out   std_logic_vector(3 downto 0);
        io_oe : out   std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of espi_target_top is

    signal qspi_mode       : qspi_mode_t;
    signal is_crc_byte     : boolean;
    signal chip_sel_active : boolean;
    signal data_to_host    : data_channel;
    signal data_from_host  : data_channel;
    signal regs_if         : cmd_reg_if;

begin

    chip_sel_active <= cs_n = '0';

    -- link layer
    links: entity work.qspi_link_layer
        port map (
            clk            => clk,
            reset          => reset,
            cs_n           => cs_n,
            sclk           => sclk,
            io             => io,
            io_o           => io_o,
            io_oe          => io_oe,
            qspi_mode      => qspi_mode,
            is_crc_byte    => is_crc_byte,
            data_to_host   => data_to_host,
            data_from_host => data_from_host
        );

    -- txn layer blocks
    transaction: entity work.txn_layer_top
        port map (
            clk             => clk,
            reset           => reset,
            is_crc_byte     => is_crc_byte,
            regs_if         => regs_if,
            chip_sel_active => chip_sel_active,
            data_to_host    => data_to_host,
            data_from_host  => data_from_host
        );

    -- register blocks
    espi_regs_inst: entity work.espi_regs
        port map (
            clk       => clk,
            reset     => reset,
            regs_if   => regs_if,
            qspi_mode => qspi_mode
        );

end rtl;
