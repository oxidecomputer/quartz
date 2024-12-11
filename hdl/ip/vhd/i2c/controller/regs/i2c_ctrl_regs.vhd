-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- AXI-accessible registers for the I2C block

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil8x32_pkg.all;

use work.i2c_ctrl_regs_pkg.all;

entity i2c_ctrl_regs is
    port (
        clk     : in    std_logic;
        reset   : in    std_logic;
        axi_if  : view  axil_target;
    );
end entity;

architecture rtl of i2c_ctrl_regs is
    constant AXI_OKAY           : std_logic_vector(1 downto 0) := "00";
    signal   axi_read_ready_int : std_logic;
    signal   axi_awready        : std_logic;
    signal   axi_wready         : std_logic;
    signal   axi_bvalid         : std_logic;
    signal   axi_bready         : std_logic;
    signal   axi_arready        : std_logic;
    signal   axi_rvalid         : std_logic;
    signal   axi_rdata          : std_logic_vector(31 downto 0);
begin

    -- AXI wiring
    axi_if.write_response.resp  <= AXI_OKAY;
    axi_if.write_response.valid <= axi_bvalid;
    axi_if.read_data.resp       <= AXI_OKAY;
    axi_if.write_data.ready     <= axi_wready;
    axi_if.write_address.ready  <= axi_awready;
    axi_if.read_address.ready   <= axi_arready;
    axi_if.read_data.data       <= axi_rdata;
    axi_if.read_data.valid      <= axi_rvalid;

    axi_bready          <= axi_if.write_response.ready;
    axi_wready          <= awready;
    axi_arready         <= not rvalid;
    axi_read_ready_int  <= axi_if.read_address.valid and axi_arready;

    axi: process(clk, reset)
    begin
        if reset then
            axi_awready <= '0';
            axi_bvalid  <= '0';
            axi_rvalid  <= '0';
        elsif rising_edge(clk) then

            -- bvalid is set on every write and then cleared after bv
            if axi_awready then
                axi_bvalid  <= '1';
            elsif axi_bready then
                axi_bvalid  <= '0';
            end if;

        end if;
    end process;

end architecture;