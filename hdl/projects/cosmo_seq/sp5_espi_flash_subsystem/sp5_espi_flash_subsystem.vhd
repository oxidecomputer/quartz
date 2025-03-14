-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil8x32_pkg.all;
use work.axi_st8_pkg.all;


entity sp5_espi_flash_subsystem is
    port(
        clk_125m : in std_logic;
        reset_125m : in std_logic;
        clk_200m : in std_logic;
        reset_200m : in std_logic;

        -- espi
        espi_axi_if : view axil_target;
        espi_csn : in std_logic;
        espi_clk : in std_logic;
        espi_dat : in std_logic_vector(3 downto 0);
        espi_dat_o : out std_logic_vector(3 downto 0);
        espi_dat_oe : out std_logic_vector(3 downto 0);
        response_csn : out std_logic;  -- Used for saleae decoding since response is shifted by 2 clocks
        ipcc_uart_from_espi : view axi_st_source;
        ipcc_uart_to_espi : view axi_st_sink;
        -- spi nor
        spinor_axi_if : view axil_target;
        spi_nor_csn : out std_logic;
        spi_nor_clk : out std_logic;
        spi_nor_dat : in std_logic_vector(3 downto 0);
        spi_nor_dat_o : out std_logic_vector(3 downto 0);
        spi_nor_dat_oe : out std_logic_vector(3 downto 0);
       

    );
end entity;

architecture rtl of sp5_espi_flash_subsystem is
    signal flash_cfifo_write : std_logic;
    signal flash_cfifo_data : std_logic_vector(31 downto 0);
    signal espi_cmd_fifo_rdata : std_logic_vector(31 downto 0);
    signal espi_cmd_fifo_rdack : std_logic;
    signal espi_cmd_fifo_rempty : std_logic;
    signal espi_data_fifo_write : std_logic;
    signal espi_data_fifo_wdata : std_logic_vector(7 downto 0);
    signal flash_rfifo_data : std_logic_vector(7 downto 0);
    signal flash_rfifo_rdack : std_logic;
    signal flash_rfifo_rempty : std_logic;


begin
    
    -- eSPI block -> SPI NOR  FIFO
    espi_spinor_cmd_fifo: entity work.dcfifo_xpm
    generic map(
        fifo_write_depth => 256,
        data_width => 32,
        showahead_mode => true
    )
     port map(
        wclk => clk_125m,  -- eSPI slow dclock
        reset => reset_125m,
        write_en => flash_cfifo_write,
        wdata => flash_cfifo_data,
        wfull => open,
        wusedwds => open,
        rclk => clk_125m,  -- SPI Nor Clock
        rdata => espi_cmd_fifo_rdata,
        rdreq => espi_cmd_fifo_rdack,
        rempty => espi_cmd_fifo_rempty,
        rusedwds => open
    );
    -- SPI NOR -> eSPI block FIFO
    espi_spinor_data_fifo: entity work.dcfifo_xpm
     generic map(
        fifo_write_depth => 256,
        data_width => 8,
        showahead_mode => true
    )
     port map(
        wclk => clk_125m,  -- spi nor clock
        reset => reset_125m,
        write_en => espi_data_fifo_write,
        wdata => espi_data_fifo_wdata,
        wfull => open,
        wusedwds => open,
        rclk => clk_125m, -- espi slow clock
        rdata => flash_rfifo_data,
        rdreq => flash_rfifo_rdack,
        rempty => flash_rfifo_rempty,
        rusedwds => open
    );

    -- eSPI block
    -- Only the link layer runs at 200MHz, the remaining
    -- logic runs at 125MHz so all the interfaces are synchronous
    -- to 125MHz
    espi_target_top_inst: entity work.espi_target_top
     port map(
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        clk => clk_125m,
        reset => reset_125m,
        axi_if => espi_axi_if,
        cs_n => espi_csn,
        sclk => espi_clk,
        io => espi_dat,
        io_o => espi_dat_o,
        io_oe => espi_dat_oe,
        response_csn => response_csn,
        flash_cfifo_data => flash_cfifo_data,
        flash_cfifo_write => flash_cfifo_write,
        flash_rfifo_data => flash_rfifo_data,
        flash_rfifo_rdack => flash_rfifo_rdack,
        flash_rfifo_rempty => flash_rfifo_rempty,
        to_sp_uart_data => ipcc_uart_to_espi.data,
        to_sp_uart_valid => ipcc_uart_to_espi.valid,
        to_sp_uart_ready => ipcc_uart_to_espi.ready,
        from_sp_uart_data => ipcc_uart_from_espi.data,
        from_sp_uart_valid => ipcc_uart_from_espi.valid,
        from_sp_uart_ready => ipcc_uart_from_espi.ready
    );


    spi_nor_top_inst: entity work.spi_nor_top
        port map(
           clk => clk_125m,
           reset => reset_125m,
           axi_if => spinor_axi_if,
           cs_n => spi_nor_csn,
           sclk => spi_nor_clk,
           io => spi_nor_dat,
           io_o => spi_nor_dat_o,
           io_oe => spi_nor_dat_oe,
           sp5_owns_flash => open,
           espi_cmd_fifo_rdata => espi_cmd_fifo_rdata,
           espi_cmd_fifo_rdack => espi_cmd_fifo_rdack,
           espi_cmd_fifo_rempty => espi_cmd_fifo_rempty, 
           espi_data_fifo_wdata => espi_data_fifo_wdata,
           espi_data_fifo_write => espi_data_fifo_write
   
    );

end rtl;