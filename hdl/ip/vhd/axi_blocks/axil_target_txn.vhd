-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company 
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil_common_pkg.all;

entity axil_target_txn is
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- axi transaction signals
        arvalid : in std_logic;
        arready : out std_logic;
        awvalid : in std_logic;
        awready : out std_logic;
        wready : out std_logic;
        wvalid : in std_logic;
        bvalid : out std_logic;
        bready : in std_logic;
        bresp : out std_logic_vector(1 downto 0);
        rvalid : out std_logic;
        rready : in std_logic;
        rresp : out std_logic_vector(1 downto 0);
        -- Helper signals
        active_read : out std_logic;
        active_write : out std_logic
    );
end entity;
architecture rtl of axil_target_txn is

begin

    bresp  <= OKAY;
    rresp  <= OKAY;

    wready  <= awready;
    arready <= not rvalid;

    active_read <=  arvalid and arready;
    active_write <= awready;


    -- axi transaction mgmt
    -- Common block for axi transaction management
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
    
            if active_read then
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

end rtl;