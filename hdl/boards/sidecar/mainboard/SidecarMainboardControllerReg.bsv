
// This is a generated file using the RDL tooling. Do not edit by hand.
package SidecarMainboardControllerReg;

import Reserved::*;
import RegCommon::*;

// Register ID0 definitions
typedef struct {
        Bit#(8)            id0   ;  // bit 7:0

} Id0 deriving (Eq, FShow);
// Register offsets
Integer id0Offset = 0;
// Field mask definitions
    Bit#(8) id0Id0    = 'hff;
// Register ID0 custom type-classes
instance Bits#(Id0, 8);
    function Bit#(8) pack (Id0 r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.id0;
        return bts;
    endfunction: pack
    function Id0 unpack (Bit#(8) b);
        let r = Id0 {
        id0: b[7:0]
        };

        return r;
    endfunction: unpack

endinstance

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

// Register ID1 definitions
typedef struct {
        Bit#(8)            id1   ;  // bit 7:0

} Id1 deriving (Eq, FShow);
// Register offsets
Integer id1Offset = 1;
// Field mask definitions
    Bit#(8) id1Id1    = 'hff;
// Register ID1 custom type-classes
instance Bits#(Id1, 8);
    function Bit#(8) pack (Id1 r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.id1;
        return bts;
    endfunction: pack
    function Id1 unpack (Bit#(8) b);
        let r = Id1 {
        id1: b[7:0]
        };

        return r;
    endfunction: unpack

endinstance

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

// Register ID2 definitions
typedef struct {
        Bit#(8)            id2   ;  // bit 7:0

} Id2 deriving (Eq, FShow);
// Register offsets
Integer id2Offset = 2;
// Field mask definitions
    Bit#(8) id2Id2    = 'hff;
// Register ID2 custom type-classes
instance Bits#(Id2, 8);
    function Bit#(8) pack (Id2 r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.id2;
        return bts;
    endfunction: pack
    function Id2 unpack (Bit#(8) b);
        let r = Id2 {
        id2: b[7:0]
        };

        return r;
    endfunction: unpack

endinstance

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

// Register ID3 definitions
typedef struct {
        Bit#(8)            id3   ;  // bit 7:0

} Id3 deriving (Eq, FShow);
// Register offsets
Integer id3Offset = 3;
// Field mask definitions
    Bit#(8) id3Id3    = 'hff;
// Register ID3 custom type-classes
instance Bits#(Id3, 8);
    function Bit#(8) pack (Id3 r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.id3;
        return bts;
    endfunction: pack
    function Id3 unpack (Bit#(8) b);
        let r = Id3 {
        id3: b[7:0]
        };

        return r;
    endfunction: unpack

endinstance

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

// Register SCRATCHPAD definitions
typedef struct {
        Bit#(8)            scratchpad;  // bit 7:0

} Scratchpad deriving (Eq, FShow);
// Register offsets
Integer scratchpadOffset = 4;
// Field mask definitions
    Bit#(8) scratchpadScratchpad = 'hff;
// Register SCRATCHPAD custom type-classes
instance Bits#(Scratchpad, 8);
    function Bit#(8) pack (Scratchpad r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.scratchpad;
        return bts;
    endfunction: pack
    function Scratchpad unpack (Bit#(8) b);
        let r = Scratchpad {
        scratchpad: b[7:0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(Scratchpad);
    function Scratchpad \& (Scratchpad i1, Scratchpad i2) =
        unpack(pack(i1) & pack(i2));
    function Scratchpad \| (Scratchpad i1, Scratchpad i2) =
        unpack(pack(i1) | pack(i2));
    function Scratchpad \^ (Scratchpad i1, Scratchpad i2) =
        unpack(pack(i1) ^ pack(i2));
    function Scratchpad \~^ (Scratchpad i1, Scratchpad i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Scratchpad \^~ (Scratchpad i1, Scratchpad i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Scratchpad invert (Scratchpad i) =
        unpack(invert(pack(i)));
    function Scratchpad \<< (Scratchpad i, t x) =
        error("Left shift operation is not supported with type Scratchpad");
    function Scratchpad \>> (Scratchpad i, t x) =
        error("Right shift operation is not supported with type Scratchpad");
    function Bit#(1) msb (Scratchpad i) =
        error("msb operation is not supported with type Scratchpad");
    function Bit#(1) lsb (Scratchpad i) =
        error("lsb operation is not supported with type Scratchpad");
endinstance

// Register TOFINO_SEQ_CTRL definitions
typedef struct {

        Bit#(1)            pcie_reset ;  // bit 3

        Bit#(1)            ack_vid    ;  // bit 2

        Bit#(1)            en         ;  // bit 1

        Bit#(1)            clear_error;  // bit 0

} TofinoSeqCtrl deriving (Eq, FShow);
// Register offsets
Integer tofinoSeqCtrlOffset = 5;
// Field mask definitions
    Bit#(8) tofinoSeqCtrlPcieReset  = 'h08;
    Bit#(8) tofinoSeqCtrlAckVid     = 'h04;
    Bit#(8) tofinoSeqCtrlEn          = 'h02;
    Bit#(8) tofinoSeqCtrlClearError = 'h01;
// Register TOFINO_SEQ_CTRL custom type-classes
instance Bits#(TofinoSeqCtrl, 8);
    function Bit#(8) pack (TofinoSeqCtrl r);
        Bit#(8) bts =  'h00;
        bts[3] = r.pcie_reset;
        bts[2] = r.ack_vid;
        bts[1] = r.en;
        bts[0] = r.clear_error;
        return bts;
    endfunction: pack
    function TofinoSeqCtrl unpack (Bit#(8) b);
        let r = TofinoSeqCtrl {
        pcie_reset: b[3] ,
        ack_vid: b[2] ,
        en: b[1] ,
        clear_error: b[0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoSeqCtrl);
    function TofinoSeqCtrl \& (TofinoSeqCtrl i1, TofinoSeqCtrl i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoSeqCtrl \| (TofinoSeqCtrl i1, TofinoSeqCtrl i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoSeqCtrl \^ (TofinoSeqCtrl i1, TofinoSeqCtrl i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoSeqCtrl \~^ (TofinoSeqCtrl i1, TofinoSeqCtrl i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoSeqCtrl \^~ (TofinoSeqCtrl i1, TofinoSeqCtrl i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoSeqCtrl invert (TofinoSeqCtrl i) =
        unpack(invert(pack(i)));
    function TofinoSeqCtrl \<< (TofinoSeqCtrl i, t x) =
        error("Left shift operation is not supported with type TofinoSeqCtrl");
    function TofinoSeqCtrl \>> (TofinoSeqCtrl i, t x) =
        error("Right shift operation is not supported with type TofinoSeqCtrl");
    function Bit#(1) msb (TofinoSeqCtrl i) =
        error("msb operation is not supported with type TofinoSeqCtrl");
    function Bit#(1) lsb (TofinoSeqCtrl i) =
        error("lsb operation is not supported with type TofinoSeqCtrl");
endinstance

// Register TOFINO_SEQ_STATE definitions
typedef struct {

        Bit#(3)            state ;  // bit 2:0

} TofinoSeqState deriving (Eq, FShow);
// Register offsets
Integer tofinoSeqStateOffset = 6;
// Field mask definitions
    Bit#(8) tofinoSeqStateState  = 'h07;
// Register TOFINO_SEQ_STATE custom type-classes
instance Bits#(TofinoSeqState, 8);
    function Bit#(8) pack (TofinoSeqState r);
        Bit#(8) bts =  'h00;
        bts[2:0] = r.state;
        return bts;
    endfunction: pack
    function TofinoSeqState unpack (Bit#(8) b);
        let r = TofinoSeqState {
        state: b[2:0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoSeqState);
    function TofinoSeqState \& (TofinoSeqState i1, TofinoSeqState i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoSeqState \| (TofinoSeqState i1, TofinoSeqState i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoSeqState \^ (TofinoSeqState i1, TofinoSeqState i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoSeqState \~^ (TofinoSeqState i1, TofinoSeqState i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoSeqState \^~ (TofinoSeqState i1, TofinoSeqState i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoSeqState invert (TofinoSeqState i) =
        unpack(invert(pack(i)));
    function TofinoSeqState \<< (TofinoSeqState i, t x) =
        error("Left shift operation is not supported with type TofinoSeqState");
    function TofinoSeqState \>> (TofinoSeqState i, t x) =
        error("Right shift operation is not supported with type TofinoSeqState");
    function Bit#(1) msb (TofinoSeqState i) =
        error("msb operation is not supported with type TofinoSeqState");
    function Bit#(1) lsb (TofinoSeqState i) =
        error("lsb operation is not supported with type TofinoSeqState");
endinstance

// Register TOFINO_SEQ_STEP definitions
typedef struct {
        Bit#(8)            step  ;  // bit 7:0

} TofinoSeqStep deriving (Eq, FShow);
// Register offsets
Integer tofinoSeqStepOffset = 7;
// Field mask definitions
    Bit#(8) tofinoSeqStepStep   = 'hff;
// Register TOFINO_SEQ_STEP custom type-classes
instance Bits#(TofinoSeqStep, 8);
    function Bit#(8) pack (TofinoSeqStep r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.step;
        return bts;
    endfunction: pack
    function TofinoSeqStep unpack (Bit#(8) b);
        let r = TofinoSeqStep {
        step: b[7:0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoSeqStep);
    function TofinoSeqStep \& (TofinoSeqStep i1, TofinoSeqStep i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoSeqStep \| (TofinoSeqStep i1, TofinoSeqStep i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoSeqStep \^ (TofinoSeqStep i1, TofinoSeqStep i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoSeqStep \~^ (TofinoSeqStep i1, TofinoSeqStep i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoSeqStep \^~ (TofinoSeqStep i1, TofinoSeqStep i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoSeqStep invert (TofinoSeqStep i) =
        unpack(invert(pack(i)));
    function TofinoSeqStep \<< (TofinoSeqStep i, t x) =
        error("Left shift operation is not supported with type TofinoSeqStep");
    function TofinoSeqStep \>> (TofinoSeqStep i, t x) =
        error("Right shift operation is not supported with type TofinoSeqStep");
    function Bit#(1) msb (TofinoSeqStep i) =
        error("msb operation is not supported with type TofinoSeqStep");
    function Bit#(1) lsb (TofinoSeqStep i) =
        error("lsb operation is not supported with type TofinoSeqStep");
endinstance

// Register TOFINO_SEQ_ERROR definitions
typedef struct {
        Bit#(8)            error ;  // bit 7:0

} TofinoSeqError deriving (Eq, FShow);
// Register offsets
Integer tofinoSeqErrorOffset = 8;
// Field mask definitions
    Bit#(8) tofinoSeqErrorError  = 'hff;
// Register TOFINO_SEQ_ERROR custom type-classes
instance Bits#(TofinoSeqError, 8);
    function Bit#(8) pack (TofinoSeqError r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.error;
        return bts;
    endfunction: pack
    function TofinoSeqError unpack (Bit#(8) b);
        let r = TofinoSeqError {
        error: b[7:0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoSeqError);
    function TofinoSeqError \& (TofinoSeqError i1, TofinoSeqError i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoSeqError \| (TofinoSeqError i1, TofinoSeqError i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoSeqError \^ (TofinoSeqError i1, TofinoSeqError i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoSeqError \~^ (TofinoSeqError i1, TofinoSeqError i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoSeqError \^~ (TofinoSeqError i1, TofinoSeqError i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoSeqError invert (TofinoSeqError i) =
        unpack(invert(pack(i)));
    function TofinoSeqError \<< (TofinoSeqError i, t x) =
        error("Left shift operation is not supported with type TofinoSeqError");
    function TofinoSeqError \>> (TofinoSeqError i, t x) =
        error("Right shift operation is not supported with type TofinoSeqError");
    function Bit#(1) msb (TofinoSeqError i) =
        error("msb operation is not supported with type TofinoSeqError");
    function Bit#(1) lsb (TofinoSeqError i) =
        error("lsb operation is not supported with type TofinoSeqError");
endinstance

// Register TOFINO_POWER_ENABLE definitions
typedef struct {

        Bit#(1)            vdda_1p8_en;  // bit 5

        Bit#(1)            vdda_1p5_en;  // bit 4

        Bit#(1)            vdd_vddt_en;  // bit 3

        Bit#(1)            vdd_pcie_en;  // bit 2

        Bit#(1)            vdd_core_en;  // bit 1

        Bit#(1)            vdd_1p8_en ;  // bit 0

} TofinoPowerEnable deriving (Eq, FShow);
// Register offsets
Integer tofinoPowerEnableOffset = 9;
// Field mask definitions
    Bit#(8) tofinoPowerEnableVdda1p8En = 'h20;
    Bit#(8) tofinoPowerEnableVdda1p5En = 'h10;
    Bit#(8) tofinoPowerEnableVddVddtEn = 'h08;
    Bit#(8) tofinoPowerEnableVddPcieEn = 'h04;
    Bit#(8) tofinoPowerEnableVddCoreEn = 'h02;
    Bit#(8) tofinoPowerEnableVdd1p8En  = 'h01;
// Register TOFINO_POWER_ENABLE custom type-classes
instance Bits#(TofinoPowerEnable, 8);
    function Bit#(8) pack (TofinoPowerEnable r);
        Bit#(8) bts =  'h00;
        bts[5] = r.vdda_1p8_en;
        bts[4] = r.vdda_1p5_en;
        bts[3] = r.vdd_vddt_en;
        bts[2] = r.vdd_pcie_en;
        bts[1] = r.vdd_core_en;
        bts[0] = r.vdd_1p8_en;
        return bts;
    endfunction: pack
    function TofinoPowerEnable unpack (Bit#(8) b);
        let r = TofinoPowerEnable {
        vdda_1p8_en: b[5] ,
        vdda_1p5_en: b[4] ,
        vdd_vddt_en: b[3] ,
        vdd_pcie_en: b[2] ,
        vdd_core_en: b[1] ,
        vdd_1p8_en: b[0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoPowerEnable);
    function TofinoPowerEnable \& (TofinoPowerEnable i1, TofinoPowerEnable i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoPowerEnable \| (TofinoPowerEnable i1, TofinoPowerEnable i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoPowerEnable \^ (TofinoPowerEnable i1, TofinoPowerEnable i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoPowerEnable \~^ (TofinoPowerEnable i1, TofinoPowerEnable i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoPowerEnable \^~ (TofinoPowerEnable i1, TofinoPowerEnable i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoPowerEnable invert (TofinoPowerEnable i) =
        unpack(invert(pack(i)));
    function TofinoPowerEnable \<< (TofinoPowerEnable i, t x) =
        error("Left shift operation is not supported with type TofinoPowerEnable");
    function TofinoPowerEnable \>> (TofinoPowerEnable i, t x) =
        error("Right shift operation is not supported with type TofinoPowerEnable");
    function Bit#(1) msb (TofinoPowerEnable i) =
        error("msb operation is not supported with type TofinoPowerEnable");
    function Bit#(1) lsb (TofinoPowerEnable i) =
        error("lsb operation is not supported with type TofinoPowerEnable");
endinstance

// Register TOFINO_POWER_GOOD definitions
typedef struct {

        Bit#(1)            vdda_1p8_pg;  // bit 5

        Bit#(1)            vdda_1p5_pg;  // bit 4

        Bit#(1)            vdd_vddt_pg;  // bit 3

        Bit#(1)            vdd_pcie_pg;  // bit 2

        Bit#(1)            vdd_core_pg;  // bit 1

        Bit#(1)            vdd_1p8_pg ;  // bit 0

} TofinoPowerGood deriving (Eq, FShow);
// Register offsets
Integer tofinoPowerGoodOffset = 10;
// Field mask definitions
    Bit#(8) tofinoPowerGoodVdda1p8Pg = 'h20;
    Bit#(8) tofinoPowerGoodVdda1p5Pg = 'h10;
    Bit#(8) tofinoPowerGoodVddVddtPg = 'h08;
    Bit#(8) tofinoPowerGoodVddPciePg = 'h04;
    Bit#(8) tofinoPowerGoodVddCorePg = 'h02;
    Bit#(8) tofinoPowerGoodVdd1p8Pg  = 'h01;
// Register TOFINO_POWER_GOOD custom type-classes
instance Bits#(TofinoPowerGood, 8);
    function Bit#(8) pack (TofinoPowerGood r);
        Bit#(8) bts =  'h00;
        bts[5] = r.vdda_1p8_pg;
        bts[4] = r.vdda_1p5_pg;
        bts[3] = r.vdd_vddt_pg;
        bts[2] = r.vdd_pcie_pg;
        bts[1] = r.vdd_core_pg;
        bts[0] = r.vdd_1p8_pg;
        return bts;
    endfunction: pack
    function TofinoPowerGood unpack (Bit#(8) b);
        let r = TofinoPowerGood {
        vdda_1p8_pg: b[5] ,
        vdda_1p5_pg: b[4] ,
        vdd_vddt_pg: b[3] ,
        vdd_pcie_pg: b[2] ,
        vdd_core_pg: b[1] ,
        vdd_1p8_pg: b[0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoPowerGood);
    function TofinoPowerGood \& (TofinoPowerGood i1, TofinoPowerGood i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoPowerGood \| (TofinoPowerGood i1, TofinoPowerGood i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoPowerGood \^ (TofinoPowerGood i1, TofinoPowerGood i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoPowerGood \~^ (TofinoPowerGood i1, TofinoPowerGood i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoPowerGood \^~ (TofinoPowerGood i1, TofinoPowerGood i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoPowerGood invert (TofinoPowerGood i) =
        unpack(invert(pack(i)));
    function TofinoPowerGood \<< (TofinoPowerGood i, t x) =
        error("Left shift operation is not supported with type TofinoPowerGood");
    function TofinoPowerGood \>> (TofinoPowerGood i, t x) =
        error("Right shift operation is not supported with type TofinoPowerGood");
    function Bit#(1) msb (TofinoPowerGood i) =
        error("msb operation is not supported with type TofinoPowerGood");
    function Bit#(1) lsb (TofinoPowerGood i) =
        error("lsb operation is not supported with type TofinoPowerGood");
endinstance

// Register TOFINO_POWER_FAULT definitions
typedef struct {

        Bit#(1)            reserved2     ;  // bit 5

        Bit#(1)            vdda_1p5_fault;  // bit 4

        Bit#(1)            vdd_vddt_fault;  // bit 3

        Bit#(1)            reserved1     ;  // bit 2

        Bit#(1)            vdd_core_fault;  // bit 1

        Bit#(1)            vdd_1p8_fault ;  // bit 0

} TofinoPowerFault deriving (Eq, FShow);
// Register offsets
Integer tofinoPowerFaultOffset = 11;
// Field mask definitions
    Bit#(8) tofinoPowerFaultReserved2      = 'h20;
    Bit#(8) tofinoPowerFaultVdda1p5Fault = 'h10;
    Bit#(8) tofinoPowerFaultVddVddtFault = 'h08;
    Bit#(8) tofinoPowerFaultReserved1      = 'h04;
    Bit#(8) tofinoPowerFaultVddCoreFault = 'h02;
    Bit#(8) tofinoPowerFaultVdd1p8Fault  = 'h01;
// Register TOFINO_POWER_FAULT custom type-classes
instance Bits#(TofinoPowerFault, 8);
    function Bit#(8) pack (TofinoPowerFault r);
        Bit#(8) bts =  'h00;
        bts[5] = r.reserved2;
        bts[4] = r.vdda_1p5_fault;
        bts[3] = r.vdd_vddt_fault;
        bts[2] = r.reserved1;
        bts[1] = r.vdd_core_fault;
        bts[0] = r.vdd_1p8_fault;
        return bts;
    endfunction: pack
    function TofinoPowerFault unpack (Bit#(8) b);
        let r = TofinoPowerFault {
        reserved2: b[5] ,
        vdda_1p5_fault: b[4] ,
        vdd_vddt_fault: b[3] ,
        reserved1: b[2] ,
        vdd_core_fault: b[1] ,
        vdd_1p8_fault: b[0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoPowerFault);
    function TofinoPowerFault \& (TofinoPowerFault i1, TofinoPowerFault i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoPowerFault \| (TofinoPowerFault i1, TofinoPowerFault i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoPowerFault \^ (TofinoPowerFault i1, TofinoPowerFault i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoPowerFault \~^ (TofinoPowerFault i1, TofinoPowerFault i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoPowerFault \^~ (TofinoPowerFault i1, TofinoPowerFault i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoPowerFault invert (TofinoPowerFault i) =
        unpack(invert(pack(i)));
    function TofinoPowerFault \<< (TofinoPowerFault i, t x) =
        error("Left shift operation is not supported with type TofinoPowerFault");
    function TofinoPowerFault \>> (TofinoPowerFault i, t x) =
        error("Right shift operation is not supported with type TofinoPowerFault");
    function Bit#(1) msb (TofinoPowerFault i) =
        error("msb operation is not supported with type TofinoPowerFault");
    function Bit#(1) lsb (TofinoPowerFault i) =
        error("lsb operation is not supported with type TofinoPowerFault");
endinstance

// Register TOFINO_POWER_VRHOT definitions
typedef struct {

        Bit#(1)            vdda_1p8_vrhot;  // bit 5

        Bit#(1)            vdda_1p5_vrhot;  // bit 4

        Bit#(1)            vdd_vddt_vrhot;  // bit 3

        Bit#(1)            reserved1     ;  // bit 2

        Bit#(1)            vdd_core_vrhot;  // bit 1

        Bit#(1)            vdd_1p8_vrhot ;  // bit 0

} TofinoPowerVrhot deriving (Eq, FShow);
// Register offsets
Integer tofinoPowerVrhotOffset = 12;
// Field mask definitions
    Bit#(8) tofinoPowerVrhotVdda1p8Vrhot = 'h20;
    Bit#(8) tofinoPowerVrhotVdda1p5Vrhot = 'h10;
    Bit#(8) tofinoPowerVrhotVddVddtVrhot = 'h08;
    Bit#(8) tofinoPowerVrhotReserved1      = 'h04;
    Bit#(8) tofinoPowerVrhotVddCoreVrhot = 'h02;
    Bit#(8) tofinoPowerVrhotVdd1p8Vrhot  = 'h01;
// Register TOFINO_POWER_VRHOT custom type-classes
instance Bits#(TofinoPowerVrhot, 8);
    function Bit#(8) pack (TofinoPowerVrhot r);
        Bit#(8) bts =  'h00;
        bts[5] = r.vdda_1p8_vrhot;
        bts[4] = r.vdda_1p5_vrhot;
        bts[3] = r.vdd_vddt_vrhot;
        bts[2] = r.reserved1;
        bts[1] = r.vdd_core_vrhot;
        bts[0] = r.vdd_1p8_vrhot;
        return bts;
    endfunction: pack
    function TofinoPowerVrhot unpack (Bit#(8) b);
        let r = TofinoPowerVrhot {
        vdda_1p8_vrhot: b[5] ,
        vdda_1p5_vrhot: b[4] ,
        vdd_vddt_vrhot: b[3] ,
        reserved1: b[2] ,
        vdd_core_vrhot: b[1] ,
        vdd_1p8_vrhot: b[0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoPowerVrhot);
    function TofinoPowerVrhot \& (TofinoPowerVrhot i1, TofinoPowerVrhot i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoPowerVrhot \| (TofinoPowerVrhot i1, TofinoPowerVrhot i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoPowerVrhot \^ (TofinoPowerVrhot i1, TofinoPowerVrhot i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoPowerVrhot \~^ (TofinoPowerVrhot i1, TofinoPowerVrhot i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoPowerVrhot \^~ (TofinoPowerVrhot i1, TofinoPowerVrhot i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoPowerVrhot invert (TofinoPowerVrhot i) =
        unpack(invert(pack(i)));
    function TofinoPowerVrhot \<< (TofinoPowerVrhot i, t x) =
        error("Left shift operation is not supported with type TofinoPowerVrhot");
    function TofinoPowerVrhot \>> (TofinoPowerVrhot i, t x) =
        error("Right shift operation is not supported with type TofinoPowerVrhot");
    function Bit#(1) msb (TofinoPowerVrhot i) =
        error("msb operation is not supported with type TofinoPowerVrhot");
    function Bit#(1) lsb (TofinoPowerVrhot i) =
        error("lsb operation is not supported with type TofinoPowerVrhot");
endinstance

// Register TOFINO_POWER_VID definitions
typedef struct {
        Bit#(1)            vid_valid;  // bit 7

        Bit#(3)            reserved ;  // bit 6:4

        Bit#(4)            vid      ;  // bit 3:0

} TofinoPowerVid deriving (Eq, FShow);
// Register offsets
Integer tofinoPowerVidOffset = 13;
// Field mask definitions
    Bit#(8) tofinoPowerVidVidValid = 'h80;
    Bit#(8) tofinoPowerVidReserved  = 'h70;
    Bit#(8) tofinoPowerVidVid       = 'h0f;
// Register TOFINO_POWER_VID custom type-classes
instance Bits#(TofinoPowerVid, 8);
    function Bit#(8) pack (TofinoPowerVid r);
        Bit#(8) bts =  'h00;
        bts[7] = r.vid_valid;
        bts[6:4] = r.reserved;
        bts[3:0] = r.vid;
        return bts;
    endfunction: pack
    function TofinoPowerVid unpack (Bit#(8) b);
        let r = TofinoPowerVid {
        vid_valid: b[7] ,
        reserved: b[6:4] ,
        vid: b[3:0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoPowerVid);
    function TofinoPowerVid \& (TofinoPowerVid i1, TofinoPowerVid i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoPowerVid \| (TofinoPowerVid i1, TofinoPowerVid i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoPowerVid \^ (TofinoPowerVid i1, TofinoPowerVid i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoPowerVid \~^ (TofinoPowerVid i1, TofinoPowerVid i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoPowerVid \^~ (TofinoPowerVid i1, TofinoPowerVid i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoPowerVid invert (TofinoPowerVid i) =
        unpack(invert(pack(i)));
    function TofinoPowerVid \<< (TofinoPowerVid i, t x) =
        error("Left shift operation is not supported with type TofinoPowerVid");
    function TofinoPowerVid \>> (TofinoPowerVid i, t x) =
        error("Right shift operation is not supported with type TofinoPowerVid");
    function Bit#(1) msb (TofinoPowerVid i) =
        error("msb operation is not supported with type TofinoPowerVid");
    function Bit#(1) lsb (TofinoPowerVid i) =
        error("lsb operation is not supported with type TofinoPowerVid");
endinstance

// Register TOFINO_RESET definitions
typedef struct {

        Bit#(1)            pcie  ;  // bit 1

        Bit#(1)            pwron ;  // bit 0

} TofinoReset deriving (Eq, FShow);
// Register offsets
Integer tofinoResetOffset = 14;
// Field mask definitions
    Bit#(8) tofinoResetPcie   = 'h02;
    Bit#(8) tofinoResetPwron  = 'h01;
// Register TOFINO_RESET custom type-classes
instance Bits#(TofinoReset, 8);
    function Bit#(8) pack (TofinoReset r);
        Bit#(8) bts =  'h00;
        bts[1] = r.pcie;
        bts[0] = r.pwron;
        return bts;
    endfunction: pack
    function TofinoReset unpack (Bit#(8) b);
        let r = TofinoReset {
        pcie: b[1] ,
        pwron: b[0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoReset);
    function TofinoReset \& (TofinoReset i1, TofinoReset i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoReset \| (TofinoReset i1, TofinoReset i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoReset \^ (TofinoReset i1, TofinoReset i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoReset \~^ (TofinoReset i1, TofinoReset i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoReset \^~ (TofinoReset i1, TofinoReset i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoReset invert (TofinoReset i) =
        unpack(invert(pack(i)));
    function TofinoReset \<< (TofinoReset i, t x) =
        error("Left shift operation is not supported with type TofinoReset");
    function TofinoReset \>> (TofinoReset i, t x) =
        error("Right shift operation is not supported with type TofinoReset");
    function Bit#(1) msb (TofinoReset i) =
        error("msb operation is not supported with type TofinoReset");
    function Bit#(1) lsb (TofinoReset i) =
        error("lsb operation is not supported with type TofinoReset");
endinstance

// Register TOFINO_MISC definitions
typedef struct {

        Bit#(1)            clocks_en    ;  // bit 1

        Bit#(1)            thermal_alert;  // bit 0

} TofinoMisc deriving (Eq, FShow);
// Register offsets
Integer tofinoMiscOffset = 15;
// Field mask definitions
    Bit#(8) tofinoMiscClocksEn     = 'h02;
    Bit#(8) tofinoMiscThermalAlert = 'h01;
// Register TOFINO_MISC custom type-classes
instance Bits#(TofinoMisc, 8);
    function Bit#(8) pack (TofinoMisc r);
        Bit#(8) bts =  'h00;
        bts[1] = r.clocks_en;
        bts[0] = r.thermal_alert;
        return bts;
    endfunction: pack
    function TofinoMisc unpack (Bit#(8) b);
        let r = TofinoMisc {
        clocks_en: b[1] ,
        thermal_alert: b[0]
        };

        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoMisc);
    function TofinoMisc \& (TofinoMisc i1, TofinoMisc i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoMisc \| (TofinoMisc i1, TofinoMisc i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoMisc \^ (TofinoMisc i1, TofinoMisc i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoMisc \~^ (TofinoMisc i1, TofinoMisc i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoMisc \^~ (TofinoMisc i1, TofinoMisc i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoMisc invert (TofinoMisc i) =
        unpack(invert(pack(i)));
    function TofinoMisc \<< (TofinoMisc i, t x) =
        error("Left shift operation is not supported with type TofinoMisc");
    function TofinoMisc \>> (TofinoMisc i, t x) =
        error("Right shift operation is not supported with type TofinoMisc");
    function Bit#(1) msb (TofinoMisc i) =
        error("msb operation is not supported with type TofinoMisc");
    function Bit#(1) lsb (TofinoMisc i) =
        error("lsb operation is not supported with type TofinoMisc");
endinstance

endpackage: SidecarMainboardControllerReg