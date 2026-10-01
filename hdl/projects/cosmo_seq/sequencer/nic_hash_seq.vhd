-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sequencer_regs_pkg.all;

-- Measurement of the NIC's boot image, run by the hash engine on request.
--
-- This is its own state machine, not a stage of the NIC's power sequence,
-- because the two have nothing to do with each other beyond the boot flash:
-- the flash does not hang off the NIC's rails, so an image can be measured
-- while they come up, or with them down. What the two share is POR_B. The
-- flash can only be ours while the NIC is held in reset, and the power
-- sequence will not let it out of reset over a measurement in flight unless
-- told to.
entity nic_hash_seq is
    port(
        clk : in std_logic;
        reset : in std_logic;

        -- Single-cycle start requests: the power sequence setting off, and
        -- software asking for a run of its own.
        start_seq : in std_logic;
        start_sw : in std_logic;
        -- The NIC is in reset and staying there, so the flash may be taken
        hold : in std_logic;

        -- A run is in flight or being taken this cycle. Combinational on the
        -- start requests so that whoever is about to give up the hold sees a
        -- run that is starting as well as one that has.
        busy : out std_logic;
        owns_flash : out std_logic;
        status : out nic_hash_status_type;

        -- Hash engine hardware request, see hash_engine_top. Held until
        -- acknowledged; hash_err is valid with the acknowledge.
        hash_req : out std_logic;
        hash_ack : in std_logic;
        hash_err : in std_logic
    );
end entity;

architecture rtl of nic_hash_seq is
    type reg_t is record
        state : nic_hash_status_hash_sm;
        done : std_logic;
        err : std_logic;
        abandoned : std_logic;
        sw_started : std_logic;
        refused : std_logic;
    end record;
    constant reg_reset : reg_t := (
        state => IDLE,
        done => '0',
        err => '0',
        abandoned => '0',
        sw_started => '0',
        refused => '0'
    );
    signal r, rin : reg_t;
    signal start : std_logic;
begin

    start <= start_seq or start_sw;
    busy <= '1' when r.state /= IDLE or (start = '1' and hold = '1') else '0';
    -- Once the hold is gone the flash is the NIC's, whatever the engine is
    -- still doing with a run it was given earlier.
    owns_flash <= '1' when r.state /= IDLE and hold = '1' and r.abandoned = '0' else '0';
    hash_req <= '1' when r.state = RUNNING else '0';

    status.hash_sm <= r.state;
    status.done <= r.done;
    status.err <= r.err;
    status.abandoned <= r.abandoned;
    status.sw_started <= r.sw_started;
    status.refused <= r.refused;

    sm: process(all)
        variable v : reg_t;
    begin
        v := r;

        case r.state is
            when IDLE =>
                if start = '1' and hold = '1' then
                    v.state := RUNNING;
                    v.done := '0';
                    v.err := '0';
                    v.abandoned := '0';
                    v.refused := '0';
                    v.sw_started := start_sw and not start_seq;
                elsif start = '1' then
                    -- The NIC has the flash. Say so, and leave the last
                    -- run's result standing.
                    v.refused := '1';
                end if;

            -- The engine has no way to be called off, so a run is seen
            -- through to its acknowledge even when the flash has been taken
            -- away underneath it. Dropping the request early would leave the
            -- next one to collect this one's acknowledge.
            when RUNNING =>
                if hold = '0' then
                    v.abandoned := '1';
                end if;
                if hash_ack = '1' then
                    v.done := not hash_err and not v.abandoned;
                    v.err := hash_err or v.abandoned;
                    v.state := ACK_RELEASE;
                end if;

            when ACK_RELEASE =>
                if hash_ack = '0' then
                    v.state := IDLE;
                end if;
        end case;

        -- A start that lands on a run in flight is not a new run
        if start = '1' and r.state /= IDLE then
            v.refused := '1';
        end if;

        rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset then
            r <= reg_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;
