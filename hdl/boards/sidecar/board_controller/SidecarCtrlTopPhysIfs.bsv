package SidecarCtrlTopPhysIfs;

interface PhysicalSpiPins;
    (* prefix = "" *)
    method Action   spi_sp_to_fpga_cs0_l((* port="spi_sp_to_fpga_cs0_l" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   spi_sp_to_fpga_sck((* port="spi_sp_to_fpga_sck" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   spi_sp_to_fpga_mosi((* port="spi_sp_to_fpga_mosi" *) Bit#(1) val);
    method Bit#(1)  sp_to_fpga_spi_miso_r;
endinterface

interface PhysicalSmuPins;
    method Bit#(1)  fpga_to_smu_reset_l;
    method Bit#(1)  fpga_to_smu_mgmt_clk_en_l;
    (* prefix = "" *)
    method Action   ldo_to_fpga_smu_pg((* port="ldo_to_fpga_smu_pg" *) Bit#(1) val);
    method Bit#(1)  fpga_to_ldo_smu_en;
    method Bit#(1)  fpga_to_smu_tf_clk_en_l;
endinterface

interface PhysicalMgmtNetworkPins;
    method Bit#(1)  fpga_to_mgmt_reset_l;
    (* prefix = "" *)
    method Action   mgmt_to_fpga_temp_therm_l((* port="mgmt_to_fpga_temp_therm_l" *) Bit#(1) val);
    method Bit#(1)  fpga_to_vr_v1p0_mgmt_en;
    method Bit#(1)  fpga_to_ldo_v1p2_mgmt_en;
    method Bit#(1)  fpga_to_ldo_v2p5_mgmt_en;
    (* prefix = "" *)
    method Action   vr_v1p0_mgmt_to_fpga_pg((* port="vr_v1p0_mgmt_to_fpga_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   ldo_to_fpga_v1p2_mgmt_pg((* port="ldo_to_fpga_v1p2_mgmt_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   ldo_to_fpga_v2p5_mgmt_pg((* port="ldo_to_fpga_v2p5_mgmt_pg" *) Bit#(1) val);
endinterface

interface PhysicalFanPins;
    method Bit#(1)  fpga_to_fan0_led_l;
    method Bit#(1)  fpga_to_fan1_led_l;
    method Bit#(1)  fpga_to_fan2_led_l;
    method Bit#(1)  fpga_to_fan3_led_l;
    method Bit#(1)  fpga_to_fan0_hsc_en;
    method Bit#(1)  fpga_to_fan1_hsc_en;
    method Bit#(1)  fpga_to_fan2_hsc_en;
    method Bit#(1)  fpga_to_fan3_hsc_en;
    (* prefix = "" *)
    method Action   fan0_hsc_to_fpga_pg((* port="fan0_hsc_to_fpga_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   fan1_hsc_to_fpga_pg((* port="fan1_hsc_to_fpga_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   fan2_hsc_to_fpga_pg((* port="fan2_hsc_to_fpga_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   fan3_hsc_to_fpga_pg((* port="fan3_hsc_to_fpga_pg" *) Bit#(1) val);
endinterface

interface PhysicalFrontIoPins;
    method Bit#(1)  fpga_to_front_io_hsc_en;
    (* prefix = "" *)
    method Action   front_io_hsc_to_fpga_pg((* port="front_io_hsc_to_fpga_pg" *) Bit#(1) val);
endinterface

interface PhysicalDebugPins;
    method Bit#(1)  fpga_debug0;
    method Bit#(1)  fpga_debug1;
    method Bit#(1)  fpga_led0;
endinterface

// Temporarily making these inputs so they don't mess with their i2c bus
interface PhysicalSPPins;
    method Bit#(4)  tf_to_fpga_irq;
    (* prefix = "" *)
    method Action   i2c_south1_scl((* port="i2c_south1_scl" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   i2c_south1_sda((* port="i2c_south1_sda" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   i2c_south1_sda_o_r((* port="i2c_south1_sda_o_r" *) Bit#(1) val);
endinterface

interface TofinoControlOutputs;
    // en
    method Bit#(1)  fpga_to_vr_tf_vdd1p8_en;
    method Bit#(1)  fpga_to_vr_tf_vddcore_en;
    method Bit#(1)  fpga_to_ldo_v0p75_tf_pcie_en;
    method Bit#(1)  fpga_to_vr_tf_vddx_en; // enables both 1.5VDDA and VDDT
    method Bit#(1)  fpga_to_vr_tf_vdda1p8_en;
    // resets
    method Bit#(1)  fpga_to_tf_pwron_rst_l;
    method Bit#(1)  fpga_to_tf_pcie_rst_l;
    method Bit#(1)  fpga_to_tf_core_rst_l;
    // misc
    method Bit#(1)  tf_pg_led;
    method Bit#(1)  fpga_to_tf_test_core_tap_l;
    method Bit#(4)  fpga_to_tf_test_jtsel;
    method Bit#(1)  fpga_to_tf_spi_wp_l;
endinterface

interface TofinoControlInputs;
    // pg
    (* prefix = "" *)
    method Action   vr_tf_v1p8_to_fpga_vdd1p8_pg((* port="vr_tf_v1p8_to_fpga_vdd1p8_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   vr_tf_vddcore_to_fpga_pg((* port="vr_tf_vddcore_to_fpga_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   ldo_to_fpga_v0p75_tf_pcie_pg((* port="ldo_to_fpga_v0p75_tf_pcie_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   vr_tf_vddx_to_fpga_vddt_pg((* port="vr_tf_vddx_to_fpga_vddt_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   vr_tf_vddx_to_fpga_vdda15_pg((* port="vr_tf_vddx_to_fpga_vdda15_pg" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   vr_tf_v1p8_to_fpga_vdda1p8_pg((* port="vr_tf_v1p8_to_fpga_vdda1p8_pg" *) Bit#(1) val);
    // fault
    (* prefix = "" *)
    method Action   vr_tf_v1p8_to_fpga_fault((* port="vr_tf_v1p8_to_fpga_fault" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   vr_tf_vddcore_to_fpga_fault((* port="vr_tf_vddcore_to_fpga_fault" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   vr_tf_vddx_to_fpga_fault((* port="vr_tf_vddx_to_fpga_fault" *) Bit#(1) val);
    // vid
    (* prefix = "" *)
    method Action   tf_to_fpga_vid((* port="tf_to_fpga_vid" *) Bit#(3) val);
    // vr hot
    (* prefix = "" *)
    method Action   vr_tf_vddcore_to_fpga_vrhot_l((* port="vr_tf_vddcore_to_fpga_vrhot_l" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   vr_tf_vddx_to_fpga_vrhot((* port="vr_tf_vddx_to_fpga_vrhot" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   vr_tf_v1p8_to_fpga_vr_hot_l((* port="vr_tf_v1p8_to_fpga_vr_hot_l" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   tf_to_fpga_temp_therm_l((* port="tf_to_fpga_temp_therm_l" *) Bit#(1) val);
endinterface

interface PhysicalTofinoControlPins;
    (* prefix = "" *)
    interface TofinoControlOutputs outputs;
    (* prefix = "" *)
    interface TofinoControlInputs inputs;

    // Temporarily setting these to inputs until we are ready to use them
    (* prefix = "" *)
    method Action   i2c_fpga_to_tf_sda_o_r((* port="i2c_fpga_to_tf_sda_o_r" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   i2c_fpga_to_tf_sda((* port="i2c_fpga_to_tf_sda" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   i2c_fpga_to_tf_scl((* port="i2c_fpga_to_tf_scl" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   i2c_tf_to_fpga_0_sda((* port="i2c_tf_to_fpga_0_sda" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   i2c_tf_to_fpga_0_scl((* port="i2c_tf_to_fpga_0_scl" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   i2c_tf_to_fpga_1_sda((* port="i2c_tf_to_fpga_1_sda" *) Bit#(1) val);
    (* prefix = "" *)
    method Action   i2c_tf_to_fpga_1_scl((* port="i2c_tf_to_fpga_1_scl" *) Bit#(1) val);
endinterface

endpackage: SidecarCtrlTopPhysIfs