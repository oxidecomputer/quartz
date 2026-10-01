-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.axil8x32_pkg;
use work.i2c_ctrl_vc_pkg.all;
use work.i2c_pca9506ish_sim_pkg.all;

-- One hotplug subsystem with the second NIC slot enabled, driven over I2C the
-- way the SP5 drives it. The slot pins are exposed as signals for the tb to
-- read and poke via external names.
entity sp5_hotplug_th is
end entity;

architecture th of sp5_hotplug_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal i2c_bus_scl : std_logic;
    signal i2c_bus_sda : std_logic;
    signal scl_o, scl_oe, sda_o, sda_oe : std_logic;
    signal axi_if : axil8x32_pkg.axil_t;

    signal int_n : std_logic;
    signal a0_ok : std_logic := '1';

    -- NIC slot, bank 2
    signal t6_power_en : std_logic;
    signal t6_perst_l : std_logic;
    signal t6_faulted : std_logic := '0';
    signal t6_prsnt_l : std_logic := '0';
    -- Second NIC slot, bank 4
    signal nic2_power_en : std_logic;
    signal nic2_perst_l : std_logic;
    signal nic2_faulted : std_logic := '0';
    signal nic2_prsnt_l : std_logic := '0';

    -- The M.2 and backplane slots are not under test; park their inputs.
    signal m2a_hsc_en, m2a_perst_l, pcie_clk_buff_m2a_oe_l : std_logic;
    signal m2b_hsc_en, m2b_perst_l, pcie_clk_buff_m2b_oe_l : std_logic;
    signal pcie_aux_rsw_perst_l, pcie_clk_buff_rsw_oe_l : std_logic;

begin

    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    axi_lite_master_inst: entity vunit_lib.axi_lite_master
        generic map (
            bus_handle => bus_handle
        )
        port map (
            aclk    => clk,
            arready => axi_if.read_address.ready,
            arvalid => axi_if.read_address.valid,
            araddr  => axi_if.read_address.addr,
            rready  => axi_if.read_data.ready,
            rvalid  => axi_if.read_data.valid,
            rdata   => axi_if.read_data.data,
            rresp   => axi_if.read_data.resp,
            awready => axi_if.write_address.ready,
            awvalid => axi_if.write_address.valid,
            awaddr  => axi_if.write_address.addr,
            wready  => axi_if.write_data.ready,
            wvalid  => axi_if.write_data.valid,
            wdata   => axi_if.write_data.data,
            wstrb   => axi_if.write_data.strb,
            bvalid  => axi_if.write_response.valid,
            bready  => axi_if.write_response.ready,
            bresp   => axi_if.write_response.resp
        );

    i2c_controller_vc_inst: entity work.i2c_controller_vc
     generic map(
        i2c_ctrl_vc => i2c_ctrl_vc
    )
     port map(
        scl => i2c_bus_scl,
        sda => i2c_bus_sda
    );

    -- Open-drain resolution for the one target on the bus
    i2c_bus_scl <= scl_o when scl_oe = '1' else 'H';
    i2c_bus_sda <= sda_o when sda_oe = '1' else 'H';

    dut: entity work.sp5_hotplug_subsystem
     generic map(
        -- Keep the PERST oneshots short so the M.2 slots settle in sim time
        PERST_US_ONESHOT => 10,
        NS_PER_CLK => 8,
        NIC2_SLOT_ENABLED => true
    )
     port map(
        clk => clk,
        reset => reset,
        sp5_i2c_sda => i2c_bus_sda,
        sp5_i2c_sda_o => sda_o,
        sp5_i2c_sda_oe => sda_oe,
        sp5_i2c_scl => i2c_bus_scl,
        sp5_i2c_scl_o => scl_o,
        sp5_i2c_scl_oe => scl_oe,
        int_n => int_n,
        a0_ok => a0_ok,
        axi_if => axi_if,
        allow_backplane_pcie_clk => '0',
        m2a_pedet => '0',
        m2a_prsnt_l => '1',
        m2a_hsc_en => m2a_hsc_en,
        m2a_perst_l => m2a_perst_l,
        pcie_clk_buff_m2a_oe_l => pcie_clk_buff_m2a_oe_l,
        m2a_pwr_fault_l => '1',
        m2b_pedet => '0',
        m2b_prsnt_l => '1',
        m2b_hsc_en => m2b_hsc_en,
        m2b_perst_l => m2b_perst_l,
        pcie_clk_buff_m2b_oe_l => pcie_clk_buff_m2b_oe_l,
        m2b_pwr_fault_l => '1',
        t6_power_en => t6_power_en,
        t6_perst_l => t6_perst_l,
        t6_faulted => t6_faulted,
        t6_prsnt_l => t6_prsnt_l,
        nic2_power_en => nic2_power_en,
        nic2_perst_l => nic2_perst_l,
        nic2_faulted => nic2_faulted,
        nic2_prsnt_l => nic2_prsnt_l,
        pcie_aux_rsw_perst_l => pcie_aux_rsw_perst_l,
        pcie_aux_rsw_prsnt_buff_l => '1',
        pcie_aux_rsw_pwrflt_buff_l => '1',
        pcie_clk_buff_rsw_oe_l => pcie_clk_buff_rsw_oe_l,
        rsw_sp5_pcie_attached_buff_l => '1'
    );

end th;
