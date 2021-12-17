package SidecarCtrlTopIOWrapper;

// BSV Core
import Clocks::*;
import Connectable::*;
import GetPut::*;

// Oxide
import Blinky::*;
import Tofino2PowerCtrl::*;
import Tofino2PowerCtrlSync::*;
import SidecarCtrlRegs::*;
import SidecarSeqRegs::*;
import SidecarCtrlTopPhysIfs::*;
import SpiDecode::*;
import Strobe::*;
import UART::*;


(* always_enabled *)
interface Top;
    (* prefix = "" *)
    interface PhysicalSpiPins phys_spi;
    (* prefix = "" *)
    interface PhysicalSmuPins phys_smu;
    (* prefix = "" *)
    interface PhysicalMgmtNetworkPins phys_mgmt;
    (* prefix = "" *)
    interface PhysicalFanPins phys_fans;
    (* prefix = "" *)
    interface PhysicalFrontIoPins phys_front_io;
    (* prefix = "" *)
    interface PhysicalTofinoControlPins phys_tf_ctrl;
    (* prefix = "" *)
    interface PhysicalDebugPins phys_dbg;
    (* prefix = "" *)
    interface PhysicalSPPins phys_sp;
endinterface

module mkSidecarCtrlTopIOWrapper (Top);
    Clock cur_clk       <- exposeCurrentClock();
    Reset reset_sync    <- mkAsyncResetFromCR(2, cur_clk);

    let tf2parameters =
        Tofino2SequenceControlParameters {
            power_good_timeout: 10,
            power_good_delay: 1,
            vid_delay: 15  ,
            pcie_delay: 190
        };

    Serializer debug_uart_tx <- mkSerializer();

    SidecarRegIF regs   <- mkSidecarRegs();

    TofinoControlSync tf_ctrl_pin   <- mkTofinoControlSync();
    Tofino2SequenceControl tofino_sequence_control <- mkTofino2SequenceControl(tf2parameters);

    mkConnection(tf_ctrl_pin, tofino_sequence_control);

    Reg#(Bit#(1)) tie_low   <- mkReg(0);
    Reg#(Bit#(1)) tie_high  <- mkReg(1);
    Reg#(UInt#(12)) smu_release_count <- mkReg(1);
    Reg#(UInt#(12)) mgmt_release_count <- mkReg(1);
    Reg#(UInt#(16)) pulse_1_ms_cntr <- mkReg(0);
    Reg#(Bit#(1)) tofino_en_prev <-mkReg(0);
    Wire#(Bool) tofino_en_redge <- mkWire();
    Wire#(Bool) tofino_en_fedge <- mkWire();

    Reg#(Bit#(1)) ldo_to_fpga_smu_pg_r <- mkReg(0);
    Reg#(Bit#(1)) vr_v1p0_mgmt_to_fpga_pg_r <- mkReg(0);

    Blinky#(100_000_000) blinky  <- Blinky::mkBlinky(); // 1s on, 1s off

    SpiPeripheralSync spi_sync  <- mkSpiPeripheralPinSync();
    SpiPeripheralPhy phy        <- mkSpiPeripheralPhy();
    SpiDecodeIF decode          <- mkSpiRegDecode();

    // Output of spi synchronizer to SPI PHY block (just pins interface)
    mkConnection(spi_sync.syncd_pins, phy.pins);
    // Output of the SPI PHY block to the SPI decoder block (client/server interface)
    mkConnection(decode.spi_byte, phy.decoder_if);
    // Output of the SPI decoder block to the registers block
    mkConnection(decode.reg_con, regs.decoder_if);

    (* fire_when_enabled *)
    rule do_tick_strobes;
        if (pulse_1_ms_cntr == 50_000) begin
            tofino_sequence_control.tick_1ms.send();
            pulse_1_ms_cntr <= 0;
        end else begin
            pulse_1_ms_cntr <= pulse_1_ms_cntr + 1;
        end
    endrule

    (* fire_when_enabled *)
    rule do_smu_reset_countdown(pulse_1_ms_cntr == 0 && smu_release_count > 0 && ldo_to_fpga_smu_pg_r == 1);
        smu_release_count <= smu_release_count - 1;
    endrule

    (* fire_when_enabled *)
    rule do_mgmt_reset_countdown(pulse_1_ms_cntr == 0 && mgmt_release_count > 0 && vr_v1p0_mgmt_to_fpga_pg_r == 1);
        mgmt_release_count <= mgmt_release_count - 1;
    endrule

    (* fire_when_enabled *)
    rule do_tofino_power_up(tofino_en_redge);
        tofino_sequence_control.start_power_up();
    endrule

    (* fire_when_enabled *)
    rule do_tofino_en_edge_detection;
        tofino_en_prev <= regs.tofino_en_reg.en;
        tofino_en_redge <= (tofino_en_prev == 0) && (regs.tofino_en_reg.en == 1);
        tofino_en_fedge <= (tofino_en_prev == 1) && (regs.tofino_en_reg.en == 0);
    endrule

    (* fire_when_enabled *)
    rule do_tofino_power_down(tofino_en_fedge);
        tofino_sequence_control.start_power_down();
    endrule

    (* fire_when_enabled *)
    rule do_tofino_state_update;
        regs.set_tf2_seq_state({'0, pack(tofino_sequence_control.regs.state)});
        regs.set_tf2_seq_error({'0, pack(tofino_sequence_control.regs.error)});
        regs.set_tf2_power_enables(tofino_sequence_control.regs.ens);
        regs.set_tf2_power_goods(tofino_sequence_control.regs.pgs);
        regs.set_tf2_vid(tofino_sequence_control.regs.vid);
    endrule

    // Map real pins onto the SPI Peripheral pins
    interface PhysicalSpiPins phys_spi;
        method spi_sp_to_fpga_cs0_l     = spi_sync.in_pins.csn;
        method spi_sp_to_fpga_sck       = spi_sync.in_pins.sclk;
        method spi_sp_to_fpga_mosi      = spi_sync.in_pins.copi;
        method sp_to_fpga_spi_miso_r    = spi_sync.in_pins.cipo;
    endinterface

    interface PhysicalDebugPins phys_dbg;
        method fpga_debug0  = tofino_sequence_control.pcie_rst_l;
        method fpga_debug1  = tofino_sequence_control.pwron_rst_l;
        method fpga_led0    = blinky.led[0];
    endinterface

    interface PhysicalSmuPins phys_smu;
        method Action ldo_to_fpga_smu_pg(Bit#(1) val) = ldo_to_fpga_smu_pg_r._write(val);
        method fpga_to_smu_reset_l          = pack(smu_release_count == 0);
        method fpga_to_smu_mgmt_clk_en_l    = ~pack(mgmt_release_count == 0);
        method fpga_to_ldo_smu_en           = tie_high._read;
        method fpga_to_smu_tf_clk_en_l      = ~pack(smu_release_count == 0);
    endinterface

    interface PhysicalMgmtNetworkPins phys_mgmt;
        method Action vr_v1p0_mgmt_to_fpga_pg(Bit#(1) val) = vr_v1p0_mgmt_to_fpga_pg_r._write(val);
        method fpga_to_mgmt_reset_l     = pack(mgmt_release_count == 0);
        method fpga_to_vr_v1p0_mgmt_en  = tie_high._read;
        method fpga_to_ldo_v1p2_mgmt_en = tie_high._read;
        method fpga_to_ldo_v2p5_mgmt_en = tie_high._read;
    endinterface

    interface PhysicalFanPins phys_fans;
        method fpga_to_fan0_led_l   = tie_high._read;
        method fpga_to_fan1_led_l   = tie_high._read;
        method fpga_to_fan2_led_l   = tie_high._read;
        method fpga_to_fan3_led_l   = tie_high._read;
        method fpga_to_fan0_hsc_en  = tie_low._read;
        method fpga_to_fan1_hsc_en  = tie_low._read;
        method fpga_to_fan2_hsc_en  = tie_low._read;
        method fpga_to_fan3_hsc_en  = tie_low._read;
    endinterface

    interface PhysicalFrontIoPins phys_front_io;
        method fpga_to_front_io_hsc_en  = tie_low._read;
    endinterface

    interface PhysicalTofinoControlPins phys_tf_ctrl;
        interface TofinoControlOutputs outputs;
            method fpga_to_vr_tf_vdd1p8_en =
                pack(tofino_sequence_control.vdd18.enabled);
            method fpga_to_vr_tf_vddcore_en =
                pack(tofino_sequence_control.vddcore.enabled);
            method fpga_to_ldo_v0p75_tf_pcie_en =
                pack(tofino_sequence_control.vddpcie.enabled);
            method fpga_to_vr_tf_vddx_en        = 
                pack(tofino_sequence_control.vddt.enabled); // also enables vdda15
            method fpga_to_vr_tf_vdda1p8_en     = 
                pack(tofino_sequence_control.vdda18.enabled);
            method fpga_to_tf_core_rst_l        = 
                tofino_sequence_control.core_rst_l;
            method fpga_to_tf_pwron_rst_l       = 
                tofino_sequence_control.pwron_rst_l;
            method fpga_to_tf_pcie_rst_l        = 
                tofino_sequence_control.pcie_rst_l;
            method tf_pg_led                    = 
                tofino_sequence_control.tofino_power_good;
            method fpga_to_tf_test_core_tap_l   = 1;
            method fpga_to_tf_test_jtsel        = 0;
        endinterface
        interface inputs = tf_ctrl_pin.in_pins;
    endinterface

    interface PhysicalSPPins phys_sp;
        method tf_to_fpga_irq = 0;
    endinterface

endmodule

endpackage: SidecarCtrlTopIOWrapper