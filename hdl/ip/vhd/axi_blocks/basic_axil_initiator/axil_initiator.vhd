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

use work.spi_axi_pkg.all;

entity basic_axil_initiator is
    generic(
        AXI_ADDR_WIDTH : integer ;
        TXN_DATA_WIDTH : integer range 8 to 32;
        BUFFER_TO_32 : boolean
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        do_read : in std_logic;
        do_write : in std_logic;
        inc_addr : in boolean;
        txn_start_addr : in std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
        tdata : in std_logic_vector(TXN_DATA_WIDTH downto 0);
        tdata_valid : in std_logic;
        tdata_ready : out std_logic;
        tdata_last : in std_logic;

        -- Would love to use 2019 record views here, but we're stuck with
        -- 2008 compat for the ice40 and open toolchain flows
        -- write address channel
        awvalid : out std_logic;
        awready : in std_logic;
        awaddr : out std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0) ;
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
        araddr : out std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
        -- read data channel
        rvalid : in std_logic;
        rready : out std_logic;
        rdata : in std_logic_vector(31 downto 0);
        rresp : in std_logic_vector(1 downto 0);
    );
end entity;

architecture rtl of basic_axil_initiator is

    

begin

end rtl;