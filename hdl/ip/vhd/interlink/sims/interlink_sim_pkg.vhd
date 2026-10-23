-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library vunit_lib;
    context vunit_lib.com_context;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;
use work.interlink_pkg.all;
use work.crc_sim_pkg.all;

-- Testbench helpers for the interlink: the stream verification components
-- for both link ends, packet builders and comparisons, and the message
-- interface to the wire model that sits between the two ends.
package interlink_sim_pkg is

    constant sim_num_channels : positive := 4;
    constant sim_preempt_channel : natural := 1;

    type source_array_t is array (natural range <>) of basic_source_t;
    type sink_array_t is array (natural range <>) of basic_sink_t;

    -- One source and one sink per user channel at each end
    constant a_sources : source_array_t(1 to sim_num_channels) := (
        new_basic_source(8), new_basic_source(8), new_basic_source(8), new_basic_source(8));
    constant b_sources : source_array_t(1 to sim_num_channels) := (
        new_basic_source(8), new_basic_source(8), new_basic_source(8), new_basic_source(8));
    constant a_sinks : sink_array_t(1 to sim_num_channels) := (
        new_basic_sink(8), new_basic_sink(8), new_basic_sink(8), new_basic_sink(8));
    constant b_sinks : sink_array_t(1 to sim_num_channels) := (
        new_basic_sink(8), new_basic_sink(8), new_basic_sink(8), new_basic_sink(8));

    -- Deterministic payload: byte i is (seed + i) mod 256
    impure function make_payload (len : natural; seed : natural := 0) return queue_t;

    -- Queue every byte of a payload at a source. The source presents them
    -- back to back, last on the final one.
    procedure send_packet (
        signal net : inout network_t;
        source : basic_source_t;
        payload : queue_t
    );

    -- Pop the next packet from a sink and compare it with what was sent.
    procedure check_packet (
        signal net : inout network_t;
        sink : basic_sink_t;
        expected : queue_t;
        expect_error : boolean := false;
        msg : string := ""
    );

    -- Wire model control. An operation arms on the next anchor character
    -- seen on the wire and acts on the character `offset` positions after it
    -- (the anchor itself is offset 0). One operation can be pending at a time.
    type wire_anchor_t is (ANCHOR_SOP, ANCHOR_COMMA, ANCHOR_PREEMPT, ANCHOR_EOP);
    type wire_op_t is (OP_NONE, OP_FLIP, OP_DELETE, OP_DUPLICATE, OP_REPLACE, OP_INSERT);

    constant wire_set_invert_msg : msg_type_t := new_msg_type("wire set invert");
    constant wire_op_msg : msg_type_t := new_msg_type("wire op");
    constant wire_wait_idle_msg : msg_type_t := new_msg_type("wire wait idle");
    constant wire_pop_chan_msg : msg_type_t := new_msg_type("wire pop chan");

    procedure wire_set_invert (
        signal net : inout network_t;
        wire : actor_t;
        invert : boolean
    );
    -- For SOP and PREEMPT anchors, chan restricts the anchor to packets on
    -- that ChannelID; -1 matches any. Other anchors ignore it.
    -- Flip one bit of the 10-bit symbol
    procedure wire_flip_bit (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        bit : natural range 0 to 9;
        chan : integer := -1
    );
    procedure wire_delete (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        chan : integer := -1
    );
    procedure wire_duplicate (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        chan : integer := -1
    );
    -- Replace the character with another, encoded with the running disparity
    procedure wire_replace (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        ctrl : std_logic;
        data : std_logic_vector(7 downto 0);
        chan : integer := -1
    );
    -- Insert a sequence of 9-bit (ctrl & data) characters ahead of the
    -- character at the offset
    procedure wire_insert (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        chars : queue_t;
        chan : integer := -1
    );
    -- Next ChannelID the wire saw a packet start for, in order, -1 if none
    -- shows up within a millisecond.
    procedure wire_pop_chan (
        signal net : inout network_t;
        wire : actor_t;
        variable chan : out integer
    );
    -- Block until the pending operation has been applied
    procedure wire_wait_idle (
        signal net : inout network_t;
        wire : actor_t
    );

    -- Build the characters of a well-formed packet, for injecting raw
    -- packets the transmit side cannot produce (such as zero-length ones).
    impure function build_packet_chars (
        chan : natural;
        seq : natural;
        payload : queue_t;
        preempt : boolean := false
    ) return queue_t;

    procedure push_char (
        queue : queue_t;
        ctrl : std_logic;
        data : std_logic_vector(7 downto 0)
    );

    -- crc8_atm as a plain 8-bit vector, for building raw characters
    impure function crc8_atm_byte (data : queue_t) return std_logic_vector;

end package;

package body interlink_sim_pkg is

    impure function make_payload (len : natural; seed : natural := 0) return queue_t is
        variable q : queue_t := new_queue;
    begin
        for i in 0 to len - 1 loop
            push_byte(q, (seed + i) mod 256);
        end loop;
        return q;
    end function;

    procedure send_packet (
        signal net : inout network_t;
        source : basic_source_t;
        payload : queue_t
    ) is
        constant copied : queue_t := copy(payload);
        variable byte : natural;
    begin
        while not is_empty(copied) loop
            byte := pop_byte(copied);
            push_basic_pkt_stream(net, source, to_std_logic_vector(byte, 8), last => is_empty(copied));
        end loop;
    end procedure;

    procedure check_packet (
        signal net : inout network_t;
        sink : basic_sink_t;
        expected : queue_t;
        expect_error : boolean := false;
        msg : string := ""
    ) is
        constant copied : queue_t := copy(expected);
        variable got : queue_t;
        variable err : boolean;
        variable idx : natural := 0;
    begin
        pop_basic_pkt(net, sink, got, err);
        while not is_empty(copied) loop
            if is_empty(got) then
                check_failed(msg & ": received packet is short, ended at byte " & to_string(idx));
                exit;
            end if;
            check_equal(pop_std_ulogic_vector(got), to_std_logic_vector(pop_byte(copied), 8), msg & ": byte " & to_string(idx));
            idx := idx + 1;
        end loop;
        check_true(is_empty(got), msg & ": received packet is long");
        check_equal(err, expect_error, msg & ": error flag");
    end procedure;

    procedure wire_set_invert (
        signal net : inout network_t;
        wire : actor_t;
        invert : boolean
    ) is
        variable msg : msg_t := new_msg(wire_set_invert_msg);
    begin
        push_boolean(msg, invert);
        send(net, wire, msg);
    end procedure;

    procedure send_wire_op (
        signal net : inout network_t;
        wire : actor_t;
        op : wire_op_t;
        anchor : wire_anchor_t;
        offset : natural;
        chan : integer;
        bit : natural := 0;
        ctrl : std_logic := '0';
        data : std_logic_vector(7 downto 0) := X"00";
        chars : queue_t := null_queue
    ) is
        variable msg : msg_t := new_msg(wire_op_msg);
        variable q : queue_t;
    begin
        push_integer(msg, wire_op_t'pos(op));
        push_integer(msg, wire_anchor_t'pos(anchor));
        push_integer(msg, chan);
        push_integer(msg, offset);
        push_integer(msg, bit);
        push_std_ulogic(msg, ctrl);
        push_std_ulogic_vector(msg, data);
        if chars = null_queue then
            q := new_queue;
        else
            q := copy(chars);
        end if;
        push_queue_ref(msg, q);
        send(net, wire, msg);
    end procedure;

    procedure wire_flip_bit (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        bit : natural range 0 to 9;
        chan : integer := -1
    ) is
    begin
        send_wire_op(net, wire, OP_FLIP, anchor, offset, chan, bit => bit);
    end procedure;

    procedure wire_delete (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        chan : integer := -1
    ) is
    begin
        send_wire_op(net, wire, OP_DELETE, anchor, offset, chan);
    end procedure;

    procedure wire_duplicate (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        chan : integer := -1
    ) is
    begin
        send_wire_op(net, wire, OP_DUPLICATE, anchor, offset, chan);
    end procedure;

    procedure wire_replace (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        ctrl : std_logic;
        data : std_logic_vector(7 downto 0);
        chan : integer := -1
    ) is
    begin
        send_wire_op(net, wire, OP_REPLACE, anchor, offset, chan, ctrl => ctrl, data => data);
    end procedure;

    procedure wire_insert (
        signal net : inout network_t;
        wire : actor_t;
        anchor : wire_anchor_t;
        offset : natural;
        chars : queue_t;
        chan : integer := -1
    ) is
    begin
        send_wire_op(net, wire, OP_INSERT, anchor, offset, chan, chars => chars);
    end procedure;

    procedure wire_pop_chan (
        signal net : inout network_t;
        wire : actor_t;
        variable chan : out integer
    ) is
        variable msg : msg_t := new_msg(wire_pop_chan_msg);
        variable reply_msg : msg_t;
    begin
        send(net, wire, msg);
        receive_reply(net, msg, reply_msg);
        chan := pop_integer(reply_msg);
        delete(msg);
        delete(reply_msg);
    end procedure;

    procedure wire_wait_idle (
        signal net : inout network_t;
        wire : actor_t
    ) is
        variable msg : msg_t := new_msg(wire_wait_idle_msg);
        variable reply_msg : msg_t;
    begin
        send(net, wire, msg);
        receive_reply(net, msg, reply_msg);
        delete(msg);
        delete(reply_msg);
    end procedure;

    procedure push_char (
        queue : queue_t;
        ctrl : std_logic;
        data : std_logic_vector(7 downto 0)
    ) is
    begin
        push_std_ulogic_vector(queue, ctrl & data);
    end procedure;

    impure function crc8_atm_byte (data : queue_t) return std_logic_vector is
        variable ret : std_logic_vector(7 downto 0);
    begin
        ret := crc8_atm(data);
        return ret;
    end function;

    impure function build_packet_chars (
        chan : natural;
        seq : natural;
        payload : queue_t;
        preempt : boolean := false
    ) return queue_t is
        constant copied : queue_t := copy(payload);
        variable q : queue_t := new_queue;
        variable hdr : queue_t := new_queue;
        variable crc16 : std_logic_vector(15 downto 0);
    begin
        push_byte(hdr, chan);
        push_byte(hdr, seq);
        crc16 := crc16_ccitt(payload);
        if preempt then
            push_char(q, '1', PREEMPT_CHAR);
        else
            push_char(q, '1', SOP_CHAR);
        end if;
        push_char(q, '0', to_std_logic_vector(chan, 8));
        push_char(q, '0', to_std_logic_vector(seq, 8));
        push_char(q, '0', crc8_atm(hdr));
        while not is_empty(copied) loop
            push_char(q, '0', to_std_logic_vector(pop_byte(copied), 8));
        end loop;
        push_char(q, '0', crc16(15 downto 8));
        push_char(q, '0', crc16(7 downto 0));
        push_char(q, '1', EOP_CHAR);
        return q;
    end function;

end package body;
