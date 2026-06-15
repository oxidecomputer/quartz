-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII PCS support types: ordered-set code-group values, the auto-negotiation
-- state enumeration, and the SGMII config word packing/unpacking. SGMII is
-- 1000BASE-X PCS (IEEE 802.3 Clause 36) at 1.25 Gbaud with the Clause-37
-- auto-neg replaced by the SGMII config word that carries speed/duplex/link.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.helper_8b10b_pkg.all;  -- K-code constants
use work.gmii_pkg.all;

package sgmii_pkg is

    -- Ordered-set defining code groups (the {K, data} byte fed to encode_8b10b).
    -- A code group is held as a 9-bit {k, data[7:0]} value to match the codec.
    subtype code_byte_t is std_logic_vector(8 downto 0);

    function k_byte (data : std_logic_vector(7 downto 0)) return code_byte_t;
    function d_byte (data : std_logic_vector(7 downto 0)) return code_byte_t;

    -- Ordered-set leading characters / special code groups.
    constant COMMA   : code_byte_t := '1' & K28_5;  -- /K28.5/ comma
    constant SOP     : code_byte_t := '1' & K27_7;  -- /S/  start of packet
    constant EOP     : code_byte_t := '1' & K29_7;  -- /T/  end of packet
    constant CEXT    : code_byte_t := '1' & K23_7;  -- /R/  carrier extend
    constant ERRP    : code_byte_t := '1' & K30_7;  -- /V/  error propagation

    -- Idle ordered-set second code groups: /I1/=K28.5 D5.6, /I2/=K28.5 D16.2.
    constant D5_6    : std_logic_vector(7 downto 0) := x"C5";  -- (6<<5)|5
    constant D16_2   : std_logic_vector(7 downto 0) := x"50";  -- (2<<5)|16

    -- Config ordered-set second code groups: /C1/=K28.5 D21.5, /C2/=K28.5 D2.2.
    constant D21_5   : std_logic_vector(7 downto 0) := x"B5";  -- (5<<5)|21
    constant D2_2    : std_logic_vector(7 downto 0) := x"42";  -- (2<<5)|2

    -- PCS transmit mode driven by the auto-neg FSM (Clause 36 `xmit` variable).
    type pcs_xmit_t is (XMIT_IDLE, XMIT_CONFIG, XMIT_DATA);

    -- Auto-negotiation state machine (Clause 37 figure 37-6, SGMII flavour).
    type an_state_t is (
        AN_ST_ENABLE,
        AN_ST_RESTART,
        AN_ST_ABILITY,
        AN_ST_ACK,
        AN_ST_COMPLETE,
        AN_ST_IDLE,
        AN_ST_LINK_OK
    );

    -- SGMII config word (16 bits). PHY->MAC encoding:
    --   bit  0    : 1 (always set)
    --   bits 11:10: speed  ("00"=10, "01"=100, "10"=1000)
    --   bit  12   : duplex (1 = full)
    --   bit  14   : acknowledge
    --   bit  15   : link   (1 = up)
    type sgmii_config_t is record
        link   : std_logic;
        ack    : std_logic;
        duplex : std_logic;
        speed  : eth_speed_t;
    end record;

    constant SGMII_CONFIG_RESET : sgmii_config_t :=
        (link => '0', ack => '0', duplex => '1', speed => SPEED_1000);

    function to_config_word (cfg : sgmii_config_t) return std_logic_vector;     -- 16 bits
    function from_config_word (word : std_logic_vector(15 downto 0)) return sgmii_config_t;

end package;

package body sgmii_pkg is

    function k_byte (data : std_logic_vector(7 downto 0)) return code_byte_t is
    begin
        return '1' & data;
    end function;

    function d_byte (data : std_logic_vector(7 downto 0)) return code_byte_t is
    begin
        return '0' & data;
    end function;

    function to_config_word (cfg : sgmii_config_t) return std_logic_vector is
        variable w : std_logic_vector(15 downto 0) := (others => '0');
    begin
        w(0)            := '1';
        w(11 downto 10) := speed_to_slv(cfg.speed);
        w(12)           := cfg.duplex;
        w(14)           := cfg.ack;
        w(15)           := cfg.link;
        return w;
    end function;

    function from_config_word (word : std_logic_vector(15 downto 0)) return sgmii_config_t is
        variable cfg : sgmii_config_t;
    begin
        cfg.link   := word(15);
        cfg.ack    := word(14);
        cfg.duplex := word(12);
        cfg.speed  := slv_to_speed(word(11 downto 10));
        return cfg;
    end function;

end package body;
