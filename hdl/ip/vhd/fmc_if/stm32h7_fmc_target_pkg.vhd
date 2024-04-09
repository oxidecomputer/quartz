-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package stm32h7_fmc_target_pkg is

    type txn_type is
        record
        read_writen : std_logic;
        addr : unsigned(25 downto 0);
    end record;

    function encode(txn: txn_type) return std_logic_vector;
    function decode(vec: std_logic_vector) return txn_type;

end package;

package body stm32h7_fmc_target_pkg is

    function encode(txn: txn_type) return std_logic_vector is
        variable vec : std_logic_vector(31 downto 0);
    begin
        vec := "00000" & txn.read_writen & std_logic_vector(txn.addr);
        return vec;
    end function;

    function decode(vec: std_logic_vector) return txn_type is
        variable txn : txn_type;
    begin
        txn := (
            read_writen => vec(26),
            addr => unsigned(vec(25 downto 0))
        );
        return txn;
    end function;
end package body;