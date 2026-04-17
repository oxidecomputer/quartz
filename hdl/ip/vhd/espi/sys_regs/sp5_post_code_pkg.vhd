-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2026 Oxide Computer Company

-- Composite record and views for exposing eSPI spec register
-- values as a read-only interface in the sys_regs address space.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.espi_spec_regs_pkg.all;
use work.espi_regs_pkg.all;


package sp5_post_code_pkg is

    -- Post codes for SP5
    constant POST_CODE_BL_SUCCESS_C_MAIN : std_logic_vector(31 downto 0) := x"EE1000A0";
    constant POST_CODE_TP_PROC_MEM_AFTER_MEM_DATA_INIT : std_logic_vector(31 downto 0) := x"EA00E046";
    constant POST_CODE_TP_ABL7_RESUME_INITIALIZATION : std_logic_vector(31 downto 0) := x"EA00E101";
    constant POST_CODE_TP_ABL_MEMORY_DDR_TRAINING_START : std_logic_vector(31 downto 0) := x"EA00E340";
    constant POST_CODE_TP_PROC_CPU_OPTIMIZED_BOOT_START : std_logic_vector(31 downto 0) := x"EA00E055";
    constant POST_CODE_TP_ABL4_APOB : std_logic_vector(31 downto 0) := x"EA00E0C9";
    constant POST_CODE_BL_SUCCESS_BIOS_LOAD_COMPLETE : std_logic_vector(31 downto 0) := x"EE1000BB";
    constant POST_CODE_PHBLHELLO : std_logic_vector(31 downto 0) := x"1DE90001";

    -- Given a valid strobe and a post code, return a post_code_monitor_type with
    -- the matching monitor bit set (all others '0'). Returns all zeros when valid
    -- is '0' or the post code is not one of the tracked values. The caller is
    -- expected to OR this into the sticky register each cycle.
    function decode_post_code_monitor(
        post_code : std_logic_vector(31 downto 0)
    ) return post_code_monitor_type;

end package sp5_post_code_pkg;

package body sp5_post_code_pkg is

    function decode_post_code_monitor(
        post_code : std_logic_vector(31 downto 0)
    ) return post_code_monitor_type is
        variable ret : post_code_monitor_type := rec_reset;
    begin
        case post_code is
            when POST_CODE_BL_SUCCESS_C_MAIN =>
                ret.bl_success_c_main := '1';
            when POST_CODE_TP_PROC_MEM_AFTER_MEM_DATA_INIT =>
                ret.tp_proc_mem_after_mem_data_init := '1';
            when POST_CODE_TP_ABL7_RESUME_INITIALIZATION =>
                ret.tp_abl7_resume_initialization := '1';
            when POST_CODE_TP_ABL_MEMORY_DDR_TRAINING_START =>
                ret.tp_abl_memory_ddr_training_start := '1';
            when POST_CODE_TP_PROC_CPU_OPTIMIZED_BOOT_START =>
                ret.tp_proc_cpu_optimized_boot_start := '1';
            when POST_CODE_TP_ABL4_APOB =>
                ret.tp_abl4_apob := '1';
            when POST_CODE_BL_SUCCESS_BIOS_LOAD_COMPLETE =>
                ret.bl_success_bios_load_complete := '1';
            when POST_CODE_PHBLHELLO =>
                ret.phbl_hello := '1';
            when others =>
                null;
        end case;
        return ret;
    end function;

end package body sp5_post_code_pkg;
