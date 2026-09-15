-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- This block provides an FMC target interface from the STM32H7's
-- local bus (synchronous multiplexed PSRAM mode, RM0433 figures 115/116),
-- crosses clock domains into the FPGA's core logic clock domain, and
-- issues AXI transactions.
--
-- Pacing contract with the SP, proven on hardware and also encoded in the
-- simulation model: the wait line is held asserted
-- by default and released under FSM control; after the SP samples the wait
-- line released at rising edge N, its current data beat is valid on the
-- bus at edge N+1, and each further release-sampled edge advances one
-- beat. Reads therefore present data one full cycle before the release is
-- sampled, and the SP samples read data on the same edge it samples the
-- released wait.
--
-- All FMC inputs are captured in dedicated per-pin registers clocked by
-- fmc_capture_clk before the FSM sees them, so the FSM runs one cycle
-- behind the bus. The interface is entirely NWAIT-paced, so that delay is
-- absorbed by the pacing (one extra stall cycle per transaction). On
-- boards with the FMC MMCM the capture clock is a later-phased sibling of
-- fmc_clk, which is what gives the input pins setup margin at 10 ns;
-- boards without an MMCM tie both clock ports to the same clock and get
-- identical cycle behavior.

-- ES0491 FMC Errata:
-- Dummy read cycles inserted when reading synchronous memories
-- Description
-- When performing a burst read access from a synchronous memory, two dummy read accesses are performed at
-- the end of the burst cycle whatever the type of burst access.
-- The extra data values read are not used by the FMC and there is no functional failure.
-- Workaround
-- None
-- (The dummy cycles land while this FSM is back in idle with the wait line
-- asserted and NADV high, so they cannot start a new transaction.)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.stm32h7_fmc_target_pkg.all;
use work.axil26x32_pkg.all;

entity stm32h7_fmc_target is
    generic (
        -- Bound on how long the SP's bus may be stalled by the wait line, in
        -- fmc_clk cycles. An AHB stall is unrecoverable on the SP side, so a
        -- wedged AXI responder is converted into poisoned read data (0xFFFF
        -- beats) or a swallowed write, plus a bump of timeout_count, instead
        -- of a hung SP.
        timeout_cycles : positive := 4096;
        -- Re-inserts the dead cycle between read beats (the pre-streaming
        -- cadence), restoring a 2-cycle data-out window for a board that
        -- cannot close single-cycle output timing. The data-out multicycle
        -- constraints must match this setting.
        extra_beat_setup : boolean := false
    );
    port (
        -- Interface to the STM32H7's FMC periph
        chip_reset : in    std_logic;
        -- fmc_clk from STM32's clock generator (deskewed/phase-shifted on
        -- boards with the FMC MMCM); clocks the FSM and all outputs
        fmc_clk : in    std_logic;
        -- clock for the input capture registers only. Tie to fmc_clk when
        -- there is no MMCM; with one, the later-phased sibling output.
        fmc_capture_clk : in    std_logic;
        -- non-multiplexed upper address bits from STM32
        a : in    std_logic_vector(24 downto 16);
        -- multiplexed lower address bits/databits to/from STM32
        addr_data_in : in    std_logic_vector(15 downto 0);
        data_out     : out   std_logic_vector(15 downto 0);
        -- Tristate control in OBUFT T polarity: '1' releases the pin, '0'
        -- drives it. One bit per pin, all driven identically, registered with
        -- no logic between flop and T input -- an active-high enable infers
        -- an inverter LUT there, which adds ~1.5 ns and blocks IOB packing.
        data_out_hiz : out   std_logic_vector(15 downto 0);
        -- active-low chip selects
        ne : in    std_logic_vector(3 downto 0);
        -- active-low output enable
        noe : in    std_logic;
        -- active-low write enable
        nwe : in    std_logic;
        -- active-low address latch for address phase
        nl : in    std_logic;
        -- active-low wait to STM32
        nwait : out   std_logic;
        -- Saturating diagnostic counters, sticky until chip_reset.
        timeout_count    : out   std_logic_vector(7 downto 0);
        contention_count : out   std_logic_vector(7 downto 0);
        -- FPGA interface
        aclk    : in    std_logic;
        aresetn : in    std_logic;
        -- AXI requester interface
        axi_if : view axil_controller
    );
end entity;

architecture rtl of stm32h7_fmc_target is

    -- Driven-'1' bits pass, everything else ('0', and any undriven
    -- 'Z'/'X'/'U' from a released bus) becomes '0'. Lets the final write
    -- beat be captured unconditionally: qualifying it on chip select would
    -- race NE's end-of-burst deassert, which is rising-edge timed and lands
    -- within nanoseconds of the capture instant, differently per board.
    function drive_or_zero (
        v : std_logic_vector
    ) return std_logic_vector is
        variable r : std_logic_vector(v'range);
    begin
        for i in v'range loop
            r(i) := '1' when v(i) = '1' else '0';
        end loop;
        return r;
    end;

    attribute mark_debug : string;

    type fmc_state_type is (
        idle,
        dispatch,
        rd_wait_data,
        rd_arm,
        rd_beat0,
        rd_rearm,
        rd_beat1,
        wr_arm,
        wr_arm2,
        wr_beat0,
        wr_beat1,
        timeout_drain
    );

    type   axi_state_type is (
        idle,
        axi_read_init,
        axi_read_wait,
        axi_write_init,
        axi_write_wait
    );
    signal fmc_state : fmc_state_type;
    attribute mark_debug of fmc_state : signal is "TRUE";
    signal axi_state : axi_state_type;
    attribute mark_debug of axi_state       : signal is "TRUE";
    signal txn       : txn_type;
    attribute mark_debug of txn       : signal is "TRUE";

    signal axi_fifo_rd_path_rdata  : std_logic_vector(31 downto 0);
    signal axi_fifo_rd_path_rd_ack : std_logic;
    signal axi_fifo_rd_path_rempty : std_logic;

    signal axi_fifo_wr_path_rdata  : std_logic_vector(31 downto 0);
    signal axi_fifo_wr_path_rempty : std_logic;

    signal axi_fifo_txn_path_write  : std_logic;
    signal axi_fifo_txn_path_rdata  : std_logic_vector(31 downto 0);
    signal axi_fifo_txn_path_rd_ack : std_logic;
    signal axi_fifo_txn_path_rempty : std_logic;
    signal axi_fifo_txn_path_wfull  : std_logic;

    signal axi_addr               : unsigned(31 downto 0);
    attribute mark_debug of axi_addr : signal is "TRUE";
    signal axi_fifo_wr_path_wdata : std_logic_vector(31 downto 0);
    signal axi_fifo_wr_path_write : std_logic;
    signal axi_fifo_wr_path_wfull : std_logic;

    -- One physical flop per pin, so each tristate T can pack into its
    -- IOB; synthesis must not merge the identical registers.
    signal data_out_hiz_int : std_logic_vector(15 downto 0);
    -- IOB rather than keep: both prevent register merging, but keep maps
    -- to a dont_touch that also blocks the pad packing it was meant to
    -- enable.
    attribute IOB : string;
    attribute IOB of data_out_hiz_int : signal is "TRUE";
    -- fmc_clk cycles spent in a state that stalls the SP
    signal timeout_cntr : natural range 0 to timeout_cycles;
    signal timeouts     : unsigned(7 downto 0);
    attribute mark_debug of timeouts : signal is "TRUE";
    -- Both sides driving the muxed bus at once means the two ends disagree
    -- about where in a transaction we are; the count is a tripwire for the
    -- testbench and for ILA debug on hardware.
    signal contentions : unsigned(7 downto 0);
    attribute mark_debug of contentions : signal is "TRUE";
    -- Reads abandoned by timeout still complete on the AXI side eventually;
    -- this many arriving read words belong to nobody and must be discarded
    -- before data is served to a live read.
    signal drop_pending : unsigned(4 downto 0);

    -- Per-pin input capture registers, clocked by fmc_capture_clk. IOB so
    -- they land in the pad's ILOGIC flop: the input timing budget is pin ->
    -- flop with nothing in between.
    -- Deliberately unreset (initial values cover the pre-clock sim window):
    -- they track the live bus whenever the clock runs, so by the time the
    -- FSM leaves reset they already hold real pin state -- and a reset pin
    -- on them would create cross-phase reset recovery paths with only the
    -- inter-phase spacing to deassert in.
    signal ne_q  : std_logic_vector(3 downto 0) := (others => '1');
    signal noe_q : std_logic := '1';
    signal nwe_q : std_logic := '1';
    signal nl_q  : std_logic := '1';
    signal a_q   : std_logic_vector(24 downto 16) := (others => '0');
    signal ad_q  : std_logic_vector(15 downto 0) := (others => '0');
    attribute IOB of ne_q  : signal is "TRUE";
    attribute IOB of noe_q : signal is "TRUE";
    attribute IOB of nwe_q : signal is "TRUE";
    attribute IOB of nl_q  : signal is "TRUE";
    attribute IOB of a_q   : signal is "TRUE";
    attribute IOB of ad_q  : signal is "TRUE";

    alias awready is axi_if.write_address.ready;
    alias wready  is axi_if.write_data.ready;
    alias bvalid  is axi_if.write_response.valid;
    alias arready is axi_if.read_address.ready;
    alias rvalid  is axi_if.read_data.valid;
    alias rdata   is axi_if.read_data.data;

    signal awvalid : std_logic;
    signal awaddr  : std_logic_vector(25 downto 0);
    signal wvalid  : std_logic;
    signal wdata   : std_logic_vector(31 downto 0);
    signal bready  : std_logic;
    signal arvalid : std_logic;
    signal araddr  : std_logic_vector(25 downto 0);
    signal rready  : std_logic;

begin

    axi_if.write_address.valid  <= awvalid;
    axi_if.write_address.addr   <= awaddr;
    axi_if.write_data.valid     <= wvalid;
    axi_if.write_data.strb      <= (others => '1');
    axi_if.write_data.data      <= wdata;
    axi_if.write_response.ready <= bready;
    axi_if.read_address.valid   <= arvalid;
    axi_if.read_address.addr    <= araddr;
    axi_if.read_data.ready      <= rready;

    data_out_hiz     <= data_out_hiz_int;
    timeout_count    <= std_logic_vector(timeouts);
    contention_count <= std_logic_vector(contentions);

    -- Input capture stage: the only logic on fmc_capture_clk.
    input_capture: process(fmc_capture_clk)
    begin
        if rising_edge(fmc_capture_clk) then
            ne_q  <= ne;
            noe_q <= noe;
            nwe_q <= nwe;
            nl_q  <= nl;
            a_q   <= a;
            ad_q  <= addr_data_in;
        end if;
    end process;

    -- State machine dealing with fmc interface
    fmc_if_sm: process(fmc_clk, chip_reset)
        variable chip_selected : boolean;
        -- The tristate control is re-derived from the live control pins
        -- every cycle it could be driving, so a bus desync (SP deasserting
        -- OE/CS under us) releases the bus within one cycle instead of
        -- holding a fight until the FSM notices. hiz_v is in T polarity:
        -- '1' = release.
        variable hiz_v : std_logic;
    begin
        if chip_reset then
            fmc_state               <= idle;
            data_out                <= (others => '0');
            data_out_hiz_int         <= (others => '1'); -- release bus
            nwait                   <= '0';
            txn                     <= ('0', (others => '0'));
            axi_fifo_wr_path_wdata  <= (others => '0');
            axi_fifo_rd_path_rd_ack <= '0';
            axi_fifo_txn_path_write <= '0';
            axi_fifo_wr_path_write  <= '0';
            timeout_cntr            <= 0;
            timeouts                <= (others => '0');
            contentions             <= (others => '0');
            drop_pending            <= (others => '0');
        elsif rising_edge(fmc_clk) then
            -- some variable naming for more legibility
            chip_selected := ne_q(0) = '0';
            hiz_v         := noe_q or ne_q(0);

            -- single-cycle flags, unconditionally cleared
            axi_fifo_rd_path_rd_ack <= '0';
            axi_fifo_txn_path_write <= '0';
            axi_fifo_wr_path_write  <= '0';

            -- The timeout counter runs in every situation that can stall the
            -- SP indefinitely. That includes sitting in idle with chip
            -- select asserted: a miscaptured NADV means we never saw the
            -- transaction start, the SP is stalled on its bus waiting for a
            -- wait release that will never come, and nothing but this
            -- counter can free it. (Normal idle-with-CS dwell -- the address
            -- cycle itself, ES0491 dummy reads -- lasts a handful of cycles,
            -- nowhere near the timeout.)
            if fmc_state = dispatch or fmc_state = rd_wait_data
                or (fmc_state = idle and chip_selected) then
                if timeout_cntr /= timeout_cycles then
                    timeout_cntr <= timeout_cntr + 1;
                end if;
            else
                timeout_cntr <= 0;
            end if;

            -- Contention tripwire: the SP drives the muxed bus during the
            -- address phase (NADV low) and during write data beats (NWE low);
            -- our enable being up in either is a protocol desync.
            if data_out_hiz_int(0) = '0' and (nl_q = '0' or nwe_q = '0') then
                if contentions /= x"FF" then
                    contentions <= contentions + 1;
                end if;
            end if;

            case fmc_state is
                when idle =>
                    nwait           <= '0';
                    data_out_hiz_int <= (others => '1'); -- release bus
                    if drop_pending /= 0 and axi_fifo_rd_path_rempty = '0'
                        and axi_fifo_rd_path_rd_ack = '0' then
                        axi_fifo_rd_path_rd_ack <= '1';
                        drop_pending            <= drop_pending - 1;
                    elsif timeout_cntr = timeout_cycles then
                        -- chip select has been pinned with no transaction
                        -- start observed: we missed one. Free the SP's bus
                        -- and swallow whatever beats it clocks out.
                        if timeouts /= x"FF" then
                            timeouts <= timeouts + 1;
                        end if;
                        data_out  <= x"FFFF";
                        nwait     <= '1';
                        fmc_state <= timeout_drain;
                    elsif chip_selected and nl_q = '0' then
                        -- Bus outputs right-shifted so we shift left here to
                        -- recover byte addrs
                        txn.addr           <= unsigned(a_q & ad_q & "0");
                        txn.read_not_write <= nwe_q;
                        fmc_state          <= dispatch;
                    end if;
                when dispatch =>
                    -- Queue the transaction. Stalling here (the wait line is
                    -- still asserted from idle) is the back-pressure path
                    -- when the AXI side has fallen behind.
                    if not chip_selected then
                        fmc_state <= idle;
                    elsif timeout_cntr = timeout_cycles then
                        -- Nothing queued yet, so nothing is in flight: free
                        -- the SP and swallow/poison its beats.
                        if timeouts /= x"FF" then
                            timeouts <= timeouts + 1;
                        end if;
                        data_out  <= x"FFFF";
                        nwait     <= '1';
                        fmc_state <= timeout_drain;
                    elsif axi_fifo_txn_path_wfull = '0' and
                          (txn.read_not_write = '1' or axi_fifo_wr_path_wfull = '0') then
                        axi_fifo_txn_path_write <= '1';
                        if txn.read_not_write then
                            -- Reads keep the SP waited: the data has to
                            -- round-trip the AXI side before anything can be
                            -- returned.
                            fmc_state <= rd_wait_data;
                        else
                            nwait     <= '1';
                            fmc_state <= wr_arm;
                        end if;
                    end if;
                when rd_wait_data =>
                    if axi_fifo_rd_path_rd_ack = '1' then
                        -- rempty/rdata are one cycle behind a pop; deciding
                        -- anything off them now would serve the word that was
                        -- just discarded
                        null;
                    elsif drop_pending /= 0 then
                        -- Stale words from earlier timed-out reads arrive
                        -- ahead of ours; discard them first.
                        if axi_fifo_rd_path_rempty = '0' then
                            axi_fifo_rd_path_rd_ack <= '1';
                            drop_pending            <= drop_pending - 1;
                        end if;
                    elsif not chip_selected then
                        -- The read was queued on entry to this state, so an
                        -- SP abort here still leaves it in flight and its
                        -- data must be discarded when it lands.
                        if drop_pending /= "11111" then
                            drop_pending <= drop_pending + 1;
                        end if;
                        fmc_state <= idle;
                    elsif timeout_cntr = timeout_cycles then
                        -- The read is in flight; whenever its data lands it
                        -- belongs to nobody.
                        if drop_pending /= "11111" then
                            drop_pending <= drop_pending + 1;
                        end if;
                        if timeouts /= x"FF" then
                            timeouts <= timeouts + 1;
                        end if;
                        data_out        <= x"FFFF";
                        data_out_hiz_int <= (others => hiz_v);
                        nwait           <= '1';
                        fmc_state       <= timeout_drain;
                    elsif axi_fifo_rd_path_rempty = '0' then
                        -- Present the first beat a full cycle before the wait
                        -- release can be sampled.
                        data_out        <= axi_fifo_rd_path_rdata(15 downto 0);
                        data_out_hiz_int <= (others => hiz_v);
                        fmc_state       <= rd_arm;
                    end if;
                when rd_arm =>
                    if not chip_selected then
                        axi_fifo_rd_path_rd_ack <= '1';
                        data_out_hiz_int         <= (others => '1');
                        fmc_state               <= idle;
                    else
                        nwait           <= '1';
                        data_out_hiz_int <= (others => hiz_v);
                        fmc_state       <= rd_beat0;
                    end if;
                when rd_beat0 =>
                    -- SP samples word0 at this edge.
                    if not chip_selected then
                        -- Shortened read: the full 32-bit AXI read already
                        -- happened, so any read side effects have occurred;
                        -- all we can do is clean up.
                        axi_fifo_rd_path_rd_ack <= '1';
                        data_out_hiz_int         <= (others => '1');
                        nwait                   <= '0';
                        fmc_state               <= idle;
                    else
                        data_out        <= axi_fifo_rd_path_rdata(31 downto 16);
                        data_out_hiz_int <= (others => hiz_v);
                        if extra_beat_setup then
                            nwait     <= '0';
                            fmc_state <= rd_rearm;
                        else
                            -- wait stays released; word1 is sampled on the
                            -- very next edge (this word0->word1 transition is
                            -- the one single-cycle data-out path).
                            fmc_state <= rd_beat1;
                        end if;
                    end if;
                when rd_rearm =>
                    -- extra_beat_setup only: one dead cycle re-opens the
                    -- 2-cycle data-out window of the pre-streaming cadence.
                    nwait           <= '1';
                    data_out_hiz_int <= (others => hiz_v);
                    fmc_state       <= rd_beat1;
                when rd_beat1 =>
                    -- SP samples word1 at this edge; done with the word.
                    axi_fifo_rd_path_rd_ack <= '1';
                    nwait                   <= '0';
                    data_out_hiz_int         <= (others => '1'); -- release bus
                    fmc_state               <= idle;
                when wr_arm =>
                    -- The SP samples the released wait at this edge and
                    -- launches beat0 on the following falling edge.
                    if not chip_selected then
                        -- The transaction is already queued; complete it with
                        -- zeros rather than leaving the AXI side wedged
                        -- waiting for write data that will never come.
                        axi_fifo_wr_path_wdata <= (others => '0');
                        axi_fifo_wr_path_write <= '1';
                        nwait                  <= '0';
                        fmc_state              <= idle;
                    else
                        fmc_state <= wr_arm2;
                    end if;
                when wr_arm2 =>
                    -- beat0 is on the bus this cycle; it lands in ad_q for
                    -- wr_beat0 to consume on the next edge
                    if not chip_selected then
                        axi_fifo_wr_path_wdata <= (others => '0');
                        axi_fifo_wr_path_write <= '1';
                        nwait                  <= '0';
                        fmc_state              <= idle;
                    else
                        fmc_state <= wr_beat0;
                    end if;
                when wr_beat0 =>
                    if not chip_selected then
                        axi_fifo_wr_path_wdata <= (others => '0');
                        axi_fifo_wr_path_write <= '1';
                        nwait                  <= '0';
                        fmc_state              <= idle;
                    else
                        axi_fifo_wr_path_wdata(15 downto 0) <= ad_q;
                        fmc_state                           <= wr_beat1;
                    end if;
                when wr_beat1 =>
                    -- Unconditional: reaching this state means the SP
                    -- committed the burst, and its data-hold contract covers
                    -- this capture even as NE deasserts. An aborted burst
                    -- leaves the bus released, which drive_or_zero turns
                    -- into zero filler rather than 'Z'/'X' in the AXI data.
                    axi_fifo_wr_path_wdata(31 downto 16) <= drive_or_zero(ad_q);
                    axi_fifo_wr_path_write <= '1';
                    nwait                  <= '0';
                    fmc_state              <= idle;
                when timeout_drain =>
                    -- Wait is released and poison is on the bus for read
                    -- phases; let the SP clock through its remaining beats
                    -- without capturing anything, then return to idle once
                    -- it deselects. Drive purely off the live OE/CS pins:
                    -- during write beats NOE is high so this never drives
                    -- against the SP, and the recorded transaction type may
                    -- be stale when the drain was entered from idle.
                    data_out_hiz_int <= (others => hiz_v);
                    if not chip_selected then
                        nwait           <= '0';
                        data_out_hiz_int <= (others => '1');
                        fmc_state       <= idle;
                    end if;
            end case;
        end if;
    end process;

    -- transaction fifo from FMC to AXI interface
    txn_dcfifo_dut: entity work.dcfifo_xpm
        generic map (

            fifo_write_depth => 16,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            -- Write interface ()
            wclk => fmc_clk,
            -- Reset interface, sync to write clock domain
            reset    => chip_reset,
            write_en => axi_fifo_txn_path_write,
            wdata    => encode(txn),
            wfull    => axi_fifo_txn_path_wfull,
            wusedwds => open,
            -- Read interface
            rclk     => aclk,
            rdata    => axi_fifo_txn_path_rdata,
            rdreq    => axi_fifo_txn_path_rd_ack,
            rempty   => axi_fifo_txn_path_rempty,
            rusedwds => open
        );

    -- Read-data path from AXI to FMC interface
    rdata_dcfifo_dut: entity work.dcfifo_xpm
        generic map (

            fifo_write_depth => 16,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            -- Write interface ()
            wclk => aclk,
            -- Reset interface, sync to write clock domain
            reset    => not aresetn,
            write_en => rready and rvalid,
            wdata    => rdata,
            wfull    => open,
            wusedwds => open,
            -- Read interface
            rclk     => fmc_clk,
            rdata    => axi_fifo_rd_path_rdata,
            rdreq    => axi_fifo_rd_path_rd_ack,
            rempty   => axi_fifo_rd_path_rempty,
            rusedwds => open
        );

    -- Write-data path from FMC to AXI interface
    wdata_dcfifo_dut: entity work.dcfifo_xpm
        generic map (

            fifo_write_depth => 16,
            data_width       => 32,
            showahead_mode   => true
        )
        port map (
            -- Write interface ()
            wclk => fmc_clk,
            -- Reset interface, sync to write clock domain
            reset    => chip_reset,
            write_en => axi_fifo_wr_path_write,
            wdata    => axi_fifo_wr_path_wdata,
            wfull    => axi_fifo_wr_path_wfull,
            wusedwds => open,
            -- Read interface
            rclk     => aclk,
            rdata    => axi_fifo_wr_path_rdata,
            rdreq    => wvalid and wready,
            rempty   => axi_fifo_wr_path_rempty,
            rusedwds => open
        );

    -- State machine dealing with AXI interface
    axi_sm: process(aclk, aresetn)
        variable cur_txn : txn_type;
    begin
        if not aresetn then
            axi_addr                 <= (others => '0');
            axi_state                <= idle;
            rready                   <= '0';
            arvalid                  <= '0';
            bready                   <= '0';
            awvalid                  <= '0';
            wvalid                   <= '0';
            axi_fifo_txn_path_rd_ack <= '0';
        elsif rising_edge(aclk) then
            -- unconditionally clear single-cycle flags
            axi_fifo_txn_path_rd_ack <= '0';
            case axi_state is
                when idle =>
                    if not axi_fifo_txn_path_rempty then
                        axi_fifo_txn_path_rd_ack <= '1';
                        cur_txn                  := decode(axi_fifo_txn_path_rdata);
                        axi_addr                 <= resize(cur_txn.addr, axi_addr'length);
                        if cur_txn.read_not_write then
                            axi_state <= axi_read_init;
                        else
                            axi_state <= axi_write_init;
                        end if;
                    end if;
                when axi_read_init =>
                    -- APPLY READ ADDR channel and allow read responses
                    rready    <= '1';
                    arvalid   <= '1';
                    axi_state <= axi_read_wait;
                when axi_read_wait =>
                    if rready and rvalid then
                        rready    <= '0';
                        axi_state <= idle;
                    end if;
                    if arready and arvalid then
                        arvalid <= '0';
                    end if;
                when axi_write_init =>
                    -- AW and W are raised together, and only once the write
                    -- data has crossed the FIFO: raising AW alone lets a
                    -- downstream decoder start a write it then has to stall
                    -- on, and this block's own W data pops on the handshake.
                    if not axi_fifo_wr_path_rempty then
                        awvalid   <= '1';
                        wvalid    <= '1';
                        bready    <= '1';
                        axi_state <= axi_write_wait;
                    end if;
                when axi_write_wait =>
                    if awready and awvalid then
                        awvalid <= '0';
                    end if;
                    if wready and wvalid then
                        wvalid <= '0';
                    end if;
                    if bvalid then
                        axi_state <= idle;
                        bready    <= '0';
                    end if;
            end case;
        end if;
    end process;

    -- no fancy concurrency here, so just point at the same register
    awaddr <= std_logic_vector(axi_addr(25 downto 0));
    araddr <= std_logic_vector(axi_addr(25 downto 0));
    wdata  <= axi_fifo_wr_path_rdata;

end rtl;
