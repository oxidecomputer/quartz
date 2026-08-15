# xem8320_eth_mgmt

The XEM8320 bring-up project for the managed SGMII<->RGMII media
converter: `sgmii_to_rgmii_mgmt` plus the board plumbing (GTY SGMII on the
SMAs, SZG-ENET1G DP83867 on SYZYGY port A, MDIO RGMII-ID init), the git
short SHA as the FPGA version, and the SPI config flash reached through
STARTUPE3. See `hdl/ip/vhd/ethernet/README.adoc` for the datapath and
`hdl/ip/vhd/ethernet/eth_mgmt/docs/mgmt_protocol.adoc` for the management
protocol.

## RGMII timing at 1000BASE-T

The RGMII interface is closed at 1000BASE-T. It did not start that way, and
the way it was closed is worth recording, because half the fix lives in the
PHY's configuration rather than in the FPGA.

Constraints come from the DP83867IR/CR datasheet (SNLS484J) section 6.9,
internal-delay rows: the PHY guarantees +/-1.2 ns of RXD validity about each
RXC edge when driving us, and requires +/-1.0 ns about TXC when receiving.
Both are worst-case minimums against a 2 ns nominal. The `TskewT`/`TskewR`
rows nearby are the *non* internal-delay specs (datasheet note 2) and do not
apply here.

### Transmit: a constraint bug, not a hardware one

Measured data-to-clock skew at the pads is +0.19 ns against that +/-1.0 ns
tolerance -- txd and txc are launched by the same clock edge through matched
output DDR primitives, which is as aligned as the interface gets. It had
nevertheless appeared to fail by 1.7 ns, because a DDR forwarded clock invites
Vivado to analyse rise-against-fall pairs and compare data with a txc edge half
a period away. `post_synth_timing.tcl` false-paths the combinations that are
not real relationships, and the interface reports what it physically is.

### Receive: the eye is narrower than the clock insertion delay

    data  path, pad -> IDDR D:   ~0.43 ns  (IBUF 0.27 + route 0.15)
    clock path, pad -> IDDR C:   ~2.67 ns  (IBUF 0.49 + route + BUFG + net 1.67)

Centering RXC in the eye at the pins -- the textbook RGMII-ID setting of
2.00 ns, which is what this design used to program -- puts the capture edge
2.24 ns later relative to the data inside the FPGA than it was at the pins.
The guaranteed eye is 2.4 ns wide and the clock insertion delay alone is
2.67 ns, so the capture edge lands outside the data window and hold fails by
about a nanosecond. No constraint tuning fixes that; it is where the edges
physically are.

What does fix it is advancing the PHY's RX clock instead of delaying the
FPGA's data. The delay is programmable in 0.25 ns steps (RGMIIDCTL bits 3:0,
0000 = 0.25 ns through 1111 = 4.00 ns), and reducing it trades setup for hold
1:1. Sweeping the setting against the routed design -- these are measured on
the RGMII RX capture path, not modelled:

    PHY RX delay      hold      setup
        0.25 ns      +0.606     -0.177
        0.50 ns      +0.356     +0.073   <- programmed
        0.75 ns      +0.106     +0.323
        1.00 ns      -0.144     +0.573

Only 0.50 and 0.75 close both checks. Note that hold + setup is 0.429 ns at
every setting: the knob redistributes a fixed budget, it does not create
margin. That budget is what the PHY's guaranteed 2.4 ns eye is worth after
clock uncertainty, the IDDR's own requirement and the 0.1 ns of board skew
allowed for, and nothing on the FPGA side widens it -- an IDELAYE3 would shift
the same 0.429 ns around exactly as the PHY delay does.

`dp83867_init` therefore writes RGMIIDCTL = 0x71: TX delay unchanged at
2.00 ns, RX delay 0.50 ns, which favours hold because that is the check that
was structurally broken and the one that moved most with placement (the same
path varied ~0.4 ns between builds before the fix). The matching window is
derived in each project's timing XDC from a `rgmii_rx_delay` variable that must
equal the RX nibble -- `dp83867_init_tb` checks the register value the sequence
actually emits so the two cannot drift apart unnoticed.

Two things follow from a 0.429 ns budget. Worst-case datasheet numbers are
pessimistic -- the eye is specified at +/-1.2 ns min against a +/-2 ns nominal,
so typical silicon has most of another nanosecond -- which is why this runs at
all. But if gigabit is going to be *relied* on rather than demonstrated, add
the IDELAYE3: not for margin, which it cannot create, but because it can be
trimmed in picoseconds on a live board and can absorb the placement variance
that a fixed PHY setting cannot.

### What this does not affect

10 and 100 Mbps are untouched, and the reasoning matters if the delay is ever
retuned. The programmed skew is a fixed delay line in 0.25 ns steps, not a
fraction of the clock period, and at 10/100 the PHY duplicates the nibble on
the falling edge (datasheet section 7.4.1.1.3) so the data is stable for a
whole 40 ns (or 400 ns) period. Reworking the same routed delays at 100M:
setup margin moves from 4.24 ns to 2.74 ns and hold from 35.8 ns to 37.3 ns --
a sub-nanosecond change against tens of nanoseconds of margin. This is also
why the board ran happily at 100M throughout the period when the gigabit hold
check was failing: hold checks are period-independent, so the single 8 ns
`create_clock` reports the gigabit case unconditionally, which is exactly what
you want from a constraint but should not be read as a 100M problem.

### The other project

`xem8320_sgmii_rgmii` shares `dp83867_init`, so it received the same delay
value and the same constraints. It reports two violations of a few tens of
picoseconds at gigabit -- a hold on the same IDDR path (placement variance
against the budget above) and a setup on `rxctl_frames`, a bring-up counter
that samples the raw rx_ctl pin into fabric rather than through the IDDR, and
which this project does not have. That scaffold is forced to 100M, where the
margins are the tens of nanoseconds described below, so the gigabit numbers are
reported but not operative for it.

### Alternatives

* **IDELAYE3 on the five RX inputs.** Delaying the data instead of
  advancing the clock reaches the same place, and is the more portable
  answer if a future board's PHY has no programmable delay. It costs an
  IDELAYCTRL plus a reference clock (one more output on the usrclk MMCM)
  and belongs in the `TARGET => "XILINX"` branch so simulation and other
  targets are untouched. Worth doing if bench measurement disagrees with
  the table above, or as belt-and-braces alongside a smaller PHY delay
  reduction. Check the achievable range in TIME mode for the chosen
  reference frequency before committing to it as the sole fix.
* **Not recommended: MMCM deskew of rxc.** Zero-delay-compensating the
  clock path gives the cleanest analysis, but the UltraScale+ MMCM
  minimum input frequency is 10 MHz -- 10BASE-T's 2.5 MHz RXC cannot
  lock, and every speed change forces a relock. Only revisit if 10M
  support is explicitly dropped.

### Also required to actually run 1000BASE-T

Timing is no longer the gate -- the interface is constrained and closed at
1000 -- but the link is still deliberately pinned at 100M by configuration:

* `dp83867_init` writes GBCR = 0x0000, removing the 1000BASE-T
  advertisement -- it must advertise 1000FD (0x0200/0x0300) instead.
* The top forces the SGMII side to 100M full duplex with autoneg off
  (`ADV`, `INCLUDE_AUTONEG => false`) to match the VSC partner; the far
  end and this advertisement must agree on 1000.

Both are one-line changes, but they are a link-policy decision (what this
box negotiates with the switch), not a timing one, so they are deliberately
left as they are until the far end is ready to run gigabit.

The management plane itself is already exercised at 1000 in simulation
(`udp_endpoint_tb` and the integration TB run the full datapath at
SPEED_1000), so once the link closes electrically nothing above the MAC
changes.
