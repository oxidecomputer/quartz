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
    signal axi_int_read_ready : std_logic;
    signal awready : std_logic;
    signal bvalid : std_logic;
    alias bready is axi_if.write_response.ready;
    signal arready : std_logic;
    signal rvalid : std_logic;
    signal rdata : std_logic_vector(31 downto 0);

begin

    -- Assign outputs to the record here
    -- write_address channel
    axi_if.write_address.ready <= awready;
    -- write_data channel
    axi_if.write_data.ready <= awready;

    -- write_response channel
    axi_if.write_response.resp <= OKAY;
    axi_if.write_response.valid <= bvalid;

    -- read_address channel
    axi_if.read_address.ready <= arready;
    -- read_data channel
    axi_if.read_data.resp <= OKAY;
    axi_if.read_data.data <= rdata;
    axi_if.read_data.valid <= rvalid;

    arready <= not rvalid;


    axi_int_read_ready <=  axi_if.read_address.valid and arready;

    -- axi transaction mgmt
    axi_txn: process(clk, reset)
    begin
        if reset then
            awready <= '0';
            bvalid <= '0';
            rvalid <= '0';
        elsif rising_edge(clk) then
            -- bvalid set on every write,
            -- cleared after bvalid && bready
            if awready then
                bvalid <= '1';
            elsif bready then
                bvalid <= '0';
            end if;

            if axi_int_read_ready then
                rvalid <= '1';
            elsif axi_if.read_data.ready then
                rvalid <= '0';
            end if;

            -- can accept a new write if we're not
            -- responding to write already or
            -- the write is not in progress
            awready <= not awready and
                       (axi_if.write_address.valid and axi_if.write_data.valid) and
                       (not bvalid or bready);
        end if;
    end process;

    write_logic: process(clk, reset)
    begin
        if reset then
            checksum <= rec_reset;
            scratchpad <= rec_reset;
        elsif rising_edge(clk) then
            if axi_if.write_data.ready then
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
            if axi_int_read_ready then
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