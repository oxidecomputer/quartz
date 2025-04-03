-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Cosmo Sequencer FPGA targeting the Spartan-7

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pca9506_pkg.all;
use work.time_pkg.all; -- for calc_ms and calc_us

entity sp5_hotplug_subsystem is
    generic(
        PERST_US_ONESHOT : integer := 100000; -- 100ms for Tpvperl, this is used in the oneshot
        NS_PER_CLK : integer := 8
    );
    port(
        clk : in std_logic;
        reset : in std_logic;

        sp5_i2c_sda : in std_logic;
        sp5_i2c_sda_o : out std_logic;
        sp5_i2c_sda_oe : out std_logic;
        sp5_i2c_scl : in std_logic;
        sp5_i2c_scl_o : out std_logic;
        sp5_i2c_scl_oe : out std_logic;

        a0_ok : in std_logic;

        -- M.2 things
        --m.2a
        m2a_pedet : in std_logic;
        m2a_prsnt_l : in std_logic;
        m2a_hsc_en : out std_logic;
        m2a_perst_l : out std_logic;
        pcie_clk_buff_m2a_oe_l : out std_logic;

        --m.2b
        m2b_pedet : in std_logic;
        m2b_prsnt_l : in std_logic;
        m2b_hsc_en : out std_logic;
        m2b_perst_l : out std_logic;
        pcie_clk_buff_m2b_oe_l : out std_logic;

        -- T6 things
        t6_power_en : out std_logic;
        t6_perst_l : out std_logic;

        -- Sidecar things
        pcie_aux_rsw_perst_l : out std_logic;
        pcie_aux_rsw_prsnt_buff_l : in std_logic;
        pcie_aux_rsw_pwrflt_buff_l : in std_logic;
        pcie_clk_buff_rsw_oe_l : out std_logic;
        rsw_sp5_pcie_attached_buff_l : in std_logic;
    );
end sp5_hotplug_subsystem;

architecture rtl of sp5_hotplug_subsystem is
    constant i2c_io_addr : std_logic_vector(6 downto 0) := b"0100_010";
    signal io : pca9506_pin_t;
    signal io_oe : pca9506_pin_t;
    signal io_o : pca9506_pin_t;
    signal m2a_pedet_sync : std_logic;
    signal m2b_pedet_sync : std_logic;
    signal m2b_power_en : std_logic;
    signal m2a_power_en : std_logic;
    signal pcie_aux_power_en : std_logic;
    constant PERST_CNTS : integer := calc_us(
        desired_us => PERST_US_ONESHOT,  -- 100ms for Tpvperl
        clk_period_ns => NS_PER_CLK);

begin

    m2a_pedet_synchro: entity work.meta_sync
     port map(
        async_input => m2a_pedet,
        clk => clk,
        sycnd_output => m2a_pedet_sync
    );

    m2b_pedet_synchro: entity work.meta_sync
    port map(
       async_input => m2b_pedet,
       clk => clk,
       sycnd_output => m2b_pedet_sync
   );



    pca9506_top_inst: entity work.pca9506_top
     generic map(
        i2c_addr => i2c_io_addr
    )
     port map(
        clk => clk,
        reset => reset,
        scl => sp5_i2c_scl,
        scl_o => sp5_i2c_scl_o,
        scl_oe => sp5_i2c_scl_oe,
        sda => sp5_i2c_sda,
        sda_o => sp5_i2c_sda_o,
        sda_oe => sp5_i2c_sda_oe,
        inband_reset => not a0_ok,  -- shove this thing in reset when we're not in A0
        io => io,
        io_oe => io_oe,
        io_o => io_o,
        int_n => open
    );

    -- M.2A
    m2a_hsc_en <= io_o(0)(4) when io_oe(0)(4) else '0';
    pcie_clk_buff_m2a_oe_l <= io_o(0)(4) when io_oe(0)(4) else 'Z';  -- enable clock when power enabled
    io(0)(0) <= m2a_prsnt_l;
    -- not PEDET becomes emils
    io(0)(3) <= not m2a_pedet_sync;

    -- M.2B
    m2b_hsc_en <= io_o(1)(4) when io_oe(1)(4) else '0';
    pcie_clk_buff_m2b_oe_l <= io_o(1)(4) when io_oe(1)(4) else 'Z';  -- enable clock when power enabled
    io(1)(0) <= m2b_prsnt_l;
    -- not PEDET becomes emils
    io(1)(3) <= not m2b_pedet_sync;

    m2a_power_en <= io_o(0)(4) when io_oe(0)(4) else '0';
    -- U.2 and M.2 devices require 100us minimum reference clock stable before PERST# inactive (Tperst-clk), 
    -- and 100ms minimum power stable to PERST# inactive (Tpvperl). 
    m2a_perst_oneshot: entity work.perst_oneshot
     generic map(
        PERST_CNTS => PERST_CNTS
     )
     port map(
        clk => clk,
        reset => reset,
        power_en => m2a_power_en,
        perst_l => m2a_perst_l
    );
    m2b_power_en <= io_o(1)(4) when io_oe(1)(4) else '0';
    
    m2b_perst_oneshot: entity work.perst_oneshot
     generic map(
        PERST_CNTS => PERST_CNTS
    )
     port map(
        clk => clk,
        reset => reset,
        power_en => m2a_power_en,
        perst_l => m2b_perst_l
    );

    -- T6
    t6_power_en <= io_o(2)(4) when io_oe(0)(4) else '0';
    io(2)(3) <= '1';  -- PEDET for T6
    io(2)(0) <= '1'; -- PRSNT_L for T6
    t6_perst_l <= io_o(2)(4) when io_oe(2)(4) else '0';

    -- Backplane connected switch
    -- TODO: this stuff is likely not totally correct
    pcie_aux_power_en <= io_o(3)(4) when io_oe(3)(4) else '0'; -- TODO: oneshot?
    pcie_perst_oneshot: entity work.perst_oneshot
     generic map(
        PERST_CNTS => PERST_CNTS
    )
     port map(
        clk => clk,
        reset => reset,
        power_en => pcie_aux_power_en,
        perst_l => pcie_aux_rsw_perst_l
    );
    io(3)(0) <= pcie_aux_rsw_prsnt_buff_l;
    pcie_clk_buff_rsw_oe_l <= pcie_aux_rsw_prsnt_buff_l;  -- Is this right?



end rtl;