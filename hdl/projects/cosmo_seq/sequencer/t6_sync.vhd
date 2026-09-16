-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sp5_power_pkg.all;
use work.sequencer_io_pkg.all;
use work.sequencer_regs_pkg.all;

-- Synchronises cosmo's T6 NIC pins: the rail power goods and the reset,
-- write-protect and manufacturing-mode handshake lines. The SP5-side pins
-- are done in seq_sync.
entity t6_sync is
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- pins (unsync'd) interface
        nic_rails_pins : view nic_power_at_fpga;
        nic_seq_pins: view nic_seq_at_fpga;
        -- internal, synchronized interfaces
        nic_rails : view nic_power_at_reg;
        nic_seq: view nic_seq_at_nic
    );
end entity;

architecture rtl of t6_sync is
   signal nic_sync_5v_hsc_pg_l : std_logic;
   signal nic_sync_12v_hsc_pg_l : std_logic;
begin

    -- nic rails sync stuff
    nic_rails_pins.nic_hsc_12v.enable <= nic_rails.nic_hsc_12v.enable;
    v1p5_nic_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p5_nic_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p5_nic_a0hp.pg
    );
    v1p2_nic_pcie_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p2_nic_pcie_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p2_nic_pcie_a0hp.pg
    );
    v1p2_nic_enet_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p2_nic_enet_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p2_nic_enet_a0hp.pg
    );
    v3p3_nic_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v3p3_nic_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v3p3_nic_a0hp.pg
    );
    v1p1_nic_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p1_nic_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p1_nic_a0hp.pg
    );
    v1p4_nic_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v1p4_nic_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v1p4_nic_a0hp.pg
    );
    v0p96_nic_vdd_a0hp: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.v0p96_nic_vdd_a0hp.pg,
       clk => clk,
       sycnd_output => nic_rails.v0p96_nic_vdd_a0hp.pg
    );
    nic_hsc_12v: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.nic_hsc_12v.pg,
       clk => clk,
       sycnd_output => nic_sync_12v_hsc_pg_l
    );
    nic_hsc_5v: entity work.meta_sync
    port map(
       async_input => nic_rails_pins.nic_hsc_5v.pg,
       clk => clk,
       sycnd_output => nic_sync_5v_hsc_pg_l
    );
   
    -- HSC's are actually pg_l signals, so invert them here
    nic_rails.nic_hsc_5v.pg <= not nic_sync_5v_hsc_pg_l;
    nic_rails.nic_hsc_12v.pg  <= not nic_sync_12v_hsc_pg_l;
    -- nic sync-related stuff
    nic_seq_pins.cld_rst_l <= nic_seq.cld_rst_l;
    nic_seq_pins.perst_l <= nic_seq.perst_l;
    nic_seq_pins.eeprom_wp_l <= nic_seq.eeprom_wp_l;
    nic_seq_pins.eeprom_wp_buffer_oe_l <= nic_seq.eeprom_wp_buffer_oe_l;
    nic_seq_pins.flash_wp_l <= nic_seq.flash_wp_l;
    nic_seq_pins.nic_mfg_mode_l <= nic_seq.nic_mfg_mode_l;
    nic_seq_pins.nic_pcie_clk_buff_oe_l <= nic_seq.nic_pcie_clk_buff_oe_l;
    ext_rst_l_sync: entity work.meta_sync
    port map(
       async_input => nic_seq_pins.ext_rst_l,
       clk => clk,
       sycnd_output => nic_seq.ext_rst_l
    );
    sp5_mfg_mode_l_sync: entity work.meta_sync
    port map(
       async_input => nic_seq_pins.sp5_mfg_mode_l,
       clk => clk,
       sycnd_output => nic_seq.sp5_mfg_mode_l
    );


end rtl;
