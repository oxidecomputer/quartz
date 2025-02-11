-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

package axilite_if_2019_pkg is
   generic (
      addr_width : integer
   );

    -- Write address channel
    type axil_write_address_t is record
       valid : std_logic;
       ready : std_logic;
       addr : std_logic_vector(addr_width - 1 downto 0);
    end record;

   view aw_controller of axil_write_address_t is
      valid, addr : out;
      ready       : in;
   end view;
   alias aw_target is aw_controller'converse;

    -- write data channel
   type axil_write_data_t is record
      valid : std_logic;
      ready : std_logic;
      data : std_logic_vector(31 downto 0);
      strb : std_logic_vector(3 downto 0);
   end record;

   view wdat_controller of axil_write_data_t is
      valid, data, strb : out;
      ready       : in;
   end view;
   alias wdat_target is wdat_controller'converse;

   -- write response channel
   type axil_write_response_t is record
      valid : std_logic;
      ready : std_logic;
      resp : std_logic_vector(1 downto 0);
   end record;
   
   view wresp_controller of axil_write_response_t is
      valid : in;
      ready : out;
      resp  : in;
   end view;
   alias wresp_target is wresp_controller'converse;

   -- read address channel
   type axil_read_address_t is record
      valid : std_logic;
      ready : std_logic;
      addr : std_logic_vector(addr_width - 1 downto 0);
   end record;

   view raddr_controller of axil_read_address_t is
      valid, addr : out;
      ready : in;
   end view;
   alias radd_target is raddr_controller'converse;

   -- read data channel
   type axil_read_data_t is record
      valid : std_logic;
      ready : std_logic;
      data : std_logic_vector(31 downto 0);
      resp : std_logic_vector(1 downto 0);
   end record;

   view rdat_controller of axil_read_data_t is
      valid, data, resp : in;
      ready : out;
   end view;
   alias rdata_target is rdat_controller'converse;

   -- AXI-lite interface
   type axil_t is record
       write_address : axil_write_address_t;
       write_data : axil_write_data_t;
       write_response : axil_write_response_t;
       read_address : axil_read_address_t;
       read_data : axil_read_data_t;
   end record;

   view axil_controller of axil_t is
      write_address : view aw_controller;
      write_data : view wdat_controller;
      write_response : view wresp_controller;
      read_address : view raddr_controller;
      read_data : view rdat_controller;
   end view;
   alias axil_target is axil_controller'converse;

   type axil_array_t is array (natural range <>) of axil_t ;

end package;

-- Some common sizes expected to be used
package axil8x32_pkg is new work.axilite_if_2019_pkg generic map(addr_width => 8);
package axil24x32_pkg is new work.axilite_if_2019_pkg generic map(addr_width => 24);
package axil26x32_pkg is new work.axilite_if_2019_pkg generic map(addr_width => 26);
