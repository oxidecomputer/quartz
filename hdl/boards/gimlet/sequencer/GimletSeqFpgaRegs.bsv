
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

Integer ifrOffset = 4;

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

Integer ierOffset = 5;

// Register STATUS definitions
typedef struct {
    Bit#(1)            int_pend;  // bit 7
    ReservedZero#(3)   zeros0  ;  // bit 6:4
    Bit#(1)            a0pwrok ;  // bit 3
    Bit#(1)            nicpwrok;  // bit 2
    Bit#(1)            a1pwrok ;  // bit 1
    Bit#(1)            fanpwrok;  // bit 0
} Status deriving (Bits, Eq, FShow);

Integer statusOffset = 6;

// Register EARLY_PWRCTRL definitions
typedef struct {
    ReservedZero#(5)   zeros0     ;  // bit 7:3
    Bit#(1)            efgh_spd_en;  // bit 2
    Bit#(1)            abcd_spd_en;  // bit 1
    Bit#(1)            fanpwren   ;  // bit 0
} EarlyPwrctrl deriving (Bits, Eq, FShow);

Integer earlyPwrctrlOffset = 7;

// Register PWRCTRL definitions
typedef struct {
    Bit#(1)            fanhp_restart;  // bit 7
    ReservedZero#(2)   zeros0       ;  // bit 6:5
    Bit#(1)            nicpwren     ;  // bit 4
    Bit#(1)            a0c_dis      ;  // bit 3
    Bit#(1)            a0b_en       ;  // bit 2
    Bit#(1)            a0a_en       ;  // bit 1
    Bit#(1)            a1pwren      ;  // bit 0
} Pwrctrl deriving (Bits, Eq, FShow);

Integer pwrctrlOffset = 8;

// Register EARLY_RBKS definitions
typedef struct {
    ReservedZero#(3)   zeros0              ;  // bit 7:5
    Bit#(1)            efgh_v2p5_spd_pg    ;  // bit 4
    Bit#(1)            abcd_v2p5_spd_pg    ;  // bit 3
    Bit#(1)            fan_to_seq_fan_fail ;  // bit 2
    Bit#(1)            fanhp_to_seq_pwrgd  ;  // bit 1
    Bit#(1)            fanhp_to_seq_fault_l;  // bit 0
} EarlyRbks deriving (Bits, Eq, FShow);

Integer earlyRbksOffset = 9;

// Register A1SMSTATUS definitions
typedef struct {
    Bit#(8)            a1sm  ;  // bit 7:0
} A1smstatus deriving (Bits, Eq, FShow);

Integer a1smstatusOffset = 10;

// Register A1READBACKS definitions
typedef struct {
    ReservedZero#(4)   zeros0            ;  // bit 7:4
    Bit#(1)            v0p9_vdd_soc_s5_pg;  // bit 3
    Bit#(1)            v1p8_s5_pg        ;  // bit 2
    Bit#(1)            v3p3_s5_pg        ;  // bit 1
    Bit#(1)            v1p5_rtc_pg       ;  // bit 0
} A1readbacks deriving (Bits, Eq, FShow);

Integer a1readbacksOffset = 11;

// Register AMD_A0 definitions
typedef struct {
    ReservedZero#(4)   zeros0;  // bit 7:4
    Bit#(1)            reset ;  // bit 3
    Bit#(1)            pwrok ;  // bit 2
    Bit#(1)            slp_s5;  // bit 1
    Bit#(1)            slp_s3;  // bit 0
} AmdA0 deriving (Bits, Eq, FShow);

Integer amdA0Offset = 12;

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

Integer groupbPgOffset = 13;

// Register GROUPB_UNUSED definitions
typedef struct {
    ReservedZero#(5)   zeros0  ;  // bit 7:3
    Bit#(1)            efgh_pg2;  // bit 2
    Bit#(1)            efgh_pg1;  // bit 1
    Bit#(1)            abcd_pg2;  // bit 0
} GroupbUnused deriving (Bits, Eq, FShow);

Integer groupbUnusedOffset = 14;

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

Integer groupbcFltsOffset = 15;

// Register GROUPC_PG definitions
typedef struct {
    ReservedZero#(6)   zeros0      ;  // bit 7:2
    Bit#(1)            vdd_vcore   ;  // bit 1
    Bit#(1)            vddcr_soc_pg;  // bit 0
} GroupcPg deriving (Bits, Eq, FShow);

Integer groupcPgOffset = 16;

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

Integer nicStatusOffset = 17;

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

Integer clkgenStatusOffset = 18;

// Register AMD_STATUS definitions
typedef struct {
    ReservedZero#(5)   zeros0   ;  // bit 7:3
    Bit#(1)            pwrgd_out;  // bit 2
    Bit#(1)            fsr_req  ;  // bit 1
    Bit#(1)            thermtrip;  // bit 0
} AmdStatus deriving (Bits, Eq, FShow);

Integer amdStatusOffset = 19;

// Register FANOUTSTATUS definitions
typedef struct {
    ReservedZero#(6)   zeros0       ;  // bit 7:2
    Bit#(1)            fanhp_restart;  // bit 1
    Bit#(1)            fan_hp_en    ;  // bit 0
} Fanoutstatus deriving (Bits, Eq, FShow);

Integer fanoutstatusOffset = 20;

// Register OUTSTATUS_A1 definitions
typedef struct {
    ReservedZero#(4)   zeros0     ;  // bit 7:4
    Bit#(1)            v0p9_s5_en ;  // bit 3
    Bit#(1)            v1p8_s5_en ;  // bit 2
    Bit#(1)            v1p5_rtc_en;  // bit 1
    Bit#(1)            v3p3_s5_en ;  // bit 0
} OutstatusA1 deriving (Bits, Eq, FShow);

Integer outstatusA1Offset = 21;

// Register OUTSTATUS_A0_1 definitions
typedef struct {
    Bit#(1)            efgh_en2   ;  // bit 7
    Bit#(1)            abcd_en2   ;  // bit 6
    Bit#(1)            efgh_en1   ;  // bit 5
    Bit#(1)            v3p3_sys_en;  // bit 4
    Bit#(1)            vtt_efgh_en;  // bit 3
    Bit#(1)            vtt_abcd_en;  // bit 2
    Bit#(1)            vpp_efgh_en;  // bit 1
    Bit#(1)            vpp_abcd_en;  // bit 0
} OutstatusA01 deriving (Bits, Eq, FShow);

Integer outstatusA01Offset = 22;

// Register OUTSTATUS_A0_2 definitions
typedef struct {
    Bit#(1)            rsmrst     ;  // bit 7
    Bit#(1)            pwr_good   ;  // bit 6
    Bit#(1)            pwr_btn    ;  // bit 5
    Bit#(1)            cont2_en   ;  // bit 4
    Bit#(1)            cont1_en   ;  // bit 3
    Bit#(1)            v1p8_sp3_en;  // bit 2
    Bit#(1)            u351_pwrok ;  // bit 1
    Bit#(1)            u350_pwrok ;  // bit 0
} OutstatusA02 deriving (Bits, Eq, FShow);

Integer outstatusA02Offset = 23;

// Register OUTSTATUS_NIC1 definitions
typedef struct {
    Bit#(1)            nic_v3p3       ;  // bit 7
    Bit#(1)            nic_v1p1_en    ;  // bit 6
    Bit#(1)            nic_v1p2_en    ;  // bit 5
    Bit#(1)            nic_v1p5d_en   ;  // bit 4
    Bit#(1)            nic_v1p5a_en   ;  // bit 3
    Bit#(1)            nic_cont_en1   ;  // bit 2
    Bit#(1)            nic_cont_en0   ;  // bit 1
    Bit#(1)            nic_v1p2_eth_en;  // bit 0
} OutstatusNic1 deriving (Bits, Eq, FShow);

Integer outstatusNic1Offset = 24;

// Register OUTSTATUS_NIC2 definitions
typedef struct {
    ReservedZero#(5)   zeros0     ;  // bit 7:3
    Bit#(1)            pwrflt     ;  // bit 2
    Bit#(1)            nic_cld_rst;  // bit 1
    Bit#(1)            nic_comb_pg;  // bit 0
} OutstatusNic2 deriving (Bits, Eq, FShow);

Integer outstatusNic2Offset = 25;

// Register OUTSTATUS_CLKGEN definitions
typedef struct {
    ReservedZero#(7)   zeros0 ;  // bit 7:1
    Bit#(1)            seq_nmr;  // bit 0
} OutstatusClkgen deriving (Bits, Eq, FShow);

Integer outstatusClkgenOffset = 26;

// Register OUTSTATUS_AMD definitions
typedef struct {
    ReservedZero#(7)   zeros0   ;  // bit 7:1
    Bit#(1)            sys_reset;  // bit 0
} OutstatusAmd deriving (Bits, Eq, FShow);

Integer outstatusAmdOffset = 27;

// Register DBG_CTRL definitions
typedef struct {
    ReservedZero#(6)   zeros0       ;  // bit 7:2
    Bit#(1)            store_current;  // bit 1
    Bit#(1)            reg_ctrl_en  ;  // bit 0
} DbgCtrl deriving (Bits, Eq, FShow);

Integer dbgCtrlOffset = 28;

// Register DBGOUTA1 definitions
typedef struct {
    ReservedZero#(4)   zeros0     ;  // bit 7:4
    Bit#(1)            v0p9_s5_en ;  // bit 3
    Bit#(1)            v1p8_s5_en ;  // bit 2
    Bit#(1)            v1p5_rtc_en;  // bit 1
    Bit#(1)            v3p3_s5_en ;  // bit 0
} Dbgouta1 deriving (Bits, Eq, FShow);

Integer dbgouta1Offset = 29;

// Register DBGOUTA0_1 definitions
typedef struct {
    Bit#(1)            efgh_en2   ;  // bit 7
    Bit#(1)            abcd_en2   ;  // bit 6
    Bit#(1)            efgh_en1   ;  // bit 5
    Bit#(1)            v3p3_sys_en;  // bit 4
    Bit#(1)            vtt_efgh_en;  // bit 3
    Bit#(1)            vtt_abcd_en;  // bit 2
    Bit#(1)            vpp_efgh_en;  // bit 1
    Bit#(1)            vpp_abcd_en;  // bit 0
} Dbgouta01 deriving (Bits, Eq, FShow);

Integer dbgouta01Offset = 30;

// Register DBGOUTA0_2 definitions
typedef struct {
    Bit#(1)            rsmrst     ;  // bit 7
    Bit#(1)            pwr_good   ;  // bit 6
    Bit#(1)            pwr_btn    ;  // bit 5
    Bit#(1)            cont2_en   ;  // bit 4
    Bit#(1)            cont1_en   ;  // bit 3
    Bit#(1)            v1p8_sp3_en;  // bit 2
    Bit#(1)            u351_pwrok ;  // bit 1
    Bit#(1)            u350_pwrok ;  // bit 0
} Dbgouta02 deriving (Bits, Eq, FShow);

Integer dbgouta02Offset = 31;

// Register DBGOUT_NIC1 definitions
typedef struct {
    Bit#(1)            nic_v3p3       ;  // bit 7
    Bit#(1)            nic_v1p1_en    ;  // bit 6
    Bit#(1)            nic_v1p2_en    ;  // bit 5
    Bit#(1)            nic_v1p5d_en   ;  // bit 4
    Bit#(1)            nic_v1p5a_en   ;  // bit 3
    Bit#(1)            nic_cont_en1   ;  // bit 2
    Bit#(1)            nic_cont_en0   ;  // bit 1
    Bit#(1)            nic_v1p2_eth_en;  // bit 0
} DbgoutNic1 deriving (Bits, Eq, FShow);

Integer dbgoutNic1Offset = 32;

// Register DBGOUT_NIC2 definitions
typedef struct {
    ReservedZero#(5)   zeros0     ;  // bit 7:3
    Bit#(1)            pwrflt     ;  // bit 2
    Bit#(1)            nic_cld_rst;  // bit 1
    Bit#(1)            nic_comb_pg;  // bit 0
} DbgoutNic2 deriving (Bits, Eq, FShow);

Integer dbgoutNic2Offset = 33;

// Register DBGOUT_CLKGEN definitions
typedef struct {
    ReservedZero#(7)   zeros0 ;  // bit 7:1
    Bit#(1)            seq_nmr;  // bit 0
} DbgoutClkgen deriving (Bits, Eq, FShow);

Integer dbgoutClkgenOffset = 34;

// Register DBGOUT_AMD definitions
typedef struct {
    ReservedZero#(7)   zeros0   ;  // bit 7:1
    Bit#(1)            sys_reset;  // bit 0
} DbgoutAmd deriving (Bits, Eq, FShow);

Integer dbgoutAmdOffset = 35;

endpackage: GimletSeqFpgaRegs