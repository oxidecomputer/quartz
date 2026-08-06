-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.hash_engine_sim_pkg.all;

-- Stands in for spi_nor_top's flash read client: pops the two command words then
-- streams back that many bytes of flash_byte() content.
--
-- This deliberately does not model the QSPI wire protocol. What matters for the
-- hash engine is the command/response FIFO contract and the fact that bytes
-- arrive slowly and in gaps, which CYCLES_PER_BYTE reproduces. The real backend's
-- chunking into 256 byte reads is invisible on this interface.
entity fake_flash_responder is
    generic (
        -- Roughly what quad rate flash costs per byte, so the hasher spends most
        -- of its time waiting, as it will in hardware.
        CYCLES_PER_BYTE : positive := 8
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- Command FIFO read side
        cmd_rdata  : in    std_logic_vector(31 downto 0);
        cmd_rdack  : out   std_logic;
        cmd_rempty : in    std_logic;

        -- Response FIFO write side
        rsp_wdata : out   std_logic_vector(7 downto 0);
        rsp_write : out   std_logic;
        rsp_wfull : in    std_logic
    );
end entity;

architecture model of fake_flash_responder is

    type state_t is (GET_ADDR, GET_LEN, STREAM);

    signal state     : state_t := GET_ADDR;
    signal addr      : natural := 0;
    signal remaining : natural := 0;
    signal delay     : natural := 0;

begin

    main: process(clk, reset)
    begin
        if reset then
            state     <= GET_ADDR;
            addr      <= 0;
            remaining <= 0;
            delay     <= 0;
            cmd_rdack <= '0';
            rsp_write <= '0';
            rsp_wdata <= (others => '0');
        elsif rising_edge(clk) then
            cmd_rdack <= '0';
            rsp_write <= '0';

            case state is

                when GET_ADDR =>
                    if cmd_rempty = '0' and cmd_rdack = '0' then
                        addr      <= to_integer(unsigned(cmd_rdata));
                        cmd_rdack <= '1';
                        state     <= GET_LEN;
                    end if;

                when GET_LEN =>
                    if cmd_rempty = '0' and cmd_rdack = '0' then
                        remaining <= to_integer(unsigned(cmd_rdata));
                        cmd_rdack <= '1';
                        delay     <= CYCLES_PER_BYTE;
                        state     <= STREAM;
                    end if;

                when STREAM =>
                    if remaining = 0 then
                        state <= GET_ADDR;
                    elsif delay > 0 then
                        delay <= delay - 1;
                    elsif rsp_wfull = '0' then
                        rsp_wdata <= flash_byte(addr);
                        rsp_write <= '1';
                        addr      <= addr + 1;
                        remaining <= remaining - 1;
                        delay     <= CYCLES_PER_BYTE;
                    end if;

            end case;
        end if;
    end process;

end model;
