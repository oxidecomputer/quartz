-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Inspired by Intel's Avalon-ST Bytes to Packets and Packets to Bytes
-- cores, but not using channels
-- Beacuse the outgoing stream of bytes has more information than the
-- incomming stream of packets, this core will assert backpressure
-- when stuffing ctrl bytes. It is also possible the downstream consumer
-- may assert backpressure which will be passed through here.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_bytes_pkg.all;

entity axi_st_packets_to_bytes is
    port (
      -- Clock and reset
      clk : in std_logic;
      reset : in std_logic;
  
      -- AXI byte
      byte_tdata : out std_logic_vector(7 downto 0);
      byte_tvalid : out std_logic;
      byte_tready : in std_logic;
  
      -- AXI packet streaming interface
      pkt_tdata : in std_logic_vector(7 downto 0);
      pkt_tvalid : in std_logic;
      pkt_tready : out std_logic;
      pkt_tlast : in std_logic;
  
    );
end entity axi_st_packets_to_bytes;

architecture rtl of axi_st_packets_to_bytes is
    type state_t is (IDLE, ESCAPE, START, DATA, STOP);
    type reg_t is record
        state : state_t;
        needs_escape : std_logic;
        needs_stop : std_logic;
        is_last: std_logic;
        valid : std_logic;
        data  : std_logic_vector(7 downto 0);
    end record;
    constant reg_t_reset : reg_t := (
        state => IDLE,
        needs_escape => '0',
        needs_stop => '0',
        is_last => '0',
        valid => '0',
        data  => (others => '0')
    );

    signal r, rin : reg_t;
begin

    sm:process(all)
        variable v : reg_t;
    begin
        v := r;

        case v.state is
            when IDLE =>
                if pkt_tvalid and pkt_tready then
                    if pkt_tdata = escape_char then
                        v.data := do_escape(pkt_tdata);
                        v.needs_escape := '1';
                    else
                        v.data := pkt_tdata;
                    end if;
                    v.is_last := pkt_tlast;
                    v.valid := '1';
                    v.state := START;
                end if;

            when START =>
                if byte_tvalid and byte_tready then
                    if r.needs_escape then 
                        v.state := ESCAPE;
                    else
                        v.state := DATA;
                    end if;
                end if;
            when ESCAPE =>
                if byte_tvalid and byte_tready then
                    if r.needs_stop then
                        v.state := STOP;
                    else
                        v.state := DATA;
                    end if;
                    v.needs_escape := '0';
                end if;

            when DATA =>
                if byte_tvalid and byte_tready then
                    v.valid := '0'; 
                    if r.is_last then
                        v.state := IDLE;
                    end if;
                end if;
                if pkt_tvalid and pkt_tready then
                    if pkt_tdata = escape_char then
                        v.data := do_escape(pkt_tdata);
                        v.needs_escape := '1';
                    else
                        v.data := pkt_tdata;
                    end if;
                    v.is_last := pkt_tlast;
                    v.valid := '1';
                end if;
                if v.needs_escape then
                    v.state := ESCAPE;
                elsif v.is_last then
                    v.needs_stop := '1';
                    v.state := STOP;
                end if;
            when STOP =>
                if byte_tvalid and byte_tready then
                    v.state := DATA;
                end if;
        end case;

        r <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset = '1' then
            r <= reg_t_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    byte_tvalid <= '1' when r.state = START or r.state = ESCAPE or r.state = STOP else 
                    r.valid ;
    byte_tdata  <=  start_char when r.state = START else
                    end_char when r.state = STOP else
                    escape_char when r.state = ESCAPE else
                    r.data;
    -- we can accept a byte when we are in the IDLE state or when
    -- we are in the DATA state and the downstream consumer
    pkt_tready <= '1' when r.state = IDLE or (byte_tready = '1' and r.state = DATA) else '0';

end rtl;
