-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- 2019-compatible wrapper for basic board information registers

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.axil8x32_pkg.all;

entity info is
    generic(
        hubris_compat_num_bits: positive range 1 to 31;
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- System Interface
        hubris_compat_pins: in std_logic_vector(hubris_compat_num_bits-1 downto 0);
        -- axi interface. This is not using VHDL2019 views so that it's compatible with
        -- GHDL/yosys based toolchains
        axi_if : view axil_target;


    );
end entity;

architecture rtl of info is

begin
    info_inst: entity work.info_2k8
     generic map(
        hubris_compat_num_bits => hubris_compat_num_bits
    )
     port map(
        clk => clk,
        reset => reset,
        hubris_compat_pins => hubris_compat_pins,
        awvalid => axi_if.write_address.valid,
        awready => axi_if.write_address.ready,
        awaddr => axi_if.write_address.addr,
        wvalid => axi_if.write_data.valid,
        wready => axi_if.write_data.ready,
        wdata => axi_if.write_data.data,
        wstrb => axi_if.write_data.strb,
        bvalid => axi_if.write_response.valid,
        bready => axi_if.write_response.ready,
        bresp => axi_if.write_response.resp,
        arvalid => axi_if.read_address.valid,
        arready => axi_if.read_address.ready,
        araddr => axi_if.read_address.addr,
        rvalid => axi_if.read_data.valid,
        rready => axi_if.read_data.ready,
        rdata => axi_if.read_data.data,
        rresp => axi_if.read_data.resp
    );
end rtl;
