-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package pca9545_pkg is
    -- We have a common pattern where we have an array of muxes. Any mux is allowed
    -- to activate if none of the *other* muxes are active, but we can't look out our
    -- own activity. This is frequently done in a generate loop, so we provide the
    -- active vector and "our" desired index to this function to determine if we
    -- are allowed to enable.
    function allowed_to_enable(active_mux: std_logic_vector; index: integer) return std_logic;


end package;

package body pca9545_pkg is

    function allowed_to_enable(active_mux: std_logic_vector; index: integer) return std_logic is
        variable others_active : std_logic := '0';
    begin
        for i in active_mux'range loop
            -- set others_active if any mux other than our index is active
            if i /= index and active_mux(i) = '1' then
                others_active := '1';
            end if;
        end loop;
        -- we want the inverse of others_active because we can only enable if
        -- no other muxes are active
        return not others_active;
    end function;

end package body pca9545_pkg;