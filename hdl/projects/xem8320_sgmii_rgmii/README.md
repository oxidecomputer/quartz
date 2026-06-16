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
- `clk_125m` (GT `txusrclk2`) is the single user-clock domain for the PCS and
  RGMII TX. The GT RX buffer + clock correction keep RX in that domain.
- The DP83867 RGMII `rxc` clocks the RGMII RX; it is delayed on-chip (IDELAYE3)
  to center the sampling and crossed back to `clk_125m` by the rate expander.
- Management is **strapped/minimal**: the advertised SGMII ability is hardwired
  (link up / full duplex / 1000). No MDIO. The XEM8320 has no dedicated LEDs, so
  link/GT/PLL status is brought out on spare Port A pins (`status[3:0]`).

## Files

| File | Purpose |
|------|---------|
| `xem8320_sgmii_rgmii_top.vhd` | Top level: clocking, reset, RGMII RX delay, LEDs |
| `gt/sgmii_gt.vhd` | GT wrapper → clean 10-bit code-group interface |
| `black_box_entities/gtwizard_sgmii.vhd` | Stub for the generated GT wizard core |
| `black_box_entities/idelay_pll.vhd` | Stub for the IDELAY/free-run MMCM |
| `xilinx_ip_gen/gtwizard_sgmii_ip.tcl` | GT wizard IP (raw 10-bit, comma-align, RX CC) |
| `xilinx_ip_gen/idelay_pll_ip.tcl` | clk_wiz: 200 MHz IDELAYCTRL ref + 100 MHz free-run |
| `xem8320_sgmii_rgmii_pins.xdc` | Pin LOCs (templated) + IOSTANDARD/SLEW |
| `xem8320_sgmii_rgmii_timing.xdc` | Clocks, RGMII I/O delays, async clock groups |

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
```

## Before a real bitstream — items to complete

RGMII package pins are fully resolved by crossing the XEM8320 pin list with the
SZG-ENET1G pinout (see the table in `*_pins.xdc`). The remaining items need an
interactive Vivado GT-wizard session and on-board tuning:

1. **Confirm Port A SmartVIO = 1.8 V** for the SZG-ENET1G, and (if you want PHY
   management later) wire MDC/MDIO — they land on D7P/D7N = K22/K23.
2. **GT wizard config** — verify in the GUI: the GTYE4_CHANNEL site for quad 226
   channel 2 (SMA lanes; serial pins H2/H1, J5/J4), the **REFCLK0** source (the
   onboard 125 MHz; not REFCLK1/the SMA input), raw user-data width, and
   comma/clock-correction settings. If the wizard forces a 20-bit @ 62.5 MHz raw
   datapath, add a 2:1 gearbox + alignment in `gt/sgmii_gt.vhd` so the bridge
   still sees one 10-bit code group per 125 MHz clock. Reconcile the generated
   core's ports with `gtwizard_sgmii.vhd` (and confirm the IBUFDS_GTE4 ODIV2
   divide gives the expected 62.5 MHz free-run).
3. **RGMII RX delay** — `IDELAYE3 DELAY_VALUE` (top level) centers `rxc` in the
   RX data eye; tune it on hardware. If the DP83867 is later configured for
   internal RGMII RX delay (needs MDIO, out of scope here), set it back toward 0.
4. **RGMII TX delay** — the first cut forwards `txc` edge-aligned to `txd`. For
   reliable PHY capture, either enable the DP83867 TX internal delay or shift
   `txc` (e.g. a 90°-phase clock) — a bring-up item.

The SGMII line can alternatively target an onboard **SFP cage** (SFP1 = quad 226
ch0, SFP2 = ch1) or a **SYZYGY transceiver port** (Port E = quad 224, Port F =
quad 225) instead of the SMAs — repoint the GT serial + refclk pins and the
GT-wizard channel if so.
