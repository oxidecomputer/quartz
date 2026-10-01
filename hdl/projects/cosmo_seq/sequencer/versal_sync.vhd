-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sp5_power_pkg.all;
use work.sequencer_io_pkg.all;
use work.sequencer_regs_pkg.all;

-- Synchronises metro's Versal NIC pins: the rail power goods, the boot
-- status pins and the two PCIe channels' slot inputs. The SP5-side pins are
-- done in seq_sync.
entity versal_sync is
    port (
        clk : in std_logic;
        reset : in std_logic;

        -- pins (unsync'd) interface
        versal_rails_pins : view versal_power_at_fpga;
        versal_boot_pins : view versal_boot_at_fpga;
        versal_pcie_pins : view versal_pcie_at_fpga;
        -- internal, synchronized interfaces
        rail_masks : in rails_type;
        versal_rails : view versal_power_at_reg;
        versal_boot : view versal_boot_at_versal;
        versal_pcie : view versal_pcie_at_nic
    );
end entity;

architecture rtl of versal_sync is
   signal versal_sync_5v_hsc_pg_l : std_logic;
   signal versal_sync_12v_hsc_pg_l : std_logic;
   signal versal_v3p3_pg_raw : std_logic;
   signal versal_v1p8_pg_raw : std_logic;
   signal versal_v1p5_pg_raw : std_logic;
   signal versal_v1p5_avccaux_pg_raw : std_logic;
   signal versal_v1p4_pg_raw : std_logic;
   signal versal_v1p1_pg_raw : std_logic;
   signal versal_v0p88_pg_raw : std_logic;
   signal versal_v0p8_vccint_pg_raw : std_logic;
   signal versal_v0p92_avcc_pg_raw : std_logic;
   signal versal_v1p2_avtt_pg_raw : std_logic;
begin

    -- Versal rails sync stuff
    versal_rails_pins.v3p3.enable <= versal_rails.v3p3.enable;
    versal_rails_pins.v1p8.enable <= versal_rails.v1p8.enable;
    versal_rails_pins.v1p5.enable <= versal_rails.v1p5.enable;
    versal_rails_pins.v1p5_avccaux.enable <= versal_rails.v1p5_avccaux.enable;
    versal_rails_pins.v1p4.enable <= versal_rails.v1p4.enable;
    versal_rails_pins.v1p1.enable <= versal_rails.v1p1.enable;
    versal_rails_pins.v0p88.enable <= versal_rails.v0p88.enable;
    versal_rails_pins.v0p8_vccint.enable <= versal_rails.v0p8_vccint.enable;
    versal_rails_pins.hsc_12v.enable <= versal_rails.hsc_12v.enable;

    versal_v3p3_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v3p3.pg,
       clk => clk,
       sycnd_output => versal_v3p3_pg_raw
    );
    versal_rails.v3p3.pg <= versal_v3p3_pg_raw when rail_masks.versal_v3p3 = '0' else '0';

    versal_v1p8_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v1p8.pg,
       clk => clk,
       sycnd_output => versal_v1p8_pg_raw
    );
    versal_rails.v1p8.pg <= versal_v1p8_pg_raw when rail_masks.versal_v1p8 = '0' else '0';

    versal_v1p5_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v1p5.pg,
       clk => clk,
       sycnd_output => versal_v1p5_pg_raw
    );
    versal_rails.v1p5.pg <= versal_v1p5_pg_raw when rail_masks.versal_v1p5 = '0' else '0';

    versal_v1p5_avccaux_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v1p5_avccaux.pg,
       clk => clk,
       sycnd_output => versal_v1p5_avccaux_pg_raw
    );
    versal_rails.v1p5_avccaux.pg <= versal_v1p5_avccaux_pg_raw when rail_masks.versal_v1p5_avccaux = '0' else '0';

    versal_v1p4_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v1p4.pg,
       clk => clk,
       sycnd_output => versal_v1p4_pg_raw
    );
    versal_rails.v1p4.pg <= versal_v1p4_pg_raw when rail_masks.versal_v1p4 = '0' else '0';

    versal_v1p1_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v1p1.pg,
       clk => clk,
       sycnd_output => versal_v1p1_pg_raw
    );
    versal_rails.v1p1.pg <= versal_v1p1_pg_raw when rail_masks.versal_v1p1 = '0' else '0';

    versal_v0p88_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v0p88.pg,
       clk => clk,
       sycnd_output => versal_v0p88_pg_raw
    );
    versal_rails.v0p88.pg <= versal_v0p88_pg_raw when rail_masks.versal_v0p88 = '0' else '0';

    versal_v0p8_vccint_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v0p8_vccint.pg,
       clk => clk,
       sycnd_output => versal_v0p8_vccint_pg_raw
    );
    versal_rails.v0p8_vccint.pg <= versal_v0p8_vccint_pg_raw when rail_masks.versal_v0p8_vccint = '0' else '0';

    versal_v0p92_avcc_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v0p92_avcc.pg,
       clk => clk,
       sycnd_output => versal_v0p92_avcc_pg_raw
    );
    versal_rails.v0p92_avcc.pg <= versal_v0p92_avcc_pg_raw when rail_masks.versal_v0p92_avcc = '0' else '0';

    versal_v1p2_avtt_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.v1p2_avtt.pg,
       clk => clk,
       sycnd_output => versal_v1p2_avtt_pg_raw
    );
    versal_rails.v1p2_avtt.pg <= versal_v1p2_avtt_pg_raw when rail_masks.versal_v1p2_avtt = '0' else '0';

    versal_hsc_12v_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.hsc_12v.pg,
       clk => clk,
       sycnd_output => versal_sync_12v_hsc_pg_l
    );

    versal_hsc_5v_pg: entity work.meta_sync
    port map(
       async_input => versal_rails_pins.hsc_5v.pg,
       clk => clk,
       sycnd_output => versal_sync_5v_hsc_pg_l
    );

    -- The hotswap controllers report power good active low, so invert here and
    -- let everything above this line treat power good as active high.
    versal_rails.hsc_12v.pg <= (not versal_sync_12v_hsc_pg_l) when rail_masks.nic_hsc_12v = '0' else '0';
    versal_rails.hsc_5v.pg <= (not versal_sync_5v_hsc_pg_l) when rail_masks.nic_hsc_5v = '0' else '0';

    -- Versal boot straps and status
    versal_boot_pins.mode <= versal_boot.mode;
    versal_boot_pins.mode_buffer_en_l <= versal_boot.mode_buffer_en_l;
    versal_boot_pins.por_b <= versal_boot.por_b;
    versal_boot_pins.err_done_buff_en <= versal_boot.err_done_buff_en;

    versal_done_sync: entity work.meta_sync
    port map(
       async_input => versal_boot_pins.done,
       clk => clk,
       sycnd_output => versal_boot.done
    );

    versal_error_out_sync: entity work.meta_sync
    port map(
       async_input => versal_boot_pins.error_out,
       clk => clk,
       sycnd_output => versal_boot.error_out
    );

    -- Versal PCIe channels
    versal_pcie_pins.cha.perst_l <= versal_pcie.cha.perst_l;
    versal_pcie_pins.cha.clk_buff_oe_l <= versal_pcie.cha.clk_buff_oe_l;
    versal_pcie_pins.chb.perst_l <= versal_pcie.chb.perst_l;
    versal_pcie_pins.chb.clk_buff_oe_l <= versal_pcie.chb.clk_buff_oe_l;

    versal_cha_prsnt_l_sync: entity work.meta_sync
    port map(
       async_input => versal_pcie_pins.cha.prsnt_l,
       clk => clk,
       sycnd_output => versal_pcie.cha.prsnt_l
    );

    versal_cha_pwren_l_sync: entity work.meta_sync
    port map(
       async_input => versal_pcie_pins.cha.pwren_l,
       clk => clk,
       sycnd_output => versal_pcie.cha.pwren_l
    );

    versal_chb_prsnt_l_sync: entity work.meta_sync
    port map(
       async_input => versal_pcie_pins.chb.prsnt_l,
       clk => clk,
       sycnd_output => versal_pcie.chb.prsnt_l
    );

    versal_chb_pwren_l_sync: entity work.meta_sync
    port map(
       async_input => versal_pcie_pins.chb.pwren_l,
       clk => clk,
       sycnd_output => versal_pcie.chb.pwren_l
    );


end rtl;
