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
        debug_enables : in debug_enables_type;
        nic_overrides_reg : in nic_overrides_type;

        raw_state : out nic_raw_status_type;
        api_state : out nic_api_status_type;

        -- From SP5 hotplug
        sp5_t6_power_en : in std_logic;
        sp5_t6_perst_l : in std_logic;

        nic_rails: view nic_power_at_fpga;
        nic_seq_pins: view nic_seq_at_fpga;



    );
end entity;

architecture rtl of nic_seq is
    constant ONE_MS : integer := 1 * CNTS_P_MS;
    constant TEN_MS : integer := 10 * ONE_MS;
    constant TWENTY_MS : integer := 20 * ONE_MS;
    constant THIRTY_MS : integer := 30 * ONE_MS;

    type state_t is ( IDLE, PWR_EN, WAIT_FOR_PGS, EARLY_CLD_RST, EARLY_PERST, DONE );

    type reset_state_t is (IN_RESET, CLD_RST_DELAY, CLD_RST_DEASSERTED, PERST_DEASSERTED);
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
        state : state_t;
        cnts  : unsigned(31 downto 0);
        nic_power_en : std_logic;
        nic_perst_l : std_logic;
        nic_cld_rst_l : std_logic;
        nic_clk_en_l : std_logic;
    end record;

    constant nic_r_reset : nic_r_t := (
        state => IDLE,
        cnts => (others => '0'),
        nic_power_en => '0',
        nic_perst_l => '0',
        nic_cld_rst_l => '0',
        nic_clk_en_l => '1'
    );
    signal nic_r, nic_rin : nic_r_t;

    signal rst_nic_r, rst_nic_rin : rst_r_t;

    signal final_nic_outs : nic_overrides_type;

begin

    raw_state.hw_sm <= std_logic_vector(to_unsigned(state_t'pos(nic_r.state), raw_state.hw_sm'length));
    
    nic_idle <= '1' when nic_r.state = IDLE else '0';

    nic_sm:process(all)
        variable v : nic_r_t;
    begin

        v := nic_r;

        case nic_r.state is
            when IDLE =>
                v.nic_power_en := '0';
                v.nic_perst_l := '0';
                v.nic_cld_rst_l := '0';
                v.nic_clk_en_l := '1';
                v.cnts := (others => '0');
                if sw_enable and upstream_ok then
                    v.state := PWR_EN;
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
                -- We release reset "early" 
                v.state := DONE;
                v.nic_perst_l := '1';

            when DONE =>
                -- nothing downstream to worry about just go back to idle
                if sw_enable = '0' then
                    v.state := IDLE;
                end if;

        end case;

        -- TODO: deal with faults

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
                    v.state := CLD_RST_DELAY;
                end if;
            when CLD_RST_DELAY =>
                if sp5_t6_perst_l = '0' or nic_r.state /= DONE or debug_enables.force_nic_reset = '1' then
                    v.state := IN_RESET;
                else
                    v.cnts := rst_nic_r.cnts + 1;
                    if rst_nic_r.cnts = TWENTY_MS then
                        v.state := CLD_RST_DEASSERTED;
                        v.cnts := (others => '0');
                    end if;
                end if;

            when CLD_RST_DEASSERTED =>
                if sp5_t6_perst_l = '0' or nic_r.state /= DONE or debug_enables.force_nic_reset = '1' then
                    v.state := IN_RESET;
                else
                    v.nic_cld_rst_l := '1';
                    v.cnts := rst_nic_r.cnts + 1;
                    if rst_nic_r.cnts = TEN_MS then
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

end rtl;