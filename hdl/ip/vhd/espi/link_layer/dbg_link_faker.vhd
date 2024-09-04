-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.qspi_link_layer_pkg.all;
use work.calc_pkg.all;


-- This block has interfaces to the following FIFOs:
-- Debug TX FIFO: a FIFO that holds data as if it was coming from the host. SW can craft arbitrary data to be sent to the eSPI target as if it was the host.
-- Debug RX FIFO: a FIFO that holds the response data, as if it was coming from the eSPI target. SW can read the data from this FIFO as if it was the target.
-- TODO: we'd potentially like to log data sent/rx'd... how do we also do that?

entity dbg_link_faker is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- Asserted by command processor during the
        -- transmission of the last command byte (the CRC)
        response_done : in boolean;
        cs_active : out boolean;
        alert_needed : in boolean;
        -- "Streaming" data recieved after deserialization
        data_to_host       : view st_sink;
        -- "Streaming" data to serialize and transmit
        data_from_host     : view st_source;

        dbg_chan : view dbg_periph_if

        
    );
end entity;

architecture rtl of dbg_link_faker is

    signal cmd_fifo_empty: std_logic;
    signal resp_fifo_write : std_logic;
    signal resp_fifo_read_data : std_logic_vector(31 downto 0);
    signal cmd_fifo_rdata : std_logic_vector(31 downto 0);
    signal resp_fifo_empty : std_logic;

    alias resp_fifo_read_ack is dbg_chan.rd.rdack;
    signal byte_strobe : std_logic;
    signal strobe_cntr: unsigned(7 downto 0) := (others => '0');
    constant strobe_limit: unsigned(7 downto 0) := to_unsigned(6, 8);

    type state_t is (idle, cs_start, cmd, resp, cs_finish);

    type reg_type is record
        state: state_t;
        cs_asserted: boolean;
        cntr : std_logic_vector(7 downto 0);
        idx: std_logic_vector(1 downto 0);
        size_rdack: std_logic;
        cmd_rdack: std_logic;
    end record;

    signal r, rin : reg_type;
    constant reg_reset : reg_type := (idle, false, (others => '0'), (others => '0'), '0', '0');
    constant cs_delay : integer := 6;
    constant idle_delay : integer := 10;
    signal cmd_size_fifo_empty : std_logic;
    signal cmd_size_rdata : std_logic_vector(31 downto 0);
    signal cmd_fifo_wusedwds: std_logic_vector(log2ceil(1024) downto 0);
    signal resp_fifo_wusedwds: std_logic_vector(log2ceil(1024) downto 0);

begin

    dbg_chan.busy <= '1' when r.state /= idle else '0';
    dbg_chan.wstatus.usedwds <= resize(cmd_fifo_wusedwds, dbg_chan.wstatus.usedwds'length);
    dbg_chan.rdstatus.usedwds <= resize(resp_fifo_wusedwds, dbg_chan.wstatus.usedwds'length);
    dbg_chan.rd.data <= resp_fifo_read_data;
    cs_active <= r.cs_asserted;

    -- Timer: the fastest byte transfer that can be done is 2 clocks at 66MHz (in quad mode) so we'll
    -- generate a strobe at that speed when enabled to provide effective rate-limiting to the design.
    -- We can later experiment with whether this is neccessary and speed the debug path up a bit.
    timer: process(clk, reset)
    begin
        if reset = '1' then
            strobe_cntr <= (others => '0');
            byte_strobe <= '0';
        elsif rising_edge(clk) then
            byte_strobe <= '0';
            if strobe_cntr = strobe_limit then
                byte_strobe <= '1';
                strobe_cntr <= (others => '0');
            else
                strobe_cntr <= strobe_cntr + 1;
            end if;
        end if;
    end process;

    -- Command FIFO
    -- WData comes from the register interface. This thing is pretty simple, we grab bytes
    -- and present them out the interface. When we're alerted by the protocol decoder that this is the
    -- crc byte, we stop popping fifo until the transaction is done, and will resume at the next byte if
    -- the command fifo is not empty.
    dbg_cmd_fifo: entity work.dcfifo_xpm
     generic map(
        fifo_write_depth => 1024,
        data_width => 32,
        showahead_mode => true
    )
     port map(
        wclk => clk,
        reset => reset,
        write_en => dbg_chan.wr.write,
        wdata => dbg_chan.wr.data,
        wfull => open,
        wusedwds => cmd_fifo_wusedwds,
        rclk => clk,
        rdata => cmd_fifo_rdata,
        rdreq => r.cmd_rdack,
        rempty => cmd_fifo_empty,
        rusedwds => open
    );

    dbg_cmd_sizefifo: entity work.dcfifo_xpm
     generic map(
        fifo_write_depth => 1024,
        data_width => 32,
        showahead_mode => true
    )
     port map(
        wclk => clk,
        reset => reset,
        write_en => dbg_chan.size.write,
        wdata => dbg_chan.size.data,
        wfull => open,
        wusedwds => open,
        rclk => clk,
        rdata => cmd_size_rdata,
        rdreq => r.size_rdack,
        rempty => cmd_size_fifo_empty,
        rusedwds => open
    );
   
    -- Wait for response_done
    -- de-assert cs
    -- check for alerts, back to top.

    dbg_sm: process(all)
        variable v : reg_type;
        variable cmd_size_fifo_not_empty: boolean;
    begin

        v := r;
        v.cmd_rdack := '0';
        v.size_rdack := '0';
        cmd_size_fifo_not_empty := cmd_size_fifo_empty = '0';

        case r.state is
            when idle =>
                if r.cntr < idle_delay then
                    v.cntr := r.cntr + 1;
                end if;
                v.cs_asserted := false;
                -- when enabled, and we have a non-empty transaction size:
                -- assert cs
                if dbg_chan.enabled and cmd_size_fifo_not_empty and r.cntr = idle_delay then
                    v.state := cs_start;
                    v.cntr := (others => '0');
                end if;
            when cs_start =>
                v.cs_asserted := true;
                v.cntr := r.cntr + 1;
                if r.cntr = cs_delay then
                    v.cntr := cmd_size_rdata(v.cntr'high downto 0);
                    v.state := cmd;
                end if;

            when cmd =>
               if byte_strobe = '1' then
                if r.idx = 3 or r.cntr = 0 then
                    v.cmd_rdack := '1';
                end if;
                   -- deal with sent byte
                   v.cntr := r.cntr - 1;
                   -- move pointer to next byte
                   v.idx := r.idx + 1;
                   if r.cntr = 1 then
                       v.state := resp;
                   end if;
                   
               end if;
             -- we're going to issue bytes from the command fifo at the timer rate.
             -- every 4 bytes or the transition out is a fifo ack since it's 32 bits wide.

            when resp =>
               if response_done then
                   v.size_rdack := '1';
                   v.state := cs_finish;
               end if;

            when cs_finish =>
            v.cntr := r.cntr + 1;
            if r.cntr = cs_delay then
                v.state := idle;
            end if;
                
        end case;

        rin <= v;
    end process;

    dbg_reg: process(clk, reset)
    begin
        if reset = '1' then
           r <= reg_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    data_from_host.valid <= byte_strobe when r.state = cmd else '0';
    process(all)
        variable byte_idx : integer;
    begin
        byte_idx := to_integer(r.idx);
        data_from_host.data <= cmd_fifo_rdata(7 + 8*byte_idx downto 8*byte_idx);
    end process;
    -- Response FIFO.
    -- when we're enabled, any target response data gets written into the response fifo.
    -- software is resonsible for reading the data out of the fifo at an appropriate rate.
    resp_fifo_write <= data_to_host.ready and data_to_host.valid when dbg_chan.enabled and r.state = resp else '0';
    resp_fifo: entity work.dcfifo_mixed_xpm
     generic map(
        wfifo_write_depth => 4096,
        wdata_width => 8,
        rdata_width => 32,
        showahead_mode => true
    )
     port map(
        wclk => clk,
        reset => reset,
        write_en => resp_fifo_write,
        wdata => data_to_host.data,
        wfull => open,
        wusedwds => open,
        rclk => clk,
        rdata => resp_fifo_read_data,
        rdreq => resp_fifo_read_ack,
        rempty => resp_fifo_empty,
        rusedwds => open
    );
    data_to_host.ready <= byte_strobe;

end rtl;