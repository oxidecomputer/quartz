
package GimletSeqFpgaRegs;

import Reserved::*;
import RegCommon::*;

// Register ID0 definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Id0 deriving (Bits, Eq, FShow);

Integer id0Offset = 0;

// Register ID1 definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Id1 deriving (Bits, Eq, FShow);

Integer id1Offset = 1;

// Register ID2 definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Id2 deriving (Bits, Eq, FShow);

Integer id2Offset = 2;

// Register ID3 definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Id3 deriving (Bits, Eq, FShow);

Integer id3Offset = 3;

// Register SCRTCHPAD definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Scrtchpad deriving (Bits, Eq, FShow);

Integer scrtchpadOffset = 4;

// Register IFR definitions
typedef struct {
    ReservedZero#(2)   zeros0    ;  // bit 7:6
    Bit#(1)            a0fault   ;  // bit 5
    Bit#(1)            a0timeout ;  // bit 4
    Bit#(1)            a1fault   ;  // bit 3
    Bit#(1)            a1timeout ;  // bit 2
    Bit#(1)            fanfault  ;  // bit 1
    Bit#(1)            fantimeout;  // bit 0
} Ifr deriving (Bits, Eq, FShow);

Integer ifrOffset = 5;

// Register IER definitions
typedef struct {
    ReservedZero#(2)   zeros0    ;  // bit 7:6
    Bit#(1)            a0fault   ;  // bit 5
    Bit#(1)            a0timeout ;  // bit 4
    Bit#(1)            a1fault   ;  // bit 3
    Bit#(1)            a1timeout ;  // bit 2
    Bit#(1)            fanfault  ;  // bit 1
    Bit#(1)            fantimeout;  // bit 0
} Ier deriving (Bits, Eq, FShow);

Integer ierOffset = 6;

// Register STATUS definitions
typedef struct {
    Bit#(1)            int_pend;  // bit 7
    ReservedZero#(3)   zeros0  ;  // bit 6:4
    Bit#(1)            a0pwrok ;  // bit 3
    Bit#(1)            nicpwrok;  // bit 2
    Bit#(1)            a1pwrok ;  // bit 1
    Bit#(1)            fanpwrok;  // bit 0
} Status deriving (Bits, Eq, FShow);

Integer statusOffset = 7;

// Register EARLY_POWER_CTRL definitions
typedef struct {
    Bit#(1)            fanhp_restart;  // bit 7
    ReservedZero#(4)   zeros0       ;  // bit 6:3
    Bit#(1)            efgh_spd_en  ;  // bit 2
    Bit#(1)            abcd_spd_en  ;  // bit 1
    Bit#(1)            fanpwren     ;  // bit 0
} EarlyPowerCtrl deriving (Bits, Eq, FShow);

Integer earlyPowerCtrlOffset = 8;

// Register PWRCTRL definitions
typedef struct {
    ReservedZero#(3)   zeros0  ;  // bit 7:5
    Bit#(1)            nicpwren;  // bit 4
    Bit#(1)            a0c_dis ;  // bit 3
    Bit#(1)            a0b_en  ;  // bit 2
    Bit#(1)            a0a_en  ;  // bit 1
    Bit#(1)            a1pwren ;  // bit 0
} Pwrctrl deriving (Bits, Eq, FShow);

Integer pwrctrlOffset = 9;

// Register EARLY_RBKS definitions
typedef struct {
    ReservedZero#(3)   zeros0             ;  // bit 7:5
    Bit#(1)            efgh_v2p5_spd_pg   ;  // bit 4
    Bit#(1)            abcd_v2p5_spd_pg   ;  // bit 3
    Bit#(1)            fan_to_seq_fan_fail;  // bit 2
    Bit#(1)            fanhp_to_seq_pwrgd ;  // bit 1
    Bit#(1)            fanhp_to_seq_fault ;  // bit 0
} EarlyRbks deriving (Bits, Eq, FShow);

Integer earlyRbksOffset = 10;

// Register A1SMSTATUS definitions
typedef struct {
    Bit#(8)            a1sm  ;  // bit 7:0
} A1smstatus deriving (Bits, Eq, FShow);

Integer a1smstatusOffset = 11;

// Register A1_READBACKS definitions
typedef struct {
    ReservedZero#(4)   zeros0            ;  // bit 7:4
    Bit#(1)            v0p9_vdd_soc_s5_pg;  // bit 3
    Bit#(1)            v1p8_s5_pg        ;  // bit 2
    Bit#(1)            v3p3_s5_pg        ;  // bit 1
    Bit#(1)            v1p5_rtc_pg       ;  // bit 0
} A1Readbacks deriving (Bits, Eq, FShow);

Integer a1ReadbacksOffset = 12;

// Register AMD_A0 definitions
typedef struct {
    ReservedZero#(4)   zeros0;  // bit 7:4
    Bit#(1)            reset ;  // bit 3
    Bit#(1)            pwrok ;  // bit 2
    Bit#(1)            slp_s5;  // bit 1
    Bit#(1)            slp_s3;  // bit 0
} AmdA0 deriving (Bits, Eq, FShow);

Integer amdA0Offset = 13;

// Register GROUPB_PG definitions
typedef struct {
    Bit#(1)            v3p3_sys_pg    ;  // bit 7
    Bit#(1)            v1p8_sp3_pg    ;  // bit 6
    Bit#(1)            vtt_efgh_pg    ;  // bit 5
    Bit#(1)            vtt_abcd_pg    ;  // bit 4
    Bit#(1)            vdd_mem_efgh_pg;  // bit 3
    Bit#(1)            vdd_mem_abcd_pg;  // bit 2
    Bit#(1)            vpp_efgh_pg    ;  // bit 1
    Bit#(1)            vpp_abcd_pg    ;  // bit 0
} GroupbPg deriving (Bits, Eq, FShow);

Integer groupbPgOffset = 14;

// Register GROUPB_UNUSED definitions
typedef struct {
    ReservedZero#(5)   zeros0  ;  // bit 7:3
    Bit#(1)            efgh_pg2;  // bit 2
    Bit#(1)            efgh_pg1;  // bit 1
    Bit#(1)            abcd_pg2;  // bit 0
} GroupbUnused deriving (Bits, Eq, FShow);

Integer groupbUnusedOffset = 15;

// Register GROUPBC_FLTS definitions
typedef struct {
    Bit#(1)            cont2_cfp   ;  // bit 7
    Bit#(1)            cont2_nvrhot;  // bit 6
    Bit#(1)            efgh_cfp    ;  // bit 5
    Bit#(1)            efgh_nvrhot ;  // bit 4
    Bit#(1)            abcd_cfp    ;  // bit 3
    Bit#(1)            abcd_nvrhot ;  // bit 2
    Bit#(1)            cont1_cfp   ;  // bit 1
    Bit#(1)            cont1_nvrhot;  // bit 0
} GroupbcFlts deriving (Bits, Eq, FShow);

Integer groupbcFltsOffset = 16;

// Register GROUPC_PG definitions
typedef struct {
    ReservedZero#(6)   zeros0      ;  // bit 7:2
    Bit#(1)            vdd_vcore   ;  // bit 1
    Bit#(1)            vddcr_soc_pg;  // bit 0
} GroupcPg deriving (Bits, Eq, FShow);

Integer groupcPgOffset = 17;

// Register NIC_STATUS definitions
typedef struct {
    Bit#(1)            nic_cfp     ;  // bit 7
    Bit#(1)            nic_nvrhot  ;  // bit 6
    Bit#(1)            nic_v1p8_pg ;  // bit 5
    Bit#(1)            nic_v1p5_pg ;  // bit 4
    Bit#(1)            nic_av1p5_pg;  // bit 3
    Bit#(1)            nic_v1p2_pg ;  // bit 2
    Bit#(1)            nic_v1p1_pg ;  // bit 1
    Bit#(1)            nic_v0p96_pg;  // bit 0
} NicStatus deriving (Bits, Eq, FShow);

Integer nicStatusOffset = 18;

// Register CLKGEN_STATUS definitions
typedef struct {
    ReservedZero#(1)   zeros0;  // bit 7
    Bit#(1)            gpio9 ;  // bit 6
    Bit#(1)            gpio8 ;  // bit 5
    Bit#(1)            gpio5 ;  // bit 4
    Bit#(1)            gpio4 ;  // bit 3
    Bit#(1)            gpio3 ;  // bit 2
    Bit#(1)            gpio2 ;  // bit 1
    Bit#(1)            gpio1 ;  // bit 0
} ClkgenStatus deriving (Bits, Eq, FShow);

Integer clkgenStatusOffset = 19;

// Register AMD_STATUS definitions
typedef struct {
    ReservedZero#(5)   zeros0   ;  // bit 7:3
    Bit#(1)            pwrgd_out;  // bit 2
    Bit#(1)            fsr_req  ;  // bit 1
    Bit#(1)            thermtrip;  // bit 0
} AmdStatus deriving (Bits, Eq, FShow);

Integer amdStatusOffset = 20;

// Register FANOUTSTATUS definitions
typedef struct {
    ReservedZero#(6)   zeros0       ;  // bit 7:2
    Bit#(1)            fanhp_restart;  // bit 1
    Bit#(1)            fan_hp_en    ;  // bit 0
} Fanoutstatus deriving (Bits, Eq, FShow);

Integer fanoutstatusOffset = 21;

// Register EARLY_PWR_STATUS definitions
typedef struct {
    Bit#(1)            fanhp_restart;  // bit 7
    ReservedZero#(4)   zeros0       ;  // bit 6:3
    Bit#(1)            efgh_spd_en  ;  // bit 2
    Bit#(1)            abcd_spd_en  ;  // bit 1
    Bit#(1)            fanpwren     ;  // bit 0
} EarlyPwrStatus deriving (Bits, Eq, FShow);

Integer earlyPwrStatusOffset = 22;

// Register A1_OUT_STATUS definitions
typedef struct {
    ReservedZero#(3)   zeros0     ;  // bit 7:5
    Bit#(1)            rsmrst     ;  // bit 4
    Bit#(1)            v0p9_s5_en ;  // bit 3
    Bit#(1)            v1p8_s5_en ;  // bit 2
    Bit#(1)            v1p5_rtc_en;  // bit 1
    Bit#(1)            v3p3_s5_en ;  // bit 0
} A1OutStatus deriving (Bits, Eq, FShow);

Integer a1OutStatusOffset = 23;

// Register A0_OUT_STATUS_1 definitions
typedef struct {
    Bit#(1)            efgh_en2   ;  // bit 7
    Bit#(1)            abcd_en2   ;  // bit 6
    Bit#(1)            efgh_en1   ;  // bit 5
    Bit#(1)            v3p3_sys_en;  // bit 4
    Bit#(1)            vtt_efgh_en;  // bit 3
    Bit#(1)            vtt_abcd_en;  // bit 2
    Bit#(1)            vpp_efgh_en;  // bit 1
    Bit#(1)            vpp_abcd_en;  // bit 0
} A0OutStatus1 deriving (Bits, Eq, FShow);

Integer a0OutStatus1Offset = 24;

// Register A0_OUT_STATUS_2 definitions
typedef struct {
    ReservedZero#(1)   zeros0     ;  // bit 7
    Bit#(1)            pwr_good   ;  // bit 6
    Bit#(1)            pwr_btn    ;  // bit 5
    Bit#(1)            cont2_en   ;  // bit 4
    Bit#(1)            cont1_en   ;  // bit 3
    Bit#(1)            v1p8_sp3_en;  // bit 2
    Bit#(1)            u351_pwrok ;  // bit 1
    Bit#(1)            u350_pwrok ;  // bit 0
} A0OutStatus2 deriving (Bits, Eq, FShow);

Integer a0OutStatus2Offset = 25;

// Register OUT_STATUS_NIC1 definitions
typedef struct {
    Bit#(1)            nic_v3p3       ;  // bit 7
    Bit#(1)            nic_v1p1_en    ;  // bit 6
    Bit#(1)            nic_v1p2_en    ;  // bit 5
    Bit#(1)            nic_v1p5d_en   ;  // bit 4
    Bit#(1)            nic_v1p5a_en   ;  // bit 3
    Bit#(1)            nic_cont_en1   ;  // bit 2
    Bit#(1)            nic_cont_en0   ;  // bit 1
    Bit#(1)            nic_v1p2_eth_en;  // bit 0
} OutStatusNic1 deriving (Bits, Eq, FShow);

Integer outStatusNic1Offset = 26;

// Register OUT_STATUS_NIC2 definitions
typedef struct {
    ReservedZero#(5)   zeros0     ;  // bit 7:3
    Bit#(1)            pwrflt     ;  // bit 2
    Bit#(1)            nic_cld_rst;  // bit 1
    Bit#(1)            nic_comb_pg;  // bit 0
} OutStatusNic2 deriving (Bits, Eq, FShow);

Integer outStatusNic2Offset = 27;

// Register CLKGEN_OUT_STATUS definitions
typedef struct {
    ReservedZero#(7)   zeros0 ;  // bit 7:1
    Bit#(1)            seq_nmr;  // bit 0
} ClkgenOutStatus deriving (Bits, Eq, FShow);

Integer clkgenOutStatusOffset = 28;

// Register AMD_OUT_STATUS definitions
typedef struct {
    ReservedZero#(7)   zeros0   ;  // bit 7:1
    Bit#(1)            sys_reset;  // bit 0
} AmdOutStatus deriving (Bits, Eq, FShow);

Integer amdOutStatusOffset = 29;

// Register DBG_CTRL definitions
typedef struct {
    ReservedZero#(6)   zeros0       ;  // bit 7:2
    Bit#(1)            store_current;  // bit 1
    Bit#(1)            reg_ctrl_en  ;  // bit 0
} DbgCtrl deriving (Bits, Eq, FShow);

Integer dbgCtrlOffset = 30;

// Register A1_DBG_OUT definitions
typedef struct {
    ReservedZero#(3)   zeros0     ;  // bit 7:5
    Bit#(1)            rsmrst     ;  // bit 4
    Bit#(1)            v0p9_s5_en ;  // bit 3
    Bit#(1)            v1p8_s5_en ;  // bit 2
    Bit#(1)            v1p5_rtc_en;  // bit 1
    Bit#(1)            v3p3_s5_en ;  // bit 0
} A1DbgOut deriving (Bits, Eq, FShow);

Integer a1DbgOutOffset = 31;

// Register A0_DBG_OUT_1 definitions
typedef struct {
    Bit#(1)            efgh_en2   ;  // bit 7
    Bit#(1)            abcd_en2   ;  // bit 6
    Bit#(1)            efgh_en1   ;  // bit 5
    Bit#(1)            v3p3_sys_en;  // bit 4
    Bit#(1)            vtt_efgh_en;  // bit 3
    Bit#(1)            vtt_abcd_en;  // bit 2
    Bit#(1)            vpp_efgh_en;  // bit 1
    Bit#(1)            vpp_abcd_en;  // bit 0
} A0DbgOut1 deriving (Bits, Eq, FShow);

Integer a0DbgOut1Offset = 32;

// Register A0_DBG_OUT_2 definitions
typedef struct {
    ReservedZero#(1)   zeros0     ;  // bit 7
    Bit#(1)            pwr_good   ;  // bit 6
    Bit#(1)            pwr_btn    ;  // bit 5
    Bit#(1)            cont2_en   ;  // bit 4
    Bit#(1)            cont1_en   ;  // bit 3
    Bit#(1)            v1p8_sp3_en;  // bit 2
    Bit#(1)            u351_pwrok ;  // bit 1
    Bit#(1)            u350_pwrok ;  // bit 0
} A0DbgOut2 deriving (Bits, Eq, FShow);

Integer a0DbgOut2Offset = 33;

// Register DBG_OUT_NIC1 definitions
typedef struct {
    Bit#(1)            nic_v3p3       ;  // bit 7
    Bit#(1)            nic_v1p1_en    ;  // bit 6
    Bit#(1)            nic_v1p2_en    ;  // bit 5
    Bit#(1)            nic_v1p5d_en   ;  // bit 4
    Bit#(1)            nic_v1p5a_en   ;  // bit 3
    Bit#(1)            nic_cont_en1   ;  // bit 2
    Bit#(1)            nic_cont_en0   ;  // bit 1
    Bit#(1)            nic_v1p2_eth_en;  // bit 0
} DbgOutNic1 deriving (Bits, Eq, FShow);

Integer dbgOutNic1Offset = 34;

// Register DBG_OUT_NIC2 definitions
typedef struct {
    ReservedZero#(5)   zeros0     ;  // bit 7:3
    Bit#(1)            pwrflt     ;  // bit 2
    Bit#(1)            nic_cld_rst;  // bit 1
    Bit#(1)            nic_comb_pg;  // bit 0
} DbgOutNic2 deriving (Bits, Eq, FShow);

Integer dbgOutNic2Offset = 35;

// Register CLKGEN_DBG_OUT definitions
typedef struct {
    ReservedZero#(7)   zeros0 ;  // bit 7:1
    Bit#(1)            seq_nmr;  // bit 0
} ClkgenDbgOut deriving (Bits, Eq, FShow);

Integer clkgenDbgOutOffset = 36;

// Register AMD_DBG_OUT definitions
typedef struct {
    ReservedZero#(7)   zeros0   ;  // bit 7:1
    Bit#(1)            sys_reset;  // bit 0
} AmdDbgOut deriving (Bits, Eq, FShow);

Integer amdDbgOutOffset = 37;

endpackage: GimletSeqFpgaRegs