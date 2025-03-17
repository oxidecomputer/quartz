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
use work.axil8x32_pkg;

use work.gfruit_regs_pkg.all;

entity registers is 
    port (
        clk: in std_logic;
        reset: in std_logic;

        axi_if : view axil8x32_pkg.axil_target;

        spi_nor_passthru: out std_logic

    );
end entity;

architecture rtl of registers is
    signal id : id_type := rec_reset;
    signal sha : sha_type := unpack(std_logic_vector'(X"00000002"));
    signal checksum : cs_type;
    signal scratchpad : scratchpad_type;
    signal passthu : passthru_type;
    signal active_read : std_logic;
    signal active_write : std_logic;
    signal rdata : std_logic_vector(31 downto 0);

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
            checksum <= rec_reset;
            scratchpad <= rec_reset;
        elsif rising_edge(clk) then
            if active_write then
                case to_integer(axi_if.write_address.addr) is
                    when ID_OFFSET => null;  -- ID is read-only
                    when SHA_OFFSET => null;  -- SHA is read-only
                    when CS_OFFSET => checksum <= unpack(axi_if.write_data.data);
                    when SCRATCHPAD_OFFSET => scratchpad <= unpack(axi_if.write_data.data);
                    when PASSTHRU_OFFSET => passthu <= unpack(axi_if.write_data.data);
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
                    when ID_OFFSET => rdata <= pack(id);
                    when SHA_OFFSET => rdata <= pack(sha);
                    when CS_OFFSET => rdata <= pack(checksum);
                    when SCRATCHPAD_OFFSET => rdata <= pack(scratchpad);
                    when PASSTHRU_OFFSET => rdata <= pack(passthu);
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;


    spi_nor_passthru <= passthu.spi_pass;


end architecture;