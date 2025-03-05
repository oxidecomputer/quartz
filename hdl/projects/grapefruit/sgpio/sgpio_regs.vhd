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

    signal axi_int_read_ready : std_logic;
    signal awready : std_logic;
    signal wready : std_logic;
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
            out0 <= rec_reset;
            out1 <= rec_reset;
        elsif rising_edge(clk) then
            if axi_if.write_data.ready then
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
            if axi_int_read_ready then
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