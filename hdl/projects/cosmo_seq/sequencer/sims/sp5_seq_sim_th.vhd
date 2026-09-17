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
use work.sp5_power_pkg.all;
use work.sequencer_io_pkg.all;
use work.sp5_seq_sim_pkg.all;

-- One harness for both NIC flavours: NIC_KIND picks which NIC's models are
-- instantiated, and the testbenches (sp5_seq_sim_tb for the T6, versal_seq_sim_tb
-- for the Versal) each set it. Both NICs' pin records exist as signals so the
-- testbenches can reach them; the absent NIC's are left at their tie-off values.
entity sp5_seq_sim_th is
    generic (
        NIC_KIND : nic_kind_t := NIC_T6
    );
end entity;

architecture th of sp5_seq_sim_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal sp5_seq_pins : sp5_seq_pins_t;
    signal nic_seq_pins : nic_seq_pins_t := (
        cld_rst_l => 'Z',
        perst_l => 'Z',
        eeprom_wp_l => 'Z',
        eeprom_wp_buffer_oe_l => 'Z',
        flash_wp_l => 'Z',
        nic_mfg_mode_l => 'Z',
        ext_rst_l => '1',
        nic_pcie_clk_buff_oe_l => 'Z',
        sp5_mfg_mode_l => '0'
        );
    signal group_a_pins : group_a_power_t;
    signal group_b_pins : group_b_power_t;
    signal group_c_pins : group_c_power_t;
    signal early_power_pins : early_power_t :=(
        fan_central_hsc_pg => '1',
        fan_east_hsc_pg => '1',
        fan_fail => '0',
        fan_west_hsc_pg => '1',
        fan_central_hsc_disable => 'Z',
        fan_east_hsc_disable => 'Z',
        fan_west_hsc_disable => 'Z'
        );
    signal reg_alert_l_pins : seq_power_alert_pins_t := (
        pwr_cont4_to_fpga1_alert_l => '1',
        smbus_fan_central_hsc_to_fpga1_alert_l => '1',
        smbus_fan_east_hsc_to_fpga1_alert_l => '1',
        smbus_fan_west_hsc_to_fpga1_alert_l => '1',
        smbus_ibc_to_fpga1_alert_l => '1',
        smbus_m2_hsc_to_fpga1_alert_l => '1',
        smbus_nic_hsc_to_fpga1_alert_l => '1',
        smbus_v12_ddr5_abcdef_hsc_to_fpga1_alert => '1',
        smbus_v12_ddr5_ghijkl_hsc_to_fpga1_alert => '1',
        smbus_v12_mcio_a0hp_hsc_to_fpga1_alert_l => '1',
        main_hsc_to_fpga1_alert_l => '1',
        vr_v1p8_sys_to_fpga1_alert_l => '1',
        vr_v3p3_sys_to_fpga1_alert_l => '1',
        vr_v5p0_sys_to_fpga1_alert_l => '1',
        pwr_cont1_to_fpga1_alert_l => '1',
        v0p96_nic_to_fpga1_alert_l => '1',
        pwr_cont2_to_fpga1_alert_l => '1',
        pwr_cont3_to_fpga1_alert_l => '1'
    );
    signal ddr_bulk_pins : ddr_bulk_power_t;
    signal nic_rails_pins : nic_power_t := nic_power_absent;
    signal a0_ok : std_logic;
    signal a0_idle : std_logic;
    signal sp5_nic_perst_l : std_logic := '1';
    signal sp5_nic_chb_perst_l : std_logic := '1';
    signal axi_if : axil8x32_pkg.axil_t;
    signal nic_dbg_pins : nic_debug_if;

    -- Versal side
    signal versal_rails_pins : versal_power_t := versal_power_absent;
    signal versal_boot_pins : versal_boot_t := versal_boot_absent;
    signal versal_pcie_pins : versal_pcie_t := (
        cha => (perst_l => 'Z', prsnt_l => '0', pwren_l => '0', clk_buff_oe_l => 'Z'),
        chb => (perst_l => 'Z', prsnt_l => '0', pwren_l => '0', clk_buff_oe_l => 'Z')
        );
    signal versal_held_in_reset : std_logic;
    signal flash_owned_by_seq : std_logic;
    -- Hash engine stand-in. The testbench sets how long a measurement takes
    -- and whether it fails; the handshake itself is modelled here.
    signal hash_req : std_logic;
    signal hash_ack : std_logic := '0';
    signal hash_err : std_logic := '0';
    signal hash_model_time : time := 20 us;
    signal hash_model_fail : boolean := false;
    signal hash_requests : natural := 0;

begin

   -- set up a fastish clock for the sim env
   -- and release reset after a bit of time
   clk   <= not clk after 4 ns;
   reset <= '0' after 200 ns;
   -- instantiate the sequencer
   dut: entity work.sp5_sequencer
    generic map(
       CNTS_P_MS => 100,
       NIC_KIND => NIC_KIND
   )
    port map(
       clk => clk,
       reset => reset,
       axi_if => axi_if,
       a0_ok => a0_ok,
       a0_idle => a0_idle,
       early_power_pins => early_power_pins,
       ddr_bulk_pins => ddr_bulk_pins,
       group_a_pins => group_a_pins,
       group_b_pins => group_b_pins,
       group_c_pins => group_c_pins,
       sp5_seq_pins => sp5_seq_pins,
       nic_rails_pins => nic_rails_pins,
       nic_seq_pins => nic_seq_pins,
       versal_rails_pins => versal_rails_pins,
       versal_boot_pins => versal_boot_pins,
       versal_pcie_pins => versal_pcie_pins,
       versal_held_in_reset => versal_held_in_reset,
       flash_owned_by_seq => flash_owned_by_seq,
       hash_req => hash_req,
       hash_ack => hash_ack,
       hash_err => hash_err,
       version_id => "01",
       nic_dbg_pins => nic_dbg_pins,
       sp5_nic_perst_l => sp5_nic_perst_l,
       sp5_nic_chb_perst_l => sp5_nic_chb_perst_l,
       irq_l_out => open,
       reg_alert_l_pins => reg_alert_l_pins
   );

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
   -- rails here
   grpa_pwr_v1p5_rtc: entity work.rail_model
    generic map(
       actor_name => "grpa_pwr_v1p5_rtc"
    )
    port map(
       clk => clk,
       reset => reset,
       rail => group_a_pins.pwr_v1p5_rtc
   );
   grpa_v3p3_sp5_a1: entity work.rail_model
   generic map(
      actor_name => "grpa_v3p3_sp5_a1"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => group_a_pins.v3p3_sp5_a1
   );
   grpa_v1p8_sp5_a1: entity work.rail_model
   generic map(
      actor_name => "grpa_v1p8_sp5_a1"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => group_a_pins.v1p8_sp5_a1
   );
   
   grpb_v1p1_sp5: entity work.rail_model
   generic map(
      actor_name => "grpb_v1p1_sp5"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => group_b_pins.v1p1_sp5
   );
   grpc_vddio_sp5_a0: entity work.rail_model
   generic map(
      actor_name => "grpc_vddio_sp5_a0"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => group_c_pins.vddio_sp5_a0
   );
   grpc_vddcr_cpu1: entity work.rail_model
   generic map(
      actor_name => "grpc_vddcr_cpu1"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => group_c_pins.vddcr_cpu1
   );
   grpc_vddcr_cpu0: entity work.rail_model
   generic map(
      actor_name => "grpc_vddcr_cpu0"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => group_c_pins.vddcr_cpu0
   );
   grpc_vddcr_soc: entity work.rail_model
   generic map(
      actor_name => "grpc_vddcr_soc"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => group_c_pins.vddcr_soc
   );
   rail_ddr_abcdef_hsc: entity work.rail_model
   generic map(
      actor_name => "rail_ddr_abcdef_hsc"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => ddr_bulk_pins.abcdef_hsc
   );
   rail_ddr_ghijkl_hsc: entity work.rail_model
   generic map(
      actor_name => "rail_ddr_ghijkl_hsc"
   )
   port map(
      clk => clk,
      reset => reset,
      rail => ddr_bulk_pins.ghijkl_hsc
   );

   sp5_model_inst: entity work.sp5_model
    port map(
       clk => clk,
       reset => reset,
       sp5_pins => sp5_seq_pins
   );
   t6: if NIC_KIND = NIC_T6 generate
       nic_model_inst: entity work.nic_model
        generic map(
           actor_name => "nic_model"
        )
        port map(
           clk => clk,
           reset => reset,
           nic_rails => nic_rails_pins
       );
   end generate;

   versal: if NIC_KIND = NIC_VERSAL generate
       versal_v3p3: entity work.rail_model
       generic map(actor_name => "versal_v3p3")
       port map(clk => clk, reset => reset, rail => versal_rails_pins.v3p3);
       versal_v1p8: entity work.rail_model
       generic map(actor_name => "versal_v1p8")
       port map(clk => clk, reset => reset, rail => versal_rails_pins.v1p8);
       versal_v1p5: entity work.rail_model
       generic map(actor_name => "versal_v1p5")
       port map(clk => clk, reset => reset, rail => versal_rails_pins.v1p5);
       versal_v1p5_avccaux: entity work.rail_model
       generic map(actor_name => "versal_v1p5_avccaux")
       port map(clk => clk, reset => reset, rail => versal_rails_pins.v1p5_avccaux);
       versal_v1p4: entity work.rail_model
       generic map(actor_name => "versal_v1p4")
       port map(clk => clk, reset => reset, rail => versal_rails_pins.v1p4);
       versal_v1p1: entity work.rail_model
       generic map(actor_name => "versal_v1p1")
       port map(clk => clk, reset => reset, rail => versal_rails_pins.v1p1);
       versal_v0p88: entity work.rail_model
       generic map(actor_name => "versal_v0p88")
       port map(clk => clk, reset => reset, rail => versal_rails_pins.v0p88);
       versal_v0p8_vccint: entity work.rail_model
       generic map(actor_name => "versal_v0p8_vccint")
       port map(clk => clk, reset => reset, rail => versal_rails_pins.v0p8_vccint);
       -- The two transceiver rails have no enable of their own; they cascade
       -- off the group that brings them up.
       versal_v0p92_avcc: entity work.cascade_rail_model
       port map(clk => clk, reset => reset, upstream_pg => versal_rails_pins.v0p88.pg, rail => versal_rails_pins.v0p92_avcc);
       versal_v1p2_avtt: entity work.cascade_rail_model
       port map(clk => clk, reset => reset, upstream_pg => versal_rails_pins.v1p5.pg, rail => versal_rails_pins.v1p2_avtt);

       -- Four-phase handshake as hash_engine_top does it: acknowledge some
       -- time after the request, hold it until the request drops.
       hash_model: process
       begin
           wait until hash_req = '1';
           hash_requests <= hash_requests + 1;
           wait for hash_model_time;
           if hash_req = '1' then
               hash_err <= '1' when hash_model_fail else '0';
               hash_ack <= '1';
               wait until hash_req = '0';
               hash_ack <= '0';
           end if;
       end process;

       versal_model_inst: entity work.versal_model
        generic map(
           actor_name => "versal_model"
        )
        port map(
           clk => clk,
           reset => reset,
           hsc_12v => versal_rails_pins.hsc_12v,
           hsc_5v => versal_rails_pins.hsc_5v,
           boot => versal_boot_pins
       );
   end generate;

end th;