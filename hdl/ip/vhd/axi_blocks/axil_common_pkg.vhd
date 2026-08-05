-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package axil_common_pkg is

    -- Interconnect configuration
    type axil_responder_config is record
        base_addr      : std_logic_vector(31 downto 0);
        addr_span_bits : integer;
    end record;

    type axil_responder_cfg_array_t is array (natural range <>) of axil_responder_config;

    type int_array is array (natural range <>) of integer;

    constant OKAY : std_logic_vector(1 downto 0)   := "00";
    constant EXOKAY : std_logic_vector(1 downto 0) := "01";
    constant SLVERR : std_logic_vector(1 downto 0) := "10";

    -- Ones in the low addr_span_bits positions, zeros above. Used both to mask
    -- a fabric address down to what a responder actually decodes and to select
    -- the bits that participate in the address compare.
    function span_mask (constant addr_span_bits : integer) return std_logic_vector;

    -- Every responder base address must be aligned to its own span, otherwise
    -- the upper-bits equality compare in the interconnect is not equivalent to
    -- a base/limit compare.
    function bases_aligned (constant cfg : axil_responder_cfg_array_t) return boolean;

    -- No two responder address ranges may overlap, otherwise more than one bit
    -- of the interconnect's one-hot select can be set at once.
    function ranges_disjoint (constant cfg : axil_responder_cfg_array_t) return boolean;

    -- Every responder must be reachable from an initiator of the given address
    -- width, otherwise it silently falls through to the error responder.
    function bases_reachable (
        constant cfg : axil_responder_cfg_array_t;
        constant initiator_addr_width : integer
    ) return boolean;

end package;

package body axil_common_pkg is

    function span_mask (constant addr_span_bits : integer) return std_logic_vector is
        variable mask : std_logic_vector(31 downto 0) := (others => '0');
    begin
        -- Set every bit below addr_span_bits. Walking the bits one at a time
        -- rather than slicing keeps addr_span_bits out of a slice bound, so this
        -- stays legal for the 0 and 32 cases (which would be null slices) and
        -- stays synthesizable under both Vivado and ghdl.
        for i in mask'reverse_range loop
            if i < addr_span_bits then
                mask(i) := '1';
            end if;
        end loop;
        return mask;
    end function;

    function bases_aligned (constant cfg : axil_responder_cfg_array_t) return boolean is
    begin
        -- Visit every responder and bail out on the first misaligned base. A base
        -- is aligned when none of the bits inside its own span are set, which is
        -- exactly the bits span_mask selects.
        for i in cfg'range loop
            if (cfg(i).base_addr and span_mask(cfg(i).addr_span_bits)) /= 32x"0" then
                return false;
            end if;
        end loop;
        return true;
    end function;

    function ranges_disjoint (constant cfg : axil_responder_cfg_array_t) return boolean is
        variable wider : integer;
    begin
        -- Visit each unordered pair of responders once (the j > i guard is what
        -- skips the self comparison and the mirror of a pair already checked) and
        -- bail out on the first overlap.
        for i in cfg'range loop
            for j in cfg'range loop
                if j > i then
                    -- both ranges are power of two aligned, so they overlap if
                    -- and only if the bases agree above the wider of the spans
                    wider := cfg(i).addr_span_bits;
                    if cfg(j).addr_span_bits > wider then
                        wider := cfg(j).addr_span_bits;
                    end if;
                    if ((cfg(i).base_addr xor cfg(j).base_addr) and not span_mask(wider)) = 32x"0" then
                        return false;
                    end if;
                end if;
            end loop;
        end loop;
        return true;
    end function;

    function bases_reachable (
        constant cfg : axil_responder_cfg_array_t;
        constant initiator_addr_width : integer
    ) return boolean is
    begin
        -- Visit every responder and bail out on the first base the initiator
        -- cannot drive, which is any base with a bit set at or above the
        -- initiator's address width. Reusing span_mask here treats the initiator
        -- width as a span: everything outside it must be zero.
        for i in cfg'range loop
            if (cfg(i).base_addr and not span_mask(initiator_addr_width)) /= 32x"0" then
                return false;
            end if;
        end loop;
        return true;
    end function;

end package body;
