-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Cosmo Sequencer FPGA targeting the Spartan-7

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axil8x32_pkg;
use work.pca9545_pkg.all;

entity sp_i2c_subsystem is
    port(
        clk : in std_logic;
        reset : in std_logic;

        axi_if : view axil8x32_pkg.axil_target;
        in_a0 : in std_logic;

        sp_scl : in std_logic;
        sp_scl_o : out std_logic;
        sp_scl_oe : out std_logic;
        sp_sda : in std_logic;
        sp_sda_o : out std_logic;
        sp_sda_oe : out std_logic;
        i2c_mux1_sel : out std_logic_vector(1 downto 0);
        i2c_mux2_sel : out std_logic_vector(1 downto 0);
        i2c_mux3_sel : out std_logic_vector(1 downto 0);

    );
end sp_i2c_subsystem;

architecture rtl of sp_i2c_subsystem is

    type io_i2c_addr_t is array (natural range <>) of std_logic_vector(6 downto 0);
    type mux_sel_t is array (natural range <>) of std_logic_vector(1 downto 0);

    constant mux_i2c_addr:  io_i2c_addr_t(0 to 2) := (
        b"1110_000",  -- Mux 1: M.2 A/B
        b"1110_001",  -- Mux 2: APML / SEC
        b"1110_010"   -- Mux 3: Fan VPD / NIC Therm
    );
    signal sp_tgt_scl : std_logic_vector(mux_i2c_addr'range);
    signal sp_tgt_scl_o : std_logic_vector(mux_i2c_addr'range);
    signal sp_tgt_scl_oe : std_logic_vector(mux_i2c_addr'range);
    signal sp_tgt_sda : std_logic_vector(mux_i2c_addr'range);
    signal sp_tgt_sda_o : std_logic_vector(mux_i2c_addr'range);
    signal sp_tgt_sda_oe : std_logic_vector(mux_i2c_addr'range);
    signal mux_is_active : std_logic_vector(mux_i2c_addr'range);
    signal mux_sel : mux_sel_t(mux_i2c_addr'range);
    signal mux_reset : std_logic;
    constant deselected : std_logic_vector(1 downto 0) := "11";

begin

    regs: entity work.sp_i2c_subsystem_regs
     port map(
        clk => clk,
        reset => reset,
        axi_if => axi_if,
        main_reset => mux_reset
    );

     -------------------------------------
    -- SP I2C STUFF
    -------------------------------------
    -- i2c breakout phy consolidator for sp i2c muxes
    sp_i2c_phy_consolidator_inst: entity work.i2c_phy_consolidator
     generic map(
        TARGET_NUM => mux_i2c_addr'length
    )
     port map(
        clk => clk,
        reset => reset,
        scl => sp_scl,
        scl_o => sp_scl_o,
        scl_oe => sp_scl_oe,
        sda => sp_sda,
        sda_o => sp_sda_o,
        sda_oe => sp_sda_oe,
        tgt_scl => sp_tgt_scl,
        tgt_scl_o => sp_tgt_scl_o,
        tgt_scl_oe => sp_tgt_scl_oe,
        tgt_sda => sp_tgt_sda,
        tgt_sda_o => sp_tgt_sda_o,
        tgt_sda_oe => sp_tgt_sda_oe
    );

    -- 3 muxes here
    mux_gen: for i in mux_i2c_addr'range generate
        pca9545ish_top_inst: entity work.pca9545ish_top
         generic map(
            i2c_addr => mux_i2c_addr(i)
        )
         port map(
            clk => clk,
            reset => reset,
            mux_reset => mux_reset,
            allowed_to_enable => allowed_to_enable(mux_is_active, i),
            mux_is_active => mux_is_active(i),
            scl => sp_tgt_scl(i),
            scl_o => sp_tgt_scl_o(i),
            scl_oe => sp_tgt_scl_oe(i),
            sda => sp_tgt_sda(i),
            sda_o => sp_tgt_sda_o(i),
            sda_oe => sp_tgt_sda_oe(i),
            mux_sel => mux_sel(i)
        );
    end generate;
    
    -- Set up the mux-sels here
    -- Note that i2c_mux_1_sel was not properly isolated into the hotplug domain
    -- in hardware so we need to prevent hubris from accidentally enabling it when
    -- the domain is down. This will be OK as a workaround on the first spin and
    -- remaining boards even after the fix is in place. We're going to mask the
    -- mux_sel signal to prevent it from being driven when the domain is down.
    -- https://github.com/oxidecomputer/hardware-cosmo/issues/641
    -- The mux will still ACK, and effectively block other mux channels in this
    -- group, so this should be software transparent. TBD if we need an additional
    -- delay as the bus comes up?
    process(clk, reset)
    begin
        if reset = '1' then
            i2c_mux1_sel <= deselected;
        elsif rising_edge(clk) then
            if in_a0 then
                i2c_mux1_sel <= mux_sel(0);
            else
                i2c_mux1_sel <= deselected;
            end if;
        end if;
    end process;
    -- No workarounds needed for these:
    i2c_mux2_sel <= mux_sel(1);
    i2c_mux3_sel <= mux_sel(2);
end rtl;