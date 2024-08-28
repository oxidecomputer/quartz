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


-- This block has interfaces to the following FIFOs:
-- Debug TX FIFO: a FIFO that holds data as if it was coming from the host. SW can craft arbitrary data to be sent to the eSPI target as if it was the host.
-- Debug RX FIFO: a FIFO that holds the response data, as if it was coming from the eSPI target. SW can read the data from this FIFO as if it was the target.
-- TODO: we'd potentially like to log data sent/rx'd... how do we also do that?

entity dbg_link_faker is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- set in registers, controls how the shifters
        -- sample per sclk
        qspi_mode : in    qspi_mode_t;
        -- Asserted by command processor during the
        -- transmission of the last command byte (the CRC)
        is_crc_byte : in    boolean;
        alert_needed : in boolean;
        -- "Streaming" data recieved after deserialization
        data_to_host       : view st_sink;
        -- "Streaming" data to serialize and transmit
        data_from_host     : view st_source;

        enabled: in std_logic;

         -- cmd FIFO Interface
         cmd_fifo_write_data : in   std_logic_vector(31 downto 0);
         cmd_fifo_write      : out   std_logic;
         -- RX FIFO Interface
         resp_fifo_read_data : out    std_logic_vector(31 downto 0);
         resp_fifo_read_ack  : in   std_logic
    );
end entity;

architecture rtl of dbg_link_faker is

    signal cmd_fifo_reset : std_logic;
    signal cmd_fifo_empty: std_logic;
    signal resp_fifo_write : std_logic;

begin

    -- Timer: the fastest byte transfer that can be done is 2 clocks at 66MHz (in quad mode) so we'll
    -- generate a strobe at that speed when enabled to provide effective rate-limiting to the design.
    -- We an later experiment with whether this is neccessary and speed the debug path up a bit.

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
        reset => cmd_fifo_reset,
        write_en => cmd_fifo_write,
        wdata => cmd_fifo_write_data,
        wfull => open,
        wusedwds => open,
        rclk => clk,
        rdata => open,
        rdreq => '0',
        rempty => cmd_fifo_empty,
        rusedwds => open
    );
    -- Response FIFO.
    -- when we're enabled, any target response data gets written into the response fifo.
    -- software is resonsible for reading the data out of the fifo at an appropriate rate.
    resp_fifo_write <= data_to_host.ready and data_to_host.valid and enabled;
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
        rempty => open,
        rusedwds => open
    );
    data_to_host.ready <= '1';
    data_from_host.valid <= '0';
    data_from_host.data <= (others => '0');

end rtl;