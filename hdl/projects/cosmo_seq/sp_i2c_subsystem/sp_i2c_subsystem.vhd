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
        i2c_mux1_en : out std_logic;
    );
end sp_i2c_subsystem;

architecture rtl of sp_i2c_subsystem is


    signal mux_sel1_int : std_logic_vector(1 downto 0);
    -- On the schematic we have the following muxes:
    --  These are virtualized to i2c address 0x70
    --  Mux 1: CHA (bit0): M.2 A, CHB (bit1): M.2 B, CHC (bit2): N/C
    --  Mux 2: CHA (bit3): APML, CHB (bit4): SEC, CHC (bit5): N/C
    --  Mux 3: CHA (bit6): Fan VPD, CHB (bit7): NIC Therm, CHC (bit8): N/C
    -- bit9..15:
    constant mux_i2c_addr: std_logic_vector(6 downto 0) :=  b"1110_000";

    signal mux_is_active : std_logic;
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
    oximux16_top_inst: entity work.oximux16_top
     generic map(
        i2c_addr => mux_i2c_addr
    )
     port map(
        clk => clk,
        reset => reset,
        mux_reset => mux_reset,
        allowed_to_enable => '1',
        mux_is_active => mux_is_active,
        scl => sp_scl,
        scl_o => sp_scl_o,
        scl_oe => sp_scl_oe,
        sda => sp_sda,
        sda_o => sp_sda_o,
        sda_oe => sp_sda_oe,
        -- this is a terminology mismatch, because the schematic used
        -- 1 indexing and we use zero indexing in the IP.
        mux0_sel => mux_sel1_int, -- see power workaround below
        mux1_sel => i2c_mux2_sel,
        mux2_sel => i2c_mux3_sel,
        mux3_sel => open, -- un-used on this i2c bus
        mux4_sel => open -- un-used on this i2c bus
    );
    
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
    -- 
    -- This logic retains the masking for versions of the board without the
    -- translator control. Outputing to the control pin is safe on older versions
    -- as the pin is unused.
    process(clk, reset)
    begin
        if reset = '1' then
            i2c_mux1_sel <= deselected;
            i2c_mux1_en <= '0';
        elsif rising_edge(clk) then
            if in_a0 then
                i2c_mux1_sel <= mux_sel1_int;
                i2c_mux1_en <= '1';
            else
                i2c_mux1_sel <= deselected;
                i2c_mux1_en <= '0';
            end if;
        end if;
    end process;
end rtl;
