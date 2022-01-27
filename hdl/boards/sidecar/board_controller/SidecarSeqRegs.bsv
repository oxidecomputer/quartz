
// This is a generated file using the RDL tooling. Do not edit by hand.
package SidecarSeqRegs;

import Reserved::*;
import RegCommon::*;

// Register ID0 definitions
typedef struct {
        Bit#(8)            tbd   ;  // bit 7:0
    
} Id0 deriving (Eq, FShow);
// Register offsets
Integer id0Offset = 0;
// Field mask definitions
    Bit#(8) id0Tbd    = 'hff;
// Register ID0 custom type-classes
instance Bits#(Id0, 8);
    function Bit#(8) pack (Id0 r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.tbd;
        return bts;
    endfunction: pack
    function Id0 unpack (Bit#(8) b);
        let r = Id0 {
        tbd: b[7:0] 
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
        Bit#(8)            tbd   ;  // bit 7:0
    
} Id1 deriving (Eq, FShow);
// Register offsets
Integer id1Offset = 1;
// Field mask definitions
    Bit#(8) id1Tbd    = 'hff;
// Register ID1 custom type-classes
instance Bits#(Id1, 8);
    function Bit#(8) pack (Id1 r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.tbd;
        return bts;
    endfunction: pack
    function Id1 unpack (Bit#(8) b);
        let r = Id1 {
        tbd: b[7:0] 
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
        Bit#(8)            tbd   ;  // bit 7:0
    
} Id2 deriving (Eq, FShow);
// Register offsets
Integer id2Offset = 2;
// Field mask definitions
    Bit#(8) id2Tbd    = 'hff;
// Register ID2 custom type-classes
instance Bits#(Id2, 8);
    function Bit#(8) pack (Id2 r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.tbd;
        return bts;
    endfunction: pack
    function Id2 unpack (Bit#(8) b);
        let r = Id2 {
        tbd: b[7:0] 
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
        Bit#(8)            tbd   ;  // bit 7:0
    
} Id3 deriving (Eq, FShow);
// Register offsets
Integer id3Offset = 3;
// Field mask definitions
    Bit#(8) id3Tbd    = 'hff;
// Register ID3 custom type-classes
instance Bits#(Id3, 8);
    function Bit#(8) pack (Id3 r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.tbd;
        return bts;
    endfunction: pack
    function Id3 unpack (Bit#(8) b);
        let r = Id3 {
        tbd: b[7:0] 
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
        Bit#(8)            tbd   ;  // bit 7:0
    
} Scratchpad deriving (Eq, FShow);
// Register offsets
Integer scratchpadOffset = 4;
// Field mask definitions
    Bit#(8) scratchpadTbd    = 'hff;
// Register SCRATCHPAD custom type-classes
instance Bits#(Scratchpad, 8);
    function Bit#(8) pack (Scratchpad r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.tbd;
        return bts;
    endfunction: pack
    function Scratchpad unpack (Bit#(8) b);
        let r = Scratchpad {
        tbd: b[7:0] 
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

// Register TOFINO_EN definitions
typedef struct {
    
        Bit#(1)            en    ;  // bit 0
    
} TofinoEn deriving (Eq, FShow);
// Register offsets
Integer tofinoEnOffset = 5;
// Field mask definitions
    Bit#(8) tofinoEnEn     = 'h01;
// Register TOFINO_EN custom type-classes
instance Bits#(TofinoEn, 8);
    function Bit#(8) pack (TofinoEn r);
        Bit#(8) bts =  'h00;
        bts[0] = r.en;
        return bts;
    endfunction: pack
    function TofinoEn unpack (Bit#(8) b);
        let r = TofinoEn {
        en: b[0] 
        };
        
        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoEn);
    function TofinoEn \& (TofinoEn i1, TofinoEn i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoEn \| (TofinoEn i1, TofinoEn i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoEn \^ (TofinoEn i1, TofinoEn i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoEn \~^ (TofinoEn i1, TofinoEn i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoEn \^~ (TofinoEn i1, TofinoEn i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoEn invert (TofinoEn i) =
        unpack(invert(pack(i)));
    function TofinoEn \<< (TofinoEn i, t x) =
        error("Left shift operation is not supported with type TofinoEn");
    function TofinoEn \>> (TofinoEn i, t x) =
        error("Right shift operation is not supported with type TofinoEn");
    function Bit#(1) msb (TofinoEn i) =
        error("msb operation is not supported with type TofinoEn");
    function Bit#(1) lsb (TofinoEn i) =
        error("lsb operation is not supported with type TofinoEn");
endinstance

// Register TOFINO_SEQ_STATE definitions
typedef struct {
        Bit#(8)            state ;  // bit 7:0
    
} TofinoSeqState deriving (Eq, FShow);
// Register offsets
Integer tofinoSeqStateOffset = 6;
// Field mask definitions
    Bit#(8) tofinoSeqStateState  = 'hff;
// Register TOFINO_SEQ_STATE custom type-classes
instance Bits#(TofinoSeqState, 8);
    function Bit#(8) pack (TofinoSeqState r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.state;
        return bts;
    endfunction: pack
    function TofinoSeqState unpack (Bit#(8) b);
        let r = TofinoSeqState {
        state: b[7:0] 
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

// Register TOFINO_SEQ_ERROR definitions
typedef struct {
        Bit#(8)            error ;  // bit 7:0
    
} TofinoSeqError deriving (Eq, FShow);
// Register offsets
Integer tofinoSeqErrorOffset = 7;
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

// Register TOFINO_POWER_ENABLES definitions
typedef struct {
    
        Bit#(1)            vdda_1p8_en;  // bit 5
    
        Bit#(1)            vdda_1p5_en;  // bit 4
    
        Bit#(1)            vdd_vddt_en;  // bit 3
    
        Bit#(1)            vdd_pcie_en;  // bit 2
    
        Bit#(1)            vdd_core_en;  // bit 1
    
        Bit#(1)            vdd_1p8_en ;  // bit 0
    
} TofinoPowerEnables deriving (Eq, FShow);
// Register offsets
Integer tofinoPowerEnablesOffset = 8;
// Field mask definitions
    Bit#(8) tofinoPowerEnablesVdda1p8En = 'h20;
    Bit#(8) tofinoPowerEnablesVdda1p5En = 'h10;
    Bit#(8) tofinoPowerEnablesVddVddtEn = 'h08;
    Bit#(8) tofinoPowerEnablesVddPcieEn = 'h04;
    Bit#(8) tofinoPowerEnablesVddCoreEn = 'h02;
    Bit#(8) tofinoPowerEnablesVdd1p8En  = 'h01;
// Register TOFINO_POWER_ENABLES custom type-classes
instance Bits#(TofinoPowerEnables, 8);
    function Bit#(8) pack (TofinoPowerEnables r);
        Bit#(8) bts =  'h00;
        bts[5] = r.vdda_1p8_en;
        bts[4] = r.vdda_1p5_en;
        bts[3] = r.vdd_vddt_en;
        bts[2] = r.vdd_pcie_en;
        bts[1] = r.vdd_core_en;
        bts[0] = r.vdd_1p8_en;
        return bts;
    endfunction: pack
    function TofinoPowerEnables unpack (Bit#(8) b);
        let r = TofinoPowerEnables {
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

instance Bitwise#(TofinoPowerEnables);
    function TofinoPowerEnables \& (TofinoPowerEnables i1, TofinoPowerEnables i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoPowerEnables \| (TofinoPowerEnables i1, TofinoPowerEnables i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoPowerEnables \^ (TofinoPowerEnables i1, TofinoPowerEnables i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoPowerEnables \~^ (TofinoPowerEnables i1, TofinoPowerEnables i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoPowerEnables \^~ (TofinoPowerEnables i1, TofinoPowerEnables i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoPowerEnables invert (TofinoPowerEnables i) =
        unpack(invert(pack(i)));
    function TofinoPowerEnables \<< (TofinoPowerEnables i, t x) =
        error("Left shift operation is not supported with type TofinoPowerEnables");
    function TofinoPowerEnables \>> (TofinoPowerEnables i, t x) =
        error("Right shift operation is not supported with type TofinoPowerEnables");
    function Bit#(1) msb (TofinoPowerEnables i) =
        error("msb operation is not supported with type TofinoPowerEnables");
    function Bit#(1) lsb (TofinoPowerEnables i) =
        error("lsb operation is not supported with type TofinoPowerEnables");
endinstance

// Register TOFINO_POWER_GOODS definitions
typedef struct {
    
        Bit#(1)            vdda_1p8_pg;  // bit 5
    
        Bit#(1)            vdda_1p5_pg;  // bit 4
    
        Bit#(1)            vdd_vddt_pg;  // bit 3
    
        Bit#(1)            vdd_pcie_pg;  // bit 2
    
        Bit#(1)            vdd_core_pg;  // bit 1
    
        Bit#(1)            vdd_1p8_pg ;  // bit 0
    
} TofinoPowerGoods deriving (Eq, FShow);
// Register offsets
Integer tofinoPowerGoodsOffset = 9;
// Field mask definitions
    Bit#(8) tofinoPowerGoodsVdda1p8Pg = 'h20;
    Bit#(8) tofinoPowerGoodsVdda1p5Pg = 'h10;
    Bit#(8) tofinoPowerGoodsVddVddtPg = 'h08;
    Bit#(8) tofinoPowerGoodsVddPciePg = 'h04;
    Bit#(8) tofinoPowerGoodsVddCorePg = 'h02;
    Bit#(8) tofinoPowerGoodsVdd1p8Pg  = 'h01;
// Register TOFINO_POWER_GOODS custom type-classes
instance Bits#(TofinoPowerGoods, 8);
    function Bit#(8) pack (TofinoPowerGoods r);
        Bit#(8) bts =  'h00;
        bts[5] = r.vdda_1p8_pg;
        bts[4] = r.vdda_1p5_pg;
        bts[3] = r.vdd_vddt_pg;
        bts[2] = r.vdd_pcie_pg;
        bts[1] = r.vdd_core_pg;
        bts[0] = r.vdd_1p8_pg;
        return bts;
    endfunction: pack
    function TofinoPowerGoods unpack (Bit#(8) b);
        let r = TofinoPowerGoods {
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

instance Bitwise#(TofinoPowerGoods);
    function TofinoPowerGoods \& (TofinoPowerGoods i1, TofinoPowerGoods i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoPowerGoods \| (TofinoPowerGoods i1, TofinoPowerGoods i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoPowerGoods \^ (TofinoPowerGoods i1, TofinoPowerGoods i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoPowerGoods \~^ (TofinoPowerGoods i1, TofinoPowerGoods i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoPowerGoods \^~ (TofinoPowerGoods i1, TofinoPowerGoods i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoPowerGoods invert (TofinoPowerGoods i) =
        unpack(invert(pack(i)));
    function TofinoPowerGoods \<< (TofinoPowerGoods i, t x) =
        error("Left shift operation is not supported with type TofinoPowerGoods");
    function TofinoPowerGoods \>> (TofinoPowerGoods i, t x) =
        error("Right shift operation is not supported with type TofinoPowerGoods");
    function Bit#(1) msb (TofinoPowerGoods i) =
        error("msb operation is not supported with type TofinoPowerGoods");
    function Bit#(1) lsb (TofinoPowerGoods i) =
        error("lsb operation is not supported with type TofinoPowerGoods");
endinstance

// Register TOFINO_VID definitions
typedef struct {
    
        Bit#(4)            vid   ;  // bit 3:0
    
} TofinoVid deriving (Eq, FShow);
// Register offsets
Integer tofinoVidOffset = 10;
// Field mask definitions
    Bit#(8) tofinoVidVid    = 'h0f;
// Register TOFINO_VID custom type-classes
instance Bits#(TofinoVid, 8);
    function Bit#(8) pack (TofinoVid r);
        Bit#(8) bts =  'h00;
        bts[3:0] = r.vid;
        return bts;
    endfunction: pack
    function TofinoVid unpack (Bit#(8) b);
        let r = TofinoVid {
        vid: b[3:0] 
        };
        
        return r;
    endfunction: unpack

endinstance

instance Bitwise#(TofinoVid);
    function TofinoVid \& (TofinoVid i1, TofinoVid i2) =
        unpack(pack(i1) & pack(i2));
    function TofinoVid \| (TofinoVid i1, TofinoVid i2) =
        unpack(pack(i1) | pack(i2));
    function TofinoVid \^ (TofinoVid i1, TofinoVid i2) =
        unpack(pack(i1) ^ pack(i2));
    function TofinoVid \~^ (TofinoVid i1, TofinoVid i2) =
        unpack(pack(i1) ~^ pack(i2));
    function TofinoVid \^~ (TofinoVid i1, TofinoVid i2) =
        unpack(pack(i1) ^~ pack(i2));
    function TofinoVid invert (TofinoVid i) =
        unpack(invert(pack(i)));
    function TofinoVid \<< (TofinoVid i, t x) =
        error("Left shift operation is not supported with type TofinoVid");
    function TofinoVid \>> (TofinoVid i, t x) =
        error("Right shift operation is not supported with type TofinoVid");
    function Bit#(1) msb (TofinoVid i) =
        error("msb operation is not supported with type TofinoVid");
    function Bit#(1) lsb (TofinoVid i) =
        error("lsb operation is not supported with type TofinoVid");
endinstance

endpackage: SidecarSeqRegs