-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Unit-level testbench for dimm_arb_mux.
--
-- https://github.com/oxidecomputer/quartz/issues/496 cannot be triggered at the integration 
-- level: the FPGA abort always finishes
-- before the CPU's first SCL falling edge (~2-3 us vs the 5 us STANDARD half-period),
-- so PLAY_STORED_START is entered while sample_r.state=SAMPLE_START and 
-- https://github.com/oxidecomputer/quartz/issues/498 fires
-- instead.  Direct stimulus control lets us reach PLAY_STORED_DATA with bit_count=1
-- while keeping cpu_scl_in='1' through the catch-up rising edge.

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
    context vunit_lib.vunit_context;

use work.i2c_common_pkg.all;
use work.tristate_if_pkg.all;

entity dimm_arb_mux_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of dimm_arb_mux_tb is
    constant CLK_PER_NS : positive := 8;
    constant I2C_MODE   : mode_t   := FAST_PLUS;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal cpu_scl_in    : std_logic := '1';
    signal cpu_scl_fedge : std_logic := '0';
    signal cpu_scl_redge : std_logic := '0';
    signal cpu_sda_in    : std_logic := '1';
    signal cpu_sda_fedge : std_logic := '0';
    signal cpu_sda_redge : std_logic := '0';

    -- dimm_scl/sda are the inputs the bus_idle_monitor watches.
    -- Keep them both high so dimm_i2c_idle asserts quickly.
    signal dimm_sda : std_logic := '1';
    signal dimm_scl : std_logic := '1';

    signal bus_request              : std_logic;
    signal bus_grant                : std_logic := '0';
    signal fpga_i2c_grant           : std_logic := '0';
    signal fpga_i2c_abort_or_finish : std_logic;

    signal playback_sda_if : tristate;
    signal playback_scl_if : tristate;

    signal fpga_i2c_has_bus         : std_logic;
    signal sp5_playback_i2c_has_bus : std_logic;
    signal sp5_i2c_has_bus          : std_logic;
begin

    clk <= not clk after 4 ns;

    -- Provide idle bus feedback to the DUT (not functionally used by dimm_arb_mux
    -- for these ports, but must be driven to avoid 'U' in the model).
    playback_sda_if.i <= '1';
    playback_scl_if.i <= '1';

    DUT: entity work.dimm_arb_mux
        generic map (
            CLK_PER_NS => CLK_PER_NS,
            I2C_MODE   => I2C_MODE
        )
        port map (
            clk                      => clk,
            reset                    => reset,
            in_a0                    => '1',
            cpu_scl_in               => cpu_scl_in,
            cpu_scl_fedge            => cpu_scl_fedge,
            cpu_scl_redge            => cpu_scl_redge,
            cpu_sda_in               => cpu_sda_in,
            cpu_sda_fedge            => cpu_sda_fedge,
            cpu_sda_redge            => cpu_sda_redge,
            dimm_sda                 => dimm_sda,
            dimm_scl                 => dimm_scl,
            bus_request              => bus_request,
            bus_grant                => bus_grant,
            fpga_i2c_grant           => fpga_i2c_grant,
            fpga_i2c_abort_or_finish => fpga_i2c_abort_or_finish,
            playback_sda             => playback_sda_if,
            playback_scl             => playback_scl_if,
            fpga_i2c_has_bus         => fpga_i2c_has_bus,
            sp5_playback_i2c_has_bus => sp5_playback_i2c_has_bus,
            sp5_i2c_has_bus          => sp5_i2c_has_bus
        );

    -- Once the intentional start condition has been generated (the first SDA change
    -- while the playback SCL is high), no further SDA transition is legal while SCL
    -- is still high.  Any such change is a spurious start or stop on the DIMM bus.
    sda_glitch_monitor: process
        variable start_seen : boolean := false;
    begin
        loop
            wait on playback_sda_if.oe;
            if sp5_playback_i2c_has_bus = '1' and playback_scl_if.o = '1' then
                if not start_seen then
                    start_seen := true;
                else
                    check_false(true,
                        "Bug 1: SDA changed while playback SCL was high -- " &
                        "spurious start/stop condition on DIMM bus");
                end if;
            end if;
        end loop;
        wait;
    end process;

    bench: process
        procedure clk_tick is begin wait until rising_edge(clk); end procedure;
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
            if run("arb_bug_sda_glitch_during_playback") then
                -- Issue https://github.com/oxidecomputer/quartz/issues/469
                -- Release reset, wait for POWER_UP_CLEAR (~9 x 1000 ns at FAST_PLUS)
                -- and for dimm_i2c_idle to assert (~504 ns with both dimm lines held high).
                reset <= '1';
                clk_tick;
                reset <= '0';
                wait for 10 us;

                -- Step 1: CPU start condition: SDA falls while SCL is high.
                -- cpu_start_detected fires -> mux: IDLE -> CPU_REQ_GRANT.
                -- sample: SAMPLE_IDLE -> SAMPLE_START.
                cpu_scl_in    <= '1';
                cpu_sda_in    <= '0';
                cpu_sda_fedge <= '1';
                clk_tick;
                cpu_sda_fedge <= '0';
                clk_tick;

                -- Step 2: CPU SCL falling edge.
                -- sample: SAMPLE_START -> SAMPLE_DATA (bit_count still 0).
                cpu_scl_in    <= '0';
                cpu_scl_fedge <= '1';
                clk_tick;
                cpu_scl_fedge <= '0';
                clk_tick;

                -- Step 3: CPU SCL rising edge; sample first bit (sda_in='0').
                -- sample: bit_count becomes 1, data_bits(0)='0'.
                cpu_scl_in    <= '1';
                cpu_scl_redge <= '1';
                clk_tick;
                cpu_scl_redge <= '0';
                clk_tick;

                -- Step 4: Grant the bus.
                -- sample_r.state=SAMPLE_DATA (not SAMPLE_START) -> 
                -- Issue https://github.com/oxidecomputer/quartz/issues/498 cannot fire
                -- even though cpu_scl_in='1'.
                -- mux: CPU_REQ_GRANT -> PLAY_STORED_START (dimm_i2c_idle='1' already).
                bus_grant <= '1';
                wait until sp5_playback_i2c_has_bus = '1';

                -- Step 5: Hold cpu_scl_in='1' and set cpu_sda_in='1' so the catch-up
                -- rising edge produces a visible SDA change.
                --
                -- data_bits(0)='0'  playback currently drives SDA low (oe='1').
                -- Bug 1 will set oe := not(cpu_sda_in) = not('1') = '0' on the catch-up
                -- rising edge, releasing SDA while the playback SCL is still high.
                --
                -- Timeline from PLAY_STORED_START entry (playback SCL starts at '1'):
                --   T + ~500 ns : first playback FEDGE -> enter PLAY_STORED_DATA,
                --                 dimm_sda_oe set to not(data_bits(0))='1' (no change)
                --   T + ~1000 ns: first playback REDGE, playback_bits=1=bit_count,
                --                 cpu_scl_in='1' -> Bug 1 exits to ENSURE_PLAYBACK_HOLD,
                --                 schedules dimm_sda_oe='0' for next cycle
                --   T + ~1008 ns: playback_sda_if.oe '1'->'0' while playback_scl_if.o='1'
                --                 -> sda_glitch_monitor fires check_false -> test fails
                cpu_sda_in <= '1';
                wait for 2 us;

                bus_grant <= '0';
                wait for 500 ns;

            elsif run("arb_bug_playback_stall") then
                -- Direct stimulus reproduction of https://github.com/oxidecomputer/quartz/issues/497.
                --
                -- Bug: in PLAY_STORED_DATA, when playback_bits catches up to bit_count
                -- at a falling playback SCL edge while cpu_scl_in='1', the exit condition
                -- `playback_scl_fedge='1' and playback_bits=bit_count and cpu_scl_in='0'`
                -- is FALSE because cpu_scl_in is '1'.  The following REDGE overshoots to
                -- playback_bits=2 > bit_count=1, and no subsequent condition ever matches,
                -- so the machine spins in PLAY_STORED_DATA forever.
                --
                -- The setup is identical to the Bug GH # 496 test (SAMPLE_DATA, bit_count=1) but
                -- the check monitors sp5_i2c_has_bus rather than SDA.  With GH # 497 fixed the
                -- mux exits to ENSURE_PLAYBACK_HOLD -> CPU_HAS_BUS within ~2 us.
                reset <= '1';
                clk_tick;
                reset <= '0';
                wait for 10 us;

                -- CPU start condition: SAMPLE_IDLE -> SAMPLE_START, mux: IDLE -> CPU_REQ_GRANT.
                cpu_scl_in    <= '1';
                cpu_sda_in    <= '0';
                cpu_sda_fedge <= '1';
                clk_tick;
                cpu_sda_fedge <= '0';
                clk_tick;

                -- CPU SCL falling edge: SAMPLE_START -> SAMPLE_DATA (bit_count=0).
                cpu_scl_in    <= '0';
                cpu_scl_fedge <= '1';
                clk_tick;
                cpu_scl_fedge <= '0';
                clk_tick;

                -- CPU SCL rising edge: sample first bit ('0'), bit_count becomes 1.
                cpu_scl_in    <= '1';
                cpu_scl_redge <= '1';
                clk_tick;
                cpu_scl_redge <= '0';
                clk_tick;

                -- Lower cpu_scl_in='0' so Bug 1's REDGE exit (which requires cpu_scl_in='1')
                -- cannot fire at the catch-up REDGE and mask Bug 2's stall.
                cpu_scl_in <= '0';
                clk_tick;

                -- Grant bus with sample_r.state=SAMPLE_DATA (not SAMPLE_START) so Bug GH # 498
                -- cannot fire.  Mux enters PLAY_STORED_START -> PLAY_STORED_DATA.
                bus_grant <= '1';
                wait until sp5_playback_i2c_has_bus = '1';

                -- Timeline from PLAY_STORED_START entry (playback SCL starts at '1'):
                --   T + ~504 ns : FEDGE 1 -> PLAY_STORED_DATA, playback_bits=0
                --   T + ~1008 ns: REDGE 1 -> playback_bits=1; cpu_scl_in='0' blocks Bug 1
                --   T + ~1512 ns: FEDGE 2 (catch-up FEDGE for bit_count=1)
                -- Wait past REDGE 1 but before FEDGE 2, then raise cpu_scl_in='1' so the
                -- this bug's exit condition (cpu_scl_in='0') is blocked at FEDGE 2.  With Bug 2
                -- the mux then stalls in PLAY_STORED_DATA forever.
                wait for 1100 ns;
                cpu_scl_in <= '1';

                -- Hold cpu_scl_in='1' past FEDGE 2 (~1512 ns) so we exercise the
                -- PLAY_STORED_DATA FEDGE-exit-without-cpu_scl_in path, then drop
                -- cpu_scl_in='0' so the ENSURE_PLAYBACK_HOLD handoff (gated on
                -- cpu_scl_in='0' after the hold timer) can fire.
                wait for 1 us;
                cpu_scl_in    <= '0';
                cpu_scl_fedge <= '1';
                clk_tick;
                cpu_scl_fedge <= '0';

                -- With this bug fixed, the FEDGE exit fires regardless of cpu_scl_in
                -- when playback_bits=bit_count=1; once cpu_scl_in drops low the
                -- ENSURE_PLAYBACK_HOLD handoff completes and sp5_i2c_has_bus asserts.
                wait until sp5_i2c_has_bus = '1' for 50 us;
                check_true(sp5_i2c_has_bus = '1',
                    "Bug GH # 497: mux stalled in PLAY_STORED_DATA -- never reached CPU_HAS_BUS");

                bus_grant <= '0';
                wait for 500 ns;

            elsif run("arb_bug_sample_error_stale_bitcount") then
                -- Direct stimulus reproduction of https://github.com/oxidecomputer/quartz/issues/499.
                --
                -- SAMPLE_ERROR is entered when bit_count reaches 7 (the bit_count subtype
                -- saturates).  The buggy SAMPLE_ERROR -> SAMPLE_IDLE transition does not
                -- reset bit_count, so the next sample_r.bit_count read returns the stale
                -- value 7.  The fix sets v.bit_count := 0 in SAMPLE_ERROR.
                --
                -- This is a white-box check: we drive seven CPU SCL rising edges to push
                -- the sampler through SAMPLE_DATA -> SAMPLE_ERROR -> SAMPLE_IDLE, then read
                -- the internal bit_count via an external name.  bus_grant stays low so
                -- the mux remains in CPU_REQ_GRANT (playback_done='0') and does not
                -- short-circuit the sampler via mux_r.playback_done.
                reset <= '1';
                clk_tick;
                reset <= '0';
                wait for 10 us;

                -- CPU start: SAMPLE_IDLE -> SAMPLE_START (resets bit_count to 0).
                cpu_scl_in    <= '1';
                cpu_sda_in    <= '0';
                cpu_sda_fedge <= '1';
                clk_tick;
                cpu_sda_fedge <= '0';
                clk_tick;

                -- First SCL falling edge: SAMPLE_START -> SAMPLE_DATA.
                cpu_scl_in    <= '0';
                cpu_scl_fedge <= '1';
                clk_tick;
                cpu_scl_fedge <= '0';
                clk_tick;

                -- Seven SCL rising/falling edges; the 7th REDGE drives bit_count to 7
                -- and v.state to SAMPLE_ERROR.  Next cycle SAMPLE_IDLE.
                for i in 0 to 6 loop
                    cpu_scl_in    <= '1';
                    cpu_scl_redge <= '1';
                    clk_tick;
                    cpu_scl_redge <= '0';
                    clk_tick;
                    if i < 6 then
                        cpu_scl_in    <= '0';
                        cpu_scl_fedge <= '1';
                        clk_tick;
                        cpu_scl_fedge <= '0';
                        clk_tick;
                    end if;
                end loop;

                -- Allow SAMPLE_ERROR -> SAMPLE_IDLE to settle.
                for i in 0 to 3 loop
                    clk_tick;
                end loop;

                check_equal(
                    << signal .dimm_arb_mux_tb.DUT.dbg_sample_bit_count : integer >>,
                    0,
                    "Bug GH # 499: sample_r.bit_count not reset after SAMPLE_ERROR -> SAMPLE_IDLE");

                wait for 500 ns;
            end if;
        end loop;

        wait for 500 ns;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

end tb;
