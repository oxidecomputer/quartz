-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil_common_pkg.all;
use work.axil8x32_pkg;
use work.axil26x32_pkg;

-- This is a somewhat naive implementation of an parameterized AXI-lite interconnect.
-- It is intended to be function as an MVP implementation allowing for basic multi-responder
-- usecases. It is not currently a full cross-bar implementation, but may grow to be one in the future.

entity axil_interconnect is
    generic (
        config_array : axil_responder_cfg_array_t
    );
    port (
        -- Clock and reset
        clk : in std_logic;
        reset : in std_logic;

        -- Responder I/F to the main initiator, which is a *target* interface
        initiator : view axil26x32_pkg.axil_target;

        -- Initiator I/Fs to the responder blocks, which is a *controller* interface
        responders : view (axil8x32_pkg.axil_controller) of axil8x32_pkg.axil_array_t(config_array'range)

    );
end entity;

architecture rtl of axil_interconnect is

    constant default_idx : integer := config_array'length;
    -- We implement a catch-all responder that will respond with an error if no other responder does
    -- so this signal is one larger than the number of responders
    signal responder_sel : integer range 0 to config_array'length := default_idx;
    signal write_done : std_logic;
    signal read_done : std_logic;
    signal in_txn : boolean;

begin

    write_done <= '1' when initiator.write_response.valid = '1' and initiator.write_response.ready = '1' else
                 '0';
    read_done <= '1' when initiator.read_data.valid = '1' and initiator.read_data.ready = '1' else
                '0';

    -- we're going to stall all the transactions until we have decoded and selected a responder,
    -- flipped the muxes and then we can let the txn_through, and we keep the responder selected until
    -- the txn is done.
    -- There's a lot of combo logic here, we'll see how this goes.
    decode: process(clk, reset)
    begin
        if reset = '1' then
            responder_sel <= default_idx;
            in_txn <= false;
        elsif rising_edge(clk) then
            if initiator.write_address.valid = '1' then
                for i in 0 to config_array'length - 1 loop
                    if (to_integer(initiator.write_address.addr) >= to_integer(config_array(i).base_addr)) and
                       (to_integer(initiator.write_address.addr) < to_integer(config_array(i).base_addr) + 2**config_array(i).addr_span_bits) then
                        responder_sel <= i;
                    end if;
                end loop;
                in_txn <= true;
            elsif initiator.read_address.valid = '1' then
                for i in 0 to config_array'length - 1 loop
                    if (to_integer(initiator.read_address.addr)) >= to_integer(config_array(i).base_addr) and
                       (to_integer(initiator.read_address.addr)) < to_integer(config_array(i).base_addr + 2**config_array(i).addr_span_bits) then
                        responder_sel <= i;
                    end if;
                end loop;
                in_txn <= true;
            elsif write_done or read_done then
                responder_sel <= default_idx;
                in_txn <= false;
            end if;
        end if;
    end process;

    mux: process(all)
    begin
        -- default no transaction state for all responders
        for i in 0 to config_array'length - 1 loop
            responders(i).write_address.valid <= '0';
            responders(i).write_address.addr <= initiator.write_address.addr(responders(i).write_address.addr'length - 1 downto 0);
            responders(i).write_data.valid <= '0';
            responders(i).write_data.data <= initiator.write_data.data;
            responders(i).write_data.strb <= initiator.write_data.strb;
            responders(i).write_response.ready <= '0';

            responders(i).read_address.valid <= '0';
            responders(i).read_address.addr <= initiator.read_address.addr(responders(i).read_address.addr'length - 1 downto 0);
            responders(i).read_data.ready <= '0';

            -- This is a "hack" do deal with signal resolution, we need to assign drivers to all signals
            -- even the output ones, so we assign them to 'Z' which is a high impedance state allowing the 
            -- resolution function to resolve correctly (anything with a 'U' resolves to a 'U')
            -- The LRM specifies that a signal assignment statement in a process creates drivers for every 
            -- sub-element of the longest static prefix of the target. The longest static prefix of responders(i).<xyz> 
            -- is `responders` (because `i` is non-static) which also, perhaps unexpectedly, includes all the input elements.
            -- these are the "input" elements on the responder interface, so we assign them something so that the resolution
            -- function works as expected.
            responders(i).write_address.ready <= 'Z';
            responders(i).read_address.ready <= 'Z';
            responders(i).write_data.ready <= 'Z';
            responders(i).write_response.valid <= 'Z';
            responders(i).read_data.data <= (others => 'Z');
            responders(i).read_data.valid <= 'Z';
            responders(i).write_response.resp <= (others => 'Z');
            responders(i).read_data.resp <= (others => 'Z');
        end loop;

        -- deal with in-txn muxing
        if in_txn and responder_sel < default_idx then
            -- responder mux
            responders(responder_sel).write_address.valid <= initiator.write_address.valid;
            responders(responder_sel).write_address.addr <= initiator.write_address.addr(responders(responder_sel).write_address.addr'length - 1 downto 0);
            responders(responder_sel).write_data.valid <= initiator.write_data.valid;
            responders(responder_sel).write_data.data <= initiator.write_data.data;
            responders(responder_sel).write_data.strb <= initiator.write_data.strb;
            responders(responder_sel).write_response.ready <= initiator.write_response.ready;

            responders(responder_sel).read_address.valid <= initiator.read_address.valid;
            responders(responder_sel).read_address.addr <= initiator.read_address.addr(responders(responder_sel).read_address.addr'length - 1 downto 0);
            responders(responder_sel).read_data.ready <= initiator.read_data.ready;
            -- initiator mux
            initiator.write_address.ready <= responders(responder_sel).write_address.ready;
            initiator.write_data.ready <= responders(responder_sel).write_data.ready;
            initiator.write_response.resp <= responders(responder_sel).write_response.resp;
            initiator.write_response.valid <= responders(responder_sel).write_response.valid;
            initiator.read_address.ready <= responders(responder_sel).read_address.ready;
            initiator.read_data.resp <= responders(responder_sel).read_data.resp;
            initiator.read_data.valid <= responders(responder_sel).read_data.valid;
            initiator.read_data.data <= responders(responder_sel).read_data.data;

        elsif in_txn then
            -- default response to not hang bus
            initiator.write_address.ready <= '1';
            initiator.write_data.ready <= '1';
            initiator.write_response.resp <= SLVERR;
            initiator.write_response.valid <= '1';
            initiator.read_address.ready <= '1';
            initiator.read_data.resp <= SLVERR;
            initiator.read_data.valid <= '1';
            initiator.read_data.data <= X"DEADBEEF";


        else
            -- hold for decode
            -- default response to not hang bus
            initiator.write_address.ready <= '0';
            initiator.write_data.ready <= '0';
            initiator.write_response.resp <= SLVERR;
            initiator.write_response.valid <= '0';
            initiator.read_address.ready <= '0';
            initiator.read_data.resp <= SLVERR;
            initiator.read_data.valid <= '0';
            initiator.read_data.data <= (others => '0');
        end if;
    end process;
    


end rtl;
