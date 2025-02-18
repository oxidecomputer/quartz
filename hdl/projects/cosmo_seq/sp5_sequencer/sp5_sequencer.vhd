-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil8x32_pkg;

use work.sequencer_io_pkg.all;
use work.sequencer_regs_pkg.all;

-- This block provides the power control on an SP5-based sled including
-- state machines and registers for software.
-- It assumes all inputs are already synchronized to the clock domain
-- and provides registers for out outputs that are destined for off-chip
-- devices.  It provides no tri-state logic so tri-stating must be done
-- at the chip top if needed/desired.
entity sp5_sequencer is
    generic (
        CNTS_P_MS: integer
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        axi_if : view axil8x32_pkg.axil_target;

        -- These signals are useful throughout the design for dealing with
        -- buffers, a0-domain "reset" kinds of things etc
        a0_ok : out std_logic;
        a0_idle: out std_logic;

        -- already synchronized to the clock domain
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
        -- nic supplies
        nic_rails : view nic_power_at_fpga;


    );
end entity;

architecture rtl of sp5_sequencer is
    signal power_ctrl : power_ctrl_type;
    signal seq_api_status : seq_api_status_type;
    signal seq_raw_status : seq_raw_status_type;
    signal nic_api_status : nic_api_status_type;
    signal nic_raw_status : nic_raw_status_type;
    signal rails_en_rdbk : rails_type;
    signal rails_pg_rdbk : rails_type;
    
    signal fans_power_ok : std_logic;
    -- We have the following states for the sequencing block
    -- power ok means we're up and happy
    -- power idle means we're down and idle
    -- power not idle could mean we're in the middle of a sequence up or down
    signal nic_ok : std_logic;
    signal nic_idle : std_logic;

begin

    regs: entity work.sequencer_regs
     port map(
        clk => clk,
        reset => reset,
        axi_if => axi_if,
        power_ctrl => power_ctrl,
        seq_api_status => seq_api_status,
        seq_raw_status => seq_raw_status,
        nic_api_status => nic_api_status,
        nic_raw_status => nic_raw_status,
        rails_en_rdbk => rails_en_rdbk,
        rails_pg_rdbk => rails_pg_rdbk
    );

    -- TODO: precursor power stuff, FANS block etc

    a1_a0_seq_inst: entity work.a1_a0_seq
     generic map(
        CNTS_P_MS => CNTS_P_MS
    )
     port map(
        clk => clk,
        reset => reset,
        upstream_ok => fans_power_ok,
        downstream_idle => nic_idle,
        a0_ok => a0_ok,
        a0_idle => a0_idle,
        a0_faulted => open,
        sw_enable => power_ctrl.a0_en,
        ignore_sp5 => '0',
        ddr_bulk => ddr_bulk,
        group_a => group_a,
        group_b => group_b,
        group_c => group_c,
        sp5_seq_pins => sp5_seq_pins
    );

    nic_seq_inst: entity work.nic_seq
     generic map(
        CNTS_P_MS => CNTS_P_MS
    )
     port map(
        clk => clk,
        reset => reset,
        sw_enable => power_ctrl.a0_en,
        upstream_ok => a0_ok,
        sp5_to_nic_mfg_mode_l => '0', -- TODO: fix this up
        fpga1_to_nic_mfg_mode_l => '0', -- TODO: fix this up
        nic_rails => nic_rails
    );

end rtl;