-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package axist_if_2k19_pkg is
    generic (
       width : integer
    );
 
    -- Basic AXI streaming interface, no last
    type axi_st_t is record
        valid : std_logic;
        ready : std_logic;
        data : std_logic_vector(width - 1 downto 0);
    end record;
    view axi_st_source of axi_st_t is
       valid, data : out;
       ready : in;
    end view;
    alias axi_st_sink is axi_st_source'converse;
    
    -- Basic AXI streaming interface, with last flag
    type axi_st_pkt_t is record
        valid : std_logic;
        ready : std_logic;
        last : std_logic;
        data : std_logic_vector(width - 1 downto 0);
    end record;
    view axi_st_pkt_source of axi_st_pkt_t is
       valid, data, last: out;
       ready : in;
    end view;
    alias axi_st_pkt_sink is axi_st_pkt_source'converse;
end package;

-- Some common sizes expected to be used
package axi_st8_pkg is new work.axist_if_2k19_pkg generic map(width => 8);
package axi_st32_pkg is new work.axist_if_2k19_pkg generic map(width => 32);
