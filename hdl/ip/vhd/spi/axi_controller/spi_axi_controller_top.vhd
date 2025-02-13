-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Acting as a SPI peripheral, turn specially formed transactions into
-- AXI-lite memory read/write transactions
-- See docs for details on the SPI protocol

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

entity spi_axi_controller is
    port (
        clk : in std_logic;
        reset : in std_logic;
        -- spi pins
        -- We're running these through meta sync so there's a rate limit
        -- here, related to your clock frequency
        csn  : in std_logic;
        sclk : in std_logic;
        copi : in std_logic;
        cipo : out std_logic;

        -- Would love to use 2019 record views here, but we're stuck with
        -- 2008 compat for the ice40 and open toolchain flows
        -- write address channel
        awvalid : out std_logic;
        awready : in std_logic;
        awaddr : out std_logic_vector(15 downto 0) ;
        -- write data channel
        wvalid : out std_logic;
        wready : in std_logic;
        wdata : out std_logic_vector(31 downto 0);
        wstrb : out std_logic_vector(3 downto 0);
        -- write response channel
        bvalid : in std_logic;
        bready : out std_logic;
        bresp : in std_logic_vector(1 downto 0);
        -- read address channel
        arvalid : out std_logic;
        arready : in std_logic;
        araddr : out std_logic_vector(15 downto 0);
        -- read data channel
        rvalid : in std_logic;
        rready : out std_logic;
        rdata : in std_logic_vector(31 downto 0);
        rresp : in std_logic_vector(1 downto 0)

    );
end entity;

architecture rtl of spi_axi_controller is
    signal from_spi_data : std_logic_vector(7 downto 0);
    signal from_spi_valid : std_logic;
    signal from_spi_ready : std_logic;

    signal to_spi_data : std_logic_vector(7 downto 0);
    signal to_spi_valid : std_logic;
    signal to_spi_ready : std_logic;

    signal csn_syncd : std_logic;

begin

    spi_phy: entity work.spi_target_phy
    port map (
        clk => clk,
        reset => reset,
        csn => csn,
        sclk => sclk,
        copi => copi,
        cipo => cipo,

        csn_syncd => csn_syncd,

        rx_data => from_spi_data,
        rx_valid => from_spi_valid,
        rx_ready => from_spi_ready,

        tx_data => to_spi_data,
        tx_valid => to_spi_valid,
        tx_ready => to_spi_ready
    );

    spi_axi_sms_inst: entity work.spi_to_axi
     port map(
        clk => clk,
        reset => reset,
        am_selected => not csn_syncd,
        from_spi_data => from_spi_data,
        from_spi_valid => from_spi_valid,
        from_spi_ready => from_spi_ready,
        to_spi_data => to_spi_data,
        to_spi_valid => to_spi_valid,
        to_spi_ready => to_spi_ready,
        awvalid => awvalid,
        awready => awready,
        awaddr => awaddr,
        wvalid => wvalid,
        wready => wready,
        wdata => wdata,
        wstrb => wstrb,
        bvalid => bvalid,
        bready => bready,
        bresp => bresp,
        arvalid => arvalid,
        arready => arready,
        araddr => araddr,
        rvalid => rvalid,
        rready => rready,
        rdata => rdata,
        rresp => rresp
    );
    



end architecture;

