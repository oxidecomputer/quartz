# XEM8320 SGMII ↔ RGMII bridge

A media converter for the Opal Kelly **XEM8320** (`xcau25p-ffvb676-2-e`) that
bridges an **SGMII** line (GTY transceiver, on the onboard SMA connectors
J15-J18) to an **RGMII** PHY — the Opal Kelly **SZG-ENET1G** pod (TI DP83867,
RGMII-only, auto-negotiation strapped on, on SYZYGY Port A).

The datapath is the reusable, simulation-tested bridge under
[`//hdl/ip/vhd/ethernet`](../../ip/vhd/ethernet): a soft SGMII PCS (8b10b +
Clause-37 auto-neg), an RGMII MAC with DDR I/O, and a dual-clock rate-expander
FIFO. This project is only the board target around it.

## Block diagram

```
  SFP / SGMII partner                                    RJ-45 / copper
        │                                                      │
   ┌────┴─────┐  10b code   ┌───────────────┐  GMII  ┌─────────┴──────┐
   │  GTY     │  groups     │   soft SGMII  │  8b    │   RGMII MAC    │  RGMII
   │ SMA      │◄──────────► │   PCS + AN    │◄─────► │  (ODDRE1/IDDRE1)│◄────► DP83867
   │ J15-J18  │  @125 MHz   └───────────────┘        └────────────────┘  (Port A)
   └──────────┘
   sgmii_gt.vhd            sgmii_to_rgmii (ethernet IP)        rgmii ddr wrappers
```

- The SGMII serial is on the onboard **SMA connectors J15-J18** (GTY quad 226,
  channel 2). The GT reference clock is the **onboard 125 MHz** on MGTREFCLK0_226
  (P7/P6) — no external clock needed. (MGTREFCLK1_226 / M7/M6 is the external SMA
  refclk on J19/J20, unused here.)
- The XEM8320 has **no fabric oscillator** — the GT reference clock is the only
  always-on clock. `sgmii_gt`
  buffers it (`IBUFDS_GTE4` + `BUFG_GT`) into an always-on free-run clock that
  feeds the GT reset FSM and the MMCM (which makes the 200 MHz IDELAYCTRL ref).
- The GT runs raw (8b10b bypassed) with a **20-bit datapath at 62.5 MHz** (two
  code groups per GT clock). `sgmii_gt` doubles that to the **125 MHz** PCS clock
  (`usrclk_mmcm`) and `sgmii_gearbox` gears 20b↔10b, finding the code-group
  boundary itself (K28.5 bit-slip) so it doesn't depend on the GT's alignment.
  `clk_125m` (the doubled GT user clock) is the single domain for the PCS and
  RGMII TX.
- The DP83867 RGMII `rxc` clocks the RGMII RX (through a BUFG); it is crossed back
  to `clk_125m` by the rate expander. RX capture needs no FPGA delay because the
  PHY is set for RGMII-ID (below).
- At startup an **MDIO master** programs the DP83867 for **RGMII internal delay**
  (the PAP package has no DLL-skew straps), so the PHY centers RXC/TXC, and
  restricts copper auto-neg to **100BASE-TX full duplex**.
- **Fixed 100 Mbps.** The cosmo SGMII partner is fixed 100M and does not
  auto-negotiate, so the SGMII PCS runs with autoneg OFF (link forced up) and a
  fixed 100M ability, which drives the whole bridge (RGMII 100M SDR + 10x SGMII
  octet replication). The copper side is pinned to 100M in the PHY (above), so all
  three legs match. To run other speeds, re-enable `INCLUDE_AUTONEG`, set
  `adv_config`, and drop the DP83867 advertisement writes.
- The XEM8320 has no LEDs, so link/GT/init status is on spare Port A pins
  (`status[3:0]`) and the ILA.

## Files

| File | Purpose |
|------|---------|
| `xem8320_sgmii_rgmii_top.vhd` | Top level: clocking, reset, MDIO startup, status |
| `gt/sgmii_gt.vhd` | GT wrapper: refclk buffers, MMCM, gearbox → clean 10-bit iface |
| `gt/sgmii_gearbox.vhd` | 20b@62.5 ↔ 10b@125 SerDes + K28.5 comma bit-slip aligner |
| `gt/sims/sgmii_gearbox_tb.vhd` | Self-check for the gearbox (VUnit) |
| `mdio/mdio_master.vhd` | Clause-22 MDIO master (read/write) |
| `mdio/dp83867_init.vhd` | Startup FSM: enables DP83867 RGMII-ID over MDIO |
| `mdio/sims/mdio_master_tb.vhd` | Self-check for the MDIO frame (VUnit) |
| `black_box_entities/gtwizard_sgmii.vhd` | Stub for the generated GT wizard core (20-bit raw) |
| `black_box_entities/usrclk_mmcm.vhd` | Stub for the 62.5→125 MHz PCS-clock MMCM |
| `xilinx_ip_gen/gtwizard_sgmii_ip.tcl` | GT wizard IP (raw 20-bit, X0Y10, comma + RX clock correction) |
| `xilinx_ip_gen/usrclk_mmcm_ip.tcl` | clk_wiz: 62.5→125 MHz PCS clock |
| `xem8320_sgmii_rgmii_pins.xdc` | Pin LOCs + IOSTANDARD/SLEW |
| `xem8320_sgmii_rgmii_timing.xdc` | Clocks, RGMII RX input delays, async clock groups |
| `post_synth_timing.tcl` | TX forwarded-clock (rgmii_txc) generated clock + output delays |
| `ila.tcl` | Debug ILA on the `mark_debug` taps (rx/tx code groups + link status) |

The UltraScale+ `ODDRE1`/`IDDRE1` branches live in the shared RGMII DDR wrappers
([`rgmii/ddr`](../../ip/vhd/ethernet/rgmii/ddr)) and are selected by the
`TARGET => "XILINX"` generic threaded from the top through `sgmii_to_rgmii`.

## Build

```bash
buck2 build //hdl/projects/xem8320_sgmii_rgmii:xem8320_sgmii_rgmii
```

Regression for the (unchanged) SIM datapath:

```bash
buck2 run //hdl/ip/vhd/ethernet/sgmii_to_rgmii:sgmii_to_rgmii_tb
buck2 run //hdl/ip/vhd/ethernet/rgmii:rgmii_mac_tb
buck2 run //hdl/ip/vhd/ethernet/sgmii:sgmii_pcs_tb
buck2 run //hdl/projects/xem8320_sgmii_rgmii:sgmii_gearbox_tb   # gearbox self-check
buck2 run //hdl/projects/xem8320_sgmii_rgmii:mdio_master_tb     # MDIO frame self-check
```

## Build status

The full flow **builds a bitstream with setup and hold met** (Vivado 2024.2:
synth → opt → place → route → `write_bitstream`, 0 errors). Post-route:
**WNS +0.04 ns / TNS 0 (setup), WHS +0.01 ns / THS 0 (hold)** with both the RGMII
RX inputs and the TX forwarded-clock outputs timed. The GT is a **single channel**
(X0Y10 = the SMA lane, quad 226 ch2, QPLL0, raw 20-bit, external user clocking).

- **RX/TX delay**: the DP83867 is programmed for **RGMII-ID** at startup over MDIO,
  so the PHY centers RXC (FPGA captures directly, no IDELAY) and delays its TX
  sampling (FPGA forwards edge-aligned). RX `set_input_delay` and TX
  `set_output_delay` are constrained analytically from the PHY's internal-delay
  window — no bench measurement.
- **Link partner**: the GT runs with **RX clock correction** (adds/removes a
  comma-led idle pair — one full ordered set = one gearbox word — in its elastic
  buffer), so RX stays in the single 62.5 MHz TX user-clock domain against an
  independent-ppm partner.
- An **ILA** (`ila.tcl`, cosmo_seq-style) gives live debug over FrontPanel/JTAG:
  the SGMII RX/TX 10-bit code groups and the resolved link status (link/speed/
  duplex, gt_ready, RGMII in-band link, MDIO init done), clocked by clk_125m.
  Signals are tagged `mark_debug` in the top so the probes connect by name without
  the "Set Up Debug" GUI; add more from the hardware manager. (This also satisfies
  the flow's post-synth debug-probe hook — the board has no LEDs.)

Timing margins are thin because the RX/TX delay numbers are representative;
finalize them from the DP83867 datasheet (see below). The hold-critical paths are
the RGMII I/O.

## Before it works on hardware — bring-up items

1. **Finalize the RGMII I/O delays** from the DP83867 RGMII-ID data-to-clock spec:
   RX `set_input_delay` in `*_timing.xdc` and TX `set_output_delay` in
   `post_synth_timing.tcl` (both flagged as placeholders; margins are thin). The
   pod is length-matched, so the board-skew term is negligible.
2. **Confirm Port A SmartVIO = 1.8 V** for the SZG-ENET1G.
3. **Confirm the GT clock-correction sequence** matches your partner's idle if you
   tighten it beyond "comma-led pair" (see `gtwizard_sgmii_ip.tcl`).

The DP83867 RGMII-ID enable runs at power-up: a startup FSM releases `phy_resetn`,
waits, then `dp83867_init` writes RGMIIDCTL/RGMIICTL over the `mdio_master`
(Clause-22, MMD-indirect). Both are unit-tested (`mdio_master_tb`), as is the
gearbox (`sgmii_gearbox_tb`).

The GT config (single channel X0Y10 / refclk / 20-bit widths) is confirmed
against the generated core; the gearbox (2:1 + comma bit-slip) and its bit order
are unit-tested (`sgmii_gearbox_tb`).

The SGMII line can alternatively target an onboard **SFP cage** (SFP1 = quad 226
ch0, SFP2 = ch1) or a **SYZYGY transceiver port** (Port E = quad 224, Port F =
quad 225) instead of the SMAs — repoint the GT serial + refclk pins and the
GT-wizard channel if so.
