# See network protocol here: 
# https://github.com/oxidecomputer/hubris/blob/master/drv/stm32h7-fmc-demo-server/README.md
port = 11114

# command
# version: 1 byte, always 0 today
# command: 1 byte, always 0 today
# Identifier byte:
# address (0), followed by 4 bytes of address, little endian encoded
# peek(1/2/3/4), reads 8, 16, 32, or 64 bits from the address specified
# peek_advance(5/6/7/8), reads 8, 16, 24, or 32 bits from the address specified but also increments addr for next read
# poke(9/10/11/12), writes 8, 16, 32, or 64 bits to the address specified
# poke_advance(13/14/15/16), writes 8, 16, 32, or 64 bits to the address specified but also increments addr for next write

# response:
# success: 1 byte, 0 for success, 1 for failure
# data: All return values from the peek commands are little endian encoded in order

# Simple example: read 32bits (target shows 0xdeadbeef) from 0x60000000
# Command:
# Ver  CMD  ID   Addr-------------------- ID  
# 0x00 0x00 0x00 0x60 0x00 0x00 0x00 0x00 0x03  
# Response:
# Success  
#     0x00 0xde 0xad 0xbe 0xef

class Read32Packet:
    def __init__(self, addr):
        self.addr = addr

    def __bytes__(self):
        return struct.pack('>BBH', 0, 0, self.addr)

    def __str__(self):
        return f'Read32({self.addr})'
    
    @classmethod
    def from_bytes(cls, packet_bytes):
        assert len(data) == 4
        addr, value = struct.unpack('>HH', data)
        return cls(addr, value)

class Write32Packet: