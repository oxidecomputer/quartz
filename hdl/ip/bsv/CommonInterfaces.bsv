// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package CommonInterfaces;

// A Reg interface which has an Action when the _read method fires
interface ReadVolatileReg #(type t);
    method ActionValue#(t) _read();
    method Action _write(t val);
endinterface

endpackage: CommonInterfaces
