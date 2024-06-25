-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Inspired by Intel's Avalon-ST Bytes to Packets and Packets to Bytes
-- cores, but not using channels

-- The "byte" interface has more data in it than the "packet" interface
-- due to encoding overhead. We don't add backpressure here, but packet
-- consumers could backpressure through this interface.
-- This is done without registering all the inputs/outputs so it may
-- limit fmax, and is technically not 100% AXI compliant because of that.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_bytes_pkg.all;

entity axi_st_bytes_to_packets is
    port (
      -- Clock and reset
      clk : in std_logic;
      reset : in std_logic;
  
      -- AXI byte
      byte_tdata : in std_logic_vector(7 downto 0);
      byte_tvalid : in std_logic;
      byte_tready : out std_logic;
  
      -- AXI packet streaming interface
      pkt_tdata : out std_logic_vector(7 downto 0);
      pkt_tvalid : out std_logic;
      pkt_tready : in std_logic;
      pkt_tlast : out std_logic;
  
    );
  end entity axi_st_bytes_to_packets;

architecture rtl of axi_st_bytes_to_packets is
    signal xor_next : boolean;
    signal next_is_last: boolean;

begin
    -- We try to do this with the thinest possible wrapper
    -- We need to xor the next data when we see an escape
    -- We drop any control bytes
    process(clk, reset)
    begin
        if reset = '1' then
            next_is_last <= false;
            xor_next <= false;
        elsif rising_edge(clk) then
            -- accept data when byte is valid and the packet
            -- interface can accept a byte.
            if byte_tvalid and byte_tready then
                -- we silently drop any control bytes
                -- and AXI doesn't have an indication for start
                -- next byte is the last byte
                if byte_tdata = end_char then
                    next_is_last <= true;
                else
                    next_is_last <= false;
                end if;
                if byte_tdata = escape_char then
                    xor_next <= true;
                else
                    xor_next <= false;
                end if;
            end if;
        end if;
    end process;

    -- Pass through anything that isn't a control_byte, drop any control bytes
    pkt_tvalid <= byte_tvalid when (not matches_ctrl_char(byte_tdata)) else '0';
    -- pass through the data unless we need to xor it
    pkt_tdata <= byte_tdata when (not xor_next) else do_escape(byte_tdata);
    -- strobe the "last" signal until we've transferred the last data byte
    pkt_tlast <= '1' when next_is_last else '0';
    byte_tready <= pkt_tready;

end rtl;