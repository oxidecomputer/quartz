-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

package i2c_common_pkg is

    --
    -- Link Layer
    --

    type mode_t is (
        SIMULATION, -- arbitrarily fast for simulation only
        STANDARD,   -- up to 100 Kbps
        FAST,       -- up to 400 Kbps
        FAST_PLUS   -- up to 1 Mbps
    );

    -- A group of settings for generics to generate constants
    -- all times in nanoseconds (ns)
    type settings_t is record
        fscl_period_ns  : positive; -- SCL clock period
        sda_su_ns       : positive; -- data set-up time
        sta_su_hd_ns    : positive; -- START set-up/hold time
        sto_su_ns       : positive; -- STOP set-up time
        sto_sta_buf_ns  : positive; -- bus free time between STOP and START
        tsp_ns          : positive; -- pulse width of spikes to be suppressed by the input filter
    end record;

    function get_i2c_settings (constant mode : mode_t) return settings_t;

    --
    -- Transaction Layer
    --

    type op_t is (
        READ,
        WRITE,
        -- RANDOM_READ will write an address byte and one more byte (intended to set an internal
        -- address register on a peripheral) before issuing a repeated start for a read.
        RANDOM_READ 
    );

    type cmd_t is record
        op      : op_t;
        addr    : std_logic_vector(6 downto 0);
        reg     : std_logic_vector(7 downto 0);
        len     : std_logic_vector(7 downto 0);
    end record;
    constant CMD_RESET  : cmd_t := (READ, (others => '0'), (others => '0'), (others => '0'));
    type cmd_t_array is array (natural range <>) of cmd_t;

end package;

package body i2c_common_pkg is

    function get_i2c_settings (constant mode : mode_t) return settings_t is
        variable r : settings_t;
    begin
        case mode is
            when SIMULATION =>
                 r := (
                    800,
                    50, -- currently unused by our simulated controller
                    200,
                    200,
                    200,
                    50 -- currently unused by our simulated controller
                 );
            when STANDARD =>
                 r := (
                    10_000, -- 10^9 / 100_000Hz
                    250,
                    4700,
                    4000,
                    4700,
                    50 -- this is technically undefined in the spec
                 );
            when FAST =>
                r := (
                    2500, -- 10^9 / 400_000Hz
                    100,
                    600,
                    600,
                    1300,
                    50
                );
            when FAST_PLUS =>
                r := (
                    1000, -- 10^9 / 1_000_000Hz
                    50,
                    260,
                    260,
                    500,
                    50
                );
        end case;

        return r;
    end;

end package body;