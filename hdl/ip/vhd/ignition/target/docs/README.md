The primordial re-write and documentation of the ignition protocol and
the ignition target.  Some portions of this might eventually make their way
back into RFD142 which currently had a number of incorrect and misleading bits
of information, making all of it suspect.

= Overview
Ignition is an 8b10b encoded protocol primarily for low-level presence indication and
power control. It finds itself as a core component of most of our custom boards that
are "smart" components in the rack.

= Ignition Protocol
Each symbol is 8b10b encoded and sent LSB first as is typical in serdes-type links.
The basic message frame has the following structure (encoded as 10 bits but though of logically as 8 bits after decode):
1 symbol: K28.0 as a Start of Packet indicator
1 symbol: constant 0x1 indicating protocol version
1 symbol: packet type (either 1: "Hello", 2: Status, 3: Request)
N symbols: N = 0 for hello, 8 for Status, 1 For Request
1 symbol: CRC using 8bit autostar CRC with poly 0x2F
1 symbol: K23.7 as an End of Packet indicator
1 symbol: K29.7 if N was odd. Unclear on why this was important, again maybe due to the use of "Ordered Sets"

Invalid symbols were "stomped" with a K30.7 as an invalid-end-of-stream
This also seems like an odd choice, but maybe made for implementation reasons around the use of "Ordered Sets"?

= Ignition Target
One challenge that any ignition target design has is the very small LUT footprint of the original devices
used on gimlet/psc/sidecar.  These are very small devices with ~1kLUTs and 64kb of block ram.  Original bsv
design for ignition target is stressed on the LUTs and not using any block ram at all.

In the original design, "expensive" portions of the design were time-domain multiplexed
to limit the logic utilization. This reimplementation will attempt a similar architecture
albeit with some different choices made in how the design is broken down. It appears that the original
implementation was actually a bit register heavy due to both carrying through the 10bit symbols (meaning
parser and all downstream logic had to store more bits *and* operate on wider symbols), and it did not
using any RAM, so any packet storage was registers.

Some opportunities for reducing logic:
- Post 8b10b decode, we can drop the control character framing, parser doesn't have to see
 this stuff, and if we use RAMs, dropping packets is "easy".
- ideally we'd store running crc, failed CRCs can "stomp" packets in a dual-port RAM easily
  enough so they don't have to propagate further through the design.

We're going to aggressively share logic, and attempt to also make use of the BRAM:
after the shared 8b10b decoder, we're going to feed messages into a shared RAM FIFO
and only "parse" them once they've been completely received. This differs from the
original design in that we don't have to store interim parsing states, we can
make the parser state machine one-shot through a whole packet.


Open Questions:
- Many? None?


LC budget: 1280 total cells to fit in the smallest devices. Newer ignition-based
designs have larger FPGAs due to DFM needs, but we'd like the option to back port the design
to smaller devices should the need arise.

Here are some yosys estimates for our "expensive" blocks

43: 8b10b encode x1
84: 8b10b decode x1
36: crc instance x2 (tx + rx)
??: ls serdes