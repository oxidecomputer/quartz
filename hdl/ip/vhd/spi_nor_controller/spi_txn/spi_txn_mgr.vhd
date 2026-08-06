-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.spi_nor_pkg.all;

entity spi_txn_mgr is
    generic (
        -- clk cycles from cs_n asserting to the first sclk edge (tSLCH)
        cs_setup_cnts : natural := 4;
        -- Minimum clk cycles cs_n must stay high between transactions (tSHSL).
        -- The eSPI read path chains page reads back to back and will otherwise
        -- re-assert cs_n the cycle after it goes high, which the flash does not
        -- allow. This is in clk cycles, so it does not scale with sclk.
        cs_high_cnts : natural := 7
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- system register interface
        spi_cmd : in    spi_nor_cmd_t;
        -- address : in unsigned(31 downto 0);
        -- dummy_cycles   : in unsigned(7 downto 0);
        -- data_bytes : in unsigned(8 downto 0);
        -- instr: in std_logic_vector(7 downto 0);
        -- go_flag: in std_logic;
        -- link interface
        cs_n : out   std_logic;
        -- Second copy of the cs_n flop, for the pin only, so it can be packed
        -- into the IOB. Same reasoning as spi_clk_gen's sclk_pin.
        cs_n_pin     : out   std_logic;
        sclk         : in    std_logic;
        rx_byte_done : in    boolean;
        rx_link_byte : in    std_logic_vector(7 downto 0);
        tx_byte_req  : in    boolean;
        tx_link_byte : out   std_logic_vector(7 downto 0);
        -- The io mode the byte above belongs to. Travels with it because the
        -- serializer needs both on the same edge; see next_tx.
        tx_link_mode : out   io_mode;
        in_rx_phases : out   boolean;
        in_tx_phases : out   boolean;
        -- Gates the sclk generator. Narrower than in_tx_phases on purpose, see
        -- is_sclk_running below.
        sclk_running : out   boolean;
        -- Lanes to stop driving ahead of a turnaround, see below
        release_lanes : out   std_logic_vector(3 downto 0);
        cur_io_mode   : out   io_mode;
        -- fifo interface
        rx_fifo_data  : out   std_logic_vector(7 downto 0);
        rx_fifo_write : out   std_logic;
        tx_fifo_data  : in    std_logic_vector(7 downto 0);
        tx_fifo_ack   : out   std_logic
    );
end entity;

architecture rtl of spi_txn_mgr is

    attribute mark_debug : string;
    constant BYTES_24BIT_ADDR  : integer := 3;
    constant BYTES_32BIT_ADDR  : integer := 4;

    type state_t is (idle, cs_assert, instruction, addr, dummy, wdata, rdata, cs_deassert);

    type     reg_type is record
        state   : state_t;
        txn     : txn_info_t;
        csn     : std_logic;
        counter : integer range 0 to 512;
        -- Counts down the enforced cs_n high time. Separate from `counter`
        -- because it has to keep running while we sit in idle.
        cs_high : integer range 0 to 63;
    end record;
    constant r_reset : reg_type := (idle, txn_info_t_reset, '1', 0, 0);

    signal r, rin    : reg_type;
    attribute mark_debug of r : signal is "TRUE";
    signal sclk_last : std_logic;

    -- The byte the serializer will load at its next reload, and the io mode it
    -- belongs to, held ready ahead of the edge that consumes them. See next_tx.
    type tx_prefetch_t is record
        byte : std_logic_vector(7 downto 0);
        mode : io_mode;
    end record;

    signal tx_pre : tx_prefetch_t;

    -- Some helper functions
    -- This block gets the expected IO mode given the state and the transaction we're running
    function get_cur_io_mode (
        txn: txn_info_t;
        state: state_t
    ) return io_mode is
    begin
        if state = idle or
           state = cs_assert or
           state = instruction or
           state = addr or
           state = dummy then
            -- no matter what the transaction moves to, we're in single mode
            -- for these phases. cs_assert belongs here because the serializer is
            -- already shifting the opcode out during it: sclk is enabled as soon
            -- as we assert cs_n, and at clk/2 the first sclk edge lands inside
            -- cs_assert rather than after it. Reporting the data mode here made
            -- the opcode go out 4 bits at a time, so the part saw a different
            -- instruction entirely.
            return single;
        else
            -- otherwise use the mode specified by the opcode
            return txn.data_mode;
        end if;
    end;

    -- The phases sclk is allowed to run in. This is deliberately *not* the same
    -- question as "are we driving the bus": cs_deassert drives but must not
    -- clock. The part counts sclk edges to decide where an instruction ends, and
    -- an erase or a write enable that gets even one trailing edge before cs_n
    -- rises is discarded outright, with no error anywhere -- it just silently
    -- does not happen. Conflating the two conditions is what broke erase.
    function is_sclk_running (
        state: state_t
    ) return boolean is
    begin
        return state = cs_assert or state = instruction or state = addr or
               state = dummy or state = wdata or state = rdata;
    end;

    -- This function takes the state and returns if we're driving data lines
    -- currently.
    --
    -- cs_deassert counts as driving for anything that is not a read: the part
    -- samples our last bit on the sclk edge after we leave wdata, and io_oe is
    -- registered, so releasing there would change mosi on the very edge being
    -- sampled once a half period is a single clk cycle. Holding until cs_n rises
    -- is what a controller should do anyway. Reads must not drive here, since
    -- the part keeps driving until it is deselected.
    function is_in_tx_phases (
        txn: txn_info_t;
        state: state_t
    ) return boolean is
    begin
        return state = cs_assert or state = wdata or state = dummy or
               state = addr or state = instruction or
               (state = cs_deassert and txn.data_kind /= read);
    end;

    -- This function takes the state and returns if we're sampling data lines
    -- currently
    function is_in_rx_phases (
        state: state_t
    ) return boolean is
    begin
        return state = rdata;
    end;

    -- The byte the serializer will load at its *next* reload.
    --
    -- The serializer reloads on the same clk edge this state machine advances a
    -- phase, so the byte has to already be sitting there when that edge arrives
    -- rather than be selected by it. Driving the mux from `v` satisfied that by
    -- hanging the entire selection off tx_reg in one combinational path:
    -- shifter-empty detect, then the next-state decode, then a byte select off
    -- the decremented counter, then the lane mux into io_o. At clk/6 there was
    -- room for it; at clk/2 it was the design's critical path, eight levels of
    -- LUT spending 6.9ns of an 8ns period to reach io_o.
    --
    -- *Which* byte comes next does not depend on *when* the request arrives,
    -- though -- it is a function of the registered state alone. So compute it
    -- from `r` and register it, leaving the reload edge nothing to do but copy a
    -- flop. The prefetch settles two clks after each phase advance and byte
    -- slots are at least four clks apart (quad data at clk/2, the fastest this
    -- block runs), so it is always in place in time.
    -- The prefetch carries the io mode with the byte, and it has to: the mode is
    -- a property of the phase the byte belongs to, and the serializer needs both
    -- at the same instant. Taking the mode from the registered state instead
    -- means the first data byte of a dual or quad write is loaded while the
    -- state still reads `addr`, so it goes out with single-bit lane assignment
    -- and, worse, gets shifted by one instead of four. That leaves the shifter's
    -- sentinel on an odd bit where the byte-complete compare can never match it,
    -- so the byte counter stops advancing and the transaction never ends.
    function next_tx (
        r    : reg_type;
        cmd  : spi_nor_cmd_t;
        fifo : std_logic_vector(7 downto 0)
    ) return tx_prefetch_t is
        variable idx : integer range 0 to 3;
    begin
        case r.state is
            when idle =>
                -- The opcode is the first byte out. The serializer preloads it
                -- on the cs_n assert edge, before the first sclk edge.
                return (byte => cmd.instr, mode => single);
            when cs_assert | instruction =>
                -- Whatever follows the opcode: the top address byte, or the
                -- first data byte for an opcode that writes without an address.
                case r.txn.addr_kind is
                    when bit32 =>
                        return (byte => cmd.addr(31 downto 24), mode => single);
                    when bit24 =>
                        return (byte => cmd.addr(23 downto 16), mode => single);
                    when none =>
                        if not r.txn.uses_dummys and r.txn.data_kind = write then
                            return (byte => fifo, mode => r.txn.data_mode);
                        end if;
                end case;
            when addr =>
                if r.counter > 0 then
                    idx := r.counter - 1;
                    return (byte => cmd.addr(8 * idx + 7 downto 8 * idx),
                            mode => single);
                elsif not r.txn.uses_dummys and r.txn.data_kind = write then
                    return (byte => fifo, mode => r.txn.data_mode);
                end if;
            when wdata =>
                -- The fifo was acked on the edge that consumed the previous
                -- byte, so its head is already the one after it. The tail of the
                -- phase keeps reporting the data mode so the lane assignment
                -- does not twitch on the last edge.
                return (byte => fifo, mode => r.txn.data_mode);
            when others =>
                null;
        end case;

        -- Nothing of ours to send: dummy cycles or a read, both of which shift
        -- ones out a bit at a time.
        return (byte => (others => '1'), mode => single);
    end;

begin

    -- "Simple outputs"
    cs_n <= r.csn;
    tx_link_byte  <= tx_pre.byte;
    tx_link_mode  <= tx_pre.mode;
    -- rx fifo is just a pass through here, no need for any muxing
    rx_fifo_data  <= rx_link_byte;
    rx_fifo_write <= '1' when rx_byte_done else '0';
    in_rx_phases  <= is_in_rx_phases(r.state);
    in_tx_phases  <= is_in_tx_phases(r.txn, r.state);
    sclk_running  <= is_sclk_running(r.state);

    -- more complicated outputs

    -- based on the current state, current transaction info, we get the current io mode
    process(all)
    begin
        cur_io_mode <= get_cur_io_mode(r.txn, r.state);
    end process;

    -- Stop driving the lanes the flash is about to drive, an sclk cycle before
    -- it starts. Only multi-bit reads with dummy cycles need this: during the
    -- dummy phase cur_io_mode is still single, so io0/io3 are being driven for
    -- HOLD avoidance right up to the point a dual or quad read takes them over.
    -- At 20MHz the registered io_oe happened to drop in time; at clk/2 it does
    -- not, and the overlap shows up as marginal first bytes rather than an
    -- obvious failure. Lanes the part never drives in this mode are left alone.
    release_gen: process(all)
    begin
        release_lanes <= "0000";
        if r.state = dummy and r.txn.data_kind = read and r.counter <= 1 then
            case r.txn.data_mode is
                when quad =>
                    release_lanes <= "1111";
                when dual =>
                    release_lanes <= "0011";
                when single =>
                    -- the part only drives io1, which we are not driving
                    release_lanes <= "0000";
            end case;
        end if;
    end process;

    -- main controller state machine
    controller: process(all)
        variable v         : reg_type;
        variable slk_redge : boolean := false;
    begin
        v := r;
        slk_redge := sclk = '1' and sclk_last = '0';

        if r.cs_high > 0 then
            v.cs_high := r.cs_high - 1;
        end if;
        case r.state is
            when idle =>
                -- Hold off until the part's minimum cs_n high time has elapsed.
                -- The eSPI manager re-asserts go_flag as soon as it sees us go
                -- un-busy, which is the same cycle cs_n rises.
                if spi_cmd.go_flag = '1' and r.cs_high = 0 then
                    v.state := cs_assert;
                    -- build up transaction info based on opcode
                    v.txn := get_txn_info(spi_cmd.instr);
                    v.counter := cs_setup_cnts;
                end if;
            when cs_assert =>
                if r.counter = 0 then
                    v.state := instruction;
                else
                    v.counter := r.counter - 1;
                end if;
            when instruction =>
                -- After the instruction, we could go to
                -- address phase, or issue dummy clocks,
                -- or go directly to a read/write phase
                -- so we check all the options here
                if tx_byte_req then
                    case r.txn.addr_kind is
                        when bit24 =>
                            v.counter := BYTES_24BIT_ADDR - 1; -- zero indexed
                            v.state := addr;
                        when bit32 =>
                            v.counter := BYTES_32BIT_ADDR - 1; -- zero indexed
                            v.state := addr;
                        when none =>
                            if r.txn.uses_dummys then
                                v.state := dummy;
                                v.counter := to_integer(spi_cmd.dummy_cycles);
                            else
                                v.counter := to_integer(spi_cmd.data_bytes);
                                case r.txn.data_kind is
                                    when read =>
                                        v.state := rdata;
                                    when write =>
                                        v.state := wdata;
                                    when none =>
                                        v.state := cs_deassert;
                                        v.counter := cs_setup_cnts;
                                end case;
                            end if;
                    end case;
                end if;
            when addr =>
                -- After the address phase, we could go to a
                -- data phase immediately, or we could issue
                -- dummy clocks. I don't think there are commands
                -- that issue an address and then do nothing but
                -- we added the de-assert state for completeness
                if tx_byte_req and r.counter = 0 then
                    if r.txn.uses_dummys then
                        v.state := dummy;
                        v.counter := to_integer(spi_cmd.dummy_cycles);
                    elsif r.txn.data_kind = write then
                        v.state := wdata;
                        v.counter := to_integer(spi_cmd.data_bytes);
                    elsif r.txn.data_kind = read then
                        v.state := rdata;
                        v.counter := to_integer(spi_cmd.data_bytes);
                    else
                        v.state := cs_deassert;
                        v.counter := cs_setup_cnts;
                    end if;
                elsif tx_byte_req then
                    v.counter := r.counter - 1;
                end if;
            when dummy =>
                -- after a dummy phase, we're going to be reading
                -- as that's the only reason to issue dummy cycles
                -- for anything else we'll just terminate the transaction
                if slk_redge and r.counter = 1 then
                    if r.txn.data_kind = read then
                        v.state := rdata;
                        v.counter := to_integer(spi_cmd.data_bytes);
                    else
                        v.state := cs_deassert;
                        v.counter := cs_setup_cnts;
                    end if;
                elsif slk_redge then
                    v.counter := r.counter - 1;
                end if;
            when wdata =>
                -- Data counter is 1 indexded to better align
                -- with sw expectations so we're done when
                -- r.counter = 1
                if tx_byte_req and r.counter = 1 then
                    -- We're done with the transaction
                    v.state := cs_deassert;
                    v.counter := cs_setup_cnts;
                elsif tx_byte_req then
                    v.counter := r.counter - 1;
                end if;
            when rdata =>
                -- Data counter is 1 indexded to better align
                -- with sw expectations so we're done when
                -- r.counter = 1
                if rx_byte_done and r.counter = 1 then
                    -- We're done with the transaction
                    v.state := cs_deassert;
                    v.counter := cs_setup_cnts;
                elsif rx_byte_done then
                    v.counter := r.counter - 1;
                end if;
            when cs_deassert =>
                if r.counter = 0 then
                    v.state := idle;
                else
                    v.counter := r.counter - 1;
                end if;
        end case;
        -- cs_n is derived from `r` rather than from the v.state we just decoded,
        -- even though the two agree. cs_n_pin is an IOB flop, so whatever feeds
        -- its D lands on the same kind of long launch path io_o does, and going
        -- through v.state put the shifter's empty detect and the entire phase
        -- decode on it for no reason: cs_n only moves on the idle -> cs_assert
        -- and cs_deassert -> idle edges, and neither involves tx_byte_req.
        -- Staying in cs_assert or idle leaves it where it already is.
        if r.state = idle and spi_cmd.go_flag = '1' and r.cs_high = 0 then
            v.csn := '0';
        elsif r.state = cs_deassert and r.counter = 0 then
            v.csn := '1';
        end if;

        -- Arm the high-time counter on the edge that raises cs_n so the next
        -- transaction cannot start too soon. Off v.state, since cs_high feeds
        -- nothing but internal logic.
        if v.state = idle and r.csn = '0' then
            v.cs_high := cs_high_cnts;
        end if;

        -- Only ack the FIFO for bytes that actually came from it
        if tx_byte_req and v.state = wdata then
            tx_fifo_ack <= '1';
        else
            tx_fifo_ack <= '0';
        end if;

        rin <= v;
    end process;

    sm_reg: process(clk, reset)
    begin
        if reset then
            r <= r_reset;
            sclk_last <= '0';
            cs_n_pin <= '1';
            tx_pre <= (byte => (others => '1'), mode => single);
        elsif rising_edge(clk) then
            sclk_last <= sclk;
            r <= rin;
            -- Off `r`, not `rin`: the point of the prefetch is to give this
            -- selection a full clk period of its own, clear of the reload edge.
            tx_pre <= next_tx(r, spi_cmd, tx_fifo_data);
            -- Duplicate of r.csn, driven from the same next-state value so the
            -- two flops always agree and change on the same edge.
            cs_n_pin <= rin.csn;
        end if;
    end process;

end rtl;
