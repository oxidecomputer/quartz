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
-- while they come up, with them down, or with the NIC booted and running.
-- What the two share is the flash itself, which is the NIC's only while it
-- is being configured. A start that lands then is kept until the flash is
-- back, and the power sequence will not give the flash to the NIC over a
-- measurement in flight unless told to.
entity nic_hash_seq is
    port(
        clk : in std_logic;
        reset : in std_logic;

        -- Single-cycle start requests: the power sequence setting off,
        -- software (the SP) asking for a run of its own, and the host asking
        -- over eSPI.
        start_seq : in std_logic;
        start_sw : in std_logic;
        start_host : in std_logic;
        -- The host acknowledging the digest it has read; drops host_done
        done_clear : in std_logic;
        -- The flash is on the FPGA side and staying there, so it may be read
        flash_free : in std_logic;

        -- A run is in flight or waiting to be. Whoever is about to give the
        -- flash away looks at this.
        busy : out std_logic;
        owns_flash : out std_logic;
        -- The host's view of done: a digest is standing that it has not yet
        -- acknowledged. Cleared by done_clear or by the next run starting.
        host_done : out std_logic;
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
        pending : std_logic;
        -- Who asked for the run that is pending, then the one in flight
        pend_sw : std_logic;
        pend_host : std_logic;
        done : std_logic;
        err : std_logic;
        abandoned : std_logic;
        sw_started : std_logic;
        host_started : std_logic;
        host_done : std_logic;
    end record;
    constant reg_reset : reg_t := (
        state => IDLE,
        pending => '0',
        pend_sw => '0',
        pend_host => '0',
        done => '0',
        err => '0',
        abandoned => '0',
        sw_started => '0',
        host_started => '0',
        host_done => '0'
    );
    signal r, rin : reg_t;
    signal start : std_logic;
begin

    start <= start_seq or start_sw or start_host;
    busy <= '1' when r.state /= IDLE or r.pending = '1' or start = '1' else '0';
    -- Once the flash is gone it is the NIC's, whatever the engine is still
    -- doing with a run it was given earlier.
    owns_flash <= '1' when r.state /= IDLE and flash_free = '1' and r.abandoned = '0' else '0';
    hash_req <= '1' when r.state = RUNNING else '0';
    host_done <= r.host_done;

    status.hash_sm <= r.state;
    status.done <= r.done;
    status.err <= r.err;
    status.abandoned <= r.abandoned;
    status.sw_started <= r.sw_started;
    status.pending <= r.pending;
    status.host_started <= r.host_started;

    sm: process(all)
        variable v : reg_t;
    begin
        v := r;

        -- A start is never turned away: it waits for the flash, or for the
        -- run in flight to finish (the host may have rewritten the image
        -- underneath that one). Several starts fold into one run.
        if start = '1' then
            v.pending := '1';
            v.pend_sw := r.pend_sw or start_sw;
            v.pend_host := r.pend_host or start_host;
        end if;

        if done_clear = '1' then
            v.host_done := '0';
        end if;

        case r.state is
            when IDLE =>
                if r.pending = '1' and flash_free = '1' then
                    v.state := RUNNING;
                    v.pending := '0';
                    v.pend_sw := '0';
                    v.pend_host := '0';
                    v.done := '0';
                    v.err := '0';
                    v.abandoned := '0';
                    v.host_done := '0';
                    v.sw_started := r.pend_sw;
                    v.host_started := r.pend_host;
                end if;

            -- The engine has no way to be called off, so a run is seen
            -- through to its acknowledge even when the flash has been taken
            -- away underneath it. Dropping the request early would leave the
            -- next one to collect this one's acknowledge.
            when RUNNING =>
                if flash_free = '0' then
                    v.abandoned := '1';
                end if;
                if hash_ack = '1' then
                    v.done := not hash_err and not v.abandoned;
                    v.err := hash_err or v.abandoned;
                    v.host_done := not hash_err and not v.abandoned;
                    v.state := ACK_RELEASE;
                end if;

            when ACK_RELEASE =>
                if hash_ack = '0' then
                    v.state := IDLE;
                end if;
        end case;

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
