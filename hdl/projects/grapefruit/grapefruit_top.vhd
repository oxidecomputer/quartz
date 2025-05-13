-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil_common_pkg.all;
use work.axil26x32_pkg;
use work.axil8x32_pkg;
use work.i2c_common_pkg.all;
use work.time_pkg.all;
use work.tristate_if_pkg.all;

entity grapefruit_top is
    port (
        clk     : in    std_logic;
        reset_l : in    std_logic;
        seq_reg_to_sp_V3P3_pg: out std_logic;
        seq_reg_to_sp_v1p2_pg: out std_logic;
        sp5_to_sp_present_l : out std_logic;
        sp_to_sp5_prochot_l : in std_logic;
        sp5_to_sp_sp5R : out std_logic_vector(4 downto 1);
        sp5_to_sp_coretype : out std_logic_vector(2 downto 0);
        sp_to_ignit_fault_l: in std_logic;
        sp5_to_sp_int_l : out std_logic;
        sp_to_sp5_int_l : in std_logic;
        sp_to_sp5_nmi_sync_flood_l: in std_logic;
        nic_to_sp_gpio0_present1: out std_logic;
        nic_to_sp_gpio0_present2: out std_logic;
        rot_to_ignit_fault_l: in std_logic;

        fmc_sp_to_fpga_clk : in std_logic;
        fmc_sp_to_fpga_oe_l : in std_logic;
        fmc_sp_to_fpga_we_l : in std_logic;
        fmc_sp_to_fpga_wait_l : out std_logic;
        fmc_sp_to_fpga_cs1_l: in std_logic;
        fmc_sp_to_fpga_adv_l : in std_logic;
        fmc_sp_to_fpga_bl0_l : in std_logic;
        fmc_sp_to_fpga_bl1_l : in std_logic;
        fmc_sp_to_fpga_da : inout std_logic_vector(15 downto 0);
        fmc_sp_to_fpga_a : in std_logic_vector(19 downto 16);

        seq_to_sp_misc_a : in std_logic;
        seq_to_sp_misc_b : in std_logic;
        seq_to_sp_misc_c : in std_logic;
        seq_to_sp_misc_d : in std_logic;

        seq_to_sp_int_l : in std_logic;
        fpga_to_sp_irq1_l : out std_logic;
        fpga_to_sp_irq2_l : out std_logic;
        fpga_to_sp_irq3_l : out std_logic;
        fpga_to_sp_irq4_l : out std_logic;

        uart0_sp_to_fpga_dat : in std_logic;
        uart0_fpga_to_sp_dat: out std_logic;
        uart0_sp_to_fpga_rts_l : in std_logic;
        uart0_fpga_to_sp_rts_l: out std_logic;

        uart1_sp_to_fpga_dat : in std_logic;
        uart1_fpga_to_sp_dat: out std_logic;
        uart1_sp_to_fpga_rts_l : in std_logic;
        uart1_fpga_to_sp_rts_l: out std_logic;

        uart_local_sp_to_fpga_dat : in std_logic;
        uart_local_fpga_to_sp_dat: out std_logic;
        uart_local_sp_to_fpga_rts_l : in std_logic;
        uart_local_fpga_to_sp_rts_l: out std_logic;

        sp_to_seq_system_reset_l : in std_logic;
        seq_rev_id : in std_logic_vector(2 downto 0);

        spi_fpga_to_flash_cs_l : out std_logic;
        spi_fpga_to_flash_clk : out std_logic;
        spi_fpga_to_flash_dat : inout std_logic_vector(3 downto 0);

        spi_fpga_to_flash2_cs_l : out std_logic;
        spi_fpga_to_flash2_clk : out std_logic;
        spi_fpga_to_flash2_dat : inout std_logic_vector(3 downto 0);
        
        i3c_sp5_to_fpga_oe_n_3v3: out std_logic;
        i3c_fpga_to_dimm_oe_n_3v3: out std_logic;

        uart0_sp5_to_fpga_data: in std_logic;
        uart0_fpga_to_sp5_data: out std_logic;
        uart0_sp5_to_fpga_rts_l : in std_logic;
        uart0_fpga_to_sp5_rts_l: out std_logic;

        uart1_scm_to_hpm_dat: out std_logic;
        uart1_hpm_to_scm_dat: in std_logic;

        fpga_spare_1v8: out std_logic_vector(7 downto 0);
        fpga_spare_3v3: out std_logic_vector(7 downto 0);

        espi_hpm_to_scm_reset_l : in std_logic;
        espi_scm_to_hpm_alert_l : out std_logic;
        espi_hpm_to_scm_cs_l: in std_logic;
        espi_hpm_to_scm_clk: in std_logic;
        espi_hpm_to_scm_dat: inout std_logic_vector(3 downto 0);

        i3c_hpm_to_scm_dimm0_abcdef_scl: inout std_logic;
        i3c_hpm_to_scm_dimm0_abcdef_sda: inout std_logic;
        i3c_hpm_to_scm_dimm0_ghijkl_scl: inout std_logic;
        i3c_hpm_to_scm_dimm0_ghijkl_sda: inout std_logic;

        i3c_hpm_to_scm_dimm1_abcdef_scl: inout std_logic;
        i3c_hpm_to_scm_dimm1_abcdef_sda: inout std_logic;
        i3c_hpm_to_scm_dimm1_ghijkl_scl: inout std_logic;
        i3c_hpm_to_scm_dimm1_ghijkl_sda: inout std_logic;

        i3c_scm_to_dimm0_abcdef_scl: inout std_logic;
        i3c_scm_to_dimm0_abcdef_sda: inout std_logic;
        i3c_scm_to_dimm0_ghijkl_scl: inout std_logic;
        i3c_scm_to_dimm0_ghijkl_sda: inout std_logic;
        i3c_scm_to_dimm1_abcdef_scl: inout std_logic;
        i3c_scm_to_dimm1_abcdef_sda: inout std_logic;
        i3c_scm_to_dimm1_ghijkl_scl: inout std_logic;
        i3c_scm_to_dimm1_ghijkl_sda: inout std_logic;

        hdt_scm_to_hpm_tck: out std_logic;
        hdt_scm_to_spm_tms: out std_logic;
        hdt_scm_to_spm_dat: out std_logic;
        hdt_hpm_to_scm_dat: in std_logic;
        scm_to_hpm_fw_recovery: out std_logic;
        hpm_to_scm_stby_rdy: in std_logic;
        scm_to_hpm_stby_en: out std_logic;
        scm_to_hpm_stby_rst_l: out std_logic;
        scm_to_hpm_pwrbtn_l: out std_logic;
        hpm_to_scm_pwrok: in std_logic;
        scm_to_hpm_dbreq_l: out std_logic;
        hpm_to_scm_pcie_rst_buf_l: out std_logic;
        hpm_to_scm_spare: in std_logic_vector(1 downto 0);
        scm_to_hpm_rot_cpu_rst_l: out std_logic;
        hpm_to_scm_chassis_intr_l: in std_logic;
        hpm_to_scm_irq_l: in std_logic;
        scm_to_hpm_virtual_reseat: out std_logic;
        uart_spare_scm_to_hpm_dat: out std_logic;
        uart_spare_hpm_to_scm_dat: in std_logic;

        qspi0_hpm_to_scm_clk : in std_logic;
        qspi0_hpm_to_scm_cs0_l: in std_logic;
        qspi0_hpm_to_scm_cs1_l: in std_logic;
        qspi0_hpm_to_scm_dat0: in std_logic;
        qspi0_hpm_to_scm_dat1: out std_logic;
        qspi0_hpm_to_scm_dat2: in std_logic;
        qspi0_hpm_to_scm_dat3: in std_logic;
        
        sgpio_scm_to_hpm_clk : out std_logic;
        sgpio_scm_to_hpm_dat: out std_logic_vector(1 downto 0);
        sgpio_hpm_to_scm_dat: in std_logic_vector(1 downto 0);
        sgpio_scm_to_hpm_ld: out std_logic_vector(1 downto 0);
        sgpio_scm_to_hpm_reset_l: out std_logic;
        sgpio_hpm_to_scm_intr_l: out std_logic;

        qspi1_scm_to_hpm_clk : out std_logic;
        qspi1_scm_to_hpm_cs_l: in std_logic;
        qspi1_scm_to_hpm_dat: inout std_logic_vector(3 downto 0);
        spi_hpm_to_scm_tpm_cs_l : in std_logic;

        i2c_sp_to_fpga_scl: inout std_logic;
        i2c_sp_to_fpga_sda: inout std_logic;

        i2c_scm_to_hpm_scl0: inout std_logic;
        i2c_scm_to_hpm_sda0: inout std_logic;
        i2c_scm_to_hpm_scl1: inout std_logic;
        i2c_scm_to_hpm_sda1: inout std_logic;
        i2c_scm_to_hpm_sda3: inout std_logic;
        i2c_scm_to_hpm_scl3: inout std_logic;
        i2c_scm_to_hpm_sda4: inout std_logic;
        i2c_scm_to_hpm_scl4: inout std_logic;
        i2c_scm_to_hpm_sda5: inout std_logic;
        i2c_scm_to_hpm_scl5: inout std_logic;
        i2c_scm_to_hpm_sda8: inout std_logic;
        i2c_scm_to_hpm_scl8: inout std_logic;
        i2c_scm_to_hpm_sda9: inout std_logic;
        i2c_scm_to_hpm_scl9: inout std_logic;
        i2c_scm_to_hpm_sda11: inout std_logic;
        i2c_scm_to_hpm_scl11: inout std_logic;
        i2c_scm_to_hpm_sda12: inout std_logic;
        i2c_scm_to_hpm_scl12: inout std_logic;

        fpga_to_fruid_scl: inout std_logic;
        fpga_to_fruid_sda: inout std_logic
    );
end entity;

architecture rtl of grapefruit_top is

    signal counter : unsigned(31 downto 0);
    signal pll_locked_async: std_logic;
    signal clk_125m : std_logic;
    signal reset_125m : std_logic;
    signal clk_200m : std_logic;
    signal reset_200m : std_logic;
    signal reset_fmc: std_logic;
    signal fmc_internal_data_out : std_logic_vector(15 downto 0);
    signal fmc_data_out_enable: std_logic;

    signal fmc_axi_if : axil26x32_pkg.axil_t;

    constant BAUD_3M_AT_125M : integer := 5;

    -- TODO: someday I'd like the rdl stuff to both generate this and the fabric maybe?
    constant config_array : axil_responder_cfg_array_t := 
     (0 => (base_addr => x"00000000", addr_span_bits => 8),
      1 => (base_addr => x"00000100", addr_span_bits => 8),
      2 => (base_addr => x"00000200", addr_span_bits => 8),
      3 => (base_addr => x"00000300", addr_span_bits => 8)
      );
    signal responders : axil8x32_pkg.axil_array_t(config_array'range);
    signal espi_cmd_fifo_rdata : std_logic_vector(31 downto 0);
    signal espi_cmd_fifo_rdack : std_logic;
    signal espi_cmd_fifo_rempty : std_logic;
    signal espi_data_fifo_write : std_logic;
    signal espi_data_fifo_wdata : std_logic_vector(7 downto 0);
    signal flash_cfifo_data : std_logic_vector(31 downto 0);
    signal flash_cfifo_write : std_logic;
    signal flash_rfifo_data : std_logic_vector(7 downto 0);
    signal flash_rfifo_rdack : std_logic;
    signal flash_rfifo_rempty : std_logic;
    signal host_espi_to_sp_uart_data : std_logic_vector(7 downto 0);
    signal host_espi_to_sp_uart_valid : std_logic;
    signal host_espi_to_sp_uart_ready : std_logic;
    signal from_sp_uart_to_host_espi_valid : std_logic;
    signal from_sp_uart_to_host_espi_ready : std_logic;
    signal from_sp_uart_to_host_espi_data : std_logic_vector(7 downto 0);
    signal console_from_sp_rx_ready : std_logic;
    signal console_from_sp_rx_data : std_logic_vector(7 downto 0);
    signal console_from_sp_rx_valid : std_logic;
    signal console_to_sp_tx_ready : std_logic;
    signal console_to_sp_tx_data : std_logic_vector(7 downto 0);
    signal console_to_sp_tx_valid : std_logic;
    signal espi_io_o : std_logic_vector(3 downto 0);
    signal espi_io_oe : std_logic_vector(3 downto 0);
    signal ipcc_sp_to_fpga_data: std_logic;
    signal ipcc_fpga_to_sp_data: std_logic;
    signal ipcc_sp_to_fpga_cts_l: std_logic;
    signal ipcc_fpga_to_sp_rts_l: std_logic;
    constant ipcc_dbg_en : std_logic := '0';
    signal hpm_to_scm_stby_rdy_syncd : std_logic;
    signal sp5_owns_flash : std_logic;
    signal spi_nor_block_data_o : std_logic_vector(3 downto 0);
    signal spi_nor_block_data_oe : std_logic_vector(3 downto 0);

    signal ruby_scl_if : tristate;
    signal ruby_sda_if : tristate;
    signal dimm_scl_if : tristate;
    signal dimm_sda_if : tristate;
begin

    espi_scm_to_hpm_alert_l <= 'Z';

    pll: entity work.gfruit_pll
        port map ( 
          clk_50m => clk,
          clk_125m => clk_125m,
          clk_200m => clk_200m,
          reset => not reset_l,
          locked => pll_locked_async
          
        );

    -- Reset synchronizer into the clock domains
    reset_sync_inst: entity work.reset_sync
     port map(
        pll_locked_async => pll_locked_async,
        clk_125m => clk_125m,
        reset_125m => reset_125m,
        clk_200m => clk_200m,
        reset_200m => reset_200m,
        sp_fmc_clk => fmc_sp_to_fpga_clk,
        reset_fmc_clk => reset_fmc
    );

    tst : process (clk_125m, reset_125m)
    begin
        if reset_125m then
            counter <= (others => '0');
        elsif rising_edge(clk_125m) then
            counter <= counter + 1;
        end if;
    end process;

    fpga_spare_1v8(1) <= pll_locked_async;
    fpga_spare_1v8(2) <= reset_l;

    stm32h7_fmc_target_inst: entity work.stm32h7_fmc_target
     port map(
        chip_reset => reset_fmc,
        fmc_clk => fmc_sp_to_fpga_clk,
        a(24 downto 20) => "00000",
        a(19 downto 16) => fmc_sp_to_fpga_a,
        addr_data_in => fmc_sp_to_fpga_da,
        data_out => fmc_internal_data_out,
        data_out_en => fmc_data_out_enable,
        ne(3 downto 1) => "111",
        ne(0) => fmc_sp_to_fpga_cs1_l,
        noe => fmc_sp_to_fpga_oe_l,
        nwe => fmc_sp_to_fpga_we_l,
        nl => fmc_sp_to_fpga_adv_l,
        nwait => fmc_sp_to_fpga_wait_l,
        aclk => clk_125m,
        aresetn => not reset_125m,
        axi_if => fmc_axi_if

    );

    -- Axi interconnect
    axil_interconnect_inst: entity work.axil_interconnect
     generic map(
        config_array => config_array
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        initiator => fmc_axi_if,
        responders => responders
    );

    -- tristate control for the FMC data bus
    fmc_sp_to_fpga_da <= fmc_internal_data_out when fmc_data_out_enable = '1' else (others => 'Z');

    info_regs: entity work.info
     generic map(
        hubris_compat_num_bits => 3
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        hubris_compat_pins => (others => '0'),
        axi_if => responders(0)
    );

    spi_nor_top_inst: entity work.spi_nor_top
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders(1),
        cs_n => spi_fpga_to_flash_cs_l,
        sclk => spi_fpga_to_flash_clk,
        io => spi_fpga_to_flash_dat,
        io_o => spi_nor_block_data_o,
        io_oe => spi_nor_block_data_oe,
        sp5_owns_flash => sp5_owns_flash,
        espi_cmd_fifo_rdata => espi_cmd_fifo_rdata,
        espi_cmd_fifo_rdack => espi_cmd_fifo_rdack,
        espi_cmd_fifo_rempty => espi_cmd_fifo_rempty, 
        espi_data_fifo_wdata => espi_data_fifo_wdata,
        espi_data_fifo_write => espi_data_fifo_write

    );

     -- eSPI block -> SPI NOR  
    espi_spinor_cmd_fifo: entity work.dcfifo_xpm
     generic map(
        fifo_write_depth => 256,
        data_width => 32,
        showahead_mode => true
    )
     port map(
        wclk => clk_125m,  -- eSPI slow clock
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
    -- SPI NOR -> eSPI block
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
        axi_if => responders(2),
        cs_n => espi_hpm_to_scm_cs_l,
        sclk => espi_hpm_to_scm_clk,
        io => espi_hpm_to_scm_dat,
        io_o => espi_io_o,
        io_oe => espi_io_oe,
        response_csn => fpga_spare_1v8(0),
        flash_cfifo_data => flash_cfifo_data,
        flash_cfifo_write => flash_cfifo_write,
        flash_rfifo_data => flash_rfifo_data,
        flash_rfifo_rdack => flash_rfifo_rdack,
        flash_rfifo_rempty => flash_rfifo_rempty,
        to_sp_uart_data => host_espi_to_sp_uart_data,
        to_sp_uart_valid => host_espi_to_sp_uart_valid,
        to_sp_uart_ready => host_espi_to_sp_uart_ready,
        from_sp_uart_data => from_sp_uart_to_host_espi_data,
        from_sp_uart_valid => from_sp_uart_to_host_espi_valid,
        from_sp_uart_ready => from_sp_uart_to_host_espi_ready
    );

    -- UARTs
    -- SP UART #0  -- Expected to be console uart
    sp_uart0: entity work.axi_fifo_st_uart
     generic map(
        CLK_DIV => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => 256,
        full_threshold => 256
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        rx_pin => uart0_sp_to_fpga_dat,
        tx_pin => uart0_fpga_to_sp_dat,
        rts_pin => uart0_fpga_to_sp_rts_l,
        cts_pin => uart0_sp_to_fpga_rts_l,
        axi_clk => clk_125m,
        axi_reset => reset_125m,
        rx_ready => console_from_sp_rx_ready,
        rx_data => console_from_sp_rx_data,
        rx_valid => console_from_sp_rx_valid,
        tx_data => console_to_sp_tx_data,
        tx_valid => console_to_sp_tx_valid,
        tx_ready => console_to_sp_tx_ready
    );

    -- IPCC UART over eSPI
    sp_uart1: entity work.axi_fifo_st_uart
     generic map(
        CLK_DIV => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => 4096,
        full_threshold => 4096
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        rx_pin => ipcc_sp_to_fpga_data,
        tx_pin => ipcc_fpga_to_sp_data,
        rts_pin => ipcc_fpga_to_sp_rts_l,
        cts_pin => ipcc_sp_to_fpga_cts_l,
        axi_clk => clk_125m,  -- from espi slow domain
        axi_reset => reset_125m,
        rx_ready => from_sp_uart_to_host_espi_ready,
        rx_data => from_sp_uart_to_host_espi_data,
        rx_valid => from_sp_uart_to_host_espi_valid,
        tx_data => host_espi_to_sp_uart_data,
        tx_valid => host_espi_to_sp_uart_valid,
        tx_ready => host_espi_to_sp_uart_ready
    );


    -- debug stuff
    -- inputs
    ipcc_sp_to_fpga_data <= uart_local_sp_to_fpga_dat when ipcc_dbg_en else uart1_sp_to_fpga_dat;
    ipcc_sp_to_fpga_cts_l <= uart_local_sp_to_fpga_rts_l when ipcc_dbg_en else uart1_sp_to_fpga_rts_l;
    -- outputs to debug, can leave always enabled for now
    uart_local_fpga_to_sp_dat <= ipcc_fpga_to_sp_data;
    uart1_fpga_to_sp_rts_l <= ipcc_fpga_to_sp_rts_l;
    -- push uart stuff out to debug header
    fpga_spare_1v8(3) <= ipcc_sp_to_fpga_data;
    fpga_spare_1v8(4) <= ipcc_sp_to_fpga_cts_l;
    fpga_spare_1v8(5) <= ipcc_fpga_to_sp_data;
    fpga_spare_1v8(6) <= ipcc_fpga_to_sp_rts_l;
    -- outputs to sp
    uart1_fpga_to_sp_dat <= ipcc_fpga_to_sp_data when not ipcc_dbg_en else '1';
    uart1_fpga_to_sp_rts_l <= ipcc_fpga_to_sp_rts_l when not ipcc_dbg_en else '0';  --default to block or not?
    
    -- 1 Host UART expected to be console uart
    -- wrapped uart-uart no espi interaction
    host_uart0: entity work.axi_fifo_st_uart
     generic map(
        CLK_DIV => BAUD_3M_AT_125M,
        parity => false,
        use_hw_handshake => true,
        fifo_depth => 256,
        full_threshold => 256
    )
     port map(
        clk => clk_125m,
        reset => reset_125m,
        rx_pin => uart0_sp5_to_fpga_data,
        tx_pin => uart0_fpga_to_sp5_data,
        rts_pin => uart0_fpga_to_sp5_rts_l,
        cts_pin => uart0_sp5_to_fpga_rts_l,
        axi_clk => clk_125m,
        axi_reset => reset_125m,
        rx_ready => console_to_sp_tx_ready,
        rx_data => console_to_sp_tx_data,
        rx_valid => console_to_sp_tx_valid,
        tx_data => console_from_sp_rx_data,
        tx_valid => console_from_sp_rx_valid,
        tx_ready => console_from_sp_rx_ready
    );

    -- espi and spiNor tris buffer
    process(all)
    begin
        for i in 0 to 3 loop
            espi_hpm_to_scm_dat(i) <= espi_io_o(i) when espi_io_oe(i) = '1' else 'Z';
        end loop;

        for i in 0 to 3 loop
            spi_fpga_to_flash_dat(i) <= spi_nor_block_data_o(i) when spi_nor_block_data_oe(i) = '1' else 'Z';
        end loop;
    end process;


    -- Debug stuff for i3c
    -- pin the enables low to enable the devices
    i3c_sp5_to_fpga_oe_n_3v3 <= '0';
    i3c_fpga_to_dimm_oe_n_3v3 <= '0';

    scm_to_hpm_virtual_reseat <= '0';
    scm_to_hpm_fw_recovery <= '0';
    scm_to_hpm_dbreq_l <= '1';
    hpm_to_scm_pcie_rst_buf_l <= '1';
    scm_to_hpm_rot_cpu_rst_l <= '1';
    sgpio_scm_to_hpm_reset_l <= '1';
    scm_to_hpm_stby_en <= '1';
    scm_to_hpm_stby_rst_l <= hpm_to_scm_stby_rdy_syncd;
    scm_to_hpm_pwrbtn_l <= '1';
    sgpio_hpm_to_scm_intr_l <= '1';


    meta_sync_inst: entity work.meta_sync
     port map(
        async_input => hpm_to_scm_stby_rdy,
        clk => clk,
        sycnd_output => hpm_to_scm_stby_rdy_syncd
    );

    gfruit_sgpio_inst: entity work.gfruit_sgpio
     port map(
        clk => clk_125m,
        reset => reset_125m,
        axi_if => responders(3),
        sclk => sgpio_scm_to_hpm_clk,
        sgpio0_do => sgpio_scm_to_hpm_dat(0),
        sgpio0_di => sgpio_hpm_to_scm_dat(0),
        sgpio0_ld => sgpio_scm_to_hpm_ld(0),
        sgpio1_do => sgpio_scm_to_hpm_dat(1),
        sgpio1_di => sgpio_hpm_to_scm_dat(1),
        sgpio1_ld => sgpio_scm_to_hpm_ld(1)
    );

    -- Disable in gfruit since we never got this fully working on a ruby
    i3c_hpm_to_scm_dimm0_ghijkl_scl <= 'Z';
    ruby_scl_if.i   <= i3c_hpm_to_scm_dimm0_ghijkl_scl;
    i3c_hpm_to_scm_dimm0_ghijkl_sda <= 'Z';
    ruby_sda_if.i   <= i3c_hpm_to_scm_dimm0_ghijkl_sda;
    i3c_scm_to_dimm0_ghijkl_scl <= 'Z';
    dimm_scl_if.i   <= i3c_scm_to_dimm0_ghijkl_scl;
    i3c_scm_to_dimm0_ghijkl_sda <= 'Z';
    dimm_sda_if.i   <= i3c_scm_to_dimm0_ghijkl_sda;

end rtl;
