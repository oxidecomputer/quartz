-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.interlink_pkg.all;
use work.crc16_pkg.all;
use work.axi_st8_pkg;

-- Transmit framer. Takes packets from the per-channel sources, wraps them in
-- the RFD 693 framing, keeps the IDLE cadence up and scrambles everything
-- that is not a control character. The output is a continuous stream of
-- characters, one per tx_char.ready, with scrambled zeros filling the gaps.
--
-- Arbitration is round-robin across the channels, except that one channel
-- (PREEMPT_CHANNEL) may interrupt a packet that is already on the wire. The
-- RFD allows one level of nesting; we also allow at most one preemption per
-- interrupted packet, which is what keeps the IDLE cadence bound honest when
-- the preemptor has an unbounded supply of packets.
entity interlink_tx is
    generic (
        NUM_CHANNELS : positive;
        -- ChannelID allowed to preempt, 0 for none. Channel 0 (statistics)
        -- stays in the round-robin and never preempts.
        PREEMPT_CHANNEL : natural;
        -- Byte cycles from one IDLE comma to the next.
        IDLE_INTERVAL_LOCKED : positive;
        IDLE_INTERVAL_FAST : positive
    );
    port (
        clk : in std_logic;
        reset : in std_logic;
        -- Sampled at the start of each IDLE and applied from the character
        -- after it, so the partner always hears about a change before it
        -- has to deal with it.
        scramble_enable : in std_logic;
        -- Go into the IDLE flags and pick the IDLE cadence.
        rx_locked : in std_logic;
        rx_polarity_inverted : in std_logic;
        partner_locked : in std_logic;

        -- Packet sources, indexed by ChannelID. Index 0 is the statistics
        -- source. A source must keep valid asserted from its first byte
        -- through last; dropping it mid-packet is an underrun.
        tx_chans : view (axi_st8_pkg.axi_st_pkt_source'converse) of axi_st8_pkg.axi_st_pkt_array_t(0 to NUM_CHANNELS);
        tx_char : view char_source;

        -- Single-cycle events for the counters
        pkt_sent : out std_logic;
        preempted : out std_logic;
        underrun : out std_logic;
        idle_sent : out std_logic
    );
end entity;

architecture rtl of interlink_tx is
    -- IDLE_* and SOP..EOP are in wire order
    type state_t is (
        IDLE_K, IDLE_POL, IDLE_SEED, IDLE_FLAGS, IDLE_SKIP, IDLE_CRC,
        FILL, SOP, CHAN, SEQ, HCRC, PAYLOAD, CRC_HI, CRC_LO, EOP
    );
    subtype chan_idx_t is natural range 0 to NUM_CHANNELS;
    type seq_array_t is array (chan_idx_t) of unsigned(7 downto 0);

    type reg_t is record
        state : state_t;
        sel : chan_idx_t;
        rr_ptr : chan_idx_t;
        seq : seq_array_t;
        -- Characters since the last comma went out
        idle_cnt : natural range 0 to IDLE_BOUND_CHARS;
        preempting : std_logic;
        outer_preempted : std_logic;
        outer_sel : chan_idx_t;
        outer_crc : crc16_t;
        crc : crc16_t;
        flags : std_logic_vector(7 downto 0);
        pol_b : std_logic;
        pkt_sent : std_logic;
        preempted : std_logic;
        underrun : std_logic;
        idle_sent : std_logic;
    end record;
    -- idle_cnt starts saturated so the first thing out after reset is an
    -- IDLE, which is the fastest way to give the partner something to lock to.
    constant rec_reset : reg_t := (
        state => IDLE_K,
        sel => 0,
        rr_ptr => 0,
        seq => (others => (others => '0')),
        idle_cnt => IDLE_BOUND_CHARS,
        preempting => '0',
        outer_preempted => '0',
        outer_sel => 0,
        outer_crc => crc16_init,
        crc => crc16_init,
        flags => (others => '0'),
        pol_b => '0',
        pkt_sent => '0',
        preempted => '0',
        underrun => '0',
        idle_sent => '0'
    );

    signal r, rin : reg_t;
    signal ready : std_logic;
    signal in_idle : std_logic;
    signal plain_ctrl : std_logic;
    signal plain_data : std_logic_vector(7 downto 0);
    signal scrambled_data : std_logic_vector(7 downto 0);
    signal lfsr_state : std_logic_vector(7 downto 0);
    signal lfsr_advance : std_logic;
    signal crc8_out : std_logic_vector(7 downto 0);
    signal crc8_enable : std_logic;
    signal crc8_clear : std_logic;
    signal idle_interval : natural range 0 to IDLE_BOUND_CHARS;
    signal idle_due : std_logic;
    signal preempt_wanted : std_logic;
    signal pol_char : std_logic_vector(7 downto 0);
begin

    -- The worst case gap between commas is the interval plus a full packet,
    -- a full preempting packet and the decision bubbles around them, which
    -- has to fit the elastic buffer budget the RFD derives 5000 from.
    assert IDLE_INTERVAL_LOCKED + 2 * MAX_PKT_CHARS + 4 <= IDLE_BOUND_CHARS
        report "interlink_tx: IDLE_INTERVAL_LOCKED leaves no room for two packets inside the 5000 character bound"
        severity failure;
    assert IDLE_INTERVAL_FAST <= IDLE_INTERVAL_LOCKED
        report "interlink_tx: IDLE_INTERVAL_FAST should not be slower than the locked interval"
        severity failure;
    assert PREEMPT_CHANNEL <= NUM_CHANNELS
        report "interlink_tx: PREEMPT_CHANNEL is not a user channel"
        severity failure;

    pkt_sent <= r.pkt_sent;
    preempted <= r.preempted;
    underrun <= r.underrun;
    idle_sent <= r.idle_sent;

    -- The serdes shifts zeros for any slot we leave empty, so we never do.
    tx_char.valid <= '1';
    ready <= tx_char.ready;

    in_idle <= '1' when r.state = IDLE_K or r.state = IDLE_POL or r.state = IDLE_SEED or
                        r.state = IDLE_FLAGS or r.state = IDLE_SKIP or r.state = IDLE_CRC else '0';

    pol_char <= POL_CHAR_B when r.pol_b = '1' else POL_CHAR_A;

    -- Plaintext character for the current slot, straight off the state so the
    -- serdes can take it whenever it is ready.
    plain_ctrl <= '1' when r.state = IDLE_K or r.state = IDLE_SKIP or r.state = SOP or r.state = EOP else '0';
    plain_data <= COMMA_CHAR when r.state = IDLE_K else
                  pol_char when r.state = IDLE_POL else
                  lfsr_state when r.state = IDLE_SEED else  -- state for the first scrambled char after this IDLE
                  r.flags when r.state = IDLE_FLAGS else
                  SKIP_CHAR when r.state = IDLE_SKIP else
                  crc8_out when r.state = IDLE_CRC or r.state = HCRC else
                  PREEMPT_CHAR when r.state = SOP and r.preempting = '1' else
                  SOP_CHAR when r.state = SOP else
                  std_logic_vector(to_unsigned(r.sel, 8)) when r.state = CHAN else
                  std_logic_vector(r.seq(r.sel)) when r.state = SEQ else
                  tx_chans(r.sel).data when r.state = PAYLOAD else
                  r.crc(15 downto 8) when r.state = CRC_HI else
                  r.crc(7 downto 0) when r.state = CRC_LO else
                  EOP_CHAR when r.state = EOP else
                  (others => '0');

    -- Everything that is a data character outside the IDLE is scrambled,
    -- filler included. The register advances regardless of whether the xor
    -- is applied so the seed we advertise stays meaningful either way.
    lfsr_advance <= ready and not plain_ctrl and not in_idle;
    scrambler_lfsr8_inst: entity work.scrambler_lfsr8
        port map (
            clk => clk,
            reset => reset,
            sync_reset => '0',
            load_valid => '0',
            load_data => (others => '0'),
            data_in => plain_data,
            data_valid => lfsr_advance,
            data_out => scrambled_data,
            lfsr_state => lfsr_state
        );

    tx_char.ctrl <= plain_ctrl;
    -- r.flags is what the last IDLE told the partner, not the live input
    tx_char.data <= scrambled_data when plain_ctrl = '0' and in_idle = '0' and r.flags(IDLE_FLAG_SCRAMBLE) = '1' else
                    plain_data;

    -- One CRC8 covers both the IDLE fields and the packet header since the
    -- two never overlap on the transmit side.
    crc8_enable <= ready when r.state = IDLE_POL or r.state = IDLE_SEED or r.state = IDLE_FLAGS or
                                 r.state = CHAN or r.state = SEQ else '0';
    crc8_clear <= '1' when r.state = IDLE_K or r.state = SOP else '0';
    crc8atm_8wide_inst: entity work.crc8atm_8wide
        port map (
            clk => clk,
            reset => reset,
            data_in => plain_data,
            enable => crc8_enable,
            clear => crc8_clear,
            crc_out => crc8_out
        );

    -- Send IDLEs quickly whenever either side is not locked. The partner's
    -- view comes from its IDLE flags, which is what that bit is for.
    idle_interval <= IDLE_INTERVAL_FAST when rx_locked = '0' or partner_locked = '0' else IDLE_INTERVAL_LOCKED;
    idle_due <= '1' when r.idle_cnt >= idle_interval else '0';

    -- A preemption only makes sense into someone else's payload, once.
    preempt_wanted <= '1' when PREEMPT_CHANNEL /= 0 and tx_chans(PREEMPT_CHANNEL).valid = '1' and
                               r.preempting = '0' and r.outer_preempted = '0' and
                               r.sel /= PREEMPT_CHANNEL else '0';

    chan_ready_gen: for i in 0 to NUM_CHANNELS generate
        tx_chans(i).ready <= '1' when r.state = PAYLOAD and r.sel = i and ready = '1' else '0';
    end generate;

    sm: process(all)
        variable v : reg_t;
        variable grant : chan_idx_t;
        variable grant_valid : std_logic;
        variable idx : chan_idx_t;

        -- What goes out next once the wire is free: a due IDLE beats any
        -- packet, the preemptor beats the round-robin, and failing all of
        -- that we send filler.
        procedure boundary is
        begin
            if idle_due = '1' then
                v.state := IDLE_K;
            elsif PREEMPT_CHANNEL /= 0 and tx_chans(PREEMPT_CHANNEL).valid = '1' then
                v.sel := PREEMPT_CHANNEL;
                v.state := SOP;
            elsif grant_valid = '1' then
                v.sel := grant;
                v.rr_ptr := grant;
                v.state := SOP;
            else
                v.state := FILL;
            end if;
        end procedure;
    begin
        v := r;
        v.pkt_sent := '0';
        v.preempted := '0';
        v.underrun := '0';
        v.idle_sent := '0';

        -- Rotating priority starting just past the last channel served. The
        -- preemptor has its own path so it is skipped here; with no preemptor
        -- configured (0) channel 0 is the statistics source and must stay in.
        grant := 0;
        grant_valid := '0';
        for i in 1 to NUM_CHANNELS + 1 loop
            idx := (r.rr_ptr + i) mod (NUM_CHANNELS + 1);
            if grant_valid = '0' and (PREEMPT_CHANNEL = 0 or idx /= PREEMPT_CHANNEL) and
               tx_chans(idx).valid = '1' then
                grant := idx;
                grant_valid := '1';
            end if;
        end loop;

        if ready = '1' then
            if r.idle_cnt < IDLE_BOUND_CHARS then
                v.idle_cnt := r.idle_cnt + 1;
            end if;

            case r.state is
                when IDLE_K =>
                    v.idle_cnt := 0;
                    v.flags := (others => '0');
                    v.flags(IDLE_FLAG_SCRAMBLE) := scramble_enable;
                    v.flags(IDLE_FLAG_LOCKED) := rx_locked;
                    v.flags(IDLE_FLAG_INVERTED) := rx_polarity_inverted;
                    -- Either polarity character does the job, the LFSR is a
                    -- free source of variety.
                    v.pol_b := lfsr_state(0);
                    v.state := IDLE_POL;
                when IDLE_POL =>
                    v.state := IDLE_SEED;
                when IDLE_SEED =>
                    v.state := IDLE_FLAGS;
                when IDLE_FLAGS =>
                    v.state := IDLE_SKIP;
                when IDLE_SKIP =>
                    v.state := IDLE_CRC;
                when IDLE_CRC =>
                    v.idle_sent := '1';
                    boundary;

                when FILL =>
                    boundary;

                when SOP =>
                    v.crc := crc16_init;
                    v.state := CHAN;
                when CHAN =>
                    v.state := SEQ;
                when SEQ =>
                    v.state := HCRC;
                when HCRC =>
                    v.state := PAYLOAD;

                when PAYLOAD =>
                    -- The byte on the bus went out this slot whether or not
                    -- it was valid. An invalid one is an underrun: close the
                    -- packet with the inverted CRC so the receiver can tell
                    -- it was abandoned rather than corrupted.
                    v.crc := crc16_next(r.crc, tx_chans(r.sel).data);
                    if tx_chans(r.sel).valid = '0' then
                        v.crc := not v.crc;
                        v.underrun := '1';
                        v.state := CRC_HI;
                    elsif tx_chans(r.sel).last = '1' then
                        v.state := CRC_HI;
                    elsif preempt_wanted = '1' then
                        v.outer_crc := v.crc;
                        v.outer_sel := r.sel;
                        v.outer_preempted := '1';
                        v.preempting := '1';
                        v.preempted := '1';
                        v.sel := PREEMPT_CHANNEL;
                        v.state := SOP;
                    end if;

                when CRC_HI =>
                    v.state := CRC_LO;
                when CRC_LO =>
                    v.state := EOP;
                when EOP =>
                    v.seq(r.sel) := r.seq(r.sel) + 1;
                    v.pkt_sent := '1';
                    if r.preempting = '1' then
                        -- Back to the interrupted packet where we left it.
                        -- outer_preempted stays set until its own EOP.
                        v.preempting := '0';
                        v.sel := r.outer_sel;
                        v.crc := r.outer_crc;
                        v.state := PAYLOAD;
                    else
                        v.outer_preempted := '0';
                        boundary;
                    end if;
            end case;
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
