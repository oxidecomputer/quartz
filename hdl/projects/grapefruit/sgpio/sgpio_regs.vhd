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
use work.axil8x32_pkg.all;

use work.gfruit_sgpio_regs_pkg.all;

entity sgpio_regs is 
    port (
        clk: in std_logic;
        reset: in std_logic;

        out0 : out out0_type;
        out1 : out out1_type;
        in0  : in in0_type;
        in1 : in in1_type;

        axi_if : view axil_target

    );
end entity;

architecture rtl of sgpio_regs is
    signal rdata : std_logic_vector(31 downto 0);
    signal active_read : std_logic;
    signal active_write : std_logic;

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

    write_logic: process(clk, reset)
    begin
        if reset then
            out0 <= rec_reset;
            out1 <= rec_reset;
        elsif rising_edge(clk) then
            if active_write then
                case to_integer(axi_if.write_address.addr) is
                    when OUT0_OFFSET => out0 <= unpack(axi_if.write_data.data);
                    when OUT1_OFFSET => out1 <= unpack(axi_if.write_data.data);
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
                    when OUT0_OFFSET => rdata <= pack(out0);
                    when OUT1_OFFSET => rdata <= pack(out1);
                    when IN0_OFFSET => rdata <= pack(in0);
                    when IN1_OFFSET => rdata <= pack(in1);
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;


end architecture;