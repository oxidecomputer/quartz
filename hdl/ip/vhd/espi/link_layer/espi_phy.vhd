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
    signal tx_bits_left      : natural range 0 to 8;
    signal ta_fall_cnt       : natural range 0 to 3;
    signal in_response_phase : std_logic;
    signal in_turnaround_phase : boolean;

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
            first_byte      <= (others => '0');
            have_first_byte <= '0';
        elsif rising_edge(sclk) then
            rx_byte_stb <= '0';
            sclk_cnt    <= sclk_cnt + 1;

            mode_latched <= '1';
            if mode_latched = '0' then
                txn_mode_r <= mode_sel;
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
    -- Response serializer
    -- ------------------------------------------------------------------
    -- Turnaround spans three SCLK edges after the last command bit is
    -- sampled: F1, R1, F2. Counting falling edges only, the response phase
    -- opens after F2 and the first byte is launched on F3, matching the edge
    -- relationship of the previous implementation.
    response_serializer: process(sclk, cs_n)
    begin
        if cs_n = '1' then
            tx_reg            <= (others => '1');
            tx_bits_left      <= 0;
            ta_fall_cnt       <= 0;
            in_response_phase <= '0';
            resp_oe           <= (others => '0');
            tx_rdack          <= '0';
        elsif falling_edge(sclk) then
            tx_rdack <= '0';

            if in_response_phase = '1' then
                if tx_bits_left = 0 then
                    -- Send 0xFF on underflow. Per spec this both raises the
                    -- lines at the end of a transaction and stands in as the
                    -- ERROR response when we choose not to answer.
                    if tx_empty = '0' then
                        tx_reg   <= tx_data;
                        tx_rdack <= '1';
                    else
                        tx_reg <= (others => '1');
                    end if;
                    tx_bits_left <= 8 - shift_amt;
                else
                    tx_reg       <= shift_left(tx_reg, shift_amt);
                    tx_bits_left <= tx_bits_left - shift_amt;
                end if;
            elsif in_turnaround_phase then
                if ta_fall_cnt = 1 then
                    in_response_phase <= '1';
                    resp_oe           <= oe_by_mode(mode_sel);
                else
                    ta_fall_cnt <= ta_fall_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Output muxing. IO[3] always carries the MSB so the taps line up across
    -- modes; the lower lines pick up successively lower bits as the bus widens.
    io_o(3) <= tx_reg(7);
    io_o(2) <= tx_reg(6);
    io_o(1) <= tx_reg(5) when mode_sel = quad else
               tx_reg(7);
    io_o(0) <= tx_reg(4) when mode_sel = quad else
               tx_reg(6) when mode_sel = dual else
               '1';  -- unused, gated off by the output enable

end rtl;
