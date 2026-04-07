---- MODULE EspiUartChannel ----
(*
 * Formal model of the eSPI virtual UART channel.
 *
 * Scope:
 *   - uart_channel_top: RX/TX FIFOs, orphan timer FSM, drain FSM, status signals
 *   - command_processor: PUT path writing to RX FIFO (UART-relevant states)
 *   - response_processor: GET path reading from TX FIFO, with header phase modeled
 *   - Host environment: protocol-compliant or unrestricted
 *   - SP UART environment: non-deterministic producer/consumer
 *
 * CDC modeling:
 *   Both FIFOs are dcfifo_xpm (dual-clock). Counters have directional staleness:
 *     - Write-domain counter (rx_wusedwds): can OVER-report by CDC_LAG
 *     - Read-domain counter (tx_rusedwds): can UNDER-report by CDC_LAG
 *   Set EXTRA_LAG > 0 to model additional pipeline delay or symmetric staleness.
 *
 * Concurrent operation modeling:
 *   RTL processes evaluate simultaneously on each clock edge. Composite actions
 *   model same-cycle read+write on a single FIFO (CmdWriteAndSpRead,
 *   RespReadAndSpWrite). The wfull/rempty flags are registered outputs from the
 *   XPM FIFO, so they reflect the PREVIOUS cycle's state — a write is blocked
 *   if the FIFO WAS full, even if a concurrent read frees a slot.
 *
 * Response processor phase modeling:
 *   The response processor goes through RESPONSE_CODE → RESPONSE_OOB_HEADER
 *   before latching the payload length. This takes ~3 clock cycles during which
 *   tx_rusedwds can change (SP writes, counter sync). The GET_PRELATCH phase
 *   models this gap: other actions can interleave before the length is latched.
 *
 * Zero-length GET edge case:
 *   In response_processor.vhd, RESPONSE_OOB_HEADER latches payload_cnt as
 *   (length - 1). If length = 0 (possible when tx_rusedwds is stale-low),
 *   payload_cnt underflows to 4095 (unsigned wrap). The NoPayloadUnderflow
 *   property checks for this condition.
 *)
EXTENDS Integers, Sequences, FiniteSets

\* ====================================================================
\* CONSTANTS
\* ====================================================================
CONSTANTS
    FIFO_DEPTH,      \* Actual depth of both FIFOs (real: 4096, model: 3-4)
    MAX_MSG_SIZE,    \* Threshold for pc_free (real: 64)
    HOLD_THRESH,     \* Orphan timer byte-count threshold (real: 32)
    MAX_PAYLOAD,     \* Max UART bytes per eSPI response (real: 61)
    CDC_LAG,         \* Asymmetric CDC synchronizer lag (real: 2-3)
    EXTRA_LAG,       \* Symmetric additional lag for pipeline delay modeling
    HDR_CYCLES,      \* Cycles between GET cmd parse and length latch (real: ~3)
    DataVal          \* Set of byte values (real: 0..255, model: {1,2})

ASSUME FIFO_DEPTH > 0
ASSUME MAX_MSG_SIZE > 0 /\ MAX_MSG_SIZE <= FIFO_DEPTH
ASSUME MAX_PAYLOAD > 0
ASSUME CDC_LAG >= 0
ASSUME EXTRA_LAG >= 0
ASSUME HDR_CYCLES >= 0

\* ====================================================================
\* VARIABLES
\* ====================================================================
VARIABLES
    rx_fifo,             \* Seq(DataVal): RX FIFO contents (host -> SP)
    rx_wusedwds,         \* 0..FIFO_DEPTH: write-domain used word count (stale)
    tx_fifo,             \* Seq(DataVal): TX FIFO contents (SP -> host)
    tx_rusedwds,         \* 0..FIFO_DEPTH: read-domain used word count (stale)
    orphan_state,        \* "MASKED" | "NOT_MASKED"
    timer_state,         \* "IDLE" | "COUNTING" | "EXPIRED"
    bleeding,            \* BOOLEAN: post-espi_reset FIFO drain active
    espi_phase,          \* Transaction phase (see below)
    cmd_payload,         \* Seq(DataVal): remaining bytes for PUT
    resp_remaining,      \* 0..MAX_PAYLOAD: remaining bytes for GET payload
    prelatch_ticks,      \* 0..HDR_CYCLES: header cycles remaining before length latch
    host_seen_pc_free,   \* BOOLEAN: pc_free from last response
    host_seen_oob_avail, \* BOOLEAN: oob_avail from last response
    has_responded,       \* BOOLEAN: ever sent a response
    last_sent_status,    \* Record: status from last response
    stale_data_sent,     \* BOOLEAN (ghost): stale FIFO data sent to host
    any_dropped,         \* BOOLEAN (ghost): byte silently dropped on PUT
    zero_length_get      \* BOOLEAN (ghost): GET latched 0-length (RTL underflows)

\* eSPI transaction phases:
\*   "IDLE"         - no transaction in progress
\*   "PUTTING"      - PUT data bytes being written to RX FIFO
\*   "PUT_RESP"     - PUT response phase (resp code + status + CRC sent to host)
\*   "GET_PRELATCH" - GET command parsed, response header being sent, length NOT YET latched
\*   "GETTING"      - GET payload bytes being read from TX FIFO

vars == <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
          orphan_state, timer_state, bleeding,
          espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
          host_seen_pc_free, host_seen_oob_avail, has_responded, last_sent_status,
          stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* HELPERS
\* ====================================================================
Max(a, b) == IF a > b THEN a ELSE b
Min(a, b) == IF a < b THEN a ELSE b

\* CDC-aware stale counter ranges.
\* Write-domain: over-reports by CDC_LAG, ±EXTRA_LAG.
\* Read-domain: under-reports by CDC_LAG, ±EXTRA_LAG.
RxWusedRange(actual) ==
    Max(0, actual - EXTRA_LAG) .. Min(FIFO_DEPTH, actual + CDC_LAG + EXTRA_LAG)
TxRusedRange(actual) ==
    Max(0, actual - CDC_LAG - EXTRA_LAG) .. Min(FIFO_DEPTH, actual + EXTRA_LAG)

\* Non-empty sequences over S with length 1..n.
SeqMaxLen(S, n) == UNION {[1..i -> S] : i \in 1..n}

\* ====================================================================
\* DERIVED SIGNALS (combinational in RTL)
\* ====================================================================

\* RTL (uart_channel_top.vhd:96): pc_free when remaining capacity >= MAX_MSG_SIZE.
PcFree == (FIFO_DEPTH - rx_wusedwds) >= MAX_MSG_SIZE
OobFree == PcFree
OobAvail == orphan_state = "NOT_MASKED"
LiveStatus == [pc_free |-> PcFree, oob_avail |-> OobAvail]
AlertNeeded == has_responded /\ LiveStatus /= last_sent_status

\* ====================================================================
\* TYPE INVARIANT
\* ====================================================================
TypeOK ==
    /\ rx_fifo \in Seq(DataVal) /\ Len(rx_fifo) <= FIFO_DEPTH
    /\ rx_wusedwds \in 0..FIFO_DEPTH
    /\ tx_fifo \in Seq(DataVal) /\ Len(tx_fifo) <= FIFO_DEPTH
    /\ tx_rusedwds \in 0..FIFO_DEPTH
    /\ orphan_state \in {"MASKED", "NOT_MASKED"}
    /\ timer_state \in {"IDLE", "COUNTING", "EXPIRED"}
    /\ bleeding \in BOOLEAN
    /\ espi_phase \in {"IDLE", "PUTTING", "PUT_RESP", "GET_PRELATCH", "GETTING"}
    /\ cmd_payload \in Seq(DataVal)
    /\ resp_remaining \in 0..MAX_PAYLOAD
    /\ prelatch_ticks \in 0..HDR_CYCLES
    /\ host_seen_pc_free \in BOOLEAN
    /\ host_seen_oob_avail \in BOOLEAN
    /\ has_responded \in BOOLEAN
    /\ last_sent_status \in [pc_free: BOOLEAN, oob_avail: BOOLEAN]
    /\ stale_data_sent \in BOOLEAN
    /\ any_dropped \in BOOLEAN
    /\ zero_length_get \in BOOLEAN

\* ====================================================================
\* INITIAL STATE
\* ====================================================================
Init ==
    /\ rx_fifo = <<>>
    /\ rx_wusedwds = 0
    /\ tx_fifo = <<>>
    /\ tx_rusedwds = 0
    /\ orphan_state = "MASKED"
    /\ timer_state = "IDLE"
    /\ bleeding = FALSE
    /\ espi_phase = "IDLE"
    /\ cmd_payload = <<>>
    /\ resp_remaining = 0
    /\ prelatch_ticks = 0
    /\ host_seen_pc_free = FALSE
    /\ host_seen_oob_avail = FALSE
    /\ has_responded = FALSE
    /\ last_sent_status = [pc_free |-> FALSE, oob_avail |-> FALSE]
    /\ stale_data_sent = FALSE
    /\ any_dropped = FALSE
    /\ zero_length_get = FALSE

\* ====================================================================
\* ACTIONS
\* ====================================================================

\* Status capture operator (used by response-completing actions).
CaptureStatus ==
    /\ host_seen_pc_free' = PcFree
    /\ host_seen_oob_avail' = OobAvail
    /\ has_responded' = TRUE
    /\ last_sent_status' = LiveStatus

\* ====================================================================
\* HOST PUT TRANSACTION
\* ====================================================================

\* Host initiates PUT (protocol-compliant: checks pc_free).
HostStartsPut(payload) ==
    /\ espi_phase = "IDLE"
    /\ ~bleeding
    /\ host_seen_pc_free
    /\ espi_phase' = "PUTTING"
    /\ cmd_payload' = payload
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* Host initiates PUT without checking pc_free (non-compliant).
HostForcePut(payload) ==
    /\ espi_phase = "IDLE"
    /\ ~bleeding
    /\ espi_phase' = "PUTTING"
    /\ cmd_payload' = payload
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* Command processor writes one byte to RX FIFO.
\* RTL: data_from_host.ready = '1' always; write gated by NOT rx_wfull.
\* If FIFO full: byte consumed but not written (silently dropped).
CmdWriteByte ==
    /\ espi_phase = "PUTTING"
    /\ cmd_payload /= <<>>
    /\ LET byte == Head(cmd_payload)
           full == Len(rx_fifo) >= FIFO_DEPTH
           new_rx == IF ~full THEN Append(rx_fifo, byte) ELSE rx_fifo
       IN
       /\ rx_fifo' = new_rx
       /\ rx_wusedwds' \in RxWusedRange(Len(new_rx))
       /\ any_dropped' = IF full THEN TRUE ELSE any_dropped
    /\ cmd_payload' = Tail(cmd_payload)
    /\ UNCHANGED <<tx_fifo, tx_rusedwds, orphan_state, timer_state, bleeding,
                   espi_phase, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail,
                   has_responded, last_sent_status, stale_data_sent, zero_length_get>>

\* --- COMPOSITE: Command processor writes RX FIFO while SP reads RX FIFO ---
\* Same clock edge: both happen simultaneously.
\* RTL: rx_wfull is a registered output reflecting PREVIOUS state.
\* So write is blocked if FIFO WAS full, even if the concurrent read frees a slot.
CmdWriteAndSpRead ==
    /\ espi_phase = "PUTTING"
    /\ cmd_payload /= <<>>
    /\ Len(rx_fifo) > 0          \* SP can read (not empty)
    /\ ~bleeding                  \* SP blocked during drain
    /\ LET byte == Head(cmd_payload)
           \* wfull checked against CURRENT state (before read takes effect)
           full == Len(rx_fifo) >= FIFO_DEPTH
           after_read == Tail(rx_fifo)
           new_rx == IF ~full THEN Append(after_read, byte) ELSE after_read
       IN
       /\ rx_fifo' = new_rx
       /\ rx_wusedwds' \in RxWusedRange(Len(new_rx))
       /\ any_dropped' = IF full THEN TRUE ELSE any_dropped
    /\ cmd_payload' = Tail(cmd_payload)
    /\ UNCHANGED <<tx_fifo, tx_rusedwds, orphan_state, timer_state, bleeding,
                   espi_phase, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail,
                   has_responded, last_sent_status, stale_data_sent, zero_length_get>>

\* PUT data phase completes. Enter response phase.
\* RTL: response processor goes through RESPONSE_CODE → STATUS → CRC.
\* Status is latched during STATUS state, a few cycles after data ends.
CmdDataDone ==
    /\ espi_phase = "PUTTING"
    /\ cmd_payload = <<>>
    /\ espi_phase' = "PUT_RESP"
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail,
                   has_responded, last_sent_status,
                   stale_data_sent, any_dropped, zero_length_get>>

\* PUT response completes. Status captured and sent to host.
\* RTL: status latched during STATUS state of response_processor.
\* Between CmdDataDone and here, SP can read from RX FIFO (changing PcFree).
PutRespDone ==
    /\ espi_phase = "PUT_RESP"
    /\ espi_phase' = "IDLE"
    /\ CaptureStatus
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   cmd_payload, resp_remaining, prelatch_ticks,
                   stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* HOST GET TRANSACTION
\* ====================================================================

\* Host initiates GET (protocol-compliant: checks oob_avail).
\* Enters GET_PRELATCH: the response processor sends RESPONSE_CODE then header
\* bytes. The payload length is NOT YET latched from tx_rusedwds.
\*
\* RTL cycle sequence:
\*   cmd parse → RESPONSE_CODE (1 cycle) → RESPONSE_OOB_HEADER idx=0 (LATCH)
\* That's ~HDR_CYCLES between command parse and the latch.
HostStartsGet ==
    /\ espi_phase = "IDLE"
    /\ ~bleeding
    /\ host_seen_oob_avail
    /\ espi_phase' = "GET_PRELATCH"
    /\ prelatch_ticks' = HDR_CYCLES
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   cmd_payload, resp_remaining,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* Host initiates GET without checking oob_avail (non-compliant).
HostForceGet ==
    /\ espi_phase = "IDLE"
    /\ ~bleeding
    /\ espi_phase' = "GET_PRELATCH"
    /\ prelatch_ticks' = HDR_CYCLES
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   cmd_payload, resp_remaining,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* One header cycle passes during GET_PRELATCH.
\* During this phase, the response processor is sending header bytes.
\* Other actions (SpWritesTxByte, CounterSync, OrphanTimer) can interleave,
\* changing tx_rusedwds before the length is latched.
RespPrelatchTick ==
    /\ espi_phase = "GET_PRELATCH"
    /\ prelatch_ticks > 0
    /\ prelatch_ticks' = prelatch_ticks - 1
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   espi_phase, cmd_payload, resp_remaining,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* Length latch: response processor reads tx_rusedwds at RESPONSE_OOB_HEADER idx=0.
\* RTL (response_processor.vhd:268):
\*   v.payload_cnt := response_chan_mux.length - 1
\* where response_chan_mux.length = resize(minimum(avail_bytes, 61), 12)
\* and avail_bytes = tx_rusedwds.
RespLatchLength ==
    /\ espi_phase = "GET_PRELATCH"
    /\ prelatch_ticks = 0
    /\ LET latched == Min(tx_rusedwds, MAX_PAYLOAD) IN
       /\ espi_phase' = "GETTING"
       /\ resp_remaining' = latched
       /\ zero_length_get' = IF latched = 0 THEN TRUE ELSE zero_length_get
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   cmd_payload, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped>>

\* Response processor reads one byte from TX FIFO.
\* RTL: cur_valid = '1' always; FIFO rdreq gated by st.valid (not empty).
\* If FIFO empty: stale showahead data sent, FIFO not advanced.
RespReadByte ==
    /\ espi_phase = "GETTING"
    /\ resp_remaining > 0
    /\ LET has_data == Len(tx_fifo) > 0
           new_tx == IF has_data THEN Tail(tx_fifo) ELSE tx_fifo
       IN
       /\ tx_fifo' = new_tx
       /\ tx_rusedwds' \in TxRusedRange(Len(new_tx))
       /\ stale_data_sent' = IF has_data THEN stale_data_sent ELSE TRUE
    /\ resp_remaining' = resp_remaining - 1
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, orphan_state, timer_state, bleeding,
                   espi_phase, cmd_payload, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail,
                   has_responded, last_sent_status, any_dropped, zero_length_get>>

\* --- COMPOSITE: Response processor reads TX FIFO while SP writes TX FIFO ---
\* Same clock edge: both happen simultaneously.
\* RTL: tx_wfull is registered, reflects PREVIOUS state.
\* Write blocked if FIFO WAS full (even if concurrent read frees a slot).
\* Read blocked if FIFO WAS empty (even if concurrent write adds an entry).
\*
\* Key race: if FIFO was empty, SP write adds data but response processor
\* sees tx_rempty='1' from previous state → sends stale data. The new byte
\* sits unread in the FIFO. This race is invisible to the sequential model.
RespReadAndSpWrite(d) ==
    /\ espi_phase = "GETTING"
    /\ resp_remaining > 0
    /\ ~bleeding
    /\ LET \* Check flags against CURRENT state (before operations)
           tx_full == Len(tx_fifo) >= FIFO_DEPTH
           tx_empty == Len(tx_fifo) = 0
           read_ok == ~tx_empty
           write_ok == ~tx_full
           \* Apply both operations
           after_read == IF read_ok THEN Tail(tx_fifo) ELSE tx_fifo
           new_tx == IF write_ok THEN Append(after_read, d) ELSE after_read
       IN
       /\ tx_fifo' = new_tx
       /\ tx_rusedwds' \in TxRusedRange(Len(new_tx))
       /\ stale_data_sent' = IF read_ok THEN stale_data_sent ELSE TRUE
    /\ resp_remaining' = resp_remaining - 1
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, orphan_state, timer_state, bleeding,
                   espi_phase, cmd_payload, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail,
                   has_responded, last_sent_status, any_dropped, zero_length_get>>

\* GET payload completes. Status captured and sent.
RespFinishes ==
    /\ espi_phase = "GETTING"
    /\ resp_remaining = 0
    /\ espi_phase' = "IDLE"
    /\ CaptureStatus
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   cmd_payload, resp_remaining, prelatch_ticks,
                   stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* HOST GET_STATUS
\* ====================================================================
HostGetsStatus ==
    /\ espi_phase = "IDLE"
    /\ ~bleeding
    /\ CaptureStatus
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, timer_state, bleeding,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* SP UART SIDE
\* ====================================================================

\* SP reads one byte from RX FIFO.
SpReadsRxByte ==
    /\ Len(rx_fifo) > 0
    /\ ~bleeding
    /\ rx_fifo' = Tail(rx_fifo)
    /\ rx_wusedwds' \in RxWusedRange(Len(rx_fifo) - 1)
    /\ UNCHANGED <<tx_fifo, tx_rusedwds, orphan_state, timer_state, bleeding,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* SP writes one byte to TX FIFO.
SpWritesTxByte(d) ==
    /\ Len(tx_fifo) < FIFO_DEPTH
    /\ ~bleeding
    /\ tx_fifo' = Append(tx_fifo, d)
    /\ tx_rusedwds' \in TxRusedRange(Len(tx_fifo) + 1)
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, orphan_state, timer_state, bleeding,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* ORPHAN TIMER FSM (uart_channel_top.vhd:119-151)
\* ====================================================================

\* Timer advances: IDLE -> COUNTING -> EXPIRED.
\* Uses tx_rusedwds (stale) for threshold, tx_rempty (exact) for empty check.
OrphanTimerTick ==
    /\ orphan_state = "MASKED"
    /\ Len(tx_fifo) > 0
    /\ tx_rusedwds < HOLD_THRESH
    /\ \/ timer_state = "IDLE"    /\ timer_state' = "COUNTING"
       \/ timer_state = "COUNTING" /\ timer_state' = "EXPIRED"
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, bleeding,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* MASKED -> NOT_MASKED when above threshold or timer expired.
OrphanUnmask ==
    /\ orphan_state = "MASKED"
    /\ Len(tx_fifo) > 0
    /\ \/ tx_rusedwds >= HOLD_THRESH
       \/ timer_state = "EXPIRED"
    /\ orphan_state' = "NOT_MASKED"
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   timer_state, bleeding,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* NOT_MASKED -> MASKED when FIFO empties.
OrphanMask ==
    /\ orphan_state = "NOT_MASKED"
    /\ Len(tx_fifo) = 0
    /\ orphan_state' = "MASKED"
    /\ timer_state' = "IDLE"
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   bleeding,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* Timer resets when FIFO empties while MASKED.
OrphanTimerReset ==
    /\ orphan_state = "MASKED"
    /\ Len(tx_fifo) = 0
    /\ timer_state /= "IDLE"
    /\ timer_state' = "IDLE"
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   orphan_state, bleeding,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* DRAIN FSM (uart_channel_top.vhd:195-214)
\* ====================================================================
DrainStep ==
    /\ bleeding
    /\ LET new_rx == IF Len(rx_fifo) > 0 THEN Tail(rx_fifo) ELSE rx_fifo
           new_tx == IF Len(tx_fifo) > 0 THEN Tail(tx_fifo) ELSE tx_fifo
       IN
       /\ rx_fifo' = new_rx
       /\ tx_fifo' = new_tx
       /\ rx_wusedwds' \in RxWusedRange(Len(new_rx))
       /\ tx_rusedwds' \in TxRusedRange(Len(new_tx))
       /\ bleeding' = (Len(new_rx) > 0 \/ Len(new_tx) > 0)
    /\ UNCHANGED <<orphan_state, timer_state,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* ESPI RESET
\* ====================================================================
EspiReset ==
    /\ espi_phase = "IDLE"
    /\ ~bleeding
    /\ bleeding' = TRUE
    /\ orphan_state' = "MASKED"
    /\ timer_state' = "IDLE"
    /\ espi_phase' = "IDLE"
    /\ cmd_payload' = <<>>
    /\ resp_remaining' = 0
    /\ prelatch_ticks' = 0
    /\ has_responded' = FALSE
    /\ last_sent_status' = [pc_free |-> FALSE, oob_avail |-> FALSE]
    /\ host_seen_pc_free' = FALSE
    /\ host_seen_oob_avail' = FALSE
    /\ UNCHANGED <<rx_fifo, rx_wusedwds, tx_fifo, tx_rusedwds,
                   stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* STALE COUNTER SYNCHRONIZATION
\* ====================================================================
CounterSync ==
    /\ \/ /\ rx_wusedwds /= Len(rx_fifo)
          /\ rx_wusedwds' \in RxWusedRange(Len(rx_fifo))
          /\ UNCHANGED tx_rusedwds
       \/ /\ tx_rusedwds /= Len(tx_fifo)
          /\ tx_rusedwds' \in TxRusedRange(Len(tx_fifo))
          /\ UNCHANGED rx_wusedwds
    /\ UNCHANGED <<rx_fifo, tx_fifo, orphan_state, timer_state, bleeding,
                   espi_phase, cmd_payload, resp_remaining, prelatch_ticks,
                   host_seen_pc_free, host_seen_oob_avail, has_responded,
                   last_sent_status, stale_data_sent, any_dropped, zero_length_get>>

\* ====================================================================
\* NEXT-STATE RELATIONS
\* ====================================================================

NextCompliant ==
    \/ \E p \in SeqMaxLen(DataVal, MAX_PAYLOAD) : HostStartsPut(p)
    \/ CmdWriteByte
    \/ CmdWriteAndSpRead
    \/ CmdDataDone
    \/ PutRespDone
    \/ HostStartsGet
    \/ RespPrelatchTick
    \/ RespLatchLength
    \/ RespReadByte
    \/ \E d \in DataVal : RespReadAndSpWrite(d)
    \/ RespFinishes
    \/ HostGetsStatus
    \/ SpReadsRxByte
    \/ \E d \in DataVal : SpWritesTxByte(d)
    \/ OrphanTimerTick
    \/ OrphanUnmask
    \/ OrphanMask
    \/ OrphanTimerReset
    \/ DrainStep
    \/ EspiReset
    \/ CounterSync

NextUnrestricted ==
    \/ NextCompliant
    \/ \E p \in SeqMaxLen(DataVal, MAX_PAYLOAD) : HostForcePut(p)
    \/ HostForceGet

\* ====================================================================
\* SPECIFICATIONS
\* ====================================================================
SpecCompliant    == Init /\ [][NextCompliant]_vars    /\ WF_vars(NextCompliant)
SpecUnrestricted == Init /\ [][NextUnrestricted]_vars /\ WF_vars(NextUnrestricted)

\* ====================================================================
\* SAFETY PROPERTIES
\* ====================================================================

\* P1: No stale FIFO data sent in a response.
NoStaleData == ~stale_data_sent

\* P2: No bytes silently dropped during PUT.
NoDroppedBytes == ~any_dropped

\* P3: No zero-length GET (causes payload_cnt underflow to 4095 in RTL).
NoPayloadUnderflow == ~zero_length_get

\* P4: FIFO depth never physically exceeded.
FifoDepthBound == Len(rx_fifo) <= FIFO_DEPTH /\ Len(tx_fifo) <= FIFO_DEPTH

\* P5: Stale counters within modeled ranges.
StaleCounterBound ==
    /\ rx_wusedwds \in RxWusedRange(Len(rx_fifo))
    /\ tx_rusedwds \in TxRusedRange(Len(tx_fifo))

\* ====================================================================
\* LIVENESS PROPERTIES
\* ====================================================================
DrainCompletes == bleeding ~> ~bleeding
DataEventuallyAvailable == Len(tx_fifo) > 0 ~> host_seen_oob_avail

====
