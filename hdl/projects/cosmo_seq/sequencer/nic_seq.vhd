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

-- A0HP sequencing for the T6 NIC used on the SP5 cosmo sled
entity nic_seq is
    generic(
        CNTS_P_MS: integer
    );
    port(
        clk : in std_logic;
        reset : in std_logic;

        sw_enable : in std_logic;
        upstream_ok : in std_logic;
        nic_idle : out std_logic;
        nic_faulted : out std_logic;
        debug_enables : in debug_enables_type;
        nic_overrides_reg : in nic_overrides_type;

        raw_state : out nic_raw_status_type;
        api_state : out nic_api_status_type;

        nic_dbg_pins : view t6_debug_seq_ss;

        -- From SP5 hotplug
        sp5_t6_perst_l : in std_logic;  -- follows exactly the power_en hotplug signal. perst_l <= power_en;

        nic_rails: view nic_power_at_fpga;
        nic_seq_pins: view nic_seq_at_fpga;



    );
end entity;

architecture rtl of nic_seq is
    constant NIC_PERST_CLD_RST_RACE_DELAY : integer := 2;
    constant ONE_MS : integer := 1 * CNTS_P_MS;
    constant TEN_MS : integer := 10 * ONE_MS;
    constant TWENTY_MS : integer := 20 * ONE_MS;
    constant THIRTY_MS : integer := 30 * ONE_MS;

    type reset_state_t is (IN_RESET, CLD_RST_DEASSERTED, PERST_DEASSERTED);
    type rst_r_t is record
        state : reset_state_t;
        cnts  : unsigned(31 downto 0);
        nic_perst_l : std_logic;
        nic_cld_rst_l : std_logic;
    end record;

    constant rst_r_reset : rst_r_t := (
        state => IN_RESET,
        cnts => (others => '0'),
        nic_perst_l => '0',
        nic_cld_rst_l => '0'
    );

    type nic_r_t is record
        state : nic_raw_status_hw_sm;
        enable_last : std_logic;
        enable_pend : std_logic;
        cnts  : unsigned(31 downto 0);
        nic_perst_l_last : std_logic;
        nic_power_en : std_logic;
        nic_perst_l : std_logic;
        nic_cld_rst_l : std_logic;
        nic_clk_en_l : std_logic;
        nic_expected : std_logic;
        faulted : std_logic;
    end record;

    constant nic_r_reset : nic_r_t := (
        state => IDLE,
        enable_last => '0',
        enable_pend => '0',
        cnts => (others => '0'),
        nic_perst_l_last => '0',
        nic_power_en => '0',
        nic_perst_l => '0',
        nic_cld_rst_l => '0',
        nic_clk_en_l => '1',
        nic_expected => '0',
        faulted => '0'
    );
    signal nic_r, nic_rin : nic_r_t;

    signal rst_nic_r, rst_nic_rin : rst_r_t;

    signal final_nic_outs : nic_overrides_type;

begin

    raw_state.hw_sm <= nic_r.state;
    
    nic_idle <= '1' when nic_r.state = IDLE else '0';

    nic_dbg_pins.cld_rst_l <= final_nic_outs.cld_rst_l;
    nic_dbg_pins.ext_rst_l <= nic_seq_pins.ext_rst_l;
    nic_dbg_pins.rails_en <= nic_r.nic_power_en;
    nic_dbg_pins.rails_pg <= '1' when is_power_good(nic_rails) else '0';
    nic_dbg_pins.nic_mfg_mode_l <= final_nic_outs.nic_mfg_mode_l;
    nic_dbg_pins.sp5_mfg_mode_l <= nic_seq_pins.sp5_mfg_mode_l;
    nic_dbg_pins.perst_l <= final_nic_outs.perst_l;

    -- Gimlet has the following sequence that was empirically determined to work
    -- We had to double-perst and we know that cld_rst_l needs to be de-asserted 10ms before perst_l
    -- is de-asserted due to T6 internal specifics.
    
    api_state_proc:process(clk, reset)
    begin
        if reset then
            api_state.nic_sm <= IDLE;

        elsif rising_edge(clk) then
            case nic_r.state is
                when IDLE =>
                    api_state.nic_sm <= IDLE;

                when PWR_EN =>
                    api_state.nic_sm <= ENABLE_POWER;

                when WAIT_FOR_PGS =>
                    api_state.nic_sm <= ENABLE_POWER;

                when EARLY_CLD_RST =>
                    api_state.nic_sm <= NIC_RESET;

                when EARLY_PERST | EARLY_PERST_ASSERT =>
                    api_state.nic_sm <= NIC_RESET;

                when DONE =>
                    -- PRE-reset is done but we want to expose the final reset state to
                    -- the API so that it can see that the NIC is up and running after the
                    -- SP5 hotplug stuff happens and it is enabled vs immediately after power on
                    -- while still in reset.
                    if rst_nic_r.state = PERST_DEASSERTED then
                        api_state.nic_sm <= DONE;
                    else
                        api_state.nic_sm <= NIC_RESET;
                    end if;

            end case;
        end if;

    end process;

    nic_sm:process(all)
        variable v : nic_r_t;
        variable nic_faulted_var : std_logic;
    begin

        v := nic_r;
        v.nic_perst_l_last := sp5_t6_perst_l;
         

        -- Fault monitoring: if we expect NIC rails to be up and they're not, that's a fault
        nic_faulted_var := '1' when nic_r.nic_expected = '1' and (not is_power_good(nic_rails)) else '0';
         v.enable_last := sw_enable;
        if (sw_enable and not nic_r.enable_last) = '1' or (nic_r.faulted = '1' and nic_r.nic_perst_l_last = '0' and sp5_t6_perst_l = '1') then
            -- To re-enable, there are 2 possible cases:
            -- Normally, we require sw to clear and enable the register for normal power up cases.
            -- In a MAPO situation though, the SP5 has "power control".  sp5_t6_perst_l just followes the slot power
            -- enable here, so if we have MAPO'd (faulted = '1') and we see a perst de-assert from the SP5, we'll attempt to sequence again.
            v.enable_pend := '1';
            -- we'll use this to clear the faulted flags
            v.faulted := '0';
        end if;
        case nic_r.state is
            when IDLE =>
                v.nic_power_en := '0';
                v.nic_perst_l := '0';
                v.nic_cld_rst_l := '0';
                v.nic_clk_en_l := '1';
                v.nic_expected := '0';
                v.cnts := (others => '0');
                if nic_r.enable_pend and upstream_ok then
                    v.state := PWR_EN;
                    v.enable_pend := '0';
                end if;

            when PWR_EN =>
                v.nic_power_en := '1';
                v.nic_clk_en_l := '0';  -- clock enable
                v.state := WAIT_FOR_PGS;

            when WAIT_FOR_PGS =>
                v.cnts := (others => '0');
                if is_power_good(nic_rails) then
                    v.cnts := nic_r.cnts + 1;
                end if;
                -- Hang here for 30ms to meet the minimum and then another
                -- 20ms before cld_rst_l release
                if nic_r.cnts = THIRTY_MS + TWENTY_MS then
                    v.state := EARLY_CLD_RST;
                    v.cnts := (others => '0');
                    -- Enable fault monitoring on NIC rails - they should remain up
                    v.nic_expected := '1';
                end if;

            when EARLY_CLD_RST =>
                -- We release reset "early" 
                v.nic_cld_rst_l := '1';
                v.cnts := nic_r.cnts + 1;
                if nic_r.cnts = TWENTY_MS then
                    v.state := EARLY_PERST;
                    v.cnts := (others => '0');
                end if;
        
            when EARLY_PERST =>
                -- We release PERST for the "early" reset 
                v.nic_perst_l := '1';
                v.cnts := nic_r.cnts + 1;
                if nic_r.cnts = TWENTY_MS then
                     v.state := EARLY_PERST_ASSERT;
                     v.cnts := (others => '0');
                end if;

            when EARLY_PERST_ASSERT =>
                -- At this point, we're done with the "early" reset and we're going to hand off control to
                -- the reset state machine below, which interacts with the SP5 hotplug signals.
                -- As we exit this condition and hand-over the to the other state machine the NIC
                -- will go back into reset.
                -- We re-assert PERST here for 2 cycles then hand-off to deal with a potential silicon
                -- race condition in the T6 if these two signals were asserted concurrently.
                v.nic_perst_l := '0';
                v.cnts := nic_r.cnts + 1;
                if nic_r.cnts = NIC_PERST_CLD_RST_RACE_DELAY then
                     v.state := DONE;
                end if;

            when DONE =>
                -- we set these high here as the reset state machine below will have taken over control and we
                -- do not want this state machine to  play into the reset sequence again unless we lose power and
                -- go back to IDLE.
                v.nic_perst_l := '1';
                v.nic_cld_rst_l := '1';
                -- nothing downstream to worry about just go back to idle
                -- we've now handed off control to the next state machine which deals with the SP5
                -- hotplug state. All of this happened *well* before the SP5 is alive and doing PCIe things.
                if sw_enable = '0' then
                    v.state := IDLE;
                end if;

        end case;

        -- MAPO fault handling - monitored in all non-IDLE states
        if nic_r.state /= IDLE then
            if nic_faulted_var = '1' or upstream_ok = '0' or nic_overrides_reg.nic_test_mapo = '1' then
                v.faulted := '1';
                -- In fault case, immediately transition to IDLE
                -- regardless of current state
                v.state := IDLE;
                -- Clear expected flag to avoid additional fault triggers
                v.nic_expected := '0';
            end if;
        end if;

        nic_rin <= v;
    end process;


    -- When the SP5 disconnects the NIC, we need to put it in "reset"
    -- but we actually need to strobe cld_rst_l and perst_l since we
    -- might have mucked with the mfg_mode pins. This logic re-sequences
    -- them.
    nic_rst_sm:process(all)
        variable v : rst_r_t;
    begin
        v := rst_nic_r;

        case rst_nic_r.state is

            when IN_RESET =>
                v.nic_perst_l := '0';
                v.nic_cld_rst_l := '0';
                v.cnts := (others => '0');
                if nic_r.state = DONE and sp5_t6_perst_l = '1' and debug_enables.force_nic_reset = '0' then
                    v.state := CLD_RST_DEASSERTED;
                end if;

            when CLD_RST_DEASSERTED =>
                v.nic_cld_rst_l := '1';
                if sp5_t6_perst_l = '0' or nic_r.state /= DONE or debug_enables.force_nic_reset = '1' then
                    v.state := IN_RESET;
                else
                    v.cnts := rst_nic_r.cnts + 1;
                    if rst_nic_r.cnts = TWENTY_MS then
                        v.state := PERST_DEASSERTED;
                        v.cnts := (others => '0');
                    end if;
                end if;

            when PERST_DEASSERTED =>
                v.nic_perst_l := '1';
                if sp5_t6_perst_l = '0' or nic_r.state /= DONE or debug_enables.force_nic_reset = '1' then
                    v.state := IN_RESET;
                end if;
        end case;

        rst_nic_rin <= v;
    end process;


    reg: process(clk, reset)
    begin
        if reset then
            nic_r <= nic_r_reset;
            rst_nic_r <= rst_r_reset;
        elsif rising_edge(clk) then
            nic_r <= nic_rin;
            rst_nic_r <= rst_nic_rin;
        end if;
    end process;


    -- register and mux for the nic outputs
    -- allowing register override for debug
    out_reg: process(clk, reset)
       variable mfg_mode_l : std_logic;
    begin 
        if reset then
            final_nic_outs <= (others => '0');
        elsif rising_edge(clk) then
            mfg_mode_l := nic_seq_pins.sp5_mfg_mode_l;
            if debug_enables.force_mfg_mode then
                -- force mfg mode for debug overriding SP5 control
                mfg_mode_l := '0';
            end if;
            if debug_enables.nic_override then
                final_nic_outs <= nic_overrides_reg;
            else
                final_nic_outs.nic_pcie_clk_buff_oe_l <= nic_r.nic_clk_en_l;
                -- write protect out of MFG mdoe
                final_nic_outs.flash_wp_l <= not mfg_mode_l;
                -- buffers active whenever we're in A0
                final_nic_outs.eeprom_wp_buffer_oe_l <= not upstream_ok;
                -- write protect out of MFG modes
                final_nic_outs.eeprom_wp_l <= not mfg_mode_l;
                final_nic_outs.nic_mfg_mode_l <= mfg_mode_l;
                if nic_r.state /= DONE then
                    -- First state machine has exclusive control of these pins at the  beginning until we're all the way up
                    final_nic_outs.perst_l <= nic_r.nic_perst_l;
                    final_nic_outs.cld_rst_l <= nic_r.nic_cld_rst_l;
                else
                    -- Now we're sequenced up, either the sequencer or the follower has control
                    -- active low so this is functioning as a logical OR
                    final_nic_outs.perst_l <= nic_r.nic_perst_l and rst_nic_r.nic_perst_l;
                    final_nic_outs.cld_rst_l <= nic_r.nic_cld_rst_l and rst_nic_r.nic_cld_rst_l;
                end if;
                
            end if;

        end if;
    end process;
    
    nic_seq_pins.nic_pcie_clk_buff_oe_l <= final_nic_outs.nic_pcie_clk_buff_oe_l;
    nic_seq_pins.flash_wp_l <= final_nic_outs.flash_wp_l;
    nic_seq_pins.eeprom_wp_buffer_oe_l <= final_nic_outs.eeprom_wp_buffer_oe_l;
    nic_seq_pins.eeprom_wp_l <= final_nic_outs.eeprom_wp_l;
    nic_seq_pins.nic_mfg_mode_l <= final_nic_outs.nic_mfg_mode_l;
    nic_seq_pins.perst_l <= final_nic_outs.perst_l;
    nic_seq_pins.cld_rst_l <= final_nic_outs.cld_rst_l;

    nic_rails.nic_hsc_12v.enable <= nic_r.nic_power_en;
    nic_faulted <= nic_r.faulted;

end rtl;