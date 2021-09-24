// This module will take spi bytes via a server interface
// And pass out requests via a client interface.

package RegCommon;

import GetPut::*;
import ClientServer::*;
import Connectable::*;


typedef enum {WRITE, READ, BITSET, BITCLEAR} RegOps deriving (Eq, Bits);

typedef struct {
   Bit#(addrWidth) address;
   Bit#(dataWidth) wdata;
   RegOps   op;
} RegRequest#(numeric type addrWidth, numeric type dataWidth) deriving (Bits);

typedef struct {
   Bit#(dataWidth) readdata;
} RegResp#(numeric type dataWidth) deriving (Bits);

endpackage