-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uart_prot_pkg.all;

entity packets_to_axi_mm is
    generic (
        -- AXI address width
        ADDR_WIDTH : integer := 26;
        -- expected

    )
    port (
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        -- cmd packet interface:
        cmd_tdata : in std_logic_vector(7 downto 0);
        cmd_tvalid : in std_logic;
        cmd_tready : out std_logic;
        cmd_tlast : in std_logic;
        -- response packet interface
        resp_tdata : out std_logic_vector(7 downto 0);
        resp_tvalid : out std_logic;
        resp_tready : in std_logic;
        resp_tlast : out std_logic;

        -- MM interface:
        -- Write addr channel
        awvalid : out   std_logic;
        awready : in    std_logic;
        awaddr  : out   std_logic_vector(25 downto 0);
        awprot  : out   std_logic_vector(2 downto 0);
        -- Write data channel
        wvalid : out   std_logic;
        wready : in    std_logic;
        wstrb  : out   std_logic_vector(3 downto 0);
        wdata  : out   std_logic_vector(31 downto 0);
        -- Write response channel
        bvalid : in    std_logic;
        bready : out   std_logic;
        -- Read address channel
        arvalid : out   std_logic;
        araddr  : out   std_logic_vector(25 downto 0);
        arready : in    std_logic;
        -- Read data channel
        rvalid : in    std_logic;
        rready : out   std_logic;
        rdata  : in    std_logic_vector(31 downto 0);
    );
end entity;

architecture rtl of packets_to_axi_mm is
   -- accept transactions as follows from the packet streamer
   -- 3 byte header, 0-255 byte payload, 1 byte CRC?
   type state_t is (IDLE, HDR_CLASS, HDR_TID, HDR_SIZE, ISSUE_WRITE, ISSUE_READ);


begin



        -- AXI transactions don't really have a way to abort, so we can't issue them until we have the
    -- information we need to finish. The SPI block could stop sending things or abort the SPI transaction
    -- given it's a processor. The task could die etc.  This also means that we don't interlock with the spi
    -- state machine, we just complete the transactions requested and supply any necessary data. If the SPI
    -- sm is in the wrong state, we'll drop any response data on the floor but not block anything here.
        axi_sm_logic: process(all)
        variable v : axi_reg_t;

    begin
        v := axi_r;

        case axi_r.state is
            when IDLE =>
                if spi_r.state = ISSUE_READ then
                    v.state := READ_BYTE;
                    v.arvalid := '1';
                    v.req_addr := spi_r.req_addr;
                    v.opcode := spi_r.opcode;
                    v.rdata := (others => '0');
                elsif spi_r.state = ISSUE_WRITE then
                    v.req_addr := spi_r.req_addr;
                    v.opcode := spi_r.opcode;
                    v.wdata := spi_r.data;

                    if is_rmw_kind_opcode(spi_r.opcode) then
                        v.state := READ_BYTE;
                        v.arvalid := '1';
                        v.rdata := (others => '0');
                    else
                        v.state := WRITE_BYTE;
                        v.awvalid := '1';
                        v.wvalid := '1';
                    end if;
                    
                end if;

            when WRITE_BYTE =>
                v.bready := '1';
                -- we have 2 independent channels that could ack, and could ack at different times
                if awvalid and awready then
                    v.awvalid := '0';
                end if;

                if wvalid and wready then
                    v.wvalid := '0';
                end if;

                if v.awvalid = '0' and v.wvalid = '0' then
                    -- both done, response acknowledge
                    v.state := WRITE_RESP;
                end if;

                -- write the byte, go to write response
            when WRITE_RESP =>
                if bvalid = '1' then
                    v.bready := '0';
                    v.state := IDLE;
                end if;
                -- go back to idle
            when READ_BYTE =>
                if arvalid and arready then
                    v.arvalid := '0';
                    v.rready := '1';
                    v.state := READ_RESP;
                end if;
                -- read the byte, go to read response
            when READ_RESP =>
                if rvalid = '1' then
                    v.rdata := rdata(to_integer(unsigned(axi_r.req_addr(1 downto 0))) * 8 + 7 downto to_integer(unsigned(axi_r.req_addr(1 downto 0))) * 8);
                    v.rready := '0';
                    -- we could be done here, but if we're doing read-modify-write
                    -- we need to write the byte back out
                    if is_rmw_kind_opcode(axi_r.opcode) then
                        v.state := WRITE_BYTE;
                        v.awvalid := '1';
                        v.wvalid := '1';
                        -- take the data we read, OR it with the data we were given
                        v.wdata := bit_operation_by_opcode(axi_r.opcode, v.rdata, axi_r.wdata);
                    else
                        -- we have data, put it in the fifo and go back to idle
                        v.state := IDLE;
                    end if;
                end if;
                -- go back to idle 

        end case;

        axi_rin <= v;
    end process;
   

end architecture;