-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sequencer_io_pkg.all;
use work.sequencer_regs_pkg.all;

-- This is the A1/A0 sequencer for the SP5 cosmo sled
-- Note that synchronization of inputs is assumed to have taken place
-- outside this block already and that everything is already synchronous
-- to the clock domain
entity a1_a0_seq is
    generic(
        CNTS_P_MS: integer
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        upstream_ok: in std_logic; -- upstream requirements met, fans, thermal hsc's etc
        downstream_idle: in std_logic; -- downstream rails are off.
        a0_ok: out std_logic;
        a0_idle: out std_logic;
        a0_faulted: out std_logic;
        sw_enable : in std_logic;
        ignore_sp5 : in std_logic;
        raw_state : out seq_raw_status_type;
        api_state : out seq_api_status_type;
        -- DDR Hotswap
        ddr_bulk: view ddr_bulk_power_at_fpga;
        -- group A supplies
        group_a : view group_a_power_at_fpga;
        -- group b supplies
        group_b : view group_b_power_at_fpga;
        -- group c supplies
        group_c : view group_c_power_at_fpga;
        -- SP5 sequencing I/O
        sp5_seq_pins : view sp5_seq_at_fpga;
       
    );
end entity;

architecture rtl of a1_a0_seq is
    constant ONE_MS : integer := 1 * CNTS_P_MS;
    constant TWO_MS : integer := 2 * ONE_MS;
    constant TEN_MS : integer := 20 * ONE_MS;
    constant TWENTY_MS : integer := 20 * ONE_MS;
    constant TWENTY_ONE_MS: integer := 21 * ONE_MS;
    constant ONE_HUNDRED_FOUR_MS: integer := 104 * ONE_MS;

    

     -- This is going into a "RAW" register, 
    -- exposed to hubris. Changes here may impact
    -- debugging tools.  Should we push this to
    -- the rdl? It makes maintenance here more annoying.
    type seq_state_t is (
        IDLE, 
        DDR_BULK_EN, 
        GROUP_A_EN, 
        GROUP_A_PG_AND_WAIT,
        RSM_RST_DEASSERT,
        RTC_CLK_WAIT, -- PBTN low for 20ms
        SLP_CHECKPOINT,
        GROUP_B_EN,
        GROUP_B_PG_AND_WAIT,
        GROUP_C_EN, -- Maybe???
        GROUP_C_PG_AND_WAIT,
        ASSERT_PWRGOOD,
        WAIT_PWROK,
        WAIT_RESET_L_RELEASE,
        DONE,
        SAFE_DISABLE
        );
    type seq_r_t is record
        state : seq_state_t;
        enable_pend: std_logic;
        enable_last: std_logic;
        cnts  : unsigned(31 downto 0);
        ddr_bulk_en: std_logic;
        group_a_en: std_logic;
        group_b_en: std_logic;
        group_c_en: std_logic;
        rsm_rst_l : std_logic;
        pwr_btn_l : std_logic;
        pwr_good : std_logic;
        group_a_expected: std_logic;
        group_b_expected: std_logic;
        group_c_expected: std_logic;
        ddr_bulk_expected: std_logic;
        faulted: std_logic;
    end record;

    constant seq_r_t_reset : seq_r_t := (
        IDLE, 
        '0', 
        '0', 
        (others => '0'), 
        '0', 
        '0', 
        '0',
        '0',
        '0',
        '1',
        '0',
        '0',
        '0',
        '0',
        '0',
        '0'
    );
    signal seq_r, seq_rin : seq_r_t;


begin

    -- for Hubris, we want something along the following:
    -- IDLE, ENABLING_A, SP5_EARLY_CHECKPOINT, ENABLING_B, ENABLING_C, SP5_FINAL_CHECKPOINT, DONE, FAULT
    api_decode:process(clk, reset)
    begin
        if reset then
            api_state.a0_sm <= IDLE;
        elsif rising_edge(clk) then
            case seq_r.state is
                when IDLE =>
                    api_state.a0_sm <= IDLE;
                when DDR_BULK_EN=>
                    api_state.a0_sm <= ENABLE_GRP_A;
                when SLP_CHECKPOINT =>
                    api_state.a0_sm <= SP5_EARLY_CHECKPOINT;
                when GROUP_B_EN =>
                    api_state.a0_sm <= ENABLE_GRP_B;
                when GROUP_C_EN =>
                    api_state.a0_sm <= ENABLE_GRP_C;
                when ASSERT_PWRGOOD =>
                    api_state.a0_sm <= POWER_GOOD;
                when WAIT_PWROK =>
                    api_state.a0_sm <= SP5_FINAL_CHECKPOINT;
                when SAFE_DISABLE =>
                    api_state.a0_sm <= DISABLING;
                when DONE =>
                    api_state.a0_sm <= DONE;
                when others =>
                    null;
            end case;
            if seq_r.faulted = '1' then
                api_state.a0_sm <= FAULTED;
            end if;
        end if;
    end process;

    -- Decode state into a number representing position in the enum type
    raw_state.hw_sm <= std_logic_vector(to_unsigned(seq_state_t'pos(seq_r.state), raw_state.hw_sm'length));
    

    seq_ns_logic: process(all)
        variable v : seq_r_t;
        variable slp_s3_l_final : std_logic;
        variable slp_s5_l_final : std_logic;
        variable pwr_ok_final : std_logic;
        variable reset_l_final : std_logic;
        variable a_faulted : std_logic;
        variable b_faulted : std_logic;
        variable c_faulted : std_logic;
    begin
        v := seq_r;

        -- We provide a hand-shake free mode where we stub out the
        -- required SP5 handshakes for power testing.
        -- these are active low signals that we eventually check for
        -- being high (de-asserted) so we bitwise or in the ignore flag
        -- so these will be high if it is set
        slp_s3_l_final := sp5_seq_pins.slp_s3_l or ignore_sp5;
        slp_s5_l_final := sp5_seq_pins.slp_s5_l or ignore_sp5;
        reset_l_final := sp5_seq_pins.reset_l or ignore_sp5;
        -- active high vs active low but we also will check for active
        -- this this case so the same logic applies, we can or in the 
        -- ignore flag
        pwr_ok_final := sp5_seq_pins.pwr_ok or ignore_sp5;

        -- Edge detection for the enable signal, cleared once we start
        -- the sequence
        v.enable_last := sw_enable;
        if sw_enable and not seq_r.enable_last then
            -- To re-enable, we require software to generate a rising_edge
            -- here, by clearing the enable and then setting it again
            v.enable_pend := '1';
        end if;

        -- Fault monitoring, if we expect a rail to be up and it's not
        -- that's a fault.
        a_faulted := '1' when seq_r.group_a_expected = '1' and (not is_power_good(group_a)) else '0';
        b_faulted := '1' when seq_r.group_b_expected = '1' and (not is_power_good(group_b)) else '0';
        c_faulted := '1' when seq_r.group_c_expected = '1' and (not is_power_good(group_c)) else '0';
        
        -- single cycle flags
        v.faulted := '0';

        case seq_r.state is
            when IDLE =>
                v.pwr_btn_l := '1';
                v.ddr_bulk_en := '0';
                v.group_a_en := '0';
                v.group_b_en := '0';
                v.group_c_en := '0';
                v.rsm_rst_l := '0';
                v.group_a_expected := '0';
                v.group_b_expected := '0';
                v.group_c_expected := '0';
                v.ddr_bulk_expected := '0';
                v.cnts := (others => '0');
                if sw_enable = '0' then
                    -- we'll use this to clear the faulted flag
                    v.faulted := '0';
                end if;
                if seq_r.enable_pend and upstream_ok then
                    v.state := DDR_BULK_EN;
                    v.enable_pend := '0';
                end if;
            -- Enable the DDR bulk supplies
            when DDR_BULK_EN => 
                -- Transitional state. Most motherboards don't provide
                -- 12V Bulk DDR control... but we do! (mostly for power measurement reasons)
                -- rather than an actual need to control it.  We should turn on the hotswap controllers here
                -- This is early, but we'll check the PG's later and might as well get them going
                v.ddr_bulk_en := '1';
                v.state := GROUP_A_EN;
            --  Enable Group A
            when GROUP_A_EN =>
                v.group_a_en := '1';
                v.state := GROUP_A_PG_AND_WAIT;
            --Wait for Group A PGs to stabilize for 10ms (sp5 eds: "t1")
            when GROUP_A_PG_AND_WAIT =>
                v.cnts := (others => '0');
                if is_power_good(group_a) then
                    v.cnts := seq_r.cnts + 1;
                end if;
                if seq_r.cnts = TEN_MS then
                    v.cnts := (others => '0');
                    v.state := RSM_RST_DEASSERT;
                    -- we enable fault monitoring here on the group A rails and DDR, until we de-sequence
                    -- these are expected to remain up.
                    v.group_a_expected := '1';  
                    v.ddr_bulk_expected := '1';
                end if;
            --  Release RSM_RST_L
            when RSM_RST_DEASSERT =>
                v.rsm_rst_l := '1';
                v.cnts := (others => '0');
                v.state := RTC_CLK_WAIT;
            -- Wait for 104 ms (RTC clk startup time, sp5 eds: "t2")
            when RTC_CLK_WAIT =>
                v.cnts := seq_r.cnts + 1;
                -- We can "push" the button in this state, this is handled on the falling edge
                -- we'll give 20ms after rsm_rst release, then hit the button for a ms and release
                if seq_r.cnts = TWENTY_MS then
                    v.pwr_btn_l := '0';
                end if;
                if seq_r.cnts = TWENTY_ONE_MS then
                    v.pwr_btn_l := '1';
                end if;
                if seq_r.cnts = ONE_HUNDRED_FOUR_MS then
                    v.state := SLP_CHECKPOINT;
                    v.cnts := (others => '0');
                end if;
            -- We want to verify the SP5 did the right hand-shakes
            -- we should see the SLP signals de-asserted since we pushed the button
            -- we should, at this time, also have PGs from the DDR 12V hotswap controllers
            -- given we enabled them more than 100ms ago.
            when SLP_CHECKPOINT =>
                if slp_s3_l_final = '1' and 
                   slp_s5_l_final = '1' and
                   is_power_good(ddr_bulk) then
                    v.state := GROUP_B_EN;
                end if;
            -- Enable Group B supplies
            when GROUP_B_EN =>
                v.group_b_en := '1';
                v.state := GROUP_B_PG_AND_WAIT;
                v.cnts := (others => '0');
            -- Wait for Group B supplies stable for at least 1ms minimum
            when GROUP_B_PG_AND_WAIT =>
                v.cnts := (others => '0');
                if is_power_good(group_b) then
                    v.cnts := seq_r.cnts + 1;
                end if;
                if seq_r.cnts = ONE_MS then
                    v.cnts := (others => '0');
                    v.state := GROUP_C_EN;
                    -- we enable fault monitoring here on the group B rails, until we de-sequence
                    -- these are expected to remain up.
                    v.group_b_expected := '1';  
                end if;
            when GROUP_C_EN =>
                v.group_c_en := '1';
                v.state := GROUP_C_PG_AND_WAIT;
            -- Wait for Group C supplies stable for at least 1ms minimum
            -- Note that Hubris probably has to enable some of these via
            -- PMBus so we might sit here for a bit
            -- For power testing, this may be done with PowerNavigator or hubris
            -- so we can't just skip it, these supplies need to turn on
            -- We need at least ms before asserting pwr_good (sp5 eds "t4")
            when GROUP_C_PG_AND_WAIT =>
                v.cnts := (others => '0');
                if is_power_good(group_c) then
                    v.cnts := seq_r.cnts + 1;
                end if;
                if seq_r.cnts = ONE_MS then
                    v.cnts := (others => '0');
                    v.state := ASSERT_PWRGOOD;
                    -- we enable fault monitoring here on the group C rails, until we de-sequence
                    -- these are expected to remain up.
                    v.group_c_expected := '1'; 
                end if;
            -- Drive PWRGOOD to the SP5
            when ASSERT_PWRGOOD =>
                v.pwr_good := '1';
                v.state := WAIT_PWROK;
            -- We expect SP5 to respond back with PWR_OK
            -- within 20.4ms but we'll let software monitor this
            -- and we'll just hang out if it doesn't go.
            -- This is a spot were we 
            when WAIT_PWROK =>
                if pwr_ok_final then
                    v.state := WAIT_RESET_L_RELEASE;
                end if;
            when WAIT_RESET_L_RELEASE =>
                if reset_l_final then
                    v.state := DONE;
                end if;
            when DONE =>
                -- Even in the disable case, we need to wait for any downstream
                -- rails to go down before we can turn off these.
                if sw_enable = '0' and downstream_idle = '1' then
                    -- take away power good, then wait before yanking
                    -- the rails
                    v.pwr_good := '0';
                    v.state := SAFE_DISABLE;
                    v.cnts := (others => '0');
                end if;
            when SAFE_DISABLE =>
                if seq_r.cnts = TWO_MS then
                    -- controlled de-sequence
                    -- we're turning rails off next clock
                    -- disable fault monitoring on all the rails
                    -- we're turning off
                    v.group_a_expected := '0';
                    v.group_b_expected := '0';
                    v.group_c_expected := '0';
                    v.ddr_bulk_expected := '0';
                    v.state := IDLE;
                end if;

        end case;

        -- fault and MAPO case that are monitored in all non-IDLE cases
        if seq_r.state /= IDLE then
            if a_faulted  or b_faulted or c_faulted or (not upstream_ok) then
                v.faulted := '1';
                -- In the fault cases, we immediately transition to IDLE
                -- regardless of the current state, and don't have time to
                -- do the 2ms safe disable sequence.
                v.state := IDLE;
                -- clear these so as not to trip any other faults incidentally
                -- as that would make debugging harder
                v.group_a_expected := '0';
                v.group_b_expected := '0';
                v.group_c_expected := '0';
                v.ddr_bulk_expected := '0';
            end if;
        end if;


        seq_rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset then
            seq_r <= seq_r_t_reset;
            a0_ok <= '0';
            a0_idle <= '1';
        elsif rising_edge(clk) then
            seq_r <= seq_rin;

            -- We expect these to be relatively high fanout
            -- signals and may want to cross into other domains
            -- so we register them here
            a0_ok <= '1' when seq_r.state = DONE else '0';
            a0_idle <= '1' when seq_r.state = IDLE else '0';
             
        end if;
    end process;

    -- Use the internal sm registers to drive the various enable outputs
    -- there's no combo logic here, this is just bonding sm-internal registers
    -- to the enable pins
    ddr_bulk <= control_enables_by(seq_r.ddr_bulk_en);
    group_a <= control_enables_by(seq_r.group_a_en);
    group_b <= control_enables_by(seq_r.group_b_en);
    group_c <= control_enables_by(seq_r.group_c_en);
    a0_faulted <= seq_r.faulted;
end rtl;
