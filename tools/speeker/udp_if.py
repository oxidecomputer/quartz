# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#

# This implements a simple UDP peek/poke interface that conforms to the
# protocol specified here: 
# https://github.com/oxidecomputer/hubris/blob/master/drv/stm32h7-fmc-demo-server/README.md


import socket

from typing import List


class Request:
    """Basic class that allows incrementally building a request and also builds
    the processor for the expected response since the expected response
    is dependent on the request.
    """
    version = 0
    command = 0
    addr_arg = 0
    peek1_arg = 1  # read 1 byte from addr
    peek2_arg = 2  # read 2 byte from addr
    peek4_arg = 3  # read 4 byte from addr
    peek8_arg = 4  # read 8 byte from addr
    peek_adv1_arg = 5  # read 1 byte from addr, increment internal addr by 1
    peek_adv2_arg = 6  # read 2 byt from addr, increment internal addr by 2
    peek_adv4_arg = 7  # read 4 byte from addr, increment internal addr by 3
    peek_adv8_arg = 8  # read 8 byte from addr, increment internal addr by 4
    poke1_arg = 9  # write 1 byte to addr
    poke2_arg = 10  # write 2 byte to addr
    poke4_arg = 11  # write 4 byte to addr
    poke8_arg = 12  # write 8 byte to addr
    poke_adv1_arg = 13  # write 1 byte to addr, increment internal addr by 1
    poke_adv2_arg = 14  # write 2 byte to addr, increment internal addr by 2
    poke_adv4_arg = 15  # write 4 byte to addr, increment internal addr by 3
    poke_adv8_arg = 16  # write 8 byte to addr, increment internal addr by 4
    # server-side block ops: N bus accesses per op with a constant-size
    # response, so request duration is dominated by the FMC accesses
    peek_block_checksum_arg = 17        # u16 count; advancing; returns u32 sum
    peek_block_checksum_fixed_arg = 18  # u16 count; same address; returns u32 sum
    poke_block_fill_arg = 19            # u16 count + u32 value; same address
    
    def __init__(self):
        # Build a bytearray to represent the packet we're going to send
        self.bytes = bytearray()
        # Always fill out the first two bytes with the defined version and command
        # per the protocol
        self.bytes += self.version.to_bytes(1, byteorder='little')
        self.bytes += self.command.to_bytes(1, byteorder='little')
        self.cur_addr = 0
        self.response = Response()

    def validate(self):
        # Let's not split packets > MTU
        if len(self.bytes) > 1500:
            raise Exception("Request too large")
    
    def __bytes__(self) -> bytes:
        self.validate()
        return bytes(self.bytes)
    
    def hex(self) -> str:
        """Return the hex string rep of our request packet"""
        return self.bytes.hex()
    
    def set_address(self, address) -> None:
        self.cur_addr = address
        self.bytes += self.addr_arg.to_bytes(1, byteorder='little')
        self.bytes += address.to_bytes(4, byteorder='little')
    
    def add_read32s(self, count) -> None:
        for i in range(count):
            self.bytes += self.peek4_arg.to_bytes(1, byteorder='little')
            self.response.add_expected_peek(ResponsePeek(self.cur_addr, 4))
    
    def add_read32_advances(self, count) -> None:
        for i in range(count):
            self.bytes += self.peek_adv4_arg.to_bytes(1, byteorder='little')
            self.response.add_expected_peek(ResponsePeek(self.cur_addr, 4))
            self.cur_addr += 4

    def add_write32s(self, values: list) -> None:
        # Want to accept lists of ints or something byte-like
        # Turn them into a bytearray, make sure they're 4 byte aligned
        # and build the transaction
        if isinstance(values, bytearray) or isinstance(values, bytes):
            ar = bytearray(values)
            assert len(ar) % 4 == 0
            for i in range(0, len(ar), 4):
                # Put the command and each chunk of 4 bytes into the request
                self.bytes += self.poke4_arg.to_bytes(1, byteorder='little')
                self.bytes += ar[i:i+4]
        else:
            for value in values:
                self.bytes += self.poke4_arg.to_bytes(1, byteorder='little')
                if isinstance(value, int):
                    if value >= 0:
                        self.bytes += value.to_bytes(4, byteorder='little')
                    else:
                        self.bytes += value.to_bytes(4, byteorder='little', signed=True)
                else:
                    raise Exception(f"Invalid type {type(value)} for value")

    def add_peek_block_checksum(self, count, advance=True) -> None:
        """Server-side read of `count` 32-bit words returning one u32
        wrapping-sum checksum; `advance` selects walking memory vs
        re-reading one address."""
        op = self.peek_block_checksum_arg if advance else self.peek_block_checksum_fixed_arg
        self.bytes += op.to_bytes(1, byteorder='little')
        self.bytes += count.to_bytes(2, byteorder='little')
        self.response.add_expected_peek(ResponsePeek(self.cur_addr, 4))
        if advance:
            self.cur_addr += 4 * count

    def add_poke_block_fill(self, count, value) -> None:
        """Server-side write of `value` to the current address `count`
        times (non-advancing)."""
        self.bytes += self.poke_block_fill_arg.to_bytes(1, byteorder='little')
        self.bytes += count.to_bytes(2, byteorder='little')
        self.bytes += value.to_bytes(4, byteorder='little')

    def add_write32_advances(self, values: list) -> None:
        for value in values:
            self.bytes += self.poke_adv4_arg.to_bytes(1, byteorder='little')
            self.bytes += value.to_bytes(4, byteorder='little')


class ResponsePeek:
    def __init__(self, addr, expected_bytes):
        self.addr = addr
        self.expected_bytes = expected_bytes
        self.bytes = bytearray()

    @property
    def payload(self):
        return int.from_bytes(self.bytes, byteorder='little')

    @property
    def payload_tuple(self):
        return self.addr, int.from_bytes(self.bytes, byteorder='little')


class Response:
    def __init__(self):
        self.expected_responses = []

    def __bytes__(self) -> bytes:
        ar = bytearray()
        for response in self.expected_responses:
            ar += response.bytes
        return bytes(ar)
    
    def hex(self) -> str:
        """Return the hex string rep of our request packet"""
        return bytes(self).hex()
    
    def add_expected_peek(self, response: ResponsePeek):
        self.expected_responses.append(response)

    def expected_bytes(self):
        return sum([response.expected_bytes for response in self.expected_responses]) + 1 # +1 for the command byte
    
    def process_bytes(self, bytes):
        if bytes[0] != 0:
            raise Exception("Got a non-zero response from target")
        # Strip off the command byte
        bytes = bytes[1:]
        for response in self.expected_responses:
            response.bytes = bytes[:response.expected_bytes]
            bytes = bytes[response.expected_bytes:]


class UDPMem:
    """ Main connection class that the system will typically 
    interact with for doing peeks/pokes

    Note that the SP is IPv6 only and runs on a link-local address so
    specification of the pc's output interface is required.
    """
    def __init__(self, target_ip, ifname, target_port=11114, timeout=2, retries=0):
        self.debug = False
        self.timeout = timeout
        # Additional attempts after a receive timeout. Requests are
        # idempotent (peeks re-read, pokes re-write the same value), so a
        # resend after a dropped frame is safe; the socket is drained before
        # each send so a late-arriving response can never be matched to a
        # newer request.
        self.retries = retries
        # count of timed-out attempts that were subsequently retried; lets a
        # caller report link flakiness instead of dying on it
        self.timeouts_retried = 0
        # Basic UDP IPv6 socket setup
        self.sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
        # Build the target address using getaddrinfo and the interface name
        host = target_ip + "%" + ifname
        self.target_addr = socket.getaddrinfo(host, target_port, socket.AF_INET6, socket.SOCK_DGRAM)[0][4]

    def __del__(self):
        self.sock.close()

    def read32(self, addr) -> int:
        """do a 32bit read from the requested address, return response as int"""
        req = Request()
        req.set_address(addr)
        # 1 32bit Read, no increment address pointer
        req.add_read32s(1)
        # full response back
        resp = self._get_resp_from_request(req)
        return resp.expected_responses[0].payload

    def write32(self, addr, data) -> None:
        """Write data to the requested address"""
        req = Request()
        req.set_address(addr)
        req.add_write32s([data])
        _ = self._get_resp_from_request(req)

    def execute_prebuilt_request(self, req: Request) -> Response:
        """Allow BYO requests for fancier things"""
        return self._get_resp_from_request(req)

    def _get_resp_from_request(self, request: Request) -> Response:
        """ Send the request, process response back into expected
        responses and return that
        """
        # full response back
        resp_bytes = self._send_get_reply_handshake(request)
        request.response.process_bytes(resp_bytes)
        return request.response

    def _drain(self) -> None:
        """Discard any stale datagrams (late responses from a timed-out
        attempt) so request/response pairing stays in lockstep."""
        self.sock.setblocking(False)
        try:
            while True:
                self.sock.recv(1500)
        except (BlockingIOError, OSError):
            pass
        finally:
            self.sock.setblocking(True)

    def _send_get_reply_handshake(self, request: Request) -> bytes:
        for attempt in range(1 + self.retries):
            self._drain()
            if self.debug:
                print(f"Sending request: {request.hex()}")
            self.sock.sendto(bytes(request), self.target_addr)
            # try rx up to mtu size for timeout time and return
            # response or exception on timeout
            self.sock.settimeout(self.timeout)
            try:
                resp = self.sock.recv(1500)
            except socket.timeout:
                if attempt < self.retries:
                    self.timeouts_retried += 1
                    continue
                raise Exception(
                    "Timeout- no response back from target"
                    + (f" after {1 + self.retries} attempts" if self.retries else "")
                )
            if self.debug:
                print(f"Got response: {resp.hex()}")
            return resp