-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.axil_common_pkg.all;

package axil_interconnect_sim_pkg is

    -- The fabric under test is instantiated with a 26 bit initiator, matching the
    -- FMC target in the real designs.
    constant INITIATOR_ADDR_WIDTH : integer := 26;

    constant bus_handle : bus_master_t := new_bus(
        data_length => 32,
        address_length => INITIATOR_ADDR_WIDTH
    );

    -- Responder map for the harness. The gap between 0x300 and 0x7FFF, plus
    -- everything at or above 0x10000, is deliberately unmapped so the catch-all
    -- SLVERR path gets exercised.
    constant SRAM_A_IDX : integer := 0;
    constant SRAM_B_IDX : integer := 1;
    constant SLOW_IDX   : integer := 2;
    constant WIDE_IDX   : integer := 3;

    constant config_array : axil_responder_cfg_array_t(0 to 3) :=
        (SRAM_A_IDX => resp_cfg(base_addr => x"00000000", addr_span_bits => 8, pipe_stages => 0),
         SRAM_B_IDX => resp_cfg(base_addr => x"00000100", addr_span_bits => 8, pipe_stages => 1),
         SLOW_IDX   => resp_cfg(base_addr => x"00000200", addr_span_bits => 8, pipe_stages => 3),
         WIDE_IDX   => resp_cfg(base_addr => x"00008000", addr_span_bits => 15, pipe_stages => 2));

    -- An integer as a bus address
    function ba (constant addr : integer) return std_logic_vector;

    -- Base address of a responder, plus a byte offset, as a bus address
    function ba (constant idx : integer; constant offset : integer) return std_logic_vector;

    -- An integer as a 32 bit data word
    function w32 (constant value : integer) return std_logic_vector;

end package;

package body axil_interconnect_sim_pkg is

    function ba (constant addr : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(addr, INITIATOR_ADDR_WIDTH));
    end function;

    function ba (constant idx : integer; constant offset : integer) return std_logic_vector is
    begin
        return std_logic_vector(unsigned(config_array(idx).base_addr(INITIATOR_ADDR_WIDTH - 1 downto 0))
                                + to_unsigned(offset, INITIATOR_ADDR_WIDTH));
    end function;

    function w32 (constant value : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(value, 32));
    end function;

end package body;
