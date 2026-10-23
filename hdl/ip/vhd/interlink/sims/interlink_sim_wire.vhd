-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

use work.helper_8b10b_pkg.all;
use work.lfsr8_pkg.all;
use work.crc_sim_pkg.all;
use work.interlink_pkg.all;
use work.interlink_sim_pkg.all;
use work.calc_pkg.all;

-- One direction of the wire between two link ends, at the 10-bit symbol
-- boundary. It does two jobs:
--
-- As a monitor it decodes everything the transmitter sends and checks the
-- protocol invariants the receiver cannot observe on its own: IDLE structure
-- and cadence, packet nesting, and that the scrambler seed advertised in each
-- IDLE really is the state applied to the next scrambled character.
--
-- As a fault injector it applies one operation at a time, armed on an anchor
-- character: flip a bit, drop or repeat a symbol, replace a character, or
-- splice in a sequence of characters. Injecting here rather than on the
-- serial wire means a flipped bit is exactly one symbol bit on either path.
-- A one character lookahead lets an SOP anchor be qualified by ChannelID so
-- statistics packets do not steal the injection.
--
-- In paced mode (the bypass harness) it emits one symbol every CHAR_GAP
-- clocks; otherwise the consumer's ready paces it, as with a serdes.
entity interlink_sim_wire is
    generic (
        actor_name : string;
        CHAR_GAP : positive := 1;
        PACED : boolean := true
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        in_data : in std_logic_vector(9 downto 0);
        in_valid : in std_logic;
        in_ready : out std_logic := '0';
        out_data : out std_logic_vector(9 downto 0) := (others => '0');
        out_valid : out std_logic := '0';
        out_ready : in std_logic;

        -- Monitor results
        max_comma_gap : out natural := 0;
        commas_seen : out natural := 0;
        packets_seen : out natural := 0;
        monitor_errors : out natural := 0
    );
end entity;

architecture model of interlink_sim_wire is
    type op_t is record
        op : wire_op_t;
        anchor : wire_anchor_t;
        chan : integer;
        offset : natural;
        bit : natural;
        ctrl : std_logic;
        data : std_logic_vector(7 downto 0);
        chars : queue_t;
    end record;

    constant pending : queue_t := new_queue;
    -- Packet channel order as seen on the wire, for arbitration checks
    constant chan_order : queue_t := new_queue;

    signal rd : std_logic := '0';
    signal decoded : std_logic_vector(8 downto 0);
    signal rd_next : std_logic;
    signal code_err : std_logic;
    signal disp_err : std_logic;

    signal invert : boolean := false;
    signal op_req : op_t := (OP_NONE, ANCHOR_SOP, -1, 0, 0, '0', X"00", null_queue);
    signal op_valid : std_logic := '0';
    signal op_busy : std_logic := '0';
    signal depth : natural := 0;
begin

    decode_8b10b_inst: entity work.decode_8b10b
        port map (
            datain => in_data,
            dispin => rd,
            dataout => decoded,
            dispout => rd_next,
            code_err => code_err,
            disp_err => disp_err
        );

    main: process(clk)
        variable accept : boolean;
        -- monitor
        variable ctrl : std_logic;
        variable data : std_logic_vector(7 downto 0);
        variable plain : std_logic_vector(7 downto 0);
        variable lfsr : std_logic_vector(7 downto 0) := lfsr8_seed;
        variable scrambled : boolean := false;
        variable idle_state : natural := 0;
        variable idle_fields : queue_t := new_queue;
        variable chars_since_comma : natural := 0;
        variable first_comma : boolean := false;
        variable nesting : natural := 0;
        variable pkt_pos : natural := 0;
        variable errors : natural := 0;
        variable max_gap : natural := 0;
        -- lookahead and injection
        variable hold_word : std_logic_vector(9 downto 0);
        variable hold_valid : boolean := false;
        variable hold_is_sop : boolean := false;
        variable hold_is_comma : boolean := false;
        variable hold_is_preempt : boolean := false;
        variable hold_is_eop : boolean := false;
        variable op : op_t;
        variable op_armed : boolean := false;
        variable op_counting : boolean := false;
        variable op_count : natural := 0;
        variable out_rd : std_logic := '0';
        variable qdepth : natural := 0;
        variable slot : natural := 0;
        variable can_emit : boolean;
        variable word : std_logic_vector(9 downto 0);
        variable enc : encoded_8b10b_t;
        variable c : std_logic_vector(8 downto 0);
        variable anchor_hit : boolean;
        variable dummy : integer;

        procedure fail (msg : string) is
        begin
            errors := errors + 1;
            check_failed(actor_name & ": " & msg);
        end procedure;

        -- Track the running disparity of what actually goes down the wire
        -- so injected characters can be encoded to fit.
        procedure push_word (w : std_logic_vector(9 downto 0)) is
        begin
            if count_ones(w) > count_zeros(w) then
                out_rd := '1';
            elsif count_ones(w) < count_zeros(w) then
                out_rd := '0';
            end if;
            if invert then
                push(pending, not w);
            else
                push(pending, w);
            end if;
            qdepth := qdepth + 1;
        end procedure;

        procedure push_char (ctrl : std_logic; data : std_logic_vector(7 downto 0)) is
        begin
            enc := encode(data, ctrl, out_rd);
            push_word(enc.data);
        end procedure;

        -- Let the held character go, applying the pending operation if this
        -- is the character it was waiting for.
        procedure release_hold is
        begin
            if op_counting and op_count = op.offset then
                case op.op is
                    when OP_FLIP =>
                        hold_word(op.bit) := not hold_word(op.bit);
                        push_word(hold_word);
                    when OP_DELETE =>
                        null;
                    when OP_DUPLICATE =>
                        push_word(hold_word);
                        push_word(hold_word);
                    when OP_REPLACE =>
                        push_char(op.ctrl, op.data);
                    when OP_INSERT =>
                        while not is_empty(op.chars) loop
                            c := pop(op.chars);
                            push_char(c(8), c(7 downto 0));
                        end loop;
                        push_word(hold_word);
                    when OP_NONE =>
                        push_word(hold_word);
                end case;
                op_counting := false;
                op_armed := false;
                op_busy <= '0';
            else
                push_word(hold_word);
            end if;
            if op_counting then
                op_count := op_count + 1;
            end if;
        end procedure;
    begin
        if rising_edge(clk) then
            -- Output side
            if PACED then
                out_valid <= '0';
                if slot = CHAR_GAP - 1 then
                    slot := 0;
                    can_emit := true;
                else
                    slot := slot + 1;
                    can_emit := false;
                end if;
            else
                if out_ready = '1' then
                    out_valid <= '0';
                end if;
                can_emit := out_valid = '0' or out_ready = '1';
            end if;
            if can_emit and qdepth > 0 then
                out_data <= pop(pending);
                out_valid <= '1';
                qdepth := qdepth - 1;
            end if;

            -- Take a new operation when idle
            if op_valid = '1' and op_busy = '0' and not op_armed then
                op := op_req;
                op_armed := true;
                op_counting := false;
                op_busy <= '1';
            end if;

            -- Input side
            accept := in_valid = '1' and in_ready = '1' and reset = '0';
            if accept then
                rd <= rd_next;
                ctrl := decoded(8);
                data := decoded(7 downto 0);
                if code_err = '1' or disp_err = '1' then
                    fail("transmitter put an invalid symbol on the wire: " & to_string(in_data));
                end if;

                -- Monitor: IDLE structure and cadence
                if ctrl = '1' and data = COMMA_CHAR then
                    if first_comma then
                        if chars_since_comma > max_gap then
                            max_gap := chars_since_comma;
                        end if;
                        if chars_since_comma > IDLE_BOUND_CHARS then
                            fail("comma to comma gap of " & to_string(chars_since_comma) & " exceeds the 5000 bound");
                        end if;
                    end if;
                    first_comma := true;
                    chars_since_comma := 0;
                    commas_seen <= commas_seen + 1;
                    if nesting > 0 then
                        fail("IDLE inside a packet");
                        nesting := 0;
                    end if;
                    idle_state := 1;
                    flush(idle_fields);
                else
                    chars_since_comma := chars_since_comma + 1;
                end if;

                plain := data;
                if ctrl = '1' and data = COMMA_CHAR then
                    null;
                elsif idle_state > 0 then
                    case idle_state is
                        when 1 =>
                            if ctrl = '1' or not (data = POL_CHAR_A or data = POL_CHAR_B) then
                                fail("bad polarity character in IDLE");
                            end if;
                            push_byte(idle_fields, to_integer(data));
                            idle_state := 2;
                        when 2 =>
                            if ctrl = '1' then
                                fail("control character where the IDLE seed should be");
                            end if;
                            push_byte(idle_fields, to_integer(data));
                            idle_state := 3;
                        when 3 =>
                            if ctrl = '1' then
                                fail("control character where the IDLE flags should be");
                            end if;
                            push_byte(idle_fields, to_integer(data));
                            idle_state := 4;
                        when 4 =>
                            if not (ctrl = '1' and data = SKIP_CHAR) then
                                fail("IDLE skip character missing");
                            end if;
                            idle_state := 5;
                        when others =>
                            if ctrl = '1' then
                                fail("control character where the IDLE CRC should be");
                            elsif data /= crc8_atm(idle_fields) then
                                fail("IDLE CRC8 mismatch");
                            else
                                -- Scoreboard: the advertised seed is the state
                                -- for the next scrambled character.
                                dummy := pop_byte(idle_fields); -- polarity
                                lfsr := to_std_logic_vector(pop_byte(idle_fields), 8);
                                scrambled := to_std_logic_vector(pop_byte(idle_fields), 8)(IDLE_FLAG_SCRAMBLE) = '1';
                            end if;
                            idle_state := 0;
                    end case;
                elsif ctrl = '0' then
                    -- Every data character outside the IDLE is scrambled
                    if scrambled then
                        plain := data xor lfsr;
                    end if;
                    lfsr := lfsr8_next_char(lfsr);
                    if nesting = 0 and plain /= X"00" then
                        fail("filler did not de-scramble to zero, seed or keystream is off");
                    end if;
                    if nesting > 0 then
                        pkt_pos := pkt_pos + 1;
                        if pkt_pos = 1 then
                            push_byte(chan_order, to_integer(plain));
                        end if;
                    end if;
                elsif data = SOP_CHAR then
                    if nesting /= 0 then
                        fail("SOP inside a packet");
                    end if;
                    nesting := 1;
                    pkt_pos := 0;
                    packets_seen <= packets_seen + 1;
                elsif data = PREEMPT_CHAR then
                    if nesting /= 1 then
                        fail("preempt character at nesting depth " & to_string(nesting));
                    end if;
                    nesting := 2;
                    pkt_pos := 0;
                    packets_seen <= packets_seen + 1;
                elsif data = EOP_CHAR then
                    if nesting = 0 then
                        fail("EOP with no packet open");
                    else
                        nesting := nesting - 1;
                    end if;
                elsif data = SKIP_CHAR then
                    fail("skip character outside an IDLE");
                else
                    fail("unexpected control character " & to_hstring(data));
                end if;
                monitor_errors <= errors;
                max_comma_gap <= max_gap;

                -- Injection: decide whether the held character is the anchor,
                -- now that the one after it is known.
                if hold_valid then
                    if op_armed and not op_counting then
                        anchor_hit := false;
                        case op.anchor is
                            when ANCHOR_SOP =>
                                anchor_hit := hold_is_sop and (op.chan < 0 or (ctrl = '0' and to_integer(plain) = op.chan));
                            when ANCHOR_COMMA =>
                                anchor_hit := hold_is_comma;
                            when ANCHOR_PREEMPT =>
                                anchor_hit := hold_is_preempt and (op.chan < 0 or (ctrl = '0' and to_integer(plain) = op.chan));
                            when ANCHOR_EOP =>
                                anchor_hit := hold_is_eop;
                        end case;
                        if anchor_hit then
                            op_counting := true;
                            op_count := 0;
                        end if;
                    end if;
                    release_hold;
                end if;
                hold_word := in_data;
                hold_valid := true;
                hold_is_sop := ctrl = '1' and data = SOP_CHAR;
                hold_is_comma := ctrl = '1' and data = COMMA_CHAR;
                hold_is_preempt := ctrl = '1' and data = PREEMPT_CHAR;
                hold_is_eop := ctrl = '1' and data = EOP_CHAR;
            end if;

            -- Keep a small backlog so the output never starves
            if qdepth < 2 then
                in_ready <= '1';
            else
                in_ready <= '0';
            end if;
            depth <= qdepth;
        end if;
    end process;

    msg_handler: process
        variable self : actor_t;
        variable msg_type : msg_type_t;
        variable request_msg : msg_t;
        variable reply_msg : msg_t;
        variable req : op_t;
    begin
        self := new_actor(actor_name);
        loop
            receive(net, self, request_msg);
            msg_type := message_type(request_msg);
            if msg_type = wire_set_invert_msg then
                invert <= pop_boolean(request_msg);
            elsif msg_type = wire_op_msg then
                req.op := wire_op_t'val(pop_integer(request_msg));
                req.anchor := wire_anchor_t'val(pop_integer(request_msg));
                req.chan := pop_integer(request_msg);
                req.offset := pop_integer(request_msg);
                req.bit := pop_integer(request_msg);
                req.ctrl := pop_std_ulogic(request_msg);
                req.data := pop_std_ulogic_vector(request_msg);
                req.chars := pop_queue_ref(request_msg);
                if op_busy = '1' then
                    wait until op_busy = '0';
                end if;
                op_req <= req;
                op_valid <= '1';
                wait until op_busy = '1';
                op_valid <= '0';
            elsif msg_type = wire_wait_idle_msg then
                if op_busy = '1' then
                    wait until op_busy = '0';
                end if;
                reply_msg := new_msg;
                reply(net, request_msg, reply_msg);
            elsif msg_type = wire_pop_chan_msg then
                if is_empty(chan_order) then
                    wait until not is_empty(chan_order) for 1 ms;
                end if;
                reply_msg := new_msg;
                if is_empty(chan_order) then
                    push_integer(reply_msg, -1);
                else
                    push_integer(reply_msg, pop_byte(chan_order));
                end if;
                reply(net, request_msg, reply_msg);
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;
        wait;
    end process;

end model;
