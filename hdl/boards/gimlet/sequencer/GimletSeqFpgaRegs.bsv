
// This is a generated file using the RDL tooling. Do not edit by hand.
package GimletSeqFpgaRegs;

import Reserved::*;
import RegCommon::*;

// Register ID0 definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Id0 deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) id0Tbd    = 'hff;
// Register ID0 custom type-classes
instance Bitwise#(Id0);
    function Id0 \& (Id0 i1, Id0 i2) =
        unpack(pack(i1) & pack(i2));
    function Id0 \| (Id0 i1, Id0 i2) =
        unpack(pack(i1) | pack(i2));
    function Id0 \^ (Id0 i1, Id0 i2) =
        unpack(pack(i1) ^ pack(i2));
    function Id0 \~^ (Id0 i1, Id0 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Id0 \^~ (Id0 i1, Id0 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Id0 invert (Id0 i) =
        unpack(invert(pack(i)));
    function Id0 \<< (Id0 i, t x) =
        error("Left shift operation is not supported with type Id0");
    function Id0 \>> (Id0 i, t x) =
        error("Right shift operation is not supported with type Id0");
    function Bit#(1) msb (Id0 i) =
        error("msb operation is not supported with type Id0");
    function Bit#(1) lsb (Id0 i) =
        error("lsb operation is not supported with type Id0");
endinstance

Integer id0Offset = 0;

// Register ID1 definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Id1 deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) id1Tbd    = 'hff;
// Register ID1 custom type-classes
instance Bitwise#(Id1);
    function Id1 \& (Id1 i1, Id1 i2) =
        unpack(pack(i1) & pack(i2));
    function Id1 \| (Id1 i1, Id1 i2) =
        unpack(pack(i1) | pack(i2));
    function Id1 \^ (Id1 i1, Id1 i2) =
        unpack(pack(i1) ^ pack(i2));
    function Id1 \~^ (Id1 i1, Id1 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Id1 \^~ (Id1 i1, Id1 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Id1 invert (Id1 i) =
        unpack(invert(pack(i)));
    function Id1 \<< (Id1 i, t x) =
        error("Left shift operation is not supported with type Id1");
    function Id1 \>> (Id1 i, t x) =
        error("Right shift operation is not supported with type Id1");
    function Bit#(1) msb (Id1 i) =
        error("msb operation is not supported with type Id1");
    function Bit#(1) lsb (Id1 i) =
        error("lsb operation is not supported with type Id1");
endinstance

Integer id1Offset = 1;

// Register ID2 definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Id2 deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) id2Tbd    = 'hff;
// Register ID2 custom type-classes
instance Bitwise#(Id2);
    function Id2 \& (Id2 i1, Id2 i2) =
        unpack(pack(i1) & pack(i2));
    function Id2 \| (Id2 i1, Id2 i2) =
        unpack(pack(i1) | pack(i2));
    function Id2 \^ (Id2 i1, Id2 i2) =
        unpack(pack(i1) ^ pack(i2));
    function Id2 \~^ (Id2 i1, Id2 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Id2 \^~ (Id2 i1, Id2 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Id2 invert (Id2 i) =
        unpack(invert(pack(i)));
    function Id2 \<< (Id2 i, t x) =
        error("Left shift operation is not supported with type Id2");
    function Id2 \>> (Id2 i, t x) =
        error("Right shift operation is not supported with type Id2");
    function Bit#(1) msb (Id2 i) =
        error("msb operation is not supported with type Id2");
    function Bit#(1) lsb (Id2 i) =
        error("lsb operation is not supported with type Id2");
endinstance

Integer id2Offset = 2;

// Register ID3 definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Id3 deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) id3Tbd    = 'hff;
// Register ID3 custom type-classes
instance Bitwise#(Id3);
    function Id3 \& (Id3 i1, Id3 i2) =
        unpack(pack(i1) & pack(i2));
    function Id3 \| (Id3 i1, Id3 i2) =
        unpack(pack(i1) | pack(i2));
    function Id3 \^ (Id3 i1, Id3 i2) =
        unpack(pack(i1) ^ pack(i2));
    function Id3 \~^ (Id3 i1, Id3 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Id3 \^~ (Id3 i1, Id3 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Id3 invert (Id3 i) =
        unpack(invert(pack(i)));
    function Id3 \<< (Id3 i, t x) =
        error("Left shift operation is not supported with type Id3");
    function Id3 \>> (Id3 i, t x) =
        error("Right shift operation is not supported with type Id3");
    function Bit#(1) msb (Id3 i) =
        error("msb operation is not supported with type Id3");
    function Bit#(1) lsb (Id3 i) =
        error("lsb operation is not supported with type Id3");
endinstance

Integer id3Offset = 3;

// Register SCRTCHPAD definitions
typedef struct {
    Bit#(8)            tbd   ;  // bit 7:0
} Scrtchpad deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) scrtchpadTbd    = 'hff;
// Register SCRTCHPAD custom type-classes
instance Bitwise#(Scrtchpad);
    function Scrtchpad \& (Scrtchpad i1, Scrtchpad i2) =
        unpack(pack(i1) & pack(i2));
    function Scrtchpad \| (Scrtchpad i1, Scrtchpad i2) =
        unpack(pack(i1) | pack(i2));
    function Scrtchpad \^ (Scrtchpad i1, Scrtchpad i2) =
        unpack(pack(i1) ^ pack(i2));
    function Scrtchpad \~^ (Scrtchpad i1, Scrtchpad i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Scrtchpad \^~ (Scrtchpad i1, Scrtchpad i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Scrtchpad invert (Scrtchpad i) =
        unpack(invert(pack(i)));
    function Scrtchpad \<< (Scrtchpad i, t x) =
        error("Left shift operation is not supported with type Scrtchpad");
    function Scrtchpad \>> (Scrtchpad i, t x) =
        error("Right shift operation is not supported with type Scrtchpad");
    function Bit#(1) msb (Scrtchpad i) =
        error("msb operation is not supported with type Scrtchpad");
    function Bit#(1) lsb (Scrtchpad i) =
        error("lsb operation is not supported with type Scrtchpad");
endinstance

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
// Field mask definitions
    Bit#(8) ifrA0fault    = 'h20;
    Bit#(8) ifrA0timeout  = 'h10;
    Bit#(8) ifrA1fault    = 'h08;
    Bit#(8) ifrA1timeout  = 'h04;
    Bit#(8) ifrFanfault   = 'h02;
    Bit#(8) ifrFantimeout = 'h01;
// Register IFR custom type-classes
instance Bitwise#(Ifr);
    function Ifr \& (Ifr i1, Ifr i2) =
        unpack(pack(i1) & pack(i2));
    function Ifr \| (Ifr i1, Ifr i2) =
        unpack(pack(i1) | pack(i2));
    function Ifr \^ (Ifr i1, Ifr i2) =
        unpack(pack(i1) ^ pack(i2));
    function Ifr \~^ (Ifr i1, Ifr i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Ifr \^~ (Ifr i1, Ifr i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Ifr invert (Ifr i) =
        unpack(invert(pack(i)));
    function Ifr \<< (Ifr i, t x) =
        error("Left shift operation is not supported with type Ifr");
    function Ifr \>> (Ifr i, t x) =
        error("Right shift operation is not supported with type Ifr");
    function Bit#(1) msb (Ifr i) =
        error("msb operation is not supported with type Ifr");
    function Bit#(1) lsb (Ifr i) =
        error("lsb operation is not supported with type Ifr");
endinstance

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
// Field mask definitions
    Bit#(8) ierA0fault    = 'h20;
    Bit#(8) ierA0timeout  = 'h10;
    Bit#(8) ierA1fault    = 'h08;
    Bit#(8) ierA1timeout  = 'h04;
    Bit#(8) ierFanfault   = 'h02;
    Bit#(8) ierFantimeout = 'h01;
// Register IER custom type-classes
instance Bitwise#(Ier);
    function Ier \& (Ier i1, Ier i2) =
        unpack(pack(i1) & pack(i2));
    function Ier \| (Ier i1, Ier i2) =
        unpack(pack(i1) | pack(i2));
    function Ier \^ (Ier i1, Ier i2) =
        unpack(pack(i1) ^ pack(i2));
    function Ier \~^ (Ier i1, Ier i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Ier \^~ (Ier i1, Ier i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Ier invert (Ier i) =
        unpack(invert(pack(i)));
    function Ier \<< (Ier i, t x) =
        error("Left shift operation is not supported with type Ier");
    function Ier \>> (Ier i, t x) =
        error("Right shift operation is not supported with type Ier");
    function Bit#(1) msb (Ier i) =
        error("msb operation is not supported with type Ier");
    function Bit#(1) lsb (Ier i) =
        error("lsb operation is not supported with type Ier");
endinstance

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
// Field mask definitions
    Bit#(8) statusIntPend = 'h80;
    Bit#(8) statusA0pwrok  = 'h08;
    Bit#(8) statusNicpwrok = 'h04;
    Bit#(8) statusA1pwrok  = 'h02;
    Bit#(8) statusFanpwrok = 'h01;
// Register STATUS custom type-classes
instance Bitwise#(Status);
    function Status \& (Status i1, Status i2) =
        unpack(pack(i1) & pack(i2));
    function Status \| (Status i1, Status i2) =
        unpack(pack(i1) | pack(i2));
    function Status \^ (Status i1, Status i2) =
        unpack(pack(i1) ^ pack(i2));
    function Status \~^ (Status i1, Status i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Status \^~ (Status i1, Status i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Status invert (Status i) =
        unpack(invert(pack(i)));
    function Status \<< (Status i, t x) =
        error("Left shift operation is not supported with type Status");
    function Status \>> (Status i, t x) =
        error("Right shift operation is not supported with type Status");
    function Bit#(1) msb (Status i) =
        error("msb operation is not supported with type Status");
    function Bit#(1) lsb (Status i) =
        error("lsb operation is not supported with type Status");
endinstance

Integer statusOffset = 7;

// Register EARLY_POWER_CTRL definitions
typedef struct {
    Bit#(1)            fanhp_restart;  // bit 7
    ReservedZero#(4)   zeros0       ;  // bit 6:3
    Bit#(1)            efgh_spd_en  ;  // bit 2
    Bit#(1)            abcd_spd_en  ;  // bit 1
    Bit#(1)            fanpwren     ;  // bit 0
} EarlyPowerCtrl deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) earlyPowerCtrlFanhpRestart = 'h80;
    Bit#(8) earlyPowerCtrlEfghSpdEn   = 'h04;
    Bit#(8) earlyPowerCtrlAbcdSpdEn   = 'h02;
    Bit#(8) earlyPowerCtrlFanpwren      = 'h01;
// Register EARLY_POWER_CTRL custom type-classes
instance Bitwise#(EarlyPowerCtrl);
    function EarlyPowerCtrl \& (EarlyPowerCtrl i1, EarlyPowerCtrl i2) =
        unpack(pack(i1) & pack(i2));
    function EarlyPowerCtrl \| (EarlyPowerCtrl i1, EarlyPowerCtrl i2) =
        unpack(pack(i1) | pack(i2));
    function EarlyPowerCtrl \^ (EarlyPowerCtrl i1, EarlyPowerCtrl i2) =
        unpack(pack(i1) ^ pack(i2));
    function EarlyPowerCtrl \~^ (EarlyPowerCtrl i1, EarlyPowerCtrl i2) =
        unpack(pack(i1) ~^ pack(i2));
    function EarlyPowerCtrl \^~ (EarlyPowerCtrl i1, EarlyPowerCtrl i2) =
        unpack(pack(i1) ^~ pack(i2));
    function EarlyPowerCtrl invert (EarlyPowerCtrl i) =
        unpack(invert(pack(i)));
    function EarlyPowerCtrl \<< (EarlyPowerCtrl i, t x) =
        error("Left shift operation is not supported with type EarlyPowerCtrl");
    function EarlyPowerCtrl \>> (EarlyPowerCtrl i, t x) =
        error("Right shift operation is not supported with type EarlyPowerCtrl");
    function Bit#(1) msb (EarlyPowerCtrl i) =
        error("msb operation is not supported with type EarlyPowerCtrl");
    function Bit#(1) lsb (EarlyPowerCtrl i) =
        error("lsb operation is not supported with type EarlyPowerCtrl");
endinstance

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
// Field mask definitions
    Bit#(8) pwrctrlNicpwren = 'h10;
    Bit#(8) pwrctrlA0cDis  = 'h08;
    Bit#(8) pwrctrlA0bEn   = 'h04;
    Bit#(8) pwrctrlA0aEn   = 'h02;
    Bit#(8) pwrctrlA1pwren  = 'h01;
// Register PWRCTRL custom type-classes
instance Bitwise#(Pwrctrl);
    function Pwrctrl \& (Pwrctrl i1, Pwrctrl i2) =
        unpack(pack(i1) & pack(i2));
    function Pwrctrl \| (Pwrctrl i1, Pwrctrl i2) =
        unpack(pack(i1) | pack(i2));
    function Pwrctrl \^ (Pwrctrl i1, Pwrctrl i2) =
        unpack(pack(i1) ^ pack(i2));
    function Pwrctrl \~^ (Pwrctrl i1, Pwrctrl i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Pwrctrl \^~ (Pwrctrl i1, Pwrctrl i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Pwrctrl invert (Pwrctrl i) =
        unpack(invert(pack(i)));
    function Pwrctrl \<< (Pwrctrl i, t x) =
        error("Left shift operation is not supported with type Pwrctrl");
    function Pwrctrl \>> (Pwrctrl i, t x) =
        error("Right shift operation is not supported with type Pwrctrl");
    function Bit#(1) msb (Pwrctrl i) =
        error("msb operation is not supported with type Pwrctrl");
    function Bit#(1) lsb (Pwrctrl i) =
        error("lsb operation is not supported with type Pwrctrl");
endinstance

Integer pwrctrlOffset = 9;

// Register A1SMSTATUS definitions
typedef struct {
    Bit#(8)            a1sm  ;  // bit 7:0
} A1smstatus deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) a1smstatusA1sm   = 'hff;
// Register A1SMSTATUS custom type-classes
instance Bitwise#(A1smstatus);
    function A1smstatus \& (A1smstatus i1, A1smstatus i2) =
        unpack(pack(i1) & pack(i2));
    function A1smstatus \| (A1smstatus i1, A1smstatus i2) =
        unpack(pack(i1) | pack(i2));
    function A1smstatus \^ (A1smstatus i1, A1smstatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function A1smstatus \~^ (A1smstatus i1, A1smstatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A1smstatus \^~ (A1smstatus i1, A1smstatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A1smstatus invert (A1smstatus i) =
        unpack(invert(pack(i)));
    function A1smstatus \<< (A1smstatus i, t x) =
        error("Left shift operation is not supported with type A1smstatus");
    function A1smstatus \>> (A1smstatus i, t x) =
        error("Right shift operation is not supported with type A1smstatus");
    function Bit#(1) msb (A1smstatus i) =
        error("msb operation is not supported with type A1smstatus");
    function Bit#(1) lsb (A1smstatus i) =
        error("lsb operation is not supported with type A1smstatus");
endinstance

Integer a1smstatusOffset = 10;

// Register A0SMSTATUS definitions
typedef struct {
    Bit#(8)            a0sm  ;  // bit 7:0
} A0smstatus deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) a0smstatusA0sm   = 'hff;
// Register A0SMSTATUS custom type-classes
instance Bitwise#(A0smstatus);
    function A0smstatus \& (A0smstatus i1, A0smstatus i2) =
        unpack(pack(i1) & pack(i2));
    function A0smstatus \| (A0smstatus i1, A0smstatus i2) =
        unpack(pack(i1) | pack(i2));
    function A0smstatus \^ (A0smstatus i1, A0smstatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function A0smstatus \~^ (A0smstatus i1, A0smstatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A0smstatus \^~ (A0smstatus i1, A0smstatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A0smstatus invert (A0smstatus i) =
        unpack(invert(pack(i)));
    function A0smstatus \<< (A0smstatus i, t x) =
        error("Left shift operation is not supported with type A0smstatus");
    function A0smstatus \>> (A0smstatus i, t x) =
        error("Right shift operation is not supported with type A0smstatus");
    function Bit#(1) msb (A0smstatus i) =
        error("msb operation is not supported with type A0smstatus");
    function Bit#(1) lsb (A0smstatus i) =
        error("lsb operation is not supported with type A0smstatus");
endinstance

Integer a0smstatusOffset = 11;

// Register EARLY_RBKS definitions
typedef struct {
    ReservedZero#(3)   zeros0             ;  // bit 7:5
    Bit#(1)            efgh_v2p5_spd_pg   ;  // bit 4
    Bit#(1)            abcd_v2p5_spd_pg   ;  // bit 3
    Bit#(1)            fan_to_seq_fan_fail;  // bit 2
    Bit#(1)            fanhp_to_seq_pwrgd ;  // bit 1
    Bit#(1)            fanhp_to_seq_fault ;  // bit 0
} EarlyRbks deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) earlyRbksEfghV2p5SpdPg    = 'h10;
    Bit#(8) earlyRbksAbcdV2p5SpdPg    = 'h08;
    Bit#(8) earlyRbksFanToSeqFanFail = 'h04;
    Bit#(8) earlyRbksFanhpToSeqPwrgd  = 'h02;
    Bit#(8) earlyRbksFanhpToSeqFault  = 'h01;
// Register EARLY_RBKS custom type-classes
instance Bitwise#(EarlyRbks);
    function EarlyRbks \& (EarlyRbks i1, EarlyRbks i2) =
        unpack(pack(i1) & pack(i2));
    function EarlyRbks \| (EarlyRbks i1, EarlyRbks i2) =
        unpack(pack(i1) | pack(i2));
    function EarlyRbks \^ (EarlyRbks i1, EarlyRbks i2) =
        unpack(pack(i1) ^ pack(i2));
    function EarlyRbks \~^ (EarlyRbks i1, EarlyRbks i2) =
        unpack(pack(i1) ~^ pack(i2));
    function EarlyRbks \^~ (EarlyRbks i1, EarlyRbks i2) =
        unpack(pack(i1) ^~ pack(i2));
    function EarlyRbks invert (EarlyRbks i) =
        unpack(invert(pack(i)));
    function EarlyRbks \<< (EarlyRbks i, t x) =
        error("Left shift operation is not supported with type EarlyRbks");
    function EarlyRbks \>> (EarlyRbks i, t x) =
        error("Right shift operation is not supported with type EarlyRbks");
    function Bit#(1) msb (EarlyRbks i) =
        error("msb operation is not supported with type EarlyRbks");
    function Bit#(1) lsb (EarlyRbks i) =
        error("lsb operation is not supported with type EarlyRbks");
endinstance

Integer earlyRbksOffset = 12;

// Register A1_READBACKS definitions
typedef struct {
    ReservedZero#(4)   zeros0            ;  // bit 7:4
    Bit#(1)            v0p9_vdd_soc_s5_pg;  // bit 3
    Bit#(1)            v1p8_s5_pg        ;  // bit 2
    Bit#(1)            v3p3_s5_pg        ;  // bit 1
    Bit#(1)            v1p5_rtc_pg       ;  // bit 0
} A1Readbacks deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) a1ReadbacksV0p9VddSocS5Pg = 'h08;
    Bit#(8) a1ReadbacksV1p8S5Pg         = 'h04;
    Bit#(8) a1ReadbacksV3p3S5Pg         = 'h02;
    Bit#(8) a1ReadbacksV1p5RtcPg        = 'h01;
// Register A1_READBACKS custom type-classes
instance Bitwise#(A1Readbacks);
    function A1Readbacks \& (A1Readbacks i1, A1Readbacks i2) =
        unpack(pack(i1) & pack(i2));
    function A1Readbacks \| (A1Readbacks i1, A1Readbacks i2) =
        unpack(pack(i1) | pack(i2));
    function A1Readbacks \^ (A1Readbacks i1, A1Readbacks i2) =
        unpack(pack(i1) ^ pack(i2));
    function A1Readbacks \~^ (A1Readbacks i1, A1Readbacks i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A1Readbacks \^~ (A1Readbacks i1, A1Readbacks i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A1Readbacks invert (A1Readbacks i) =
        unpack(invert(pack(i)));
    function A1Readbacks \<< (A1Readbacks i, t x) =
        error("Left shift operation is not supported with type A1Readbacks");
    function A1Readbacks \>> (A1Readbacks i, t x) =
        error("Right shift operation is not supported with type A1Readbacks");
    function Bit#(1) msb (A1Readbacks i) =
        error("msb operation is not supported with type A1Readbacks");
    function Bit#(1) lsb (A1Readbacks i) =
        error("lsb operation is not supported with type A1Readbacks");
endinstance

Integer a1ReadbacksOffset = 13;

// Register AMD_A0 definitions
typedef struct {
    ReservedZero#(4)   zeros0;  // bit 7:4
    Bit#(1)            reset ;  // bit 3
    Bit#(1)            pwrok ;  // bit 2
    Bit#(1)            slp_s5;  // bit 1
    Bit#(1)            slp_s3;  // bit 0
} AmdA0 deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) amdA0Reset  = 'h08;
    Bit#(8) amdA0Pwrok  = 'h04;
    Bit#(8) amdA0SlpS5 = 'h02;
    Bit#(8) amdA0SlpS3 = 'h01;
// Register AMD_A0 custom type-classes
instance Bitwise#(AmdA0);
    function AmdA0 \& (AmdA0 i1, AmdA0 i2) =
        unpack(pack(i1) & pack(i2));
    function AmdA0 \| (AmdA0 i1, AmdA0 i2) =
        unpack(pack(i1) | pack(i2));
    function AmdA0 \^ (AmdA0 i1, AmdA0 i2) =
        unpack(pack(i1) ^ pack(i2));
    function AmdA0 \~^ (AmdA0 i1, AmdA0 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function AmdA0 \^~ (AmdA0 i1, AmdA0 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function AmdA0 invert (AmdA0 i) =
        unpack(invert(pack(i)));
    function AmdA0 \<< (AmdA0 i, t x) =
        error("Left shift operation is not supported with type AmdA0");
    function AmdA0 \>> (AmdA0 i, t x) =
        error("Right shift operation is not supported with type AmdA0");
    function Bit#(1) msb (AmdA0 i) =
        error("msb operation is not supported with type AmdA0");
    function Bit#(1) lsb (AmdA0 i) =
        error("lsb operation is not supported with type AmdA0");
endinstance

Integer amdA0Offset = 14;

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
// Field mask definitions
    Bit#(8) groupbPgV3p3SysPg     = 'h80;
    Bit#(8) groupbPgV1p8Sp3Pg     = 'h40;
    Bit#(8) groupbPgVttEfghPg     = 'h20;
    Bit#(8) groupbPgVttAbcdPg     = 'h10;
    Bit#(8) groupbPgVddMemEfghPg = 'h08;
    Bit#(8) groupbPgVddMemAbcdPg = 'h04;
    Bit#(8) groupbPgVppEfghPg     = 'h02;
    Bit#(8) groupbPgVppAbcdPg     = 'h01;
// Register GROUPB_PG custom type-classes
instance Bitwise#(GroupbPg);
    function GroupbPg \& (GroupbPg i1, GroupbPg i2) =
        unpack(pack(i1) & pack(i2));
    function GroupbPg \| (GroupbPg i1, GroupbPg i2) =
        unpack(pack(i1) | pack(i2));
    function GroupbPg \^ (GroupbPg i1, GroupbPg i2) =
        unpack(pack(i1) ^ pack(i2));
    function GroupbPg \~^ (GroupbPg i1, GroupbPg i2) =
        unpack(pack(i1) ~^ pack(i2));
    function GroupbPg \^~ (GroupbPg i1, GroupbPg i2) =
        unpack(pack(i1) ^~ pack(i2));
    function GroupbPg invert (GroupbPg i) =
        unpack(invert(pack(i)));
    function GroupbPg \<< (GroupbPg i, t x) =
        error("Left shift operation is not supported with type GroupbPg");
    function GroupbPg \>> (GroupbPg i, t x) =
        error("Right shift operation is not supported with type GroupbPg");
    function Bit#(1) msb (GroupbPg i) =
        error("msb operation is not supported with type GroupbPg");
    function Bit#(1) lsb (GroupbPg i) =
        error("lsb operation is not supported with type GroupbPg");
endinstance

Integer groupbPgOffset = 15;

// Register GROUPB_UNUSED definitions
typedef struct {
    ReservedZero#(5)   zeros0  ;  // bit 7:3
    Bit#(1)            efgh_pg2;  // bit 2
    Bit#(1)            efgh_pg1;  // bit 1
    Bit#(1)            abcd_pg2;  // bit 0
} GroupbUnused deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) groupbUnusedEfghPg2 = 'h04;
    Bit#(8) groupbUnusedEfghPg1 = 'h02;
    Bit#(8) groupbUnusedAbcdPg2 = 'h01;
// Register GROUPB_UNUSED custom type-classes
instance Bitwise#(GroupbUnused);
    function GroupbUnused \& (GroupbUnused i1, GroupbUnused i2) =
        unpack(pack(i1) & pack(i2));
    function GroupbUnused \| (GroupbUnused i1, GroupbUnused i2) =
        unpack(pack(i1) | pack(i2));
    function GroupbUnused \^ (GroupbUnused i1, GroupbUnused i2) =
        unpack(pack(i1) ^ pack(i2));
    function GroupbUnused \~^ (GroupbUnused i1, GroupbUnused i2) =
        unpack(pack(i1) ~^ pack(i2));
    function GroupbUnused \^~ (GroupbUnused i1, GroupbUnused i2) =
        unpack(pack(i1) ^~ pack(i2));
    function GroupbUnused invert (GroupbUnused i) =
        unpack(invert(pack(i)));
    function GroupbUnused \<< (GroupbUnused i, t x) =
        error("Left shift operation is not supported with type GroupbUnused");
    function GroupbUnused \>> (GroupbUnused i, t x) =
        error("Right shift operation is not supported with type GroupbUnused");
    function Bit#(1) msb (GroupbUnused i) =
        error("msb operation is not supported with type GroupbUnused");
    function Bit#(1) lsb (GroupbUnused i) =
        error("lsb operation is not supported with type GroupbUnused");
endinstance

Integer groupbUnusedOffset = 16;

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
// Field mask definitions
    Bit#(8) groupbcFltsCont2Cfp    = 'h80;
    Bit#(8) groupbcFltsCont2Nvrhot = 'h40;
    Bit#(8) groupbcFltsEfghCfp     = 'h20;
    Bit#(8) groupbcFltsEfghNvrhot  = 'h10;
    Bit#(8) groupbcFltsAbcdCfp     = 'h08;
    Bit#(8) groupbcFltsAbcdNvrhot  = 'h04;
    Bit#(8) groupbcFltsCont1Cfp    = 'h02;
    Bit#(8) groupbcFltsCont1Nvrhot = 'h01;
// Register GROUPBC_FLTS custom type-classes
instance Bitwise#(GroupbcFlts);
    function GroupbcFlts \& (GroupbcFlts i1, GroupbcFlts i2) =
        unpack(pack(i1) & pack(i2));
    function GroupbcFlts \| (GroupbcFlts i1, GroupbcFlts i2) =
        unpack(pack(i1) | pack(i2));
    function GroupbcFlts \^ (GroupbcFlts i1, GroupbcFlts i2) =
        unpack(pack(i1) ^ pack(i2));
    function GroupbcFlts \~^ (GroupbcFlts i1, GroupbcFlts i2) =
        unpack(pack(i1) ~^ pack(i2));
    function GroupbcFlts \^~ (GroupbcFlts i1, GroupbcFlts i2) =
        unpack(pack(i1) ^~ pack(i2));
    function GroupbcFlts invert (GroupbcFlts i) =
        unpack(invert(pack(i)));
    function GroupbcFlts \<< (GroupbcFlts i, t x) =
        error("Left shift operation is not supported with type GroupbcFlts");
    function GroupbcFlts \>> (GroupbcFlts i, t x) =
        error("Right shift operation is not supported with type GroupbcFlts");
    function Bit#(1) msb (GroupbcFlts i) =
        error("msb operation is not supported with type GroupbcFlts");
    function Bit#(1) lsb (GroupbcFlts i) =
        error("lsb operation is not supported with type GroupbcFlts");
endinstance

Integer groupbcFltsOffset = 17;

// Register GROUPC_PG definitions
typedef struct {
    ReservedZero#(6)   zeros0      ;  // bit 7:2
    Bit#(1)            vdd_vcore   ;  // bit 1
    Bit#(1)            vddcr_soc_pg;  // bit 0
} GroupcPg deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) groupcPgVddVcore    = 'h02;
    Bit#(8) groupcPgVddcrSocPg = 'h01;
// Register GROUPC_PG custom type-classes
instance Bitwise#(GroupcPg);
    function GroupcPg \& (GroupcPg i1, GroupcPg i2) =
        unpack(pack(i1) & pack(i2));
    function GroupcPg \| (GroupcPg i1, GroupcPg i2) =
        unpack(pack(i1) | pack(i2));
    function GroupcPg \^ (GroupcPg i1, GroupcPg i2) =
        unpack(pack(i1) ^ pack(i2));
    function GroupcPg \~^ (GroupcPg i1, GroupcPg i2) =
        unpack(pack(i1) ~^ pack(i2));
    function GroupcPg \^~ (GroupcPg i1, GroupcPg i2) =
        unpack(pack(i1) ^~ pack(i2));
    function GroupcPg invert (GroupcPg i) =
        unpack(invert(pack(i)));
    function GroupcPg \<< (GroupcPg i, t x) =
        error("Left shift operation is not supported with type GroupcPg");
    function GroupcPg \>> (GroupcPg i, t x) =
        error("Right shift operation is not supported with type GroupcPg");
    function Bit#(1) msb (GroupcPg i) =
        error("msb operation is not supported with type GroupcPg");
    function Bit#(1) lsb (GroupcPg i) =
        error("lsb operation is not supported with type GroupcPg");
endinstance

Integer groupcPgOffset = 18;

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
// Field mask definitions
    Bit#(8) nicStatusNicCfp      = 'h80;
    Bit#(8) nicStatusNicNvrhot   = 'h40;
    Bit#(8) nicStatusNicV1p8Pg  = 'h20;
    Bit#(8) nicStatusNicV1p5Pg  = 'h10;
    Bit#(8) nicStatusNicAv1p5Pg = 'h08;
    Bit#(8) nicStatusNicV1p2Pg  = 'h04;
    Bit#(8) nicStatusNicV1p1Pg  = 'h02;
    Bit#(8) nicStatusNicV0p96Pg = 'h01;
// Register NIC_STATUS custom type-classes
instance Bitwise#(NicStatus);
    function NicStatus \& (NicStatus i1, NicStatus i2) =
        unpack(pack(i1) & pack(i2));
    function NicStatus \| (NicStatus i1, NicStatus i2) =
        unpack(pack(i1) | pack(i2));
    function NicStatus \^ (NicStatus i1, NicStatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function NicStatus \~^ (NicStatus i1, NicStatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function NicStatus \^~ (NicStatus i1, NicStatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function NicStatus invert (NicStatus i) =
        unpack(invert(pack(i)));
    function NicStatus \<< (NicStatus i, t x) =
        error("Left shift operation is not supported with type NicStatus");
    function NicStatus \>> (NicStatus i, t x) =
        error("Right shift operation is not supported with type NicStatus");
    function Bit#(1) msb (NicStatus i) =
        error("msb operation is not supported with type NicStatus");
    function Bit#(1) lsb (NicStatus i) =
        error("lsb operation is not supported with type NicStatus");
endinstance

Integer nicStatusOffset = 19;

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
// Field mask definitions
    Bit#(8) clkgenStatusGpio9  = 'h40;
    Bit#(8) clkgenStatusGpio8  = 'h20;
    Bit#(8) clkgenStatusGpio5  = 'h10;
    Bit#(8) clkgenStatusGpio4  = 'h08;
    Bit#(8) clkgenStatusGpio3  = 'h04;
    Bit#(8) clkgenStatusGpio2  = 'h02;
    Bit#(8) clkgenStatusGpio1  = 'h01;
// Register CLKGEN_STATUS custom type-classes
instance Bitwise#(ClkgenStatus);
    function ClkgenStatus \& (ClkgenStatus i1, ClkgenStatus i2) =
        unpack(pack(i1) & pack(i2));
    function ClkgenStatus \| (ClkgenStatus i1, ClkgenStatus i2) =
        unpack(pack(i1) | pack(i2));
    function ClkgenStatus \^ (ClkgenStatus i1, ClkgenStatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function ClkgenStatus \~^ (ClkgenStatus i1, ClkgenStatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function ClkgenStatus \^~ (ClkgenStatus i1, ClkgenStatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function ClkgenStatus invert (ClkgenStatus i) =
        unpack(invert(pack(i)));
    function ClkgenStatus \<< (ClkgenStatus i, t x) =
        error("Left shift operation is not supported with type ClkgenStatus");
    function ClkgenStatus \>> (ClkgenStatus i, t x) =
        error("Right shift operation is not supported with type ClkgenStatus");
    function Bit#(1) msb (ClkgenStatus i) =
        error("msb operation is not supported with type ClkgenStatus");
    function Bit#(1) lsb (ClkgenStatus i) =
        error("lsb operation is not supported with type ClkgenStatus");
endinstance

Integer clkgenStatusOffset = 20;

// Register AMD_STATUS definitions
typedef struct {
    ReservedZero#(5)   zeros0   ;  // bit 7:3
    Bit#(1)            pwrgd_out;  // bit 2
    Bit#(1)            fsr_req  ;  // bit 1
    Bit#(1)            thermtrip;  // bit 0
} AmdStatus deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) amdStatusPwrgdOut = 'h04;
    Bit#(8) amdStatusFsrReq   = 'h02;
    Bit#(8) amdStatusThermtrip = 'h01;
// Register AMD_STATUS custom type-classes
instance Bitwise#(AmdStatus);
    function AmdStatus \& (AmdStatus i1, AmdStatus i2) =
        unpack(pack(i1) & pack(i2));
    function AmdStatus \| (AmdStatus i1, AmdStatus i2) =
        unpack(pack(i1) | pack(i2));
    function AmdStatus \^ (AmdStatus i1, AmdStatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function AmdStatus \~^ (AmdStatus i1, AmdStatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function AmdStatus \^~ (AmdStatus i1, AmdStatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function AmdStatus invert (AmdStatus i) =
        unpack(invert(pack(i)));
    function AmdStatus \<< (AmdStatus i, t x) =
        error("Left shift operation is not supported with type AmdStatus");
    function AmdStatus \>> (AmdStatus i, t x) =
        error("Right shift operation is not supported with type AmdStatus");
    function Bit#(1) msb (AmdStatus i) =
        error("msb operation is not supported with type AmdStatus");
    function Bit#(1) lsb (AmdStatus i) =
        error("lsb operation is not supported with type AmdStatus");
endinstance

Integer amdStatusOffset = 21;

// Register FANOUTSTATUS definitions
typedef struct {
    ReservedZero#(6)   zeros0       ;  // bit 7:2
    Bit#(1)            fanhp_restart;  // bit 1
    Bit#(1)            fan_hp_en    ;  // bit 0
} Fanoutstatus deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) fanoutstatusFanhpRestart = 'h02;
    Bit#(8) fanoutstatusFanHpEn     = 'h01;
// Register FANOUTSTATUS custom type-classes
instance Bitwise#(Fanoutstatus);
    function Fanoutstatus \& (Fanoutstatus i1, Fanoutstatus i2) =
        unpack(pack(i1) & pack(i2));
    function Fanoutstatus \| (Fanoutstatus i1, Fanoutstatus i2) =
        unpack(pack(i1) | pack(i2));
    function Fanoutstatus \^ (Fanoutstatus i1, Fanoutstatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function Fanoutstatus \~^ (Fanoutstatus i1, Fanoutstatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Fanoutstatus \^~ (Fanoutstatus i1, Fanoutstatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Fanoutstatus invert (Fanoutstatus i) =
        unpack(invert(pack(i)));
    function Fanoutstatus \<< (Fanoutstatus i, t x) =
        error("Left shift operation is not supported with type Fanoutstatus");
    function Fanoutstatus \>> (Fanoutstatus i, t x) =
        error("Right shift operation is not supported with type Fanoutstatus");
    function Bit#(1) msb (Fanoutstatus i) =
        error("msb operation is not supported with type Fanoutstatus");
    function Bit#(1) lsb (Fanoutstatus i) =
        error("lsb operation is not supported with type Fanoutstatus");
endinstance

Integer fanoutstatusOffset = 22;

// Register EARLY_PWR_STATUS definitions
typedef struct {
    Bit#(1)            fanhp_restart;  // bit 7
    ReservedZero#(4)   zeros0       ;  // bit 6:3
    Bit#(1)            efgh_spd_en  ;  // bit 2
    Bit#(1)            abcd_spd_en  ;  // bit 1
    Bit#(1)            fanpwren     ;  // bit 0
} EarlyPwrStatus deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) earlyPwrStatusFanhpRestart = 'h80;
    Bit#(8) earlyPwrStatusEfghSpdEn   = 'h04;
    Bit#(8) earlyPwrStatusAbcdSpdEn   = 'h02;
    Bit#(8) earlyPwrStatusFanpwren      = 'h01;
// Register EARLY_PWR_STATUS custom type-classes
instance Bitwise#(EarlyPwrStatus);
    function EarlyPwrStatus \& (EarlyPwrStatus i1, EarlyPwrStatus i2) =
        unpack(pack(i1) & pack(i2));
    function EarlyPwrStatus \| (EarlyPwrStatus i1, EarlyPwrStatus i2) =
        unpack(pack(i1) | pack(i2));
    function EarlyPwrStatus \^ (EarlyPwrStatus i1, EarlyPwrStatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function EarlyPwrStatus \~^ (EarlyPwrStatus i1, EarlyPwrStatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function EarlyPwrStatus \^~ (EarlyPwrStatus i1, EarlyPwrStatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function EarlyPwrStatus invert (EarlyPwrStatus i) =
        unpack(invert(pack(i)));
    function EarlyPwrStatus \<< (EarlyPwrStatus i, t x) =
        error("Left shift operation is not supported with type EarlyPwrStatus");
    function EarlyPwrStatus \>> (EarlyPwrStatus i, t x) =
        error("Right shift operation is not supported with type EarlyPwrStatus");
    function Bit#(1) msb (EarlyPwrStatus i) =
        error("msb operation is not supported with type EarlyPwrStatus");
    function Bit#(1) lsb (EarlyPwrStatus i) =
        error("lsb operation is not supported with type EarlyPwrStatus");
endinstance

Integer earlyPwrStatusOffset = 23;

// Register A1_OUT_STATUS definitions
typedef struct {
    ReservedZero#(3)   zeros0     ;  // bit 7:5
    Bit#(1)            rsmrst     ;  // bit 4
    Bit#(1)            v0p9_s5_en ;  // bit 3
    Bit#(1)            v1p8_s5_en ;  // bit 2
    Bit#(1)            v1p5_rtc_en;  // bit 1
    Bit#(1)            v3p3_s5_en ;  // bit 0
} A1OutStatus deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) a1OutStatusRsmrst      = 'h10;
    Bit#(8) a1OutStatusV0p9S5En  = 'h08;
    Bit#(8) a1OutStatusV1p8S5En  = 'h04;
    Bit#(8) a1OutStatusV1p5RtcEn = 'h02;
    Bit#(8) a1OutStatusV3p3S5En  = 'h01;
// Register A1_OUT_STATUS custom type-classes
instance Bitwise#(A1OutStatus);
    function A1OutStatus \& (A1OutStatus i1, A1OutStatus i2) =
        unpack(pack(i1) & pack(i2));
    function A1OutStatus \| (A1OutStatus i1, A1OutStatus i2) =
        unpack(pack(i1) | pack(i2));
    function A1OutStatus \^ (A1OutStatus i1, A1OutStatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function A1OutStatus \~^ (A1OutStatus i1, A1OutStatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A1OutStatus \^~ (A1OutStatus i1, A1OutStatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A1OutStatus invert (A1OutStatus i) =
        unpack(invert(pack(i)));
    function A1OutStatus \<< (A1OutStatus i, t x) =
        error("Left shift operation is not supported with type A1OutStatus");
    function A1OutStatus \>> (A1OutStatus i, t x) =
        error("Right shift operation is not supported with type A1OutStatus");
    function Bit#(1) msb (A1OutStatus i) =
        error("msb operation is not supported with type A1OutStatus");
    function Bit#(1) lsb (A1OutStatus i) =
        error("lsb operation is not supported with type A1OutStatus");
endinstance

Integer a1OutStatusOffset = 24;

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
// Field mask definitions
    Bit#(8) a0OutStatus1EfghEn2    = 'h80;
    Bit#(8) a0OutStatus1AbcdEn2    = 'h40;
    Bit#(8) a0OutStatus1EfghEn1    = 'h20;
    Bit#(8) a0OutStatus1V3p3SysEn = 'h10;
    Bit#(8) a0OutStatus1VttEfghEn = 'h08;
    Bit#(8) a0OutStatus1VttAbcdEn = 'h04;
    Bit#(8) a0OutStatus1VppEfghEn = 'h02;
    Bit#(8) a0OutStatus1VppAbcdEn = 'h01;
// Register A0_OUT_STATUS_1 custom type-classes
instance Bitwise#(A0OutStatus1);
    function A0OutStatus1 \& (A0OutStatus1 i1, A0OutStatus1 i2) =
        unpack(pack(i1) & pack(i2));
    function A0OutStatus1 \| (A0OutStatus1 i1, A0OutStatus1 i2) =
        unpack(pack(i1) | pack(i2));
    function A0OutStatus1 \^ (A0OutStatus1 i1, A0OutStatus1 i2) =
        unpack(pack(i1) ^ pack(i2));
    function A0OutStatus1 \~^ (A0OutStatus1 i1, A0OutStatus1 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A0OutStatus1 \^~ (A0OutStatus1 i1, A0OutStatus1 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A0OutStatus1 invert (A0OutStatus1 i) =
        unpack(invert(pack(i)));
    function A0OutStatus1 \<< (A0OutStatus1 i, t x) =
        error("Left shift operation is not supported with type A0OutStatus1");
    function A0OutStatus1 \>> (A0OutStatus1 i, t x) =
        error("Right shift operation is not supported with type A0OutStatus1");
    function Bit#(1) msb (A0OutStatus1 i) =
        error("msb operation is not supported with type A0OutStatus1");
    function Bit#(1) lsb (A0OutStatus1 i) =
        error("lsb operation is not supported with type A0OutStatus1");
endinstance

Integer a0OutStatus1Offset = 25;

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
// Field mask definitions
    Bit#(8) a0OutStatus2PwrGood    = 'h40;
    Bit#(8) a0OutStatus2PwrBtn     = 'h20;
    Bit#(8) a0OutStatus2Cont2En    = 'h10;
    Bit#(8) a0OutStatus2Cont1En    = 'h08;
    Bit#(8) a0OutStatus2V1p8Sp3En = 'h04;
    Bit#(8) a0OutStatus2U351Pwrok  = 'h02;
    Bit#(8) a0OutStatus2U350Pwrok  = 'h01;
// Register A0_OUT_STATUS_2 custom type-classes
instance Bitwise#(A0OutStatus2);
    function A0OutStatus2 \& (A0OutStatus2 i1, A0OutStatus2 i2) =
        unpack(pack(i1) & pack(i2));
    function A0OutStatus2 \| (A0OutStatus2 i1, A0OutStatus2 i2) =
        unpack(pack(i1) | pack(i2));
    function A0OutStatus2 \^ (A0OutStatus2 i1, A0OutStatus2 i2) =
        unpack(pack(i1) ^ pack(i2));
    function A0OutStatus2 \~^ (A0OutStatus2 i1, A0OutStatus2 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A0OutStatus2 \^~ (A0OutStatus2 i1, A0OutStatus2 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A0OutStatus2 invert (A0OutStatus2 i) =
        unpack(invert(pack(i)));
    function A0OutStatus2 \<< (A0OutStatus2 i, t x) =
        error("Left shift operation is not supported with type A0OutStatus2");
    function A0OutStatus2 \>> (A0OutStatus2 i, t x) =
        error("Right shift operation is not supported with type A0OutStatus2");
    function Bit#(1) msb (A0OutStatus2 i) =
        error("msb operation is not supported with type A0OutStatus2");
    function Bit#(1) lsb (A0OutStatus2 i) =
        error("lsb operation is not supported with type A0OutStatus2");
endinstance

Integer a0OutStatus2Offset = 26;

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
// Field mask definitions
    Bit#(8) outStatusNic1NicV3p3        = 'h80;
    Bit#(8) outStatusNic1NicV1p1En     = 'h40;
    Bit#(8) outStatusNic1NicV1p2En     = 'h20;
    Bit#(8) outStatusNic1NicV1p5dEn    = 'h10;
    Bit#(8) outStatusNic1NicV1p5aEn    = 'h08;
    Bit#(8) outStatusNic1NicContEn1    = 'h04;
    Bit#(8) outStatusNic1NicContEn0    = 'h02;
    Bit#(8) outStatusNic1NicV1p2EthEn = 'h01;
// Register OUT_STATUS_NIC1 custom type-classes
instance Bitwise#(OutStatusNic1);
    function OutStatusNic1 \& (OutStatusNic1 i1, OutStatusNic1 i2) =
        unpack(pack(i1) & pack(i2));
    function OutStatusNic1 \| (OutStatusNic1 i1, OutStatusNic1 i2) =
        unpack(pack(i1) | pack(i2));
    function OutStatusNic1 \^ (OutStatusNic1 i1, OutStatusNic1 i2) =
        unpack(pack(i1) ^ pack(i2));
    function OutStatusNic1 \~^ (OutStatusNic1 i1, OutStatusNic1 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function OutStatusNic1 \^~ (OutStatusNic1 i1, OutStatusNic1 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function OutStatusNic1 invert (OutStatusNic1 i) =
        unpack(invert(pack(i)));
    function OutStatusNic1 \<< (OutStatusNic1 i, t x) =
        error("Left shift operation is not supported with type OutStatusNic1");
    function OutStatusNic1 \>> (OutStatusNic1 i, t x) =
        error("Right shift operation is not supported with type OutStatusNic1");
    function Bit#(1) msb (OutStatusNic1 i) =
        error("msb operation is not supported with type OutStatusNic1");
    function Bit#(1) lsb (OutStatusNic1 i) =
        error("lsb operation is not supported with type OutStatusNic1");
endinstance

Integer outStatusNic1Offset = 27;

// Register OUT_STATUS_NIC2 definitions
typedef struct {
    ReservedZero#(5)   zeros0     ;  // bit 7:3
    Bit#(1)            pwrflt     ;  // bit 2
    Bit#(1)            nic_cld_rst;  // bit 1
    Bit#(1)            nic_comb_pg;  // bit 0
} OutStatusNic2 deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) outStatusNic2Pwrflt      = 'h04;
    Bit#(8) outStatusNic2NicCldRst = 'h02;
    Bit#(8) outStatusNic2NicCombPg = 'h01;
// Register OUT_STATUS_NIC2 custom type-classes
instance Bitwise#(OutStatusNic2);
    function OutStatusNic2 \& (OutStatusNic2 i1, OutStatusNic2 i2) =
        unpack(pack(i1) & pack(i2));
    function OutStatusNic2 \| (OutStatusNic2 i1, OutStatusNic2 i2) =
        unpack(pack(i1) | pack(i2));
    function OutStatusNic2 \^ (OutStatusNic2 i1, OutStatusNic2 i2) =
        unpack(pack(i1) ^ pack(i2));
    function OutStatusNic2 \~^ (OutStatusNic2 i1, OutStatusNic2 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function OutStatusNic2 \^~ (OutStatusNic2 i1, OutStatusNic2 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function OutStatusNic2 invert (OutStatusNic2 i) =
        unpack(invert(pack(i)));
    function OutStatusNic2 \<< (OutStatusNic2 i, t x) =
        error("Left shift operation is not supported with type OutStatusNic2");
    function OutStatusNic2 \>> (OutStatusNic2 i, t x) =
        error("Right shift operation is not supported with type OutStatusNic2");
    function Bit#(1) msb (OutStatusNic2 i) =
        error("msb operation is not supported with type OutStatusNic2");
    function Bit#(1) lsb (OutStatusNic2 i) =
        error("lsb operation is not supported with type OutStatusNic2");
endinstance

Integer outStatusNic2Offset = 28;

// Register CLKGEN_OUT_STATUS definitions
typedef struct {
    ReservedZero#(7)   zeros0 ;  // bit 7:1
    Bit#(1)            seq_nmr;  // bit 0
} ClkgenOutStatus deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) clkgenOutStatusSeqNmr = 'h01;
// Register CLKGEN_OUT_STATUS custom type-classes
instance Bitwise#(ClkgenOutStatus);
    function ClkgenOutStatus \& (ClkgenOutStatus i1, ClkgenOutStatus i2) =
        unpack(pack(i1) & pack(i2));
    function ClkgenOutStatus \| (ClkgenOutStatus i1, ClkgenOutStatus i2) =
        unpack(pack(i1) | pack(i2));
    function ClkgenOutStatus \^ (ClkgenOutStatus i1, ClkgenOutStatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function ClkgenOutStatus \~^ (ClkgenOutStatus i1, ClkgenOutStatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function ClkgenOutStatus \^~ (ClkgenOutStatus i1, ClkgenOutStatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function ClkgenOutStatus invert (ClkgenOutStatus i) =
        unpack(invert(pack(i)));
    function ClkgenOutStatus \<< (ClkgenOutStatus i, t x) =
        error("Left shift operation is not supported with type ClkgenOutStatus");
    function ClkgenOutStatus \>> (ClkgenOutStatus i, t x) =
        error("Right shift operation is not supported with type ClkgenOutStatus");
    function Bit#(1) msb (ClkgenOutStatus i) =
        error("msb operation is not supported with type ClkgenOutStatus");
    function Bit#(1) lsb (ClkgenOutStatus i) =
        error("lsb operation is not supported with type ClkgenOutStatus");
endinstance

Integer clkgenOutStatusOffset = 29;

// Register AMD_OUT_STATUS definitions
typedef struct {
    ReservedZero#(7)   zeros0   ;  // bit 7:1
    Bit#(1)            sys_reset;  // bit 0
} AmdOutStatus deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) amdOutStatusSysReset = 'h01;
// Register AMD_OUT_STATUS custom type-classes
instance Bitwise#(AmdOutStatus);
    function AmdOutStatus \& (AmdOutStatus i1, AmdOutStatus i2) =
        unpack(pack(i1) & pack(i2));
    function AmdOutStatus \| (AmdOutStatus i1, AmdOutStatus i2) =
        unpack(pack(i1) | pack(i2));
    function AmdOutStatus \^ (AmdOutStatus i1, AmdOutStatus i2) =
        unpack(pack(i1) ^ pack(i2));
    function AmdOutStatus \~^ (AmdOutStatus i1, AmdOutStatus i2) =
        unpack(pack(i1) ~^ pack(i2));
    function AmdOutStatus \^~ (AmdOutStatus i1, AmdOutStatus i2) =
        unpack(pack(i1) ^~ pack(i2));
    function AmdOutStatus invert (AmdOutStatus i) =
        unpack(invert(pack(i)));
    function AmdOutStatus \<< (AmdOutStatus i, t x) =
        error("Left shift operation is not supported with type AmdOutStatus");
    function AmdOutStatus \>> (AmdOutStatus i, t x) =
        error("Right shift operation is not supported with type AmdOutStatus");
    function Bit#(1) msb (AmdOutStatus i) =
        error("msb operation is not supported with type AmdOutStatus");
    function Bit#(1) lsb (AmdOutStatus i) =
        error("lsb operation is not supported with type AmdOutStatus");
endinstance

Integer amdOutStatusOffset = 30;

// Register DBG_CTRL definitions
typedef struct {
    ReservedZero#(5)   zeros0       ;  // bit 7:3
    Bit#(1)            store_current;  // bit 2
    Bit#(1)            reg_ctrl_en  ;  // bit 1
    Bit#(1)            ignore_sp    ;  // bit 0
} DbgCtrl deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) dbgCtrlStoreCurrent = 'h04;
    Bit#(8) dbgCtrlRegCtrlEn   = 'h02;
    Bit#(8) dbgCtrlIgnoreSp     = 'h01;
// Register DBG_CTRL custom type-classes
instance Bitwise#(DbgCtrl);
    function DbgCtrl \& (DbgCtrl i1, DbgCtrl i2) =
        unpack(pack(i1) & pack(i2));
    function DbgCtrl \| (DbgCtrl i1, DbgCtrl i2) =
        unpack(pack(i1) | pack(i2));
    function DbgCtrl \^ (DbgCtrl i1, DbgCtrl i2) =
        unpack(pack(i1) ^ pack(i2));
    function DbgCtrl \~^ (DbgCtrl i1, DbgCtrl i2) =
        unpack(pack(i1) ~^ pack(i2));
    function DbgCtrl \^~ (DbgCtrl i1, DbgCtrl i2) =
        unpack(pack(i1) ^~ pack(i2));
    function DbgCtrl invert (DbgCtrl i) =
        unpack(invert(pack(i)));
    function DbgCtrl \<< (DbgCtrl i, t x) =
        error("Left shift operation is not supported with type DbgCtrl");
    function DbgCtrl \>> (DbgCtrl i, t x) =
        error("Right shift operation is not supported with type DbgCtrl");
    function Bit#(1) msb (DbgCtrl i) =
        error("msb operation is not supported with type DbgCtrl");
    function Bit#(1) lsb (DbgCtrl i) =
        error("lsb operation is not supported with type DbgCtrl");
endinstance

Integer dbgCtrlOffset = 31;

// Register A1_DBG_OUT definitions
typedef struct {
    ReservedZero#(3)   zeros0     ;  // bit 7:5
    Bit#(1)            rsmrst     ;  // bit 4
    Bit#(1)            v0p9_s5_en ;  // bit 3
    Bit#(1)            v1p8_s5_en ;  // bit 2
    Bit#(1)            v1p5_rtc_en;  // bit 1
    Bit#(1)            v3p3_s5_en ;  // bit 0
} A1DbgOut deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) a1DbgOutRsmrst      = 'h10;
    Bit#(8) a1DbgOutV0p9S5En  = 'h08;
    Bit#(8) a1DbgOutV1p8S5En  = 'h04;
    Bit#(8) a1DbgOutV1p5RtcEn = 'h02;
    Bit#(8) a1DbgOutV3p3S5En  = 'h01;
// Register A1_DBG_OUT custom type-classes
instance Bitwise#(A1DbgOut);
    function A1DbgOut \& (A1DbgOut i1, A1DbgOut i2) =
        unpack(pack(i1) & pack(i2));
    function A1DbgOut \| (A1DbgOut i1, A1DbgOut i2) =
        unpack(pack(i1) | pack(i2));
    function A1DbgOut \^ (A1DbgOut i1, A1DbgOut i2) =
        unpack(pack(i1) ^ pack(i2));
    function A1DbgOut \~^ (A1DbgOut i1, A1DbgOut i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A1DbgOut \^~ (A1DbgOut i1, A1DbgOut i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A1DbgOut invert (A1DbgOut i) =
        unpack(invert(pack(i)));
    function A1DbgOut \<< (A1DbgOut i, t x) =
        error("Left shift operation is not supported with type A1DbgOut");
    function A1DbgOut \>> (A1DbgOut i, t x) =
        error("Right shift operation is not supported with type A1DbgOut");
    function Bit#(1) msb (A1DbgOut i) =
        error("msb operation is not supported with type A1DbgOut");
    function Bit#(1) lsb (A1DbgOut i) =
        error("lsb operation is not supported with type A1DbgOut");
endinstance

Integer a1DbgOutOffset = 32;

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
// Field mask definitions
    Bit#(8) a0DbgOut1EfghEn2    = 'h80;
    Bit#(8) a0DbgOut1AbcdEn2    = 'h40;
    Bit#(8) a0DbgOut1EfghEn1    = 'h20;
    Bit#(8) a0DbgOut1V3p3SysEn = 'h10;
    Bit#(8) a0DbgOut1VttEfghEn = 'h08;
    Bit#(8) a0DbgOut1VttAbcdEn = 'h04;
    Bit#(8) a0DbgOut1VppEfghEn = 'h02;
    Bit#(8) a0DbgOut1VppAbcdEn = 'h01;
// Register A0_DBG_OUT_1 custom type-classes
instance Bitwise#(A0DbgOut1);
    function A0DbgOut1 \& (A0DbgOut1 i1, A0DbgOut1 i2) =
        unpack(pack(i1) & pack(i2));
    function A0DbgOut1 \| (A0DbgOut1 i1, A0DbgOut1 i2) =
        unpack(pack(i1) | pack(i2));
    function A0DbgOut1 \^ (A0DbgOut1 i1, A0DbgOut1 i2) =
        unpack(pack(i1) ^ pack(i2));
    function A0DbgOut1 \~^ (A0DbgOut1 i1, A0DbgOut1 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A0DbgOut1 \^~ (A0DbgOut1 i1, A0DbgOut1 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A0DbgOut1 invert (A0DbgOut1 i) =
        unpack(invert(pack(i)));
    function A0DbgOut1 \<< (A0DbgOut1 i, t x) =
        error("Left shift operation is not supported with type A0DbgOut1");
    function A0DbgOut1 \>> (A0DbgOut1 i, t x) =
        error("Right shift operation is not supported with type A0DbgOut1");
    function Bit#(1) msb (A0DbgOut1 i) =
        error("msb operation is not supported with type A0DbgOut1");
    function Bit#(1) lsb (A0DbgOut1 i) =
        error("lsb operation is not supported with type A0DbgOut1");
endinstance

Integer a0DbgOut1Offset = 33;

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
// Field mask definitions
    Bit#(8) a0DbgOut2PwrGood    = 'h40;
    Bit#(8) a0DbgOut2PwrBtn     = 'h20;
    Bit#(8) a0DbgOut2Cont2En    = 'h10;
    Bit#(8) a0DbgOut2Cont1En    = 'h08;
    Bit#(8) a0DbgOut2V1p8Sp3En = 'h04;
    Bit#(8) a0DbgOut2U351Pwrok  = 'h02;
    Bit#(8) a0DbgOut2U350Pwrok  = 'h01;
// Register A0_DBG_OUT_2 custom type-classes
instance Bitwise#(A0DbgOut2);
    function A0DbgOut2 \& (A0DbgOut2 i1, A0DbgOut2 i2) =
        unpack(pack(i1) & pack(i2));
    function A0DbgOut2 \| (A0DbgOut2 i1, A0DbgOut2 i2) =
        unpack(pack(i1) | pack(i2));
    function A0DbgOut2 \^ (A0DbgOut2 i1, A0DbgOut2 i2) =
        unpack(pack(i1) ^ pack(i2));
    function A0DbgOut2 \~^ (A0DbgOut2 i1, A0DbgOut2 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function A0DbgOut2 \^~ (A0DbgOut2 i1, A0DbgOut2 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function A0DbgOut2 invert (A0DbgOut2 i) =
        unpack(invert(pack(i)));
    function A0DbgOut2 \<< (A0DbgOut2 i, t x) =
        error("Left shift operation is not supported with type A0DbgOut2");
    function A0DbgOut2 \>> (A0DbgOut2 i, t x) =
        error("Right shift operation is not supported with type A0DbgOut2");
    function Bit#(1) msb (A0DbgOut2 i) =
        error("msb operation is not supported with type A0DbgOut2");
    function Bit#(1) lsb (A0DbgOut2 i) =
        error("lsb operation is not supported with type A0DbgOut2");
endinstance

Integer a0DbgOut2Offset = 34;

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
// Field mask definitions
    Bit#(8) dbgOutNic1NicV3p3        = 'h80;
    Bit#(8) dbgOutNic1NicV1p1En     = 'h40;
    Bit#(8) dbgOutNic1NicV1p2En     = 'h20;
    Bit#(8) dbgOutNic1NicV1p5dEn    = 'h10;
    Bit#(8) dbgOutNic1NicV1p5aEn    = 'h08;
    Bit#(8) dbgOutNic1NicContEn1    = 'h04;
    Bit#(8) dbgOutNic1NicContEn0    = 'h02;
    Bit#(8) dbgOutNic1NicV1p2EthEn = 'h01;
// Register DBG_OUT_NIC1 custom type-classes
instance Bitwise#(DbgOutNic1);
    function DbgOutNic1 \& (DbgOutNic1 i1, DbgOutNic1 i2) =
        unpack(pack(i1) & pack(i2));
    function DbgOutNic1 \| (DbgOutNic1 i1, DbgOutNic1 i2) =
        unpack(pack(i1) | pack(i2));
    function DbgOutNic1 \^ (DbgOutNic1 i1, DbgOutNic1 i2) =
        unpack(pack(i1) ^ pack(i2));
    function DbgOutNic1 \~^ (DbgOutNic1 i1, DbgOutNic1 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function DbgOutNic1 \^~ (DbgOutNic1 i1, DbgOutNic1 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function DbgOutNic1 invert (DbgOutNic1 i) =
        unpack(invert(pack(i)));
    function DbgOutNic1 \<< (DbgOutNic1 i, t x) =
        error("Left shift operation is not supported with type DbgOutNic1");
    function DbgOutNic1 \>> (DbgOutNic1 i, t x) =
        error("Right shift operation is not supported with type DbgOutNic1");
    function Bit#(1) msb (DbgOutNic1 i) =
        error("msb operation is not supported with type DbgOutNic1");
    function Bit#(1) lsb (DbgOutNic1 i) =
        error("lsb operation is not supported with type DbgOutNic1");
endinstance

Integer dbgOutNic1Offset = 35;

// Register DBG_OUT_NIC2 definitions
typedef struct {
    ReservedZero#(5)   zeros0     ;  // bit 7:3
    Bit#(1)            pwrflt     ;  // bit 2
    Bit#(1)            nic_cld_rst;  // bit 1
    Bit#(1)            nic_comb_pg;  // bit 0
} DbgOutNic2 deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) dbgOutNic2Pwrflt      = 'h04;
    Bit#(8) dbgOutNic2NicCldRst = 'h02;
    Bit#(8) dbgOutNic2NicCombPg = 'h01;
// Register DBG_OUT_NIC2 custom type-classes
instance Bitwise#(DbgOutNic2);
    function DbgOutNic2 \& (DbgOutNic2 i1, DbgOutNic2 i2) =
        unpack(pack(i1) & pack(i2));
    function DbgOutNic2 \| (DbgOutNic2 i1, DbgOutNic2 i2) =
        unpack(pack(i1) | pack(i2));
    function DbgOutNic2 \^ (DbgOutNic2 i1, DbgOutNic2 i2) =
        unpack(pack(i1) ^ pack(i2));
    function DbgOutNic2 \~^ (DbgOutNic2 i1, DbgOutNic2 i2) =
        unpack(pack(i1) ~^ pack(i2));
    function DbgOutNic2 \^~ (DbgOutNic2 i1, DbgOutNic2 i2) =
        unpack(pack(i1) ^~ pack(i2));
    function DbgOutNic2 invert (DbgOutNic2 i) =
        unpack(invert(pack(i)));
    function DbgOutNic2 \<< (DbgOutNic2 i, t x) =
        error("Left shift operation is not supported with type DbgOutNic2");
    function DbgOutNic2 \>> (DbgOutNic2 i, t x) =
        error("Right shift operation is not supported with type DbgOutNic2");
    function Bit#(1) msb (DbgOutNic2 i) =
        error("msb operation is not supported with type DbgOutNic2");
    function Bit#(1) lsb (DbgOutNic2 i) =
        error("lsb operation is not supported with type DbgOutNic2");
endinstance

Integer dbgOutNic2Offset = 36;

// Register CLKGEN_DBG_OUT definitions
typedef struct {
    ReservedZero#(7)   zeros0 ;  // bit 7:1
    Bit#(1)            seq_nmr;  // bit 0
} ClkgenDbgOut deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) clkgenDbgOutSeqNmr = 'h01;
// Register CLKGEN_DBG_OUT custom type-classes
instance Bitwise#(ClkgenDbgOut);
    function ClkgenDbgOut \& (ClkgenDbgOut i1, ClkgenDbgOut i2) =
        unpack(pack(i1) & pack(i2));
    function ClkgenDbgOut \| (ClkgenDbgOut i1, ClkgenDbgOut i2) =
        unpack(pack(i1) | pack(i2));
    function ClkgenDbgOut \^ (ClkgenDbgOut i1, ClkgenDbgOut i2) =
        unpack(pack(i1) ^ pack(i2));
    function ClkgenDbgOut \~^ (ClkgenDbgOut i1, ClkgenDbgOut i2) =
        unpack(pack(i1) ~^ pack(i2));
    function ClkgenDbgOut \^~ (ClkgenDbgOut i1, ClkgenDbgOut i2) =
        unpack(pack(i1) ^~ pack(i2));
    function ClkgenDbgOut invert (ClkgenDbgOut i) =
        unpack(invert(pack(i)));
    function ClkgenDbgOut \<< (ClkgenDbgOut i, t x) =
        error("Left shift operation is not supported with type ClkgenDbgOut");
    function ClkgenDbgOut \>> (ClkgenDbgOut i, t x) =
        error("Right shift operation is not supported with type ClkgenDbgOut");
    function Bit#(1) msb (ClkgenDbgOut i) =
        error("msb operation is not supported with type ClkgenDbgOut");
    function Bit#(1) lsb (ClkgenDbgOut i) =
        error("lsb operation is not supported with type ClkgenDbgOut");
endinstance

Integer clkgenDbgOutOffset = 37;

// Register AMD_DBG_OUT definitions
typedef struct {
    ReservedZero#(7)   zeros0   ;  // bit 7:1
    Bit#(1)            sys_reset;  // bit 0
} AmdDbgOut deriving (Bits, Eq, FShow);
// Field mask definitions
    Bit#(8) amdDbgOutSysReset = 'h01;
// Register AMD_DBG_OUT custom type-classes
instance Bitwise#(AmdDbgOut);
    function AmdDbgOut \& (AmdDbgOut i1, AmdDbgOut i2) =
        unpack(pack(i1) & pack(i2));
    function AmdDbgOut \| (AmdDbgOut i1, AmdDbgOut i2) =
        unpack(pack(i1) | pack(i2));
    function AmdDbgOut \^ (AmdDbgOut i1, AmdDbgOut i2) =
        unpack(pack(i1) ^ pack(i2));
    function AmdDbgOut \~^ (AmdDbgOut i1, AmdDbgOut i2) =
        unpack(pack(i1) ~^ pack(i2));
    function AmdDbgOut \^~ (AmdDbgOut i1, AmdDbgOut i2) =
        unpack(pack(i1) ^~ pack(i2));
    function AmdDbgOut invert (AmdDbgOut i) =
        unpack(invert(pack(i)));
    function AmdDbgOut \<< (AmdDbgOut i, t x) =
        error("Left shift operation is not supported with type AmdDbgOut");
    function AmdDbgOut \>> (AmdDbgOut i, t x) =
        error("Right shift operation is not supported with type AmdDbgOut");
    function Bit#(1) msb (AmdDbgOut i) =
        error("msb operation is not supported with type AmdDbgOut");
    function Bit#(1) lsb (AmdDbgOut i) =
        error("lsb operation is not supported with type AmdDbgOut");
endinstance

Integer amdDbgOutOffset = 38;

endpackage: GimletSeqFpgaRegs