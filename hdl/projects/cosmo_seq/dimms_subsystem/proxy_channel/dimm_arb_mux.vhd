-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- 3 possible things trying to drive the DIMM i2c bus:
-- 1) i2c transactions from the host CPU via slow i2c on a dedicated bus
-- 2) SPD cache fetching fromm the DIMM cache FPGA block
-- 3) i2c transactions from hubris via the FPGA interface
-- Of these, the highest priority is the host CPU, since we don't control that software and it
-- expects "exclusive" access to the bus at arbitrary times.
-- To accomplish this, we'll need a strategy to abort any on-going i2c transactions from hubris, and
-- flip over the mux to the host CPU in enough time. RFD 393 discusses the timing around this, but 
-- as we went through the design and testing, we realized that if hubris has requested a multi-byte
-- read, and the host CPU tries to start a transaction after we have ACK'd a data byte, it is impossible
-- to safely abort at the end of this byte: Multi-byte reads require the master to NACK the final byte so the
-- target node doesn't begin outputting the next data bit so that a STOP condition can be issued from the
-- our controller. For example, if the next byte starts with a 0 bit, and we've ACK'd the previous byte, the
-- target has every right to drive SDA low which will prevent us from properly issuing a STOP.
--
-- This has another problem though, we don't really have time to wait until the end of a multi-byte transaction
-- given the timing analysis in RFD393. So the solution here is to "buffer" the host CPU bits until the hubris
-- transaction is safely aborted. Given the baud-rate disparity here, we actually have ~8 slow (AMD CPU) clocks
-- that we can buffer before we need to hand over the bus for the ack. We can do this with some logic to queue up
-- the transaction, and play them back out at a faster baud rate before handing over control of the bus back to the host CPU.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.i2c_common_pkg.all;
use work.time_pkg.all;
use work.tristate_if_pkg.all;


entity dimm_arb_mux is
    generic (
        CLK_PER_NS  : positive;
        I2C_MODE    : mode_t
    );
    port (
        clk         : in  std_logic;
        reset     : in  std_logic;

        in_a0 : in std_logic;
        -- CPU I2C bus signals
        cpu_scl_in  : in  std_logic;
        cpu_scl_fedge : in std_logic;
        cpu_scl_redge : in std_logic;

        cpu_sda_in  : in  std_logic;
        cpu_sda_fedge : in std_logic;
        cpu_sda_redge : in std_logic;
        
        dimm_sda : in std_logic;
        dimm_scl : in std_logic;

        bus_request : out std_logic;
        bus_grant : in std_logic;
        fpga_i2c_grant : in std_logic;
        fpga_i2c_abort_or_finish : out std_logic;

        playback_sda : view tristate_if;
        playback_scl : view tristate_if;

        fpga_i2c_has_bus : out std_logic;
        sp5_playback_i2c_has_bus : out std_logic;
        forced_idle_delay : out std_logic;
        sp5_i2c_has_bus : out std_logic;
        
    );
end entity;

architecture rtl of dimm_arb_mux is
    constant FAST_SCL_PERIOD : integer :=
        to_integer(calc_ns(get_i2c_settings(I2C_MODE).fscl_period_ns, CLK_PER_NS, 8));

    constant BUS_IDLE_MIN : integer := to_integer(calc_ns(get_i2c_settings(I2C_MODE).sto_sta_buf_ns, CLK_PER_NS, 8));

    type mux_state_t is (
        IDLE,
        POWER_UP_CLEAR,
        FPGA_HAS_GRANT,
        CPU_REQ_GRANT,
        PLAY_STORED_START,
        PLAY_STORED_DATA,
        ENSURE_PLAYBACK_HOLD,
        CPU_HAS_BUS,
        BUS_IDLE_DELAY
    );

    type sample_state_t is (
        SAMPLE_IDLE,
        SAMPLE_START,
        SAMPLE_DATA,
        SAMPLE_ERROR
    );

    type mux_reg_t is record
        state       : mux_state_t;
        playback_bits : integer range 0 to 11;
        hold_timer   : integer range 0 to 511;
        initialized : std_logic;
        fpga_abort_or_finish : std_logic;
        cpu_req_bus : std_logic;
        playback_done : std_logic;
        dimm_sda_oe     : std_logic;
        dimm_scl_oe     : std_logic;
    end record;
    constant MUX_REG_RESET : mux_reg_t := (
        state          => IDLE,
        playback_bits  => 0,
        hold_timer     => 0,
        initialized    => '0',
        fpga_abort_or_finish => '0',
        cpu_req_bus    => '0',
        playback_done  => '0',
        dimm_sda_oe       => '0',
        dimm_scl_oe       => '0'
    );
    signal mux_r, mux_rin : mux_reg_t;

    type sample_reg_t is record
        state       : sample_state_t;
        data_bits   : unsigned(6 downto 0);
        bit_count   : integer range 0 to 7;
        allowed_to_handoff : std_logic;
    end record;
    constant SAMPLE_REG_RESET : sample_reg_t := (
        state          => SAMPLE_IDLE,
        data_bits       => (others => '0'),
        bit_count       => 0,
        allowed_to_handoff => '0'
    );
    signal sample_r, sample_rin : sample_reg_t;
    signal dimm_i2c_idle : std_logic;

    type playback_reg_t
        is record
        scl_cnts    : integer range 0 to FAST_SCL_PERIOD;
        scl_out     : std_logic;
        scl_out_last : std_logic;
    end record;
    constant PLAYBACK_REG_RESET : playback_reg_t := (
        scl_cnts   => 0,
        scl_out    => '1',
        scl_out_last => '1'
    );
    signal playback_r, playback_rin : playback_reg_t;
    signal playback_scl_redge : std_logic;
    signal playback_scl_fedge : std_logic;
    signal dimm_i2c_idle_cnts : integer range 0 to BUS_IDLE_MIN := 0;

begin

    fpga_i2c_has_bus <= '1' when fpga_i2c_grant else '0';
    sp5_playback_i2c_has_bus <= '1' when mux_r.state = PLAY_STORED_START or 
                                         mux_r.state = PLAY_STORED_DATA  or  
                                         mux_r.state = POWER_UP_CLEAR or 
                                         mux_r.state = ENSURE_PLAYBACK_HOLD else '0';
    sp5_i2c_has_bus <= '1' when mux_r.state = CPU_HAS_BUS else '0';
    forced_idle_delay <= '1' when  mux_r.state = BUS_IDLE_DELAY else '0';
    fpga_i2c_abort_or_finish <= mux_r.fpga_abort_or_finish;

    -- need to enforce minimum idle time on the bus before we can
    -- safely start a new transaction
    bus_idle_monitor: process(clk, reset)
    begin
        if reset = '1' then
            dimm_i2c_idle <= '0';
            dimm_i2c_idle_cnts <= 0;
        elsif rising_edge(clk) then
            if dimm_scl = '0' or dimm_sda = '0' then
                dimm_i2c_idle <= '0';
                dimm_i2c_idle_cnts <= 0;
            elsif dimm_i2c_idle_cnts = BUS_IDLE_MIN then
                dimm_i2c_idle <= '1';
            else
                dimm_i2c_idle_cnts <= dimm_i2c_idle_cnts + 1;
            end if;
        end if;
    end process;
    

    -- cpu i2c sample process
    -- this block monitors the CPU's i2c bus for start conditions, clock edges etc and queues up
    -- to 7 data bits for playback later in a static buffer. This machine does not do any playback.
    cpu_i2c_sample_proc: process(all)
        variable v : sample_reg_t;
        variable cpu_start_detected : std_logic;
        variable cpu_stop_detected : std_logic;
    begin
        v := sample_r;
        cpu_start_detected := cpu_scl_in and cpu_sda_fedge;
        cpu_stop_detected := cpu_scl_in and cpu_sda_redge;

        case sample_r.state is 
            when SAMPLE_IDLE =>
                if cpu_start_detected = '1' then
                    v.state := SAMPLE_START;
                    v.bit_count := 0;
                    v.data_bits := (others => '0');
                end if;

            when SAMPLE_START =>
                -- waiting for first clock edge during the start phase
                -- past this point, we *must* synthesize a start and any other bits.
                if cpu_scl_fedge = '1' then
                    v.state := SAMPLE_DATA;
                elsif mux_r.playback_done = '1' or cpu_stop_detected = '1' then
                    -- no data bits, go back to idle
                    v.state := SAMPLE_IDLE;
                end if;

            when SAMPLE_DATA =>
                if cpu_scl_redge = '1' then
                    -- sample data bit, we don't want to shift these
                    -- as we could move the data on the other block.
                    v.data_bits(v.bit_count) := cpu_sda_in;
                    v.bit_count := v.bit_count + 1;
                    if mux_r.playback_done = '1' or cpu_stop_detected = '1' then
                        -- all bits sampled, go back to idle
                        -- we should *always* get to playback done before we hit 7 bits.
                       v.state := SAMPLE_IDLE;
                    elsif v.bit_count = 7 then
                        -- all bits sampled, go back to idle
                        -- we should *always* get to playback done before we hit 7 bits.
                       v.state := SAMPLE_ERROR;
                    end if;
                end if;
            when SAMPLE_ERROR =>
                -- Unexpected state, go back to idle
                v.state := SAMPLE_IDLE;
        end case;

        sample_rin <= v;
        
    end process;

    bus_request <= mux_r.cpu_req_bus;

    -- cpu arbitration and playback process
    -- if a CPU initiates a transaction, we need to:
    --  1) abort any ongoing i2c transaction
    --  2) acquire the bus (via arbiter) and play back the start and any sampled data bits at
    --     our "fast" speed
    --  3) hand over control of the bus to the CPU lines to finish the transaction
    arb_and_playback: process(all)
        variable v : mux_reg_t;
        variable cpu_start_detected : std_logic;
        variable cpu_stop_detected : std_logic;
    begin
        v := mux_r;
        v.fpga_abort_or_finish := '0';
        cpu_start_detected := cpu_scl_in and cpu_sda_fedge;
        cpu_stop_detected := cpu_scl_in and cpu_sda_redge;
        case mux_r.state is 
            when IDLE =>
                v.dimm_sda_oe := '0';
                -- belts and suspenders: when we come up, clear any pending i2c transaction
                -- since we don't know what state the bus is in.
                if in_a0 and not mux_r.initialized then
                    v.state := POWER_UP_CLEAR;
                    v.playback_bits := 0;
                elsif not in_a0 then
                    v.initialized := '0';
                end if;

                if cpu_start_detected and mux_r.initialized then
                    v.state := CPU_REQ_GRANT;
                    v.cpu_req_bus := '1';
                elsif fpga_i2c_grant and mux_r.initialized then
                    v.state := FPGA_HAS_GRANT;
                end if;
            when POWER_UP_CLEAR =>
                -- wait for at least 9 scl cycles then set initialized and go back to idle
                if mux_r.playback_bits = 9 then
                    v.state := IDLE;
                    v.initialized := '1';
                    v.playback_bits := 0;
                elsif playback_scl_redge = '1' then 
                   v.playback_bits := mux_r.playback_bits + 1;
                end if;
            when FPGA_HAS_GRANT =>
                if  cpu_start_detected = '1' then
                    v.state := CPU_REQ_GRANT;
                    v.cpu_req_bus := '1';
                    v.fpga_abort_or_finish := '1';
                elsif fpga_i2c_grant = '0' then
                    v.state := IDLE;
                end if;

            when CPU_REQ_GRANT =>
                -- waiting for arbiter to grant us the bus
                -- We may sit here for a bit b/c if the FPGA was running an i2c transaction, we need to
                -- wait until it has aborted and the bus goes idle again.
                -- The sampler is sampling bits in parallel so we wait here until we have the bus
                -- We're going to generate a start condition and play back any stored bits, so we
                -- also need the sda and scl lines for the DIMM to be high at this point.
                if bus_grant = '1' and dimm_i2c_idle = '1' then
                    v.state := PLAY_STORED_START;
                end if;

            when PLAY_STORED_START =>
                -- play back the stored start condition
                -- if the CPU is still in the start condition but SCL is still high
                -- just hand over the bus immediately. We'll have generated start already here.
                v.dimm_sda_oe := '1';  --generate a start by pulling sda low
                if sample_r.state = SAMPLE_START and cpu_scl_in = '1' then
                    v.state := CPU_HAS_BUS;
                    v.playback_done := '1';
                elsif playback_scl_fedge = '1'  then
                    if sample_r.state = SAMPLE_DATA and sample_r.bit_count > 0 then
                        v.state := PLAY_STORED_DATA;
                        v.playback_bits := 0;
                        v.dimm_sda_oe := not sample_r.data_bits(v.playback_bits);
                    else
                        -- no data bits to play back, hand over to CPU
                        -- and scl for start was low
                        v.state := ENSURE_PLAYBACK_HOLD;
                        v.hold_timer := 0;
                        v.playback_done := '1';
                        -- prevent small glitches or arbitration oddities. Since we've caught up
                        -- and are at a scl fedge, match the CPU's sda line for a smooth transition
                        v.dimm_sda_oe := not cpu_sda_in;
                    end if;
                end if;   
            when PLAY_STORED_DATA =>
                -- play back the stored data bits
                -- We're going to play back one bit per synthesized scl rising edge until we catch
                -- up with the sampled bits. We'll to CPU_HAS_BUS only if we've caught up
                -- and CPU's SCL is low so that the SDA handoff is clean.
                
                if playback_scl_redge = '1' then
                    v.playback_bits := mux_r.playback_bits + 1;
                    if v.playback_bits = sample_r.bit_count and cpu_scl_in = '1' then
                            v.state := ENSURE_PLAYBACK_HOLD;
                            v.playback_done := '1';
                            v.playback_bits := 0;
                            v.hold_timer := 0;
                            -- prevent small glitches or arbitration oddities. Since we've caught up
                        -- and are at a scl fedge, match the CPU's sda line for a smooth transition
                            v.dimm_sda_oe := not cpu_sda_in;
                    end if;
                elsif playback_scl_fedge = '1' and mux_r.playback_bits < sample_r.bit_count then
                    -- oe = 1 is output = 0 so there's an inversion here.
                    v.dimm_sda_oe := not sample_r.data_bits(mux_r.playback_bits);
                elsif  playback_scl_fedge = '1' and mux_r.playback_bits = sample_r.bit_count and cpu_scl_in = '0' then
                    -- we've played all the bits we have, just float sda until we can hand off
                    v.state := ENSURE_PLAYBACK_HOLD;
                    v.playback_done := '1';
                    v.playback_bits := 0;
                    v.hold_timer := 0;
                    -- prevent small glitches or arbitration oddities. Since we've caught up
                    -- and are at a scl fedge, match the CPU's sda line for a smooth transition
                    v.dimm_sda_oe := not cpu_sda_in;
                end if;
            when ENSURE_PLAYBACK_HOLD =>
                if mux_r.hold_timer < (FAST_SCL_PERIOD / 2) then
                    v.hold_timer := mux_r.hold_timer + 1;
                else
                    v.hold_timer := 0;
                    v.state := CPU_HAS_BUS;
                end if;

            when CPU_HAS_BUS =>
                -- hand over control of the bus to the CPU
                v.dimm_sda_oe := '0';
                if cpu_stop_detected = '1' then
                    v.playback_done := '0';
                    v.state := BUS_IDLE_DELAY;
                    
                end if;

            when BUS_IDLE_DELAY =>
                if dimm_i2c_idle then
                    v.state := IDLE;
                    v.cpu_req_bus := '0';
                end if;
            when others =>
                v.state := IDLE;
                v.cpu_req_bus := '0';

        end case;
        mux_rin <= v;
    end process;

    -- when we do playback, we need to generate scl edges faster than the CPU i2c clock
    -- to allow us to catch up with the sampled bits before handing over the bus.
    playback_scl_generator:process(all)
    variable v: playback_reg_t;
    begin
        v := playback_r;
        -- generate scl. we're going to start high, count for 1/2 period counts
        -- go low and continue until we  transition out of the appropriate states
        if mux_r.state = PLAY_STORED_START or mux_r.state = PLAY_STORED_DATA or mux_r.state = POWER_UP_CLEAR then
           if v.scl_cnts = (FAST_SCL_PERIOD / 2) then
               v.scl_cnts := 0;
               v.scl_out := not playback_r.scl_out;
           else
              v.scl_cnts := playback_r.scl_cnts + 1;
           end if;

        -- we need to make sure we have given appropriate hold-time on scl while transitioning
        -- out of the playback states. We could end up in a scenario where we are transitioning
        -- out of playback *right* on or near an CPU scl edge which can cause runt pulses and make
        -- things unhappy as we'll have possibly missed a bit due to i2c glitch filtering.   
        elsif mux_r.state /= ENSURE_PLAYBACK_HOLD then
           v.scl_cnts := 0;
           v.scl_out := '1';
        end if;
        v.scl_out_last := playback_r.scl_out;

        playback_rin <= v;

    end process;

    playback_scl_redge <= '1' when playback_r.scl_out = '1' and playback_r.scl_out_last = '0' else '0';
    playback_scl_fedge <= '1' when playback_r.scl_out = '0' and playback_r.scl_out_last = '1' else '0';

    playback_sda.o <= '0';
    playback_sda.oe <= mux_r.dimm_sda_oe;
    -- Things we want to know about the current CPU i2c transaction
    playback_scl.o <= playback_r.scl_out;
    playback_scl.oe <= '1' when mux_r.state = PLAY_STORED_START or mux_r.state = PLAY_STORED_DATA or mux_r.state = POWER_UP_CLEAR  or mux_r.state = ENSURE_PLAYBACK_HOLD else '0';
    

    
    -- Let's build a state machine to help make arbitration clearer, since we're building a buffering mechanism here anyway,
    -- we're going to 

    reg_proc: process(clk, reset)
    begin
        if reset = '1' then
            sample_r <= SAMPLE_REG_RESET;
            mux_r <= MUX_REG_RESET;
            playback_r <= PLAYBACK_REG_RESET;
        elsif rising_edge(clk) then
            sample_r <= sample_rin;
            mux_r <= mux_rin;
            playback_r <= playback_rin;
        end if;
    end process reg_proc;

end rtl;    
