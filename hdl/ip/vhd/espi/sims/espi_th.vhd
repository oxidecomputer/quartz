-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qspi_vc_pkg.all;

entity espi_th is
end entity;

architecture th of espi_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal   ss_n       : std_logic_vector(7 downto 0);
    signal   sclk       : std_logic;
    signal   io         : std_logic_vector(3 downto 0);
    signal   io_o       : std_logic_vector(3 downto 0);
    signal   io_oe      : std_logic_vector(3 downto 0);
    constant qspi_actor : qspi_vc_t := new_qspi_vc("espi_vc");

    signal flash_cfifo_data   : std_logic_vector(31 downto 0);
    signal flash_cfifo_write  : std_logic;
    signal flash_rfifo_data   : std_logic_vector(7 downto 0);
    signal flash_rfifo_rdack  : std_logic;
    signal flash_rfifo_rempty : std_logic;

begin

    -- set up a fastish clock for the sim
    -- environment and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    qspi_controller_vc_inst: entity work.qspi_controller_vc
        generic map (
            qspi_vc => qspi_actor
        )
        port map (
            ss_n => ss_n,
            sclk => sclk,
            io   => io
        );

    dut: entity work.espi_target_top
        port map (
            clk                => clk,
            reset              => reset,
            cs_n               => ss_n(0),
            sclk               => sclk,
            io                 => io,
            io_o               => io_o,
            io_oe              => io_oe,
            flash_cfifo_data   => flash_cfifo_data,
            flash_cfifo_write  => flash_cfifo_write,
            flash_rfifo_data   => flash_rfifo_data,
            flash_rfifo_rdack  => flash_rfifo_rdack,
            flash_rfifo_rempty => flash_rfifo_rempty
        );

    fake_flash_txn_mgr_inst: entity work.fake_flash_txn_mgr
        port map (
            clk                 => clk,
            reset               => reset,
            espi_cmd_fifo_data  => flash_cfifo_data,
            espi_cmd_fifo_write => flash_cfifo_write,
            flash_rdata         => flash_rfifo_data,
            flash_rdata_empty   => flash_rfifo_rempty,
            flash_rdata_rdack   => flash_rfifo_rdack
        );

    io_tris: process(all)
    begin
        for i in io'range loop
            io(i) <= io_o(i) when io_oe(i) = '1' else 'H';
        end loop;
    end process;

end th;
