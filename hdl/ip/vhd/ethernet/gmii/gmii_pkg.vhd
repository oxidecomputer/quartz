-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Shared types for the GMII stitch between the SGMII PCS (module 1) and the
-- RGMII adapter (module 2). A single 8-bit GMII bundle carries one data byte
-- plus the valid/error qualifiers. At 10/100 Mbps the bundle still lives in the
-- 125 MHz clock domain; the `dv` strobe simply fires every 10th/100th cycle
-- (clock-enable model) rather than the GMII clock being slowed.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package gmii_pkg is

    -- Link speed shared by the SGMII config word and the RGMII in-band status.
    type eth_speed_t is (SPEED_10, SPEED_100, SPEED_1000);

    -- One direction of GMII. `dv` doubles as tx_en on the transmit side and
    -- rx_dv on the receive side; `er` is tx_er / rx_er respectively.
    type gmii_t is record
        data : std_logic_vector(7 downto 0);
        dv   : std_logic;
        er   : std_logic;
    end record;

    constant GMII_IDLE : gmii_t := (data => (others => '0'), dv => '0', er => '0');

    -- 2-bit speed encoding used by both the SGMII config word (bits 11:10) and
    -- the RGMII in-band status nibble: "00"=10, "01"=100, "10"=1000.
    function speed_to_slv (s : eth_speed_t) return std_logic_vector;
    function slv_to_speed (s : std_logic_vector(1 downto 0)) return eth_speed_t;

    -- Number of 125 MHz GMII cycles per transferred byte at each speed. This is
    -- the replicate/decimate ratio (1 / 10 / 100) used by the rate adaptation.
    function speed_cycles_per_byte (s : eth_speed_t) return positive;

end package;

package body gmii_pkg is

    function speed_to_slv (s : eth_speed_t) return std_logic_vector is
    begin
        case s is
            when SPEED_10   => return "00";
            when SPEED_100  => return "01";
            when SPEED_1000 => return "10";
        end case;
    end function;

    function slv_to_speed (s : std_logic_vector(1 downto 0)) return eth_speed_t is
    begin
        case s is
            when "00"   => return SPEED_10;
            when "01"   => return SPEED_100;
            when others => return SPEED_1000;  -- "10" and the reserved "11"
        end case;
    end function;

    function speed_cycles_per_byte (s : eth_speed_t) return positive is
    begin
        case s is
            when SPEED_10   => return 100;
            when SPEED_100  => return 10;
            when SPEED_1000 => return 1;
        end case;
    end function;

end package body;
