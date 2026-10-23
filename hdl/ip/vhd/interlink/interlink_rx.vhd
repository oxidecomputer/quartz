-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.interlink_pkg.all;
use work.crc16_pkg.all;

-- Receive deframer. Parses the IDLE sequences for the lock state machine,
-- de-scrambles the stream, and turns packets back into per-channel byte
-- streams.
--
-- Delivery is cut-through. Payload length is not in the header, so the only
-- way to know a byte was payload rather than CRC is to see what follows it:
-- bytes sit in a three deep delay line and come out when a fourth arrives,
-- or at the EOP, which is also when we learn whether the packet was good.
--
-- Two parse contexts, one for the packet on the wire and one for a packet
-- that preempted it. An EOP closes the newest open packet, so the outer one
-- just stays frozen until the preempting one is done.
entity interlink_rx is
    generic (
        NUM_CHANNELS : positive;
        STATS_RX_ENABLE : boolean
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        rx_char : view char_source'converse;
        -- Qualifies rx_char.valid: the decoder could not make sense of this
        -- symbol.
        rx_code_err : in std_logic;
        rx_locked : in std_logic;
        descramble_enable : in std_logic;

        -- IDLE parsing results for the lock state machine, single cycle.
        idle_good : out std_logic;
        idle_bad : out std_logic;
        pol_valid : out std_logic;
        pol_inverted : out std_logic;
        partner_flags : out std_logic_vector(7 downto 0);

        -- Delivered packet streams, indexed by ChannelID. 0 is statistics.
        rx_chans : view (rx_source) of rx_st_array_t(0 to NUM_CHANNELS);

        -- Only the receive-side bits are ever set.
        events : out link_events_t
    );
end entity;

architecture rtl of interlink_rx is
    type state_t is (
        HUNT, IDLE_POL, IDLE_SEED, IDLE_FLAGS, IDLE_SKIP_OR_CRC,
        HDR_CHAN, HDR_SEQ, HDR_CRC, PAYLOAD
    );
    subtype chan_idx_t is natural range 0 to NUM_CHANNELS;
    type seq_array_t is array (chan_idx_t) of unsigned(7 downto 0);

    type ctx_t is record
        is_open : std_logic;
        -- Header was bad or the packet ran too long: swallow it to the EOP.
        dropping : std_logic;
        bad : std_logic;
        -- bytes held back, d2 oldest; nothing is delivered until 3 are in
        fill : natural range 0 to 3;
        d0 : std_logic_vector(7 downto 0);
        d1 : std_logic_vector(7 downto 0);
        d2 : std_logic_vector(7 downto 0);
        crc : crc16_t;
        -- beats delivered so far; 0 = consumer has seen none of this packet
        emitted : unsigned(7 downto 0);
        chan : chan_idx_t;
    end record;
    constant ctx_reset : ctx_t := (
        is_open => '0',
        dropping => '0',
        bad => '0',
        fill => 0,
        d0 => (others => '0'),
        d1 => (others => '0'),
        d2 => (others => '0'),
        crc => crc16_init,
        emitted => (others => '0'),
        chan => 0
    );
    type ctx_array_t is array (0 to 1) of ctx_t;

    type reg_t is record
        state : state_t;
        ctx : ctx_array_t;
        active : natural range 0 to 1;
        seed_tmp : std_logic_vector(7 downto 0);
        flags_tmp : std_logic_vector(7 downto 0);
        partner_flags : std_logic_vector(7 downto 0);
        hdr_chan : std_logic_vector(7 downto 0);
        hdr_seq : std_logic_vector(7 downto 0);
        exp_seq : seq_array_t;
        seq_synced : std_logic_vector(chan_idx_t);
        -- One shared output beat, demuxed onto the channels by out_chan
        out_valid : std_logic;
        out_last : std_logic;
        out_error : std_logic;
        out_data : std_logic_vector(7 downto 0);
        out_chan : chan_idx_t;
        -- A second beat that could not go out this cycle
        flush_pending : std_logic;
        flush_error : std_logic;
        flush_data : std_logic_vector(7 downto 0);
        flush_chan : chan_idx_t;
        events : link_events_t;
        idle_good : std_logic;
        idle_bad : std_logic;
        pol_valid : std_logic;
        pol_inverted : std_logic;
    end record;
    constant rec_reset : reg_t := (
        state => HUNT,
        ctx => (others => ctx_reset),
        active => 0,
        seed_tmp => (others => '0'),
        flags_tmp => (others => '0'),
        partner_flags => (others => '0'),
        hdr_chan => (others => '0'),
        hdr_seq => (others => '0'),
        exp_seq => (others => (others => '0')),
        seq_synced => (others => '0'),
        out_valid => '0',
        out_last => '0',
        out_error => '0',
        out_data => (others => '0'),
        out_chan => 0,
        flush_pending => '0',
        flush_error => '0',
        flush_data => (others => '0'),
        flush_chan => 0,
        events => (others => '0'),
        idle_good => '0',
        idle_bad => '0',
        pol_valid => '0',
        pol_inverted => '0'
    );

    signal r, rin : reg_t;
    signal in_idle : std_logic;
    signal in_packet : std_logic;
    signal raw_data : std_logic_vector(7 downto 0);
    signal descrambled_data : std_logic_vector(7 downto 0);
    signal byte : std_logic_vector(7 downto 0);
    signal data_valid : std_logic;
    signal lfsr_advance : std_logic;
    signal lfsr_state : std_logic_vector(7 downto 0);
    signal seed_load : std_logic;
    signal crc8_out : std_logic_vector(7 downto 0);
    signal crc8_enable : std_logic;
    signal crc8_clear : std_logic;
begin

    idle_good <= r.idle_good;
    idle_bad <= r.idle_bad;
    pol_valid <= r.pol_valid;
    pol_inverted <= r.pol_inverted;
    partner_flags <= r.partner_flags;
    events <= r.events;
    rx_char.ready <= '1';

    in_idle <= '1' when r.state = IDLE_POL or r.state = IDLE_SEED or r.state = IDLE_FLAGS or
                        r.state = IDLE_SKIP_OR_CRC else '0';
    in_packet <= '1' when r.state = HDR_CHAN or r.state = HDR_SEQ or r.state = HDR_CRC or
                          r.state = PAYLOAD else '0';

    raw_data <= rx_char.data;
    data_valid <= rx_char.valid and not rx_char.ctrl and not rx_code_err;

    -- The LFSR advances on every data character outside the IDLE whether we
    -- apply it or not, including ones the decoder flagged: a flagged symbol
    -- is almost always a data character, and skipping the advance would put
    -- us out of step until the next IDLE. The xor itself waits for lock.
    lfsr_advance <= rx_char.valid and not in_idle and (not rx_char.ctrl or rx_code_err);
    -- The seed is the state applied to the first scrambled character after
    -- the IDLE, which at one character per clock is the very next cycle. A
    -- load beats an advance in the scrambler, so it has to be issued in the
    -- cycle the IDLE CRC lands, straight off the compare.
    seed_load <= '1' when r.state = IDLE_SKIP_OR_CRC and data_valid = '1' and raw_data = crc8_out else '0';
    scrambler_lfsr8_inst: entity work.scrambler_lfsr8
        port map (
            clk => clk,
            reset => reset,
            sync_reset => '0',
            load_valid => seed_load,
            load_data => r.seed_tmp,
            data_in => raw_data,
            data_valid => lfsr_advance,
            data_out => descrambled_data,
            lfsr_state => lfsr_state
        );
    -- IDLE fields are sent in clear
    byte <= descrambled_data when descramble_enable = '1' and in_idle = '0' else raw_data;

    -- Shared between the IDLE fields and the packet header, since a comma
    -- inside a packet ends the packet anyway.
    crc8_enable <= data_valid when r.state = IDLE_POL or r.state = IDLE_SEED or r.state = IDLE_FLAGS or
                                   r.state = HDR_CHAN or r.state = HDR_SEQ else '0';
    crc8_clear <= '1' when rx_char.valid = '1' and rx_char.ctrl = '1' and rx_code_err = '0' and
                           (raw_data = COMMA_CHAR or raw_data = SOP_CHAR or raw_data = PREEMPT_CHAR) else '0';
    crc8atm_8wide_inst: entity work.crc8atm_8wide
        port map (
            clk => clk,
            reset => reset,
            data_in => byte,
            enable => crc8_enable,
            clear => crc8_clear,
            crc_out => crc8_out
        );

    out_gen: for i in 0 to NUM_CHANNELS generate
        rx_chans(i).valid <= r.out_valid when r.out_chan = i else '0';
        rx_chans(i).last <= r.out_last;
        rx_chans(i).error <= r.out_error;
        rx_chans(i).data <= r.out_data;
    end generate;

    sm: process(all)
        variable v : reg_t;
        variable st : state_t;
        variable a : natural range 0 to 1;
        variable chan : natural range 0 to 255;
        variable residue : crc16_t;

        -- Put one beat on the output. Two in one cycle can only happen when
        -- both contexts are torn down at once; the second waits a cycle in
        -- the flush register, and the header that follows guarantees nothing
        -- else wants the output before it drains.
        procedure emit (
            data : std_logic_vector(7 downto 0);
            chan : chan_idx_t;
            last : std_logic;
            error : std_logic
        ) is
        begin
            if v.out_valid = '0' then
                v.out_valid := '1';
                v.out_data := data;
                v.out_chan := chan;
                v.out_last := last;
                v.out_error := error;
            else
                v.flush_pending := '1';
                v.flush_data := data;
                v.flush_chan := chan;
                v.flush_error := error;
            end if;
        end procedure;

        -- Tear a context down. If the consumer has already seen beats of
        -- this packet it gets a terminating one so the stream never dangles;
        -- if it has not, nothing goes out and only the counter records it.
        procedure close (
            i : natural range 0 to 1;
            error : std_logic
        ) is
        begin
            if v.ctx(i).is_open = '1' and v.ctx(i).dropping = '0' and v.ctx(i).emitted /= 0 then
                emit(v.ctx(i).d2, v.ctx(i).chan, '1', error);
            end if;
            v.ctx(i).is_open := '0';
            v.ctx(i).dropping := '0';
            v.ctx(i).bad := '0';
            v.ctx(i).fill := 0;
        end procedure;

        procedure open_ctx (
            i : natural range 0 to 1
        ) is
        begin
            v.ctx(i) := ctx_reset;
            v.ctx(i).is_open := '1';
        end procedure;

        -- Close every open packet as lost. Used for anything that cannot
        -- legally appear inside a packet.
        procedure abandon_all is
        begin
            if v.ctx(1).is_open = '1' then
                close(1, '1');
                v.events(EV_RX_FRAMING_ERR) := '1';
            end if;
            if v.ctx(0).is_open = '1' then
                close(0, '1');
                v.events(EV_RX_FRAMING_ERR) := '1';
            end if;
            v.active := 0;
        end procedure;

        -- A packet ended normally: classify it from the CRC residue and
        -- deliver the last byte.
        procedure finish (
            i : natural range 0 to 1
        ) is
        begin
            if v.ctx(i).dropping = '1' then
                null;
            elsif v.ctx(i).fill >= 2 then
                residue := v.ctx(i).crc;
                if v.ctx(i).fill = 3 then
                    emit(v.ctx(i).d2, v.ctx(i).chan, '1',
                         v.ctx(i).bad or (residue ?/= crc16_residue_good));
                end if;
                if residue = crc16_residue_abort then
                    v.events(EV_RX_ABORTED) := '1';
                elsif residue /= crc16_residue_good then
                    v.events(EV_RX_CRC16_ERR) := '1';
                elsif v.ctx(i).bad = '0' then
                    v.events(EV_RX_PKTS) := '1';
                end if;
            else
                -- Not even room for the CRC
                v.events(EV_RX_FRAMING_ERR) := '1';
            end if;
            v.ctx(i).is_open := '0';
            v.ctx(i).dropping := '0';
            v.ctx(i).bad := '0';
            v.ctx(i).fill := 0;
        end procedure;

        -- Start parsing a packet into a context.
        procedure start_packet (
            i : natural range 0 to 1
        ) is
        begin
            open_ctx(i);
            v.active := i;
            v.state := HDR_CHAN;
        end procedure;
    begin
        v := r;
        v.out_valid := '0';
        v.events := (others => '0');
        v.idle_good := '0';
        v.idle_bad := '0';
        v.pol_valid := '0';
        -- st is the state to act on; it gets overridden below when an
        -- IDLE is cut short or lock drops
        st := r.state;
        a := r.active;

        if r.flush_pending = '1' then
            v.flush_pending := '0';
            emit(r.flush_data, r.flush_chan, '1', r.flush_error);
        end if;

        -- Losing lock loses whatever was in flight; the IDLE parser keeps
        -- going since that is how we get lock back.
        if rx_locked = '0' then
            if in_packet = '1' then
                st := HUNT;
                v.state := HUNT;
            end if;
            abandon_all;
            v.seq_synced := (others => '0');
        end if;

        if rx_char.valid = '1' then
            if rx_code_err = '1' then
                -- Whatever this was, the packet it landed in is suspect. We
                -- do not try to guess what it should have been.
                v.events(EV_RX_CODE_ERR) := '1';
                if st = PAYLOAD then
                    v.ctx(a).bad := '1';
                elsif in_packet = '1' then
                    -- The header cannot be checked with a byte missing, and
                    -- parsing on would take the wrong bytes as the fields.
                    v.ctx(a).dropping := '1';
                    v.state := PAYLOAD;
                elsif in_idle = '1' then
                    v.idle_bad := '1';
                    v.events(EV_RX_IDLE_BAD) := '1';
                    v.state := HUNT;
                end if;
            elsif rx_char.ctrl = '1' then
                -- Only a skip is at home inside an IDLE. Anything else cuts
                -- the IDLE short and is then handled as if we were hunting.
                if in_idle = '1' and not (raw_data = SKIP_CHAR and r.state = IDLE_SKIP_OR_CRC) then
                    v.idle_bad := '1';
                    v.events(EV_RX_IDLE_BAD) := '1';
                    st := HUNT;
                    v.state := HUNT;
                end if;

                if raw_data = COMMA_CHAR then
                    abandon_all;
                    v.state := IDLE_POL;
                elsif raw_data = SKIP_CHAR then
                    -- Elastic buffers may add or drop these; harmless anywhere.
                    null;
                elsif rx_locked = '0' then
                    -- Not parsing packets yet
                    null;
                elsif raw_data = SOP_CHAR then
                    -- A plain SOP ends everything that was open (the RFD's
                    -- re-sequencing rule) and starts afresh.
                    if v.ctx(0).is_open = '1' or v.ctx(1).is_open = '1' then
                        abandon_all;
                    end if;
                    start_packet(0);
                elsif raw_data = PREEMPT_CHAR then
                    if a = 0 and v.ctx(0).is_open = '1' and st = PAYLOAD then
                        v.events(EV_RX_PREEMPTIONS) := '1';
                        start_packet(1);
                    elsif a = 1 then
                        -- Nesting deeper than one is not allowed. The RFD does
                        -- not say what this means, so the newest packet is
                        -- taken as the one that was lost.
                        close(1, '1');
                        v.events(EV_RX_FRAMING_ERR) := '1';
                        start_packet(1);
                    else
                        -- Nothing to preempt, or the outer packet has not got
                        -- past its header. Treat it as a start of packet.
                        if v.ctx(0).is_open = '1' then
                            close(0, '1');
                        end if;
                        v.events(EV_RX_FRAMING_ERR) := '1';
                        start_packet(0);
                    end if;
                elsif raw_data = EOP_CHAR then
                    case st is
                        when PAYLOAD =>
                            finish(a);
                            if a = 1 then
                                -- The outer packet picks up where it stopped
                                v.active := 0;
                                v.state := PAYLOAD;
                            else
                                v.state := HUNT;
                            end if;
                        when HDR_CHAN | HDR_SEQ | HDR_CRC =>
                            close(a, '1');
                            v.events(EV_RX_FRAMING_ERR) := '1';
                            if a = 1 then
                                v.active := 0;
                                v.state := PAYLOAD;
                            else
                                v.state := HUNT;
                            end if;
                        when others =>
                            v.events(EV_RX_FRAMING_ERR) := '1';
                    end case;
                else
                    v.events(EV_RX_FRAMING_ERR) := '1';
                end if;
            else
                case st is
                    when HUNT =>
                        -- Filler, or a packet we are not locked enough to read
                        null;

                    when IDLE_POL =>
                        if raw_data = POL_CHAR_A or raw_data = POL_CHAR_B then
                            v.pol_valid := '1';
                            v.pol_inverted := '0';
                            v.state := IDLE_SEED;
                        elsif raw_data = POL_CHAR_A_INV or raw_data = POL_CHAR_B_INV then
                            v.pol_valid := '1';
                            v.pol_inverted := '1';
                            v.state := IDLE_SEED;
                        else
                            v.idle_bad := '1';
                            v.events(EV_RX_IDLE_BAD) := '1';
                            v.state := HUNT;
                        end if;
                    when IDLE_SEED =>
                        v.seed_tmp := raw_data;
                        v.state := IDLE_FLAGS;
                    when IDLE_FLAGS =>
                        v.flags_tmp := raw_data;
                        v.state := IDLE_SKIP_OR_CRC;
                    when IDLE_SKIP_OR_CRC =>
                        if raw_data = crc8_out then
                            v.idle_good := '1';
                            v.partner_flags := r.flags_tmp;
                        else
                            v.idle_bad := '1';
                            v.events(EV_RX_IDLE_BAD) := '1';
                        end if;
                        v.state := HUNT;

                    when HDR_CHAN =>
                        v.hdr_chan := byte;
                        v.state := HDR_SEQ;
                    when HDR_SEQ =>
                        v.hdr_seq := byte;
                        v.state := HDR_CRC;
                    when HDR_CRC =>
                        chan := to_integer(unsigned(r.hdr_chan));
                        if byte /= crc8_out then
                            v.events(EV_RX_CRC8_ERR) := '1';
                            v.ctx(a).dropping := '1';
                        elsif chan > NUM_CHANNELS then
                            v.events(EV_RX_FRAMING_ERR) := '1';
                            v.ctx(a).dropping := '1';
                        elsif chan = STATS_CHANNEL and not STATS_RX_ENABLE then
                            -- The RFD lets a partner send statistics we do
                            -- not decode, so this is not an error.
                            v.ctx(a).dropping := '1';
                        else
                            v.ctx(a).chan := chan;
                            -- Sequence numbers only mean something once we
                            -- have seen one; the first packet after lock just
                            -- sets the expectation.
                            if r.seq_synced(chan) = '1' and unsigned(r.hdr_seq) /= r.exp_seq(chan) then
                                v.events(EV_RX_SEQ_ERR) := '1';
                            end if;
                            v.exp_seq(chan) := unsigned(r.hdr_seq) + 1;
                            v.seq_synced(chan) := '1';
                        end if;
                        v.state := PAYLOAD;

                    when PAYLOAD =>
                        if v.ctx(a).dropping = '0' then
                            if r.ctx(a).fill = 3 then
                                -- A fourth byte beyond the maximum payload
                                -- cannot be the CRC, so the packet is longer
                                -- than the protocol allows. End the stream
                                -- now rather than wait for an EOP that may
                                -- never come.
                                if r.ctx(a).emitted = MAX_PAYLOAD_BYTES - 1 then
                                    emit(r.ctx(a).d2, r.ctx(a).chan, '1', '1');
                                    v.ctx(a).dropping := '1';
                                    v.events(EV_RX_FRAMING_ERR) := '1';
                                else
                                    emit(r.ctx(a).d2, r.ctx(a).chan, '0', '0');
                                    v.ctx(a).emitted := r.ctx(a).emitted + 1;
                                end if;
                            else
                                v.ctx(a).fill := r.ctx(a).fill + 1;
                            end if;
                            v.ctx(a).d2 := r.ctx(a).d1;
                            v.ctx(a).d1 := r.ctx(a).d0;
                            v.ctx(a).d0 := byte;
                            v.ctx(a).crc := crc16_next(r.ctx(a).crc, byte);
                        end if;
                end case;
            end if;
        end if;

        rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;
