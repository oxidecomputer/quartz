-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

-- The eSPI serdes, clocked directly by the eSPI SCLK.
--
-- The previous implementation oversampled SCLK in the 200MHz fabric domain.
-- That costs a fixed ~10-16ns between a real SCLK edge and the resulting
-- sample or launch, which is a whole half-period at 50MHz and beyond, so it
-- cannot be constrained above 20MHz no matter how the logic is arranged.
-- Clocking the shift registers from SCLK replaces that with the clock buffer's
-- insertion delay, which the tools can actually model.
--
-- Chip select is the domain reset. eSPI guarantees CS is stable around every
-- SCLK edge, and using it asynchronously means the per-transaction state
-- machines come up clean without needing a clock edge that may never arrive --
-- SCLK only runs while a transaction is in flight.
--
-- The command "sizer" lives here rather than in the fabric domain so the
-- command/turnaround/response phase boundary is exact and never crosses a
-- clock domain. A crossed phase decision would carry a cycle of uncertainty,
-- which at 66MHz is most of a bit time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_base_types_pkg.all;
use work.espi_protocol_pkg.all;
use work.link_layer_pkg.all;

entity espi_phy is
    port (
        --! eSPI clock from the host. Used as a clock, not sampled.
        sclk : in    std_logic;
        --! eSPI chip select, active low. Asynchronous domain reset.
        cs_n : in    std_logic;

        -- Serial data
        io      : in    std_logic_vector(3 downto 0);
        io_o    : out   std_logic_vector(3 downto 0);
        --! Output enables for the response phase only. Alert-driven output
        --! enable is generated in the fabric domain, since an alert has to be
        --! driven with no SCLK running.
        resp_oe : out   std_logic_vector(3 downto 0);

        --! I/O mode. Quasi-static: only changes as a result of a
        --! SET_CONFIGURATION, and is frozen for the duration of a transaction
        --! by the latch below.
        qspi_mode : in    qspi_mode_t;

        --! Launch each bit a half period early, on the rising edge rather than
        --! the falling one. Only valid where the flight time back to the
        --! controller exceeds a half SCLK period -- see the comment on the
        --! serializer. Quasi-static and latched with the I/O mode.
        early_launch : in    std_logic;

        -- Received bytes, handed to the fabric domain with a toggle. `rx_byte`
        -- is held for a full byte time, so the fabric side can sample it any
        -- time it sees the toggle move.
        rx_byte   : out   std_logic_vector(7 downto 0);
        rx_toggle : out   std_logic;

        -- Response bytes, read from the cross-domain buffer.
        tx_data  : in    std_logic_vector(7 downto 0);
        tx_empty : in    std_logic;
        tx_rdack : out   std_logic
    );
end entity;

architecture rtl of espi_phy is

    signal sclk_cnt          : std_logic_vector(15 downto 0);
    signal completed_byte_cnt : std_logic_vector(15 downto 0);
    signal size_info         : size_info_t;
    signal sizer_cmd         : byte_stream;

    -- Fast path for opcode-determined packet lengths, see below.
    signal first_byte      : std_logic_vector(7 downto 0);
    signal have_first_byte : std_logic;
    signal fast_hdr        : hdr_t;
    signal fast_size_valid : std_logic;
    signal eff_size        : std_logic_vector(12 downto 0);
    signal eff_size_valid  : std_logic;

    -- I/O mode capture. The host can issue a SET_CONFIGURATION that changes
    -- the mode, and the command processor applies it mid-transaction -- but
    -- the response to that very command still has to go out in the old mode.
    signal mode_latched : std_logic;
    signal txn_mode_r   : qspi_mode_t;
    signal mode_sel     : qspi_mode_t;
    signal txn_early_r  : std_logic;
    signal early_sel    : std_logic;
    signal shift_amt    : natural range 1 to 4;

    -- RX
    signal rx_reg      : std_logic_vector(8 downto 0);
    signal rx_byte_stb : std_logic;
    -- Deliberately never reset, same discipline as `tacd`: the absolute state
    -- of a toggle carries no meaning, only its transitions do. Clearing it at
    -- chip select would look like a completed byte to the fabric side and
    -- inject a bogus command byte after every odd-length transaction.
    signal rx_toggle_r : std_logic := '0';
    signal rx_byte_r   : std_logic_vector(7 downto 0) := (others => '0');

    -- TX
    signal tx_reg            : std_logic_vector(7 downto 0);
    signal io_o_early        : std_logic_vector(3 downto 0);
    signal io_o_late         : std_logic_vector(3 downto 0);
    signal tx_bits_left      : natural range 0 to 8;
    signal ta_fall_cnt       : natural range 0 to 3;
    signal in_response_phase : std_logic;
    signal in_turnaround_phase : boolean;

    --! The four pad values for a byte in flight. IO[3] always carries the MSB
    --! so the taps line up across modes; the lower lines pick up successively
    --! lower bits as the bus widens. IO[0] in single mode is unused and gated
    --! off by the output enable.
    function tap_by_mode (
        constant d    : std_logic_vector(7 downto 0);
        constant mode : qspi_mode_t
    ) return std_logic_vector is
        variable r : std_logic_vector(3 downto 0) := (others => '1');
    begin
        r(3) := d(7);
        r(2) := d(6);
        case mode is
            when single =>
                r(1) := d(7);
            when dual =>
                r(1) := d(7);
                r(0) := d(6);
            when quad =>
                r(1) := d(5);
                r(0) := d(4);
        end case;
        return r;
    end function;

    --! Output enables by mode. Note IO[1] is the response data line in single
    --! mode -- it doubles as the alert pin per the AMD convention.
    function oe_by_mode (constant mode : qspi_mode_t) return std_logic_vector is
    begin
        case mode is
            when single => return "0010";
            when dual   => return "0011";
            when quad   => return "1111";
        end case;
    end function;

begin

    -- ------------------------------------------------------------------
    -- Mode capture
    -- ------------------------------------------------------------------
    -- While chip select is deasserted the mode tracks the register block.
    -- At the first SCLK edge of a transaction it freezes for the duration.
    -- `mode_sel` covers the first edge itself, before the capture register
    -- has anything in it.
    mode_sel  <= txn_mode_r when mode_latched = '1' else qspi_mode;
    early_sel <= txn_early_r when mode_latched = '1' else early_launch;
    shift_amt <= get_qspi_shift_amt_by_mode(mode_sel);

    -- ------------------------------------------------------------------
    -- Command deserializer
    -- ------------------------------------------------------------------
    -- 9-bit register with a sentinel '1' walking up from the LSB, so no bit
    -- counter is needed: the byte is complete when the sentinel reaches the
    -- MSB. This works unchanged for all three shift amounts because 8 is
    -- divisible by 1, 2 and 4.
    --
    -- Unlike the old implementation this free-runs for the whole transaction
    -- rather than being gated by a command-phase signal. Bytes shifted in
    -- during turnaround and response are simply ignored downstream, and
    -- dropping the gate removes a signal that is awkward to produce here.
    cmd_deserializer: process(sclk, cs_n)
        variable nxt : std_logic_vector(8 downto 0);
    begin
        if cs_n = '1' then
            -- rx_toggle_r and rx_byte_r are deliberately absent here: see
            -- their declarations. They only carry meaning together, and both
            -- are stale-but-harmless between transactions.
            rx_reg          <= (rx_reg'low => '1', others => '0');
            rx_byte_stb     <= '0';
            sclk_cnt        <= (others => '0');
            mode_latched    <= '0';
            txn_mode_r      <= single;
            txn_early_r     <= '0';
            first_byte      <= (others => '0');
            have_first_byte <= '0';
        elsif rising_edge(sclk) then
            rx_byte_stb <= '0';
            sclk_cnt    <= sclk_cnt + 1;

            mode_latched <= '1';
            if mode_latched = '0' then
                txn_mode_r  <= mode_sel;
                txn_early_r <= early_sel;
            end if;

            nxt := shift_left(rx_reg, shift_amt);
            -- Sample into the vacated LSBs. The sentinel has already moved
            -- above this range, so it is never clobbered.
            case mode_sel is
                when single => nxt(0 downto 0) := io(0 downto 0);
                when dual   => nxt(1 downto 0) := io(1 downto 0);
                when quad   => nxt(3 downto 0) := io(3 downto 0);
            end case;

            if nxt(nxt'high) = '1' then
                rx_byte_r   <= nxt(7 downto 0);
                rx_byte_stb <= '1';
                rx_toggle_r <= not rx_toggle_r;
                rx_reg      <= (rx_reg'low => '1', others => '0');
                if have_first_byte = '0' then
                    first_byte      <= nxt(7 downto 0);
                    have_first_byte <= '1';
                end if;
            else
                rx_reg <= nxt;
            end if;
        end if;
    end process;

    rx_byte   <= rx_byte_r;
    rx_toggle <= rx_toggle_r;

    -- Minimal parser giving us the packet length, and therefore where the
    -- turnaround falls. Chip select holds it in reset between transactions.
    sizer_cmd.data  <= rx_byte_r;
    sizer_cmd.valid <= rx_byte_stb;
    sizer_cmd.ready <= '1';

    size_finder: entity work.cmd_sizer
        port map (
            clk        => sclk,
            reset      => cs_n,
            cs_n       => cs_n,
            cmd        => sizer_cmd,
            size_info  => size_info,
            -- In-band reset is detected in the fabric domain instead: it has
            -- to be reported when chip select rises, and there is no SCLK edge
            -- left at that point to clock it out.
            espi_reset => open
        );

    completed_byte_cnt <= shift_right(sclk_cnt, get_sclk_to_bytes_shift_amt_by_mode(mode_sel));

    -- The sizer needs three SCLK to raise `valid` after a byte completes: one
    -- for the byte strobe to land, then two state transitions. That was free
    -- when it ran at 200MHz, but here those are SCLK periods. A two-byte
    -- command is 16 SCLK in single mode and 8 in dual, so there is room -- but
    -- only 4 in quad, and the turnaround has to be placed after the 4th edge.
    --
    -- For the commands whose length follows from the opcode alone, and that is
    -- every short command including GET_STATUS, the answer is already known
    -- the moment the first byte lands. Take it combinationally from there and
    -- leave the sizer to the commands that carry a length in the header, which
    -- are long enough that its latency does not matter. Note this deliberately
    -- does not fire for the in-band reset opcode, which has no length and must
    -- never produce a response.
    fast_hdr.opcode     <= first_byte;
    fast_hdr.cycle_type <= (others => '0');
    fast_hdr.len        <= (others => '0');

    -- opcode_reset is listed in known_size_by_opcode but has no length, and
    -- size_by_header rejects it outright. cmd_sizer copes by testing for reset
    -- before it consults the size tables at all; the fast path has to do the
    -- same, or an in-band reset walks straight into size_by_header's "Unknown
    -- opcode". Excluded here it falls through to the sizer, which routes it to
    -- the in-band reset path and never produces a response -- which is correct.
    fast_size_valid <= '1' when have_first_byte = '1'
                            and first_byte /= opcode_reset
                            and known_size_by_opcode(fast_hdr)
                       else '0';

    eff_size_valid <= fast_size_valid or size_info.valid;
    eff_size       <= size_by_header(fast_hdr) when fast_size_valid = '1' else size_info.size;

    in_turnaround_phase <= eff_size_valid = '1' and
                           completed_byte_cnt >= eff_size and
                           in_response_phase = '0';

    -- ------------------------------------------------------------------
    -- Response phase state machine
    -- ------------------------------------------------------------------
    -- Turnaround spans three SCLK edges after the last command bit is sampled.
    -- The output enable stays on the falling edge deliberately: it must not come
    -- up before the controller has released the bus, and the falling edge is
    -- where that handover happens.
    response_phase_sm: process(sclk, cs_n)
    begin
        if cs_n = '1' then
            ta_fall_cnt       <= 0;
            in_response_phase <= '0';
            resp_oe           <= (others => '0');
        elsif falling_edge(sclk) then
            if in_response_phase = '0' and in_turnaround_phase then
                if ta_fall_cnt = 1 then
                    in_response_phase <= '1';
                    resp_oe           <= oe_by_mode(mode_sel);
                else
                    ta_fall_cnt <= ta_fall_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- ------------------------------------------------------------------
    -- Response serializer
    -- ------------------------------------------------------------------
    -- Always runs on the rising edge. `io_o_early` therefore presents each bit a
    -- half period ahead of where the old falling-edge serializer put it, and
    -- `io_o_late` below re-registers it on the falling edge to reproduce the
    -- original timing exactly. Which one reaches the pad is selected at run time
    -- by the negotiated frequency.
    --
    -- Why this is not simply always-early: the controller captures at a fixed
    -- edge one period after the target is *supposed* to have launched, not
    -- wherever the data happens to land. Launching early only buys time while
    -- the flight time back to the controller still exceeds a half period -- if it
    -- does not, the next bit has already replaced this one by the time the
    -- controller looks, and the whole response shifts by a bit. On cosmo flight
    -- is about 12ns, so early launch is correct at 66MHz (half period 7.6ns) and
    -- wrong at 20MHz (half period 25ns).
    --
    -- That makes this the one place in the block whose correctness depends on a
    -- physical delay rather than only on the protocol. The testbench models the
    -- round trip precisely so it can catch the mistake; forcing early launch on
    -- at 20MHz fails the sweeps immediately.
    response_serializer: process(sclk, cs_n)
        variable nxt_tx : std_logic_vector(7 downto 0);
    begin
        if cs_n = '1' then
            tx_reg       <= (others => '1');
            -- IO[1] idles low so the in-band alert only has to assert the output
            -- enable; keeping the alert out of this data path is what lets these
            -- registers sit next to the pad.
            io_o_early   <= (1 => '0', others => '1');
            tx_bits_left <= 0;
            tx_rdack     <= '0';
        elsif rising_edge(sclk) then
            tx_rdack <= '0';
            nxt_tx   := tx_reg;

            if in_response_phase = '1' then
                if tx_bits_left = 0 then
                    -- Send 0xFF on underflow. Per spec this both raises the
                    -- lines at the end of a transaction and stands in as the
                    -- ERROR response when we choose not to answer.
                    if tx_empty = '0' then
                        nxt_tx   := tx_data;
                        tx_rdack <= '1';
                    else
                        nxt_tx := (others => '1');
                    end if;
                    tx_bits_left <= 8 - shift_amt;
                else
                    nxt_tx       := shift_left(tx_reg, shift_amt);
                    tx_bits_left <= tx_bits_left - shift_amt;
                end if;
                tx_reg     <= nxt_tx;
                io_o_early <= tap_by_mode(nxt_tx, mode_sel);
            end if;
        end if;
    end process;

    -- Half a period of delay, which is what turns the early launch back into the
    -- original falling-edge one.
    late_launch_reg: process(sclk, cs_n)
    begin
        if cs_n = '1' then
            io_o_late <= (1 => '0', others => '1');
        elsif falling_edge(sclk) then
            io_o_late <= io_o_early;
        end if;
    end process;

    io_o <= io_o_early when early_sel = '1' else io_o_late;

end rtl;
