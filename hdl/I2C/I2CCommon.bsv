// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2CCommon;

import BuildVector::*;
import DefaultValue::*;
import Vector::*;

import CommonInterfaces::*;

interface Pins;
    interface Tristate scl;
    interface Tristate sda;
endinterface

// Using a Vector of Maybe#(Bit#(1)) is a convenient way to not have to track
// where we are in the shift in/out of a byte, but is a little expensive...
typedef Vector#(8, Maybe#(Bit#(1))) ShiftBits;
ShiftBits shift_bits_reset = vec(tagged Invalid, tagged Invalid, tagged Invalid, tagged Invalid,
                            tagged Invalid, tagged Invalid, tagged Invalid, tagged Invalid);
// Creating a variant fromMaybe to for use with map() on the ShiftBits type
function Bit#(1) bit_from_maybe(Maybe#(Bit#(1)) b) = fromMaybe(0, b);

// Common code for tests
typedef struct {
    Integer core_clk_freq;
    Integer scl_freq;
    Bit#(7) peripheral_addr;
} I2CTestParams;

instance DefaultValue #(I2CTestParams);
    defaultValue = I2CTestParams {
        core_clk_freq: 4000,
        scl_freq: 100,
        peripheral_addr: 7'b1010110
    };
endinstance

endpackage: I2CCommon