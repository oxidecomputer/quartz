// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package SidecarMainboardControllerBench;

import ClientServer::*;

import RegCommon::*;


typedef RegRequest#(16, 8) SpiRequest;
typedef RegResp#(8) SpiResponse;
typedef Client#(SpiRequest, SpiResponse) SpiServer;

interface SidecarMainboardControllerBench;

endinterface

endpackage