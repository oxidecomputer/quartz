# Fault Tree Analysis: Failure to Sequence to A0

**Top-level event:** State machine in `a1_a0_seq.vhd` fails to reach `DONE`.

The state machine progresses through 14 states from IDLE to DONE. Failure means either stalling indefinitely in an intermediate state, or being forced back to IDLE by a fault/disable condition. The tree is organized by the state where progress is blocked or reversed.

---

## 1. Stuck in IDLE (never begins sequencing)

The IDLE→DDR_BULK_EN transition requires `enable_pend AND upstream_ok`.

- **1a. `enable_pend` never asserted**
  - Software never writes `a0_en` in `power_ctrl` register
  - Software wrote `a0_en` but never generated a rising edge (was already high, no clear-then-set)
  - Previous fault left `faulted` latched and software re-enabled without a fresh rising edge (though note: the rising edge clears `faulted`)

- **1b. `upstream_ok` never asserted**
  - Upstream prerequisites not met (fans, thermal, hot-swap controllers — driven from `sp5_sequencer` top level)
  - Upstream sequencer itself faulted or stuck

**Registers to check:**

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_raw_status` | `hw_sm[7:0]` | `0x00` (IDLE) | Confirms stuck in IDLE vs. elsewhere |
| `seq_api_status` | `a0_sm[7:0]` | `0x00` (IDLE) | Same, coarser view |
| `power_ctrl` | `a0_en` (bit 0) | `1` | `0` → software never wrote enable |
| `seq_api_status` | `a0_sm[7:0]` | `0x0b` (FAULTED) | Previous fault not cleared; need clear-then-set of `a0_en` |
| `early_power_rdbks` | `fan_hsc_*_pg` (bits 1–3) | All `1` | Any `0` → upstream fan HSC not good, blocking `upstream_ok` |
| `status` | `fanpwrok` (bit 0) | `1` | `0` → fan power prerequisite not met |

## 2. Stuck in GROUP_A_PG_AND_WAIT (Group A rails fail to come good)

Requires `is_power_good(group_a)` sustained for 1 second (ONE_SECOND counts).

- **2a. V1P5_RTC PG never asserts** — regulator fault, no input power, enable not reaching regulator
- **2b. V3P3_SP5_A1 PG never asserts** — same class of regulator/input fault
- **2c. V1P8_SP5_A1 PG never asserts** — same
- **2d. PG asserts but is intermittent** — counter resets to zero each cycle where `is_power_good` is false, so any glitch restarts the 1s wait; sustained instability means infinite stall

**Registers to check:**

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_raw_status` | `hw_sm[7:0]` | `0x03` (GROUP_A_PG_AND_WAIT) | Confirms stuck in this state |
| `rail_enables` | `v1p5_rtc` (bit 2), `v3p3_sp5` (bit 3), `v1p8_sp5` (bit 4) | All `1` | Any `0` → enable not being driven |
| `rail_pgs` | `v1p5_rtc` (bit 2), `v3p3_sp5` (bit 3), `v1p8_sp5` (bit 4) | All `1` | Whichever bit is `0` identifies the blocking rail |
| `rail_pgs_max_hold` | Same bits as `rail_pgs` | All `1` | Bit is `1` in max_hold but `0` in live → intermittent PG (fault 2d) |

## 3. Stuck in SLP_CHECKPOINT (SP5 sleep handshake fails)

Requires `SLP_S3_L=1 AND SLP_S5_L=1 AND is_power_good(ddr_bulk)`.

- **3a. SLP_S5_L remains asserted (low)** — SP5 not responding to power button press, SP5 absent/dead, RSM_RST_L didn't propagate, power button pulse too short or not recognized
- **3b. SLP_S3_L remains asserted (low)** — SP5 staying in S3 sleep state, same root causes as 3a
- **3c. DDR bulk PG not good** — ABCDEF_HSC or GHIJKL_HSC hot-swap controller PG not asserting; input 12V missing, HSC fault, HSC enable didn't reach the device
- **3d. `ignore_sp5` not set during bench testing** — if testing without SP5, SLP signals stay low and checkpoint blocks forever unless `ignore_sp5` is asserted via `debug_enables` register

**Registers to check:**

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_raw_status` | `hw_sm[7:0]` | `0x06` (SLP_CHECKPOINT) | Confirms stuck in this state |
| `sp5_readbacks` | `slp_s5_l` (bit 5) | `1` (deasserted) | `0` → SP5 still in S5 sleep (fault 3a) |
| `sp5_readbacks` | `slp_s3_l` (bit 4) | `1` (deasserted) | `0` → SP5 still in S3 sleep (fault 3b) |
| `sp5_readbacks` | `rsmrst_l` (bit 6) | `1` | `0` → RSM_RST_L not released, SP5 can't wake |
| `sp5_readbacks` | `pwr_btn_l` (bit 7) | `1` (idle) | Stuck `0` → power button still asserted |
| `rail_pgs` | `abcdef_hsc` (bit 0), `ghijkl_hsc` (bit 1) | Both `1` | Either `0` → DDR bulk PG missing (fault 3c) |
| `rail_enables` | `abcdef_hsc` (bit 0), `ghijkl_hsc` (bit 1) | Both `1` | Either `0` → HSC enable not driven |
| `debug_enables` | `ignore_sp5` (bit 0) | `1` for bench, `0` for production | If bench-testing without SP5 and this is `0` → fault 3d |

## 4. Stuck in GROUP_B_PG_AND_WAIT (Group B rails fail)

Requires `is_power_good(group_b)` sustained for 1ms.

- **4a. V1P1_SP5 PG never asserts** — single rail in this group; regulator fault or input power missing

**Registers to check:**

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_raw_status` | `hw_sm[7:0]` | `0x08` (GROUP_B_PG_AND_WAIT) | Confirms stuck in this state |
| `rail_enables` | `v1p1_sp5` (bit 5) | `1` | `0` → enable not driven |
| `rail_pgs` | `v1p1_sp5` (bit 5) | `1` | `0` → regulator not reporting power good |
| `rail_pgs_max_hold` | `v1p1_sp5` (bit 5) | `1` | `1` in max_hold but `0` in live → intermittent PG |

## 5. Stuck in GROUP_C_PG_AND_WAIT (Group C rails fail)

Requires `is_power_good(group_c)` sustained for 2ms. Any one of four rails failing blocks progress.

- **5a. VDDIO_SP5_A0 PG never asserts**
- **5b. VDDCR_CPU0 PG never asserts** — these rails may require Hubris to enable via PMBus; if PMBus configuration is missing or wrong, the VR never turns on
- **5c. VDDCR_CPU1 PG never asserts** — same; also depends on SP5 VID (voltage ID) being valid
- **5d. VDDCR_SOC PG never asserts** — same PMBus dependency

**Registers to check:**

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_raw_status` | `hw_sm[7:0]` | `0x0a` (GROUP_C_PG_AND_WAIT) | Confirms stuck in this state |
| `rail_enables` | `vddio_sp5` (bit 6), `vddcr_cpu1` (bit 7), `vddcr_cpu0` (bit 8), `vddcr_soc` (bit 9) | All `1` | Any `0` → enable not driven (PMBus VR not configured?) |
| `rail_pgs` | `vddio_sp5` (bit 6) | `1` | `0` → VDDIO not good (fault 5a) |
| `rail_pgs` | `vddcr_cpu0` (bit 8) | `1` | `0` → CPU0 VR not good (fault 5b) |
| `rail_pgs` | `vddcr_cpu1` (bit 7) | `1` | `0` → CPU1 VR not good (fault 5c) |
| `rail_pgs` | `vddcr_soc` (bit 9) | `1` | `0` → SOC VR not good (fault 5d) |
| `rail_pgs_max_hold` | Same bits as above | All `1` | Bit `1` in max_hold but `0` in live → intermittent PG |
| `IFR` | `pwr_cont1_to_fpga1_alert` (bit 21) | `0` | `1` → alert from VR controller 1 (VDDCR_CPU0, VDDCR_SOC) |
| `IFR` | `pwr_cont2_to_fpga1_alert` (bit 22) | `0` | `1` → alert from VR controller 2 (VDDCR_CPU1, VDDIO_SP5) |

## 6. Stuck in WAIT_PWROK (SP5 doesn't acknowledge power good)

Requires `pwr_ok` from SP5 (or `ignore_sp5`).

- **6a. SP5 doesn't assert PWR_OK** — internal SP5 checks failing (e.g., its own PLL lock, internal rail checks), SP5 silicon defect, bad SP5 seating
- **6b. Signal integrity issue on PWR_OK line** — open trace, poor solder joint, synchronizer not resolving

**Registers to check:**

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_raw_status` | `hw_sm[7:0]` | `0x0c` (WAIT_PWROK) | Confirms stuck in this state |
| `sp5_readbacks` | `pwr_ok` (bit 3) | `1` | `0` → SP5 not asserting PWR_OK |
| `sp5_readbacks` | `pwr_good` (bit 8) | `1` | `0` → FPGA not driving PWR_GOOD to SP5 (sequencer bug) |
| `rail_pgs` | All Group A/B/C bits (bits 2–9) | All `1` | Any `0` → rail dropped, SP5 may be refusing PWR_OK |
| `debug_enables` | `ignore_sp5` (bit 0) | `1` for bench | If bench-testing without SP5, set this to bypass |

## 7. Stuck in WAIT_RESET_L_RELEASE (SP5 holds reset)

Requires `reset_l` deasserted from SP5 (or `ignore_sp5`).

- **7a. SP5 holds RESET_L low** — SP5 internal initialization not completing, microcode/PSP boot failure, SPIROM issues
- **7b. Physical fault on RESET_L line**

**Registers to check:**

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_raw_status` | `hw_sm[7:0]` | `0x0d` (WAIT_RESET_L_RELEASE) | Confirms stuck in this state |
| `sp5_readbacks` | `reset_l` (bit 2) | `1` (deasserted) | `0` → SP5 holding reset low |
| `sp5_readbacks` | `pwr_ok` (bit 3) | `1` | `0` → SP5 dropped PWR_OK (regression to fault 6) |
| `debug_enables` | `ignore_sp5` (bit 0) | `1` for bench | If bench-testing without SP5, set this to bypass |

## 8. Global fault: MAPO (rail power-good loss after enablement)

Active from any state after IDLE. Forces immediate return to IDLE with `faulted=1`. Monitored via `*_expected` flags, which are set progressively as groups come up.

- **8a. Group A MAPO** (monitored from GROUP_A_PG_AND_WAIT onward)
  - V1P5_RTC drops PG — regulator overcurrent, thermal shutdown, input brownout
  - V3P3_SP5_A1 drops PG
  - V1P8_SP5_A1 drops PG

- **8b. Group B MAPO** (monitored from GROUP_B_PG_AND_WAIT onward)
  - V1P1_SP5 drops PG — load spike from SP5, regulator thermal, input droop

- **8c. Group C MAPO** (monitored from GROUP_C_PG_AND_WAIT onward)
  - VDDIO_SP5_A0, VDDCR_CPU0, VDDCR_CPU1, or VDDCR_SOC drops PG
  - PMBus VR commanded off externally (e.g., errant Hubris command)

- **8d. `upstream_ok` deasserts** — upstream conditions (fans, thermals, HSCs) lost at any point during sequencing

**Registers to check:**

After a MAPO, the state machine returns to IDLE with the FAULTED API status. The key is correlating the sticky IFR flag with `rail_pgs_max_hold` to identify which rail came up then dropped.

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_api_status` | `a0_sm[7:0]` | `0x0b` (FAULTED) | Confirms a fault occurred (vs. normal IDLE) |
| `seq_raw_status` | `hw_sm[7:0]` | `0x00` (IDLE) | State machine returned to IDLE after MAPO |
| `IFR` | `a0mapo` (bit 3) | `0` | `1` → A0-domain MAPO occurred (sticky, W1C) |
| `rail_pgs` | All bits | All previously-enabled rails `1` | Whichever bit is `0` is the rail that dropped |
| `rail_pgs_max_hold` | All bits | Matches `rail_enables` | Bit `1` in max_hold but `0` in live `rail_pgs` → that rail came good then dropped (the MAPO culprit) |
| `rail_enables` | All bits | Reflects the group that was reached | Shows how far sequencing got before the fault |
| `early_power_rdbks` | `fan_hsc_*_pg` (bits 1–3) | All `1` | Any `0` → fan HSC lost, caused `upstream_ok` deassert (fault 8d) |
| `IFR` | `pwr_cont1_to_fpga1_alert` (bit 21) | `0` | `1` → VR controller 1 alert (VDDCR_CPU0/SOC fault) |
| `IFR` | `pwr_cont2_to_fpga1_alert` (bit 22) | `0` | `1` → VR controller 2 alert (VDDCR_CPU1/VDDIO fault) |
| `IFR` | `pwr_cont3_to_fpga1_alert` (bit 23) | `0` | `1` → VR controller 3 alert (V1P1_SP5/V1P8_SP5/V3P3_SP5 fault) |

## 9. Global fault: Software disable during sequencing

Active from any non-IDLE state when `sw_enable=0 AND downstream_idle=1`.

- **9a. Software clears `a0_en`** — Hubris decides to abort (e.g., CPU not detected, wrong CPU type)
- **9b. Ignition commands power-off** — system-level power management overrides local enable

**Registers to check:**

| Register | Field | Expected (healthy) | Indicates fault when |
|---|---|---|---|
| `seq_api_status` | `a0_sm[7:0]` | `0x0a` (DISABLING) or `0x00` (IDLE) | DISABLING during teardown, IDLE once complete |
| `seq_raw_status` | `hw_sm[7:0]` | `0x0f` (SAFE_DISABLE) or `0x00` (IDLE) | Shows the disable path was taken (not MAPO) |
| `power_ctrl` | `a0_en` (bit 0) | `0` | Confirms software cleared the enable |
| `IFR` | `a0mapo` (bit 3) | `0` | `0` distinguishes a software disable from a MAPO fault |

## 10. Notes on observability

The design provides several diagnostic registers for triaging which fault tree branch is active:

| Register | Purpose |
|---|---|
| `seq_raw_status` | Exact FSM state — reveals which state is stuck |
| `seq_api_status` | Coarser state for Hubris consumption |
| `rail_pgs` | Live PG status of every rail — identifies which rail is blocking |
| `rail_pgs_max_hold` | Sticky PG bits — shows if a rail ever came good then dropped |
| `rail_enables` | Confirms enables are being driven |
| `sp5_readbacks` | Live SLP_S3_L, SLP_S5_L, PWR_OK, RESET_L — diagnoses SP5 handshake stalls |
| `IFR` (interrupt flags) | MAPO, THERMTRIP, SMERR flags — identifies fault class |
| `debug_enables` | `ignore_sp5` bit — allows bypassing SP5 handshakes for bench debug |
