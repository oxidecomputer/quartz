-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package cem_hp_io_pkg is

    -- Sharkfin Relevant signal descriptions
    -- sharkfin_present: '1' if sharkfin is present, '0' if not. pin A05 on CEM connector. PU on sharkfin.
    -- IFDET_L: '0' for PCIe U.2 drives. Pass Thru from U.2 connector on sharkfin. PU on Mobo.
    -- PERST_L: output from FPGA, should be tri-state to not cross power domains. PU on Mobo.
    -- ALERT_L: smbus alert. PU on Mobo to A2 rail
    -- PG_L: power good from CEM. PU on mobo. AIC's drive this low as it doubles as a presence strap.
    -- PWRFLT_L: power fault from CEM. PU on mobo. AIC's
    -- PRSNT_L: sharkfin passthru drive presence. PU on Mobo. only x4 AIC's drive this low, x1 AIC's leave it high.
    --     SFF-8639 says this is *de-asserted* high when a valid device is present (and ifdet_l is low):

    -- Want:
    -- hotplug presence (PRSNT_L = '0') when:
    -- 1. Sharkfin is present, and a valid U.2 SSD is present:
    --     IFDET_L = '0' and sharkfin_present = '1' and PRSNT_L = '1'
    -- 2. AIC is present:
    --     sharkfin_present = '0' and PG_L = '0' (AIC presence strap) (PRSNT_L is don't care, only low for x4 AIC's)
    -- ?? How does PG_L want to work with all of this?
    -- PWREN = '1' when (valid U.2 SSD is present or AIC is present) and hotplog slot is powered on.
    -- EMILs = '1' when we have a sharkfin installed and wrong kind of SSD
    --    IFDET_L = '1' and sharkfin_present = '1' and PRSNT_L = '0'
    -- clock_en_l follows PRSNT_L
    -- PERST_L follows PWREN, sharkfins guarantee timings via on-board hw

    -- What we get from the CEM
    type cem_to_fpga_io_t is record
        alert_l : std_logic;
        ifdet_l : std_logic;
        pg_l : std_logic;
        prsnt_l : std_logic;
        pwrflt_l : std_logic;
        sharkfin_present : std_logic;
    end record;
    constant CEM_INPUT_BIT_COUNT : integer := 6;
    -- What we send to the CEM
    type fpga_to_cem_io_t is record
        attnled : std_logic;  -- default this to off
        pwren : std_logic; -- default this to off
    end record;
    -- What we expose to SP5 via the i/o expander
    type fpga_to_hp_io_t is record
        present_l : std_logic;
        pwrflt_l : std_logic;
        atnsw_l : std_logic;
        emils : std_logic;
    end record;
    -- what we get from the SP5 via the i/o expander
    type hp_to_fpga_io_t is record
       atnled : std_logic;
       pwren_l : std_logic;
       emil: std_logic;
    end record;

    type from_cem_t is array (0 to 9) of cem_to_fpga_io_t;
    type to_cem_t is array (0 to 9) of fpga_to_cem_io_t;
    type to_sp5_io_t is array (0 to 9) of fpga_to_hp_io_t;
    type from_sp5_io_t is array (0 to 9) of hp_to_fpga_io_t;

    -- Mode A for i/o expanders
    -- PRSNT_L: bit0 in
    -- PWRFLT_L: bit1 in
    -- ATNSW_L: bit2 -- not used
    -- EMILS : bit3 in
    -- PWR_EN_L: bit4 out
    -- ATN_LED_L: bit5 out
    -- PWR_LED_L: bit6 -- not used
    -- EMIL: bit7 -- not used

    -- Stuff we want to know about the CEM
    -- Invalid SSD present
    -- Sharkfin present
    -- AIC present



    function sharkfin_present(cem : cem_to_fpga_io_t) return boolean;
    function aic_present(cem : cem_to_fpga_io_t) return boolean;
    function invalid_ssd_present(cem : cem_to_fpga_io_t) return boolean;
    function valid_ssd_present(cem : cem_to_fpga_io_t) return boolean;

    function to_sp5_io(rec: fpga_to_hp_io_t) return std_logic_vector;
    function from_sp5_io(o: std_logic_vector(7 downto 0); oe: std_logic_vector(7 downto 0)) return hp_to_fpga_io_t;
    function to_sp5_in_pins_from_cem(cem : cem_to_fpga_io_t) return fpga_to_hp_io_t;
    function to_cem_pins_from_hp(hp: hp_to_fpga_io_t) return fpga_to_cem_io_t;

    function to_vec(cem: cem_to_fpga_io_t) return std_logic_vector;
    function from_vec(vec: std_logic_vector(CEM_INPUT_BIT_COUNT -1 downto 0)) return cem_to_fpga_io_t;

    type interim_sync_t is array (0 to 9) of std_logic_vector(CEM_INPUT_BIT_COUNT - 1 downto 0);

    function to_record_array(vec: interim_sync_t) return from_cem_t;


end package;

package body cem_hp_io_pkg is

    function to_vec(cem: cem_to_fpga_io_t) return std_logic_vector is
        variable vec : std_logic_vector(CEM_INPUT_BIT_COUNT - 1 downto 0);
    begin
        vec :=  cem.alert_l &
                cem.ifdet_l &
                cem.pg_l &
                cem.prsnt_l &
                cem.pwrflt_l &
                cem.sharkfin_present;
        return vec;
    end function;

    function to_record_array(vec: interim_sync_t) return from_cem_t is
        variable cem : from_cem_t;
    begin
        for i in vec'range loop
            cem(i) := from_vec(vec(i));
        end loop;
        return cem;
    end function;

    function from_vec(vec: std_logic_vector(CEM_INPUT_BIT_COUNT -1 downto 0)) return cem_to_fpga_io_t is
        variable cem : cem_to_fpga_io_t;
    begin
        cem.alert_l := vec(5);
        cem.ifdet_l := vec(4);
        cem.pg_l := vec(3);
        cem.prsnt_l := vec(2);
        cem.pwrflt_l := vec(1);
        cem.sharkfin_present := vec(0);
        return cem;
    end function;


    function sharkfin_present(cem : cem_to_fpga_io_t) return boolean is
    begin
        -- This is the easy one, we just check the sharkfin_present bit
        return cem.sharkfin_present = '1';
    end function;

    function aic_present(cem : cem_to_fpga_io_t) return boolean is 
    begin
        -- AIC is installed if sharkfin is not, and we have something pulling
        -- PG_L low. Since it's not a sharkfin, it's an AIC presence strap.
        -- PRESNT_L pin will be open since it's a x1 AIC, so high.
        return cem.pg_l = '0' and
            cem.sharkfin_present = '0';
    end function;

    function invalid_ssd_present(cem : cem_to_fpga_io_t) return boolean is
    begin
        -- Invalid SSD is installed if we have a sharkfin present, and
        -- ifdet is high but something is in the slot
        return sharkfin_present(cem) and cem.ifdet_l = '1' and cem.prsnt_l = '0';
    end function;

    function valid_ssd_present(cem : cem_to_fpga_io_t) return boolean is
    begin
        -- Valid SSD is installed if we have a sharkfin present, and
        -- ifdet is low and something is in the slot
        return sharkfin_present(cem) and cem.ifdet_l = '0' and cem.prsnt_l = '1';
    end function;

    function to_sp5_in_pins_from_cem(cem : cem_to_fpga_io_t) return fpga_to_hp_io_t is
        variable to_hp: fpga_to_hp_io_t;
    begin
         -- general logic to the SP5
        to_hp.present_l := '0' when aic_present(cem) or valid_ssd_present(cem) else '1';
        to_hp.pwrflt_l := cem.pwrflt_l;
        to_hp.atnsw_l := '1'; -- not used
        to_hp.emils := '1' when invalid_ssd_present(cem) else '0';
        return to_hp;
    end function;

    function to_cem_pins_from_hp(hp: hp_to_fpga_io_t) return fpga_to_cem_io_t is
        variable to_cem: fpga_to_cem_io_t;
    begin
         -- general logic to the SP5
        to_cem.attnled := hp.atnled;
        -- TODO: we need to fix this design eventually
        to_cem.pwren := '1' when hp.pwren_l = '0' else '0';
        return to_cem;
    end function;

    function to_sp5_io(rec: fpga_to_hp_io_t) return std_logic_vector is
        variable io : std_logic_vector(7 downto 0) := (others => '0');
    begin
        -- PRSNT_L: bit0
        io(0) := rec.present_l;
        -- PWRFLT_L: bit1
        io(1) := rec.pwrflt_l;
        -- ATNSW_L: bit2 
        io(2) := rec.atnsw_l;
        -- EMILS: bit3
        io(3) := rec.emils;
        return io;
    end function;

    function from_sp5_io(o: std_logic_vector(7 downto 0); oe: std_logic_vector(7 downto 0)) return hp_to_fpga_io_t is
        variable io : hp_to_fpga_io_t;
        variable pulls: hp_to_fpga_io_t;
    begin
        pulls := (atnled => '0', pwren_l => '1', emil => '1');
        io := pulls;
        if oe(4) then
            io.pwren_l := o(4);
        end if;
        if oe(5) then
            io.atnled := o(5);
        end if;
        return io;
    end function;

end package body;