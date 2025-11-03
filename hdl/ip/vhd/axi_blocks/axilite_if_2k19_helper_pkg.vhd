-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil8x32_pkg;
use work.axil15x32_pkg;
use work.axil32x32_pkg;

package axilite_if_2k19_helper_pkg is
    
   procedure resize_axil(signal fabric :  view axil32x32_pkg.axil_target; signal responder : view axil8x32_pkg.axil_controller);
   procedure resize_axil(signal fabric :  view axil32x32_pkg.axil_target; signal responder : view axil15x32_pkg.axil_controller);
end package;

package body axilite_if_2k19_helper_pkg is
   procedure resize_axil(signal fabric :  view axil32x32_pkg.axil_target; signal responder : view axil8x32_pkg.axil_controller) is
   begin

      responder.write_address.valid <= fabric.write_address.valid;
      fabric.write_address.ready <= responder.write_address.ready;
      responder.write_address.addr <= fabric.write_address.addr(responder.write_address.addr'length - 1 downto 0);
      
      responder.write_data.valid <= fabric.write_data.valid;
      fabric.write_data.ready <= responder.write_data.ready; 
      responder.write_data.data <= fabric.write_data.data;
      responder.write_data.strb <= fabric.write_data.strb;
        
      responder.write_response.ready <= fabric.write_response.ready;
      fabric.write_response.resp <= responder.write_response.resp;
      fabric.write_response.valid <= responder.write_response.valid;

      responder.read_address.valid <= fabric.read_address.valid;
      responder.read_address.addr <= fabric.read_address.addr(responder.read_address.addr'length - 1 downto 0);
      fabric.read_address.ready <= responder.read_address.ready;

      responder.read_data.ready <= fabric.read_data.ready;
      fabric.read_data.resp <= responder.read_data.resp;
      fabric.read_data.valid <= responder.read_data.valid;
      fabric.read_data.data <= responder.read_data.data;

   end procedure;
   procedure resize_axil(signal fabric :  view axil32x32_pkg.axil_target; signal responder : view axil15x32_pkg.axil_controller) is
   begin

      responder.write_address.valid <= fabric.write_address.valid;
      fabric.write_address.ready <= responder.write_address.ready;
      responder.write_address.addr <= fabric.write_address.addr(responder.write_address.addr'length - 1 downto 0);
      
      responder.write_data.valid <= fabric.write_data.valid;
      fabric.write_data.ready <= responder.write_data.ready; 
      responder.write_data.data <= fabric.write_data.data;
      responder.write_data.strb <= fabric.write_data.strb;
        
      responder.write_response.ready <= fabric.write_response.ready;
      fabric.write_response.resp <= responder.write_response.resp;
      fabric.write_response.valid <= responder.write_response.valid;

      responder.read_address.valid <= fabric.read_address.valid;
      responder.read_address.addr <= fabric.read_address.addr(responder.read_address.addr'length - 1 downto 0);
      fabric.read_address.ready <= responder.read_address.ready;

      responder.read_data.ready <= fabric.read_data.ready;
      fabric.read_data.resp <= responder.read_data.resp;
      fabric.read_data.valid <= responder.read_data.valid;
      fabric.read_data.data <= responder.read_data.data;

   end procedure;
end package body;