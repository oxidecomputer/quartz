# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright 2026 Oxide Computer Company

# Reads a length-prefixed buffer via the UDP peek/poke interface.
#
# Usage:
#   python read_buffer.py --target <ipv6> --ifname <iface> [--port <port>]
#
# Protocol:
#   - Read 4 bytes from 0xc0008024 to get the byte count N
#   - Read ceil(N/4) words from 0xc0008100..0xc0008100+(N-1)

import argparse
import math
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
import udp_if

COUNT_ADDR  = 0xc0008024
BUFFER_ADDR = 0xc0008100

# Max words per request: response must fit in 1500-byte MTU.
# Response = 1 status byte + N * 4 data bytes  =>  N <= (1500 - 1) // 4 = 374
WORDS_PER_CHUNK = 374


def read_buffer(con: udp_if.UDPMem) -> bytes:
    # Step 1: read the byte count
    byte_count = con.read32(COUNT_ADDR)
    print(f"Byte count at {COUNT_ADDR:#010x}: {byte_count} (0x{byte_count:x})")

    if byte_count == 0:
        print("Buffer is empty.")
        return b""

    word_count = math.ceil(byte_count / 4)
    print(f"Reading {word_count} word(s) from {BUFFER_ADDR:#010x}...")

    result = bytearray()

    # Step 2: read words in chunks that fit within one UDP response packet
    words_remaining = word_count
    chunk_start_addr = BUFFER_ADDR

    while words_remaining > 0:
        chunk_words = min(words_remaining, WORDS_PER_CHUNK)

        req = udp_if.Request()
        req.set_address(chunk_start_addr)
        req.add_read32_advances(chunk_words)

        resp = con.execute_prebuilt_request(req)

        for peek in resp.expected_responses:
            result += peek.bytes

        chunk_start_addr += chunk_words * 4
        words_remaining  -= chunk_words

    # Trim to the exact byte count
    result = result[:byte_count]
    return bytes(result)


def main():
    parser = argparse.ArgumentParser(
        description="Read a length-prefixed buffer over the UDP peek/poke interface."
    )
    parser.add_argument("--target", required=True,
                        help="IPv6 link-local address of the target (e.g. fe80::...)")
    parser.add_argument("--ifname", required=True,
                        help="Network interface name (e.g. eno1)")
    parser.add_argument("--port", type=int, default=11114,
                        help="UDP port (default: 11114)")
    parser.add_argument("--timeout", type=float, default=2.0,
                        help="Socket timeout in seconds (default: 2.0)")
    args = parser.parse_args()

    con = udp_if.UDPMem(args.target, args.ifname, args.port, args.timeout)

    data = read_buffer(con)

    # Print as a hex dump
    print(f"\nBuffer contents ({len(data)} bytes):")
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_part  = " ".join(f"{b:02x}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        print(f"  {BUFFER_ADDR + i:#010x}:  {hex_part:<47}  {ascii_part}")


if __name__ == "__main__":
    main()
