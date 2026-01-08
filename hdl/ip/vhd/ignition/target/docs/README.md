The primordial re-write and documentation of the ignition protocol and the
ignition target.  These were mostly during-implementation notes as the RFD was
stale at the time but the correct info has been worked back into RFD 142.

# Overview

Ignition is an 8b10b encoded protocol primarily for low-level presence
indication and power control. It finds itself as a core component of most of our
custom boards that are "smart" components in the rack.

# Ignition Protocol
Each symbol is 8b10b encoded and sent LSB first as is typical in serdes-type
links. The basic message frame has the following structure (encoded as 10 bits
but though of logically as 8 bits after decode): 1 symbol: K28.0 as a Start of
Packet indicator 1 symbol: constant 0x1 indicating protocol version 1 symbol:
packet type (either 1: "Hello", 2: Status, 3: Request) N symbols: N = 0 for
hello, 8 for Status, 1 For Request 1 symbol: CRC using 8bit autostar CRC with
poly 0x2F. Note that this has an additional final xor of the crc register with
0xFF 1 symbol: K23.7 as an End of Packet indicator 1 symbol: K29.7 if N was odd.
Legacy implementation in bsv requires "Ordered Sets" so this re-aligns to an
even boundary. The only packet ignition target sends is STATUS which is odd so
this is hard-coded into the end of the transmit sequence.

## IDLE sequence notes
The legacy IDLE sequence is more complicated than it needs to be, but was
replicated here for compatibility reasons. There's a neat IDLE sequence protocol
feature where polarity inversion can be compensated for at the rx block. There
are two IDLE patterns, IDLE1 and IDLE2: IDLE1 is a K28.5 followed by a D10.2
character. IDLE2 is a K28.5 followed by a D19.5 character.

Invalid symbols were "stomped" with a K30.7 as an invalid-end-of-stream in the
legacy implementation. In this implementation, ctrl characters or other bit
errors during packet reception are expected to cause crc errors and thus are not
treated specially, and the reception code only acts on reception of frames with
a passing CRC.

Polarity inversion detection and correction makes use of the following properties: K28.5+ and K28.5- are bitwise
inverses of each other, which means that a K28.5 is properly decoded regardless
of whether polarity is inverted or not. This property is also true of a number
of characters in their post-8b10b encoding representation, but the D10.2 and D19.5 characters where
chosen specifically because they do not have polarity-symmetric representations.
A D10.2 that has been polarity inverted decodes to a D12.2 character and a
polarity inverted D19.5 turns into a D21.5 character. Thus, it is sufficient to
compare the data character following the K28.5 to determine link polarity. If
you get a D10.2 or a D12.2, no polarity inversion is required. If you get a
D12.2 or D21.5 character you are polarity inverted and need to invert the data.

It is at this point, that the legacy implementation adds some unnecessary
complexity: the choice of which IDLE sequence (IDLE1 or IDLE2) is based on the
current running disparity, and the legacy RX block uses which IDLE it gets to
adjust the running disparity on the fly, regardless of the actual 8b10b
decoder's disparity. This is unnecessary complication that doesn't actually
address any issues. A D10.2 regardless of which disparity was transmitted, will
always decode to a D10.2 so there's no need to interlock running disparity with
the IDLE sequence. And, regardless of disparity, a polarity inverted D10.2 will
decode into a D12.2, and any invalid disparity will eventually sort itself out
as the system runs.

This disparity-based IDLE sequence selection remains in this implementation for
interoperability reasons if and until we can alter the controller rx implementations 
to not adjust the rx RD
based on the IDLE sequence and instead just use the current running RD.


# Ignition Target 

One challenge that any ignition target design has is the very
small LUT footprint of the original devices used on gimlet/psc/sidecar.  These
are very small devices with ~1kLUTs and 64kb of block ram. Current
implementation sits at just shy of 800 Ice40 LUTs, so we have options to back
port this if we choose to do so.

This implementation attempts to share logic (such as the whole TX path) where
possible, but didn't in-scope any RAM usage since the packets transmitting and
receiving are small. Using RAM and then sharing the RX CRC block was briefly
investigated but the TDM and ram pointer logic was trending to make the logic
savings a wash.


LC budget: 1280 total cells to fit in the smallest devices. Newer ignition-based
designs have larger FPGAs due to board DFM needs, but we'd like the option to
back port the design to smaller devices should the need arise.

![Ignition Target Block Diagram](ignition_target.drawio.svg)