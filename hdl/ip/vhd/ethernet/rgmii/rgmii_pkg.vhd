-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- RGMII support types. RGMII carries 4-bit data on both edges of a 125/25/2.5
-- MHz clock. During the inter-frame gap (RX_CTL low) the PHY drives in-band
-- status on RXD: rising-edge nibble = {duplex, speed[1:0], link}.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;

package rgmii_pkg is

    -- RGMII pin bundles, one per direction.
    type rgmii_pins_t is record
        clk : std_logic;
        ctl : std_logic;
        d   : std_logic_vector(3 downto 0);
    end record;

    -- In-band status presented on RXD during the inter-frame gap.
    type rgmii_inband_t is record
        link   : std_logic;
        duplex : std_logic;
        speed  : eth_speed_t;
    end record;

    constant RGMII_INBAND_RESET : rgmii_inband_t :=
        (link => '0', duplex => '1', speed => SPEED_1000);

    -- Rising-edge nibble = {duplex, speed[1], speed[0], link}.
    function inband_to_nibble (s : rgmii_inband_t) return std_logic_vector;      -- 4 bits
    function nibble_to_inband (n : std_logic_vector(3 downto 0)) return rgmii_inband_t;

end package;

package body rgmii_pkg is

    function inband_to_nibble (s : rgmii_inband_t) return std_logic_vector is
        variable n : std_logic_vector(3 downto 0);
    begin
        n(0)          := s.link;
        n(2 downto 1) := speed_to_slv(s.speed);
        n(3)          := s.duplex;
        return n;
    end function;

    function nibble_to_inband (n : std_logic_vector(3 downto 0)) return rgmii_inband_t is
        variable s : rgmii_inband_t;
    begin
        s.link   := n(0);
        s.speed  := slv_to_speed(n(2 downto 1));
        s.duplex := n(3);
        return s;
    end function;

end package body;
