-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Common register block for basic board information

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.info_regs_pkg.all;
use work.git_sha_pkg.all;

entity info_2k8 is
    generic(
        hubris_compat_num_bits: positive range 1 to 31
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- System Interface
        hubris_compat_pins: in std_logic_vector(hubris_compat_num_bits-1 downto 0);
        -- axi interface. This is not using VHDL2019 views so that it's compatible with
        -- GHDL/yosys based toolchains
        -- write address channel
        awvalid : in std_logic;
        awready : out std_logic;
        awaddr : in std_logic_vector(7 downto 0) ;
        -- write data channel
        wvalid : in std_logic;
        wready : out std_logic;
        wdata : in std_logic_vector(31 downto 0);
        wstrb : in std_logic_vector(3 downto 0); -- un-used
        -- write response channel
        bvalid : out std_logic;
        bready : in std_logic;
        bresp : out std_logic_vector(1 downto 0);
        -- read address channel
        arvalid : in std_logic;
        arready : out std_logic;
        araddr : in std_logic_vector(7 downto 0);
        -- read data channel
        rvalid : out std_logic;
        rready : in std_logic;
        rdata : out std_logic_vector(31 downto 0);
        rresp : out std_logic_vector(1 downto 0)


    );
end entity;

architecture rtl of info_2k8 is
    constant OKAY               : std_logic_vector(1 downto 0) := "00";
    signal   axi_int_read_ready : std_logic;

    constant identity : identity_type := rec_reset;
    constant version : version_type := rec_reset;
    constant git_info : git_info_type := (sha => short_sha);
    signal checksum : fpga_checksum_type := rec_reset;
    signal scratchpad : scratchpad_type := rec_reset;
    signal hubris_compat: hubris_compat_type := rec_reset;

begin
    bresp  <= OKAY;
    rresp      <= OKAY;

    wready  <= awready;
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
            hubris_compat <= rec_reset;
            scratchpad <= rec_reset;
        elsif rising_edge(clk) then
            -- go ahead and flo this every cycle, it's external but not
            -- changing
            hubris_compat <= unpack(resize(hubris_compat_pins, 32));
            if wready then
                case to_integer(awaddr) is
                    when FPGA_CHECKSUM_OFFSET => checksum <= unpack(wdata);
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
                    when IDENTITY_OFFSET => rdata <= pack(identity);
                    when HUBRIS_COMPAT_OFFSET => rdata <= pack(hubris_compat);
                    when VERSION_OFFSET => rdata <= pack(version);
                    when GIT_INFO_OFFSET => rdata <= pack(git_info);
                    when FPGA_CHECKSUM_OFFSET => rdata <= pack(checksum);
                    when SCRATCHPAD_OFFSET => rdata <= pack(scratchpad);
                    when others =>
                        rdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

end rtl;