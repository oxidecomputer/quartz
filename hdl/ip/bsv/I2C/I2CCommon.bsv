// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2CCommon;

import DefaultValue::*;
import Vector::*;

import Bidirection::*;

interface Pins;
    interface Bidirection#(Bit#(1)) scl;
    interface Bidirection#(Bit#(1)) sda;
endinterface

// Using a Vector of Maybe#(Bit#(1)) is a convenient way to not have to track
// where we are in the shift in/out of a byte, but is a little expensive...
typedef Vector#(8, Maybe#(Bit#(1))) ShiftBits;
ShiftBits shift_bits_reset = replicate(tagged Invalid);
// Creating a variant fromMaybe to for use with map() on the ShiftBits type
function Bit#(1) bit_from_maybe(Maybe#(Bit#(1)) b) = fromMaybe(0, b);

// Common code for tests
typedef struct {
    Integer core_clk_freq_hz;
    Integer scl_freq_hz;
    Integer core_clk_period_ns;
    Integer max_scl_stretch_us;
    Bit#(7) peripheral_addr;
} I2CTestParams;

instance DefaultValue #(I2CTestParams);
    defaultValue = I2CTestParams {
        core_clk_freq_hz: 50_000_000,
        scl_freq_hz: 100_000,
        core_clk_period_ns: 20,
        max_scl_stretch_us: 5,
        peripheral_addr: 7'b1010110
    };
endinstance

endpackage: I2CCommon
