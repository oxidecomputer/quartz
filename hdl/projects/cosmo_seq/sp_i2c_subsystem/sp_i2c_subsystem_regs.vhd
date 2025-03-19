-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil8x32_pkg;
use work.sp_i2c_regs_pkg.all;

entity sp_i2c_subsystem_regs is
    port(
        clk : in std_logic;
        reset : in std_logic;

        axi_if : view axil8x32_pkg.axil_target;
        main_reset : out std_logic
    );
end entity;
architecture rtl of sp_i2c_subsystem_regs is
    signal active_read : std_logic;
    signal active_write : std_logic;
    signal rdata : std_logic_vector(31 downto 0);
    signal mux_resets : mux_resets_type;
begin

    axil_target_txn_inst: entity work.axil_target_txn
     port map(
        clk => clk,
        reset => reset,
        arvalid => axi_if.read_address.valid,
        arready => axi_if.read_address.ready,
        awvalid => axi_if.write_address.valid,
        awready => axi_if.write_address.ready,
        wvalid => axi_if.write_data.valid,
        wready => axi_if.write_data.ready,
        bvalid => axi_if.write_response.valid,
        bready => axi_if.write_response.ready,
        bresp => axi_if.write_response.resp,
        rvalid => axi_if.read_data.valid,
        rready => axi_if.read_data.ready,
        rresp => axi_if.read_data.resp,
        active_read => active_read,
        active_write => active_write
    );
    axi_if.read_data.data <= rdata;

    main_reset <= mux_resets.main_bus_reset;


    write_logic: process(clk, reset)
    begin
        if reset then
            mux_resets <= reset_0s;
        elsif rising_edge(clk) then
            mux_resets <= reset_0s; -- always clear
            if active_write then
                case to_integer(axi_if.write_address.addr) is
                    when MUX_RESETS_OFFSET =>
                        mux_resets <= unpack(axi_if.write_data.data);
                    
                    when others => null;
                end case;
            end if;

        end if;
    end process;

    

    read_logic: process(clk, reset)
    begin
        if reset then
            rdata <= (others => '0');
        elsif rising_edge(clk) then
            if active_read then
                case to_integer(axi_if.read_address.addr) is
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;

end rtl;
