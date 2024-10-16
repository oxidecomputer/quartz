-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

package i2c_link_layer_pkg is

    type mode_t is (STANDARD, FAST, FAST_PLUS);

    type state_t is (IDLE, WAIT_BUF, START, BYTE_TX, BYTE_RX, ACK_TX, ACK_RX, STOP, AWAIT_STREAM);

    -- all times in nanoseconds (ns)
    type settings_t is record
        fscl_period_ns  : positive; -- SCL clock period
        sda_su_ns       : positive; -- data set-up time
        sta_su_hd_ns    : positive; -- START set-up/hold time
        sto_su_ns       : positive; -- STOP set-up time
        sto_sta_buf_ns  : positive; -- bus free time between STOP and START
    end record;

    function get_i2c_settings (constant mode : mode_t) return settings_t;
end package;

package body i2c_link_layer_pkg is

    function get_i2c_settings (constant mode : mode_t) return settings_t is
        variable r : settings_t;
    begin
        case mode is
            when STANDARD =>
                 r := (
                    10_000, -- 10^9 / 100_000Hz
                    250,
                    4700,
                    4000,
                    4700
                 );
            when FAST =>
                r := (
                    2500, -- 10^9 / 400_000Hz
                    100,
                    600,
                    600,
                    1300
                );
            when FAST_PLUS =>
                r := (
                    1000, -- 10^9 / 1_000_000Hz
                    50,
                    260,
                    260,
                    500
                );
        end case;

        return r;
    end;

end package body;