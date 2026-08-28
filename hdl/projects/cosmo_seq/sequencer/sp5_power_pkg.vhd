-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The board-agnostic half of the sequencer's I/O types: the generic rail
-- records and the SP5-side rail groups and pins. Every SP5 board carries these
-- unchanged, so they live apart from sequencer_io_pkg's cosmo-specific records
-- to let a sibling design reuse a1_a0_seq without dragging in cosmo's NIC.
package sp5_power_pkg is

    -- Generic record type for the common enable/pg feedback.
    -- we'll treat this as both active high internally so
    -- the outer-most blocks need to invert if required.
    type power_rail_t is record
        enable : std_logic;
        pg : std_logic;
    end record;
    -- FPGA's view of the world as the controller and recipient of
    -- the feedback
    view power_rail_at_fpga of power_rail_t is
        enable : out;
        pg : in;
    end view;
    alias power_rail_at_reg is power_rail_at_fpga'converse;
    -- a cascade power rail only has a PG, the enable came from some
    -- other supply
    type cascade_power_rail_t is record
        pg : std_logic;
    end record;
    view cascade_power_rail_at_fpga of cascade_power_rail_t is
        pg : in;
    end view;
    alias cascade_power_rail_at_reg is cascade_power_rail_at_fpga'converse;

    -- Sequencing-related SP5 control/feedback pins
    type sp5_seq_pins_t is record
        thermtrip_l : std_logic;
        reset_l : std_logic;
        pwr_ok : std_logic;
        slp_s3_l : std_logic;
        slp_s5_l : std_logic;
        rsmrst_l : std_logic;
        pwr_btn_l : std_logic;
        pwr_good : std_logic;
        pwrgd_out : std_logic;
        smerr_l : std_logic;
        is_cosmo : std_logic; -- uses SP5_TO_FPGA1_DEBUG1 high at power up to indicate cosmo
    end record;
    -- FPGA's view of the world as the controller and recipient of
    -- the feedback
    view sp5_seq_at_fpga of sp5_seq_pins_t is
        thermtrip_l : in;
        reset_l : in;
        pwr_ok : in;
        slp_s3_l : in;
        slp_s5_l : in;
        smerr_l : in;
        pwrgd_out : in;
        rsmrst_l : out;
        pwr_btn_l : out;
        pwr_good : out;
        is_cosmo : out;
    end view;
    alias sp5_seq_at_sp5 is sp5_seq_at_fpga'converse;

    type early_power_t is record
        fan_central_hsc_pg : std_logic;
        fan_east_hsc_pg : std_logic;
        fan_fail : std_logic;
        fan_west_hsc_pg : std_logic;
        fan_central_hsc_disable : std_logic;
        fan_east_hsc_disable : std_logic;
        fan_west_hsc_disable : std_logic;
    end record;
    view early_power_at_fpga of early_power_t is
        fan_central_hsc_pg : in;
        fan_east_hsc_pg : in;
        fan_west_hsc_pg : in;
        fan_fail : in;
        fan_central_hsc_disable : out;
        fan_east_hsc_disable : out;
        fan_west_hsc_disable : out;
    end view;
    alias early_power_on_board is early_power_at_fpga'converse;

    -- DDR 12V bulk power rail
    type ddr_bulk_power_t is record
       abcdef_hsc : power_rail_t;
       ghijkl_hsc : power_rail_t;
    end record;
    function is_power_good(power_group: ddr_bulk_power_t) return boolean;
    -- FPGA's view of the world as the controller and recipient of
    -- the feedback
    view ddr_bulk_power_at_fpga of ddr_bulk_power_t is
        abcdef_hsc : view power_rail_at_fpga;
        ghijkl_hsc : view power_rail_at_fpga;
    end view;
    alias ddr_bulk_at_reg is ddr_bulk_power_at_fpga'converse;

    -- SP5 group a rails
    --A (G3/S5): VDDBT_RTC_G, VDD_18_S5,VDD_33_S5, VDDIO_AUDIO (shared as 1V8)
    type group_a_power_t is record
        pwr_v1p5_rtc : power_rail_t;
        v3p3_sp5_a1 : power_rail_t;
        v1p8_sp5_a1 : power_rail_t;
    end record;
    function is_power_good(power_group: group_a_power_t) return boolean;
    view group_a_power_at_fpga of group_a_power_t is
        pwr_v1p5_rtc : view power_rail_at_fpga;
        v3p3_sp5_a1 : view power_rail_at_fpga;
        v1p8_sp5_a1 : view power_rail_at_fpga;
    end view;
    alias group_a_power_at_reg is group_a_power_at_fpga'converse;

    -- B (S3): VDD_11_S3
    type group_b_power_t is record
        v1p1_sp5 : power_rail_t;
    end record;
    function is_power_good(power_group: group_b_power_t) return boolean;
    view group_b_power_at_fpga of group_b_power_t is
        v1p1_sp5 : view power_rail_at_fpga;
    end view;
    alias group_b_power_at_reg is group_b_power_at_fpga'converse;


    -- C (S0): VDDIO, VDDCR_SOC,VDDCR_CPU0, VDDCR_CPU1
    type group_c_power_t is record
        vddio_sp5_a0 : power_rail_t;
        vddcr_cpu1 : power_rail_t;
        vddcr_cpu0 : power_rail_t;
        vddcr_soc : power_rail_t;
    end record;
    function is_power_good(power_group: group_c_power_t) return boolean;
    view group_c_power_at_fpga of group_c_power_t is
        vddio_sp5_a0 : view power_rail_at_fpga;
        vddcr_cpu1 : view power_rail_at_fpga;
        vddcr_cpu0 : view power_rail_at_fpga;
        vddcr_soc : view power_rail_at_fpga;
    end view;
    alias group_c_power_at_reg is group_c_power_at_fpga'converse;

end package;

package body sp5_power_pkg is

     -- Functions for DDR bulk
    function is_power_good(power_group: ddr_bulk_power_t) return boolean is
    begin
        return (power_group.abcdef_hsc.pg and  power_group.ghijkl_hsc.pg) = '1';
    end function;

    -- Functions for groupA
    function is_power_good(power_group: group_a_power_t) return boolean is
    begin
        return (power_group.pwr_v1p5_rtc.pg and  power_group.v3p3_sp5_a1.pg and power_group.v1p8_sp5_a1.pg) = '1';
    end function;
    
    -- Functions for groupB
    function is_power_good(power_group: group_b_power_t) return boolean is
    begin
        return power_group.v1p1_sp5.pg = '1';
    end function;

    -- Functions for groupc
    function is_power_good(power_group: group_c_power_t) return boolean is
    begin
        return (power_group.vddio_sp5_a0.pg and 
            power_group.vddcr_cpu1.pg and
            power_group.vddcr_cpu0.pg and
            power_group.vddcr_soc.pg
            ) = '1';
    end function;

end package body;
