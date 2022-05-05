package AllEnable;

import Connectable::*;

// Cobalt-provided stuff
import ICE40::*;
import SPI::*;

import GimletRegs::*;

interface SpiPeripheralPinsTop;
    (* prefix = "" *)
    method Action csn((* port = "csn" *) Bit#(1) value);   // Chip select pin, always sampled
    (* prefix = "" *)
    method Action sclk((* port = "sclk" *) Bit#(1) value);  // sclk pin, always sampled
    (* prefix = "" *)
    method Action copi((* port = "copi" *) Bit#(1) data);   // Input data pin sampled on appropriate sclk detected edge

    interface Inout#(Bit#(1)) cipo; // Output pin, tri-state when not selected.
endinterface

(* always_enabled *)
interface Pins;
    (* prefix = "" *)
    method Bit#(1) seq_to_fan_hp_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_led_en_l ();
    (* prefix = "" *)
    method Bit#(1) seq_to_clk_nmr_l();
    (* prefix = "" *)
    method Bit#(1) seq_to_clk_ntest();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v0p9_a0hp_en ();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p1_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p2_enet_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p5a_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_cld_rst_l ();
    (* prefix = "" *)
    method Bit#(1) pwr_cont_nic_en0();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_ldo_v3p3_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p2_en();
    (* prefix = "" *)    
    method Bit#(1) pwr_cont_nic_en1();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_v1p5d_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_comb_pg_l();
    (* prefix = "" *)
    method Bit#(1) seq_to_nic_perst_l();
    (* prefix = "" *)
    method Bit#(1) nic_to_sp3_pwrflt_l ();
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v0p9_s5_en();
    (* prefix = "" *)
    method Bit#(1) pwr_cont_dimm_en1 ();
    (* prefix = "" *)
    method Bit#(1) pwr_cont_dimm_en0();
    (* prefix = "" *)
    method Bit#(1) pwr_cont_dimm_efgh_en0();
    (* prefix = "" *)
    method Bit#(1) seq_to_vtt_abcd_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_vtt_efgh_en ();
    (* prefix = "" *)
    method Bit#(1) seq_to_dimm_efgh_v2p5_en ();
    (* prefix = "" *)
    method Bit#(1) seq_to_dimm_abcd_v2p5_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v1p8_en ();
    (* prefix = "" *)
    method Bit#(1) seq_to_v3p3_sys_en ();
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v1p8_s5_en();
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v3p3_s5_en();
    (* prefix = "" *)
    method Bit#(1) pwr_cont1_sp3_pwrok();
    (* prefix = "" *)
    method Bit#(1) pwr_cont2_sp3_pwrok ();
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_v1p5_rtc_en();
    (* prefix = "" *)
    method Bit#(1) pwr_cont1_sp3_en();
    (* prefix = "" *)
    method Bit#(1) pwr_cont2_sp3_en ();
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_pwr_btn_l();
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_rsmrst_v3p3_l();
    (* prefix = "" *)
    method Bit#(1) seq_to_sp3_pwr_good();
    (* prefix = "" *)
    interface SpiPeripheralPinsTop spi_pins;

endinterface

(* synthesize, default_clock_osc="clk50m" *)
module mkGimletPowerSeqTop (Pins);

    Reg#(Bit#(1)) high_reg <- mkReg(1);
    Reg#(Bit#(1)) low_reg <- mkReg(0);

    // SPI block, including synchronizer
    SpiPeripheralSync spi_sync <- mkSpiPeripheralPinSync();    
    SpiPeripheralPhy phy <- mkSpiPeripheralPhy();
    SpiDecodeIF decode <- mkSpiRegDecode();
    // Regiser block
    GimletRegIF regs <- mkGimletRegs();

    //  SPI
    mkConnection(spi_sync.syncd_pins, phy.pins);    // Output of spi synchronizer to SPI PHY block (just pins interface)
    mkConnection(decode.spi_byte, phy.decoder_if);  // Output of the SPI PHY block to the SPI decoder block (client/server interface)
    mkConnection(decode.reg_con, regs.decoder_if);  // Client of SPI decoder to Server of registers block.


    ICE40::Output#(Bit#(1)) cipo <- mkOutput(OutputTriState, False);

    rule test (phy.pins.output_en);
        cipo <= phy.pins.cipo;
    endrule


    method seq_to_fan_hp_en = high_reg._read;
    method seq_to_led_en_l  = low_reg._read;
    method seq_to_clk_nmr_l = high_reg._read;
    method seq_to_clk_ntest = high_reg._read;
    method seq_to_nic_v0p9_a0hp_en  = high_reg._read;
    method seq_to_nic_v1p1_en = high_reg._read;
    method seq_to_nic_v1p2_enet_en = high_reg._read;
    method seq_to_nic_v1p5a_en = high_reg._read;
    method seq_to_nic_cld_rst_l  = high_reg._read;
    method pwr_cont_nic_en0 = high_reg._read;
    method seq_to_nic_ldo_v3p3_en = high_reg._read;
    method seq_to_nic_v1p2_en = high_reg._read;
    method pwr_cont_nic_en1 = high_reg._read;
    method seq_to_nic_v1p5d_en = high_reg._read;
    method seq_to_nic_comb_pg_l = high_reg._read;
    method seq_to_nic_perst_l = high_reg._read;
    method nic_to_sp3_pwrflt_l = high_reg._read;
    method seq_to_sp3_v0p9_s5_en = high_reg._read;
    method pwr_cont_dimm_en1  = high_reg._read;
    method pwr_cont_dimm_en0 = high_reg._read;
    method pwr_cont_dimm_efgh_en0 = high_reg._read;
    method seq_to_vtt_abcd_en = high_reg._read;
    method seq_to_vtt_efgh_en  = high_reg._read;
    method seq_to_dimm_efgh_v2p5_en  = high_reg._read;
    method seq_to_dimm_abcd_v2p5_en = high_reg._read;
    method seq_to_sp3_v1p8_en  = high_reg._read;
    method seq_to_v3p3_sys_en  = high_reg._read;
    method seq_to_sp3_v1p8_s5_en = high_reg._read;
    method seq_to_sp3_v3p3_s5_en = high_reg._read;
    method pwr_cont1_sp3_pwrok = high_reg._read;
    method pwr_cont2_sp3_pwrok  = high_reg._read;
    method seq_to_sp3_v1p5_rtc_en = high_reg._read;
    method pwr_cont1_sp3_en = high_reg._read;
    method pwr_cont2_sp3_en  = high_reg._read;
    method seq_to_sp3_pwr_btn_l = high_reg._read;
    method seq_to_sp3_rsmrst_v3p3_l = high_reg._read;
    method seq_to_sp3_pwr_good = high_reg._read;

     interface SpiPeripheralPinsTop spi_pins;
        method csn = spi_sync.in_pins.csn;
        method sclk = spi_sync.in_pins.sclk;
        method copi = spi_sync.in_pins.copi;
        interface cipo = cipo.pad;
    endinterface

endmodule

endpackage
