-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil_common_pkg.all;

-- Sim-only AXI-Lite responder: a handful of read/write words behind the *real*
-- axil_target_txn block. Using the production transaction block is the whole
-- point of this model -- it reproduces the handshake contract that every
-- register block in the tree presents to the interconnect:
--   * awready is a registered one-cycle pulse gated on awvalid AND wvalid
--   * wready is tied to awready, so AW and W always handshake together
--   * arready is combinational (not rvalid), so AR handshakes immediately
--   * bvalid is a single-cycle pulse when bready is already asserted
-- That last property in particular catches a pipeline stage that goes looking
-- for B a cycle too late.

entity axil_sram_responder is
    generic (
        addr_width : integer := 8
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        awvalid : in    std_logic;
        awready : out   std_logic;
        awaddr  : in    std_logic_vector(addr_width - 1 downto 0);

        wvalid : in    std_logic;
        wready : out   std_logic;
        wdata  : in    std_logic_vector(31 downto 0);
        wstrb  : in    std_logic_vector(3 downto 0);

        bvalid : out   std_logic;
        bready : in    std_logic;
        bresp  : out   std_logic_vector(1 downto 0);

        arvalid : in    std_logic;
        arready : out   std_logic;
        araddr  : in    std_logic_vector(addr_width - 1 downto 0);

        rvalid : out   std_logic;
        rready : in    std_logic;
        rdata  : out   std_logic_vector(31 downto 0);
        rresp  : out   std_logic_vector(1 downto 0)
    );
end entity;

architecture rtl of axil_sram_responder is

    constant NUM_WORDS : integer := 16;

    type storage_t is array (0 to NUM_WORDS - 1) of std_logic_vector(31 downto 0);

    signal storage      : storage_t;
    signal active_read  : std_logic;
    signal active_write : std_logic;
    signal rdata_reg    : std_logic_vector(31 downto 0);

begin

    axil_target_txn_inst: entity work.axil_target_txn
        port map (
            clk          => clk,
            reset        => reset,
            arvalid      => arvalid,
            arready      => arready,
            awvalid      => awvalid,
            awready      => awready,
            wready       => wready,
            wvalid       => wvalid,
            bvalid       => bvalid,
            bready       => bready,
            bresp        => bresp,
            rvalid       => rvalid,
            rready       => rready,
            rresp        => rresp,
            active_read  => active_read,
            active_write => active_write
        );

    rdata <= rdata_reg;

    -- word addressed off bits 5:2, so 16 words repeat through the space
    sram: process(clk, reset)
        variable idx : integer range 0 to NUM_WORDS - 1;
    begin
        if reset = '1' then
            storage   <= (others => (others => '0'));
            rdata_reg <= (others => '0');
        elsif rising_edge(clk) then
            if active_write = '1' then
                idx := to_integer(unsigned(awaddr(5 downto 2)));
                for byte in 0 to 3 loop
                    if wstrb(byte) = '1' then
                        storage(idx)(8 * byte + 7 downto 8 * byte) <= wdata(8 * byte + 7 downto 8 * byte);
                    end if;
                end loop;
            end if;

            if active_read = '1' then
                idx       := to_integer(unsigned(araddr(5 downto 2)));
                rdata_reg <= storage(idx);
            end if;
        end if;
    end process;

end rtl;
