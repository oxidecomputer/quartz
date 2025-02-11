-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Acting as a SPI peripheral, turn specially formed transactions into
-- AXI-lite memory read/write transactions
-- See docs for details on the SPI protocol

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.spi_axi_pkg.all;

entity spi_axi_sms is
    port (
        clk : in std_logic;
        reset : in std_logic;
        -- spi pins
        -- We're running these through meta sync so there's a rate limit
        -- here, related to your clock frequency
        am_selected : in std_logic;

        -- data to/from the spi phy block
        from_spi_data : in std_logic_vector(7 downto 0);
        from_spi_valid : in std_logic;
        from_spi_ready : out std_logic;

        to_spi_data : out std_logic_vector(7 downto 0);
        to_spi_valid : out std_logic;
        to_spi_ready : in std_logic;

        -- Would love to use 2019 record views here, but we're stuck with
        -- 2008 compat for the ice40 and open toolchain flows
        -- write address channel
        awvalid : out std_logic;
        awready : in std_logic;
        awaddr : out std_logic_vector(15 downto 0) ;
        -- write data channel
        wvalid : out std_logic;
        wready : in std_logic;
        wdata : out std_logic_vector(31 downto 0);
        wstrb : out std_logic_vector(3 downto 0);
        -- write response channel
        bvalid : in std_logic;
        bready : out std_logic;
        bresp : in std_logic_vector(1 downto 0);
        -- read address channel
        arvalid : out std_logic;
        arready : in std_logic;
        araddr : out std_logic_vector(15 downto 0);
        -- read data channel
        rvalid : in std_logic;
        rready : out std_logic;
        rdata : in std_logic_vector(31 downto 0);
        rresp : in std_logic_vector(1 downto 0)

    );
end entity;

architecture rtl of spi_axi_sms is

    type spi_sm_t is (
        OPCODE,
        ADDR1,
        ADDR2,
        GET_WRITE_DATA_BYTE,
        ISSUE_READ,
        ISSUE_WRITE,
        WAIT_READ_RESP,
        WAIT_SPI_READ_DATA_BYTE,
        ERR_WAIT_FOR_DESELECT
    );

    type axi_sm is (
        IDLE,
        WRITE_BYTE,
        WRITE_RESP,
        READ_BYTE,
        READ_RESP
    );

    type spi_reg_t is record
        opcode : std_logic_vector(3 downto 0);
        req_addr : std_logic_vector(15 downto 0);
        data : std_logic_vector(7 downto 0);
        state : spi_sm_t;
        from_spi_ready : std_logic;
        to_spi_valid : std_logic;
    end record;

    signal spi_r, spi_rin : spi_reg_t;
    constant spi_reg_reset : spi_reg_t := (
        opcode => (others => '0'),
        req_addr => (others => '0'),
        data => (others => '0'),
        state => OPCODE,
        from_spi_ready => '0',
        to_spi_valid => '0'
    );

    type axi_reg_t is record
        state : axi_sm;
        opcode : std_logic_vector(3 downto 0);
        req_addr : std_logic_vector(15 downto 0);
        bready : std_logic;
        arvalid : std_logic;
        rready : std_logic;
        awvalid : std_logic;
        wvalid : std_logic;
        rdata : std_logic_vector(7 downto 0);
        wdata : std_logic_vector(7 downto 0);
    end record;

    signal axi_r, axi_rin : axi_reg_t;
    constant axi_reg_reset : axi_reg_t := (
        state => IDLE,
        opcode => (others => '0'),
        req_addr => (others => '0'),
        bready => '0',
        arvalid => '0',
        rready => '0',
        awvalid => '0',
        wvalid => '0',
        rdata => (others => '0'),
        wdata => (others => '0')
    );

begin

    -- consume bytes from the spi phy as they're available
    spi_sm: process(all)
        variable v : spi_reg_t;
    begin
        v := spi_r;

        case spi_r.state is
            when OPCODE =>
                v.from_spi_ready := '1';
                if from_spi_valid and from_spi_ready then
                    v.opcode := from_spi_data(3 downto 0);
                    v.state := ADDR1;
                    -- only move forward if we have a valid opcode
                    -- otherwise we'll ignore the remainder of this
                    -- transaction and pick up the next cs
                    if not is_known_opcode(v.opcode) then
                        v.state := ERR_WAIT_FOR_DESELECT;
                    end if;
                end if;

            when ADDR1 =>
                if from_spi_valid and from_spi_ready then
                    v.req_addr(15 downto 8) := from_spi_data;
                    v.state := ADDR2;
                end if;
            when ADDR2 =>
                if from_spi_valid and from_spi_ready then
                    v.req_addr(15 downto 8) := from_spi_data;
                    if is_read_kind_opcode(spi_r.opcode) then
                        v.state := ISSUE_READ;
                    else
                        v.state := GET_WRITE_DATA_BYTE;
                    end if;
                end if;
                
            when ISSUE_READ =>
                -- wait for axi sm to pick this request up then wait for response
                -- we want this to happen immediately
                if axi_r.state = IDLE then
                    v.state := WAIT_READ_RESP;
                end if;
            when WAIT_READ_RESP =>
                -- wait for axi response
                if axi_r.state = IDLE then
                    v.data := axi_r.rdata;
                    v.to_spi_valid := '1';
                end if;
                if to_spi_valid = '1' and to_spi_ready = '1' then
                    v.to_spi_valid := '0';
                    v.req_addr := v.req_addr + 1;  -- increment and go again
                    v.state := WAIT_SPI_READ_DATA_BYTE;
                end if;
            when WAIT_SPI_READ_DATA_BYTE =>
                -- wait as we send data back out spi
                if from_spi_valid and from_spi_ready then
                    v.state := ISSUE_READ;
                end if;
                -- wait for response back from axi
                -- store data, increment addr and wait for next spi transfer, then go back to ISSUE READ
                -- keep going until cs goes away
            when GET_WRITE_DATA_BYTE =>
                -- get data from spi, move to wait write response
                if from_spi_valid and from_spi_ready then
                    v.data := from_spi_data;
                    v.from_spi_ready := '0';
                    v.state := ISSUE_WRITE;
                end if;
            when ISSUE_WRITE =>
                if axi_r.state = IDLE then
                    v.from_spi_ready := '1';
                    v.req_addr := v.req_addr + 1;  -- increment and go again
                    v.state := GET_WRITE_DATA_BYTE;
                end if;
                -- wait for axi handshake, incr addr wait for next spi transfer, then go back to GET_WRITE_DATA
                -- keep going until cs goes away

            when ERR_WAIT_FOR_DESELECT =>
                null;  -- wait for cs de-select to clear us (outside case)
        end case;

        if not am_selected then
            v.state := OPCODE;
            v.opcode := (others => '0');
            v.req_addr := (others => '0');
        end if;

        spi_rin <= v;
    end process;

    from_spi_ready <= spi_r.from_spi_ready;
    to_spi_data <= spi_r.data;
    to_spi_valid <= spi_r.to_spi_valid;


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
    -- read address channel
    arvalid <= axi_r.arvalid;
    araddr <= axi_r.req_addr(15 downto 2) & "00";
    -- read response channel
    rready <= axi_r.rready;
    -- write address channel
    awvalid <= axi_r.awvalid;
    awaddr <= axi_r.req_addr(15 downto 2) & "00";
    -- write data channel
    wvalid <= axi_r.wvalid;

    wdata_and_strobe:process(all)
        variable dat_shift: std_logic_vector(31 downto 0) := (others => '0');
    begin
        dat_shift(7 downto 0) := axi_r.wdata;
        dat_shift := shift_left(dat_shift, to_integer(unsigned(axi_r.req_addr(1 downto 0))) * 8);
    
        wdata <= dat_shift;
        wstrb <= shift_left("0001", to_integer(unsigned(axi_r.req_addr(1 downto 0))));

    end process;
    -- write response channel
    bready <= axi_r.bready;


    -- register process for both of the above state machines
    reg: process(clk, reset)
    begin

        if reset then
            spi_r <= spi_reg_reset;
            axi_r <= axi_reg_reset;
        elsif rising_edge(clk) then
            spi_r <= spi_rin;
            axi_r <= axi_rin;
        end if;

    end process;

end architecture;