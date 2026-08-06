-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.hash_engine_regs_pkg.all;

package hash_engine_sim_pkg is

    -- 8 bit address, so register offsets are the raw RDL offsets with no window
    -- base to add. The DUT hangs off this directly, there is no interconnect in
    -- the harness.
    constant bus_handle : bus_master_t := new_bus(
        data_length    => 32,
        address_length => 8
    );

    -- The contents the fake flash returns for a given byte address. 193 is odd so
    -- this is a bijection modulo 256: every byte value appears and neighbouring
    -- addresses always differ, which makes an off-by-one in the fetch path show up
    -- as a wrong digest rather than an accidental match. The address is folded to
    -- 16 bits first purely to keep the multiply inside an integer.
    function flash_byte (
        addr : natural
    ) return std_logic_vector;

    procedure write_reg (
        signal net : inout network_t;
        offset     : natural;
        data       : std_logic_vector(31 downto 0)
    );

    procedure read_reg (
        signal net    : inout network_t;
        offset        : natural;
        variable data : out std_logic_vector(31 downto 0)
    );

    -- Reassemble the digest from the eight registers into the same bit order the
    -- core uses, ie bits 7 downto 0 are hash byte 0.
    procedure read_digest (
        signal net      : inout network_t;
        variable digest : out std_logic_vector(255 downto 0)
    );

    -- Poll STATUS until done sets. Preferred over waiting on busy for a normal
    -- completion: done is monotonic within a run and is cleared by the start that
    -- precedes this call, so there is no window where a poll can slip through
    -- before the engine has picked the work up.
    procedure wait_hash_done (
        signal net      : inout network_t;
        variable status : out std_logic_vector(31 downto 0)
    );

    -- Poll STATUS until busy clears. Only safe when the engine is known to be busy
    -- already, ie after an abort, where the drain keeps busy asserted.
    procedure wait_not_busy (
        signal net      : inout network_t;
        variable status : out std_logic_vector(31 downto 0)
    );

end package;

package body hash_engine_sim_pkg is

    function flash_byte (
        addr : natural
    ) return std_logic_vector is
    begin
        return To_StdLogicVector((((addr mod 65536) * 193) + 41) mod 256, 8);
    end function;

    procedure write_reg (
        signal net : inout network_t;
        offset     : natural;
        data       : std_logic_vector(31 downto 0)
    ) is
    begin
        write_bus(net, bus_handle, To_StdLogicVector(offset, bus_handle.p_address_length), data);
    end procedure;

    procedure read_reg (
        signal net    : inout network_t;
        offset        : natural;
        variable data : out std_logic_vector(31 downto 0)
    ) is
    begin
        read_bus(net, bus_handle, To_StdLogicVector(offset, bus_handle.p_address_length), data);
    end procedure;

    procedure read_digest (
        signal net      : inout network_t;
        variable digest : out std_logic_vector(255 downto 0)
    ) is
        variable word : std_logic_vector(31 downto 0);
    begin
        for i in 0 to 7 loop
            read_reg(net, DIGEST0_OFFSET + 4 * i, word);
            digest(32 * i + 31 downto 32 * i) := word;
        end loop;
    end procedure;

    procedure wait_hash_done (
        signal net      : inout network_t;
        variable status : out std_logic_vector(31 downto 0)
    ) is
        variable rdata : std_logic_vector(31 downto 0);
    begin
        loop
            read_reg(net, STATUS_OFFSET, rdata);
            exit when (rdata and STATUS_DONE_MASK) /= (rdata'range => '0');
        end loop;

        status := rdata;
    end procedure;

    procedure wait_not_busy (
        signal net      : inout network_t;
        variable status : out std_logic_vector(31 downto 0)
    ) is
        variable rdata : std_logic_vector(31 downto 0);
    begin
        loop
            read_reg(net, STATUS_OFFSET, rdata);
            exit when (rdata and STATUS_BUSY_MASK) = (rdata'range => '0');
        end loop;

        status := rdata;
    end procedure;

end package body;
