-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.grapefruit_regs_pkg.all;

entity registers is 
    port (
        clk: in std_logic;
        reset: in std_logic;

        -- AXI write address
        awvalid : in std_logic;
        awready : out std_logic;
        awaddr : in std_logic_vector(7 downto 0);

        -- AXI write data
        wvalid : in std_logic;
        wready : out std_logic;
        wdata : in std_logic_vector(31 downto 0);
        wstrb : in std_logic_vector(3 downto 0) := "1111";  -- not implemented

        -- AXI write return
        bvalid : out std_logic;
        bready : in std_logic;
        bresp : out std_logic_vector(1 downto 0);

        -- AXI read address
        arvalid : in std_logic;
        arready : out std_logic;
        araddr : in std_logic_vector(7 downto 0);

        -- AXI read return
        rvalid : out std_logic;
        rready : in std_logic;
        rresp : out std_logic_vector(1 downto 0);
        rdata: out std_logic_vector(31 downto 0)

    );
end entity;

architecture rtl of registers is
    signal id : id_type;
    signal sha : sha_type;
    signal checksum : cs_type;
    signal scratchpad : scratchpad_type;
    signal axi_int_write_ready : std_logic;
    signal axi_int_read_ready : std_logic;
begin

    bresp <= OKAY;
    rresp <= OKAY;

    wready <= awready;
    arready <= not rvalid;
    axi_int_read_ready <= arvalid and arready;

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
            elsif rready then
                rvalid <= '0';
            end if;

            -- can accept a new write if we're not
            -- responding to write already or
            -- the write is not in progress
            awready <= not awready and
                       (awvalid and wvalid) and
                       (not bvalid or bready);
        end if;
    end process;

    write_logic: process(clk, reset)
    begin
        if reset then
            id <= rec_reset;
            sha <= rec_reset;
            checksum <= rec_reset;
            scratchpad <= rec_reset;
        elsif rising_edge(clk) then
            if wready then
                case to_integer(awaddr) is
                    when ID_OFFSET => null;  -- ID is read-only
                    when SHA_OFFSET => null;  -- SHA is read-only
                    when CS_OFFSET => checksum <= unpack(wdata);
                    when SCRATCHPAD_OFFSET => scratchpad <= unpack(wdata);
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
            if (not arvalid) or arready then
                case to_integer(araddr) is
                    when ID_OFFSET => rdata <= pack(id);
                    when SHA_OFFSET => rdata <= pack(sha);
                    when CS_OFFSET => rdata <= pack(checksum);
                    when SCRATCHPAD_OFFSET => rdata <= pack(scratchpad);
                    when others => rdata <= (others => '0');
                end case;
            end if;

        end if;
    end process;


end architecture;