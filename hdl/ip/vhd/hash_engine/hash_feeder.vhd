-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_st8_pkg;
use work.hash_engine_regs_pkg.all;

-- Feeds the SHA3-256 core: a run of 0xFF bytes, then bytes from either the
-- software data FIFO or the host QSPI flash, then waits for the digest.
--
-- Flash fetching mirrors the eSPI flash channel: one command of (address,
-- length) is pushed into a 32-bit command FIFO and the bytes come back on an
-- 8-bit response FIFO. Splitting that into <= 256 byte reads is the transaction
-- manager's job on the far side, so this block only counts bytes.
--
-- Two things here are less obvious than they look.
--
-- Abandoning a hash while a flash read is in flight. The transaction manager
-- cannot be called off, so its remaining bytes would leak into whatever ran
-- next. Rather than try to stop it, an abort or a restart goes through DRAIN and
-- discards exactly the bytes still owed. That is why busy stays asserted after an
-- abort until the channel is resynchronised.
--
-- When the software data FIFO gets flushed. It would be natural to flush it as a
-- run starts, but that races with software: a processor that polls wfifo_full,
-- sees it clear, and then writes can have its write land inside the flush window
-- and silently disappear. So the flush happens at the *end* of a run instead, in
-- FLUSH, when software is waiting on status rather than feeding. A run therefore
-- begins with a FIFO that is already known clean and needs no flush at all, which
-- removes the race entirely. It also means data written before the first start is
-- kept, so pre-loading works.
entity hash_feeder is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- Control strobes from the register block
        start_strobe : in    std_logic;
        abort_strobe : in    std_logic;

        -- Configuration, sampled when a start is accepted
        cfg        : in    config_type;
        prepend    : in    prepend_type;
        flash_addr : in    flash_addr_type;
        msg_length : in    length_type;

        -- Status
        busy      : out   std_logic;
        done      : out   std_logic;
        aborted   : out   std_logic;
        cfg_err   : out   std_logic;
        bytes_fed : out   std_logic_vector(31 downto 0);

        -- SHA3 core
        sha3_init    : out   std_logic;
        msg_if       : view  axi_st8_pkg.axi_st_pkt_source;
        digest_valid : in    std_logic;

        -- Software data FIFO, 8 bit read side, showahead
        sw_fifo_rdata  : in    std_logic_vector(7 downto 0);
        sw_fifo_rdack  : out   std_logic;
        sw_fifo_rempty : in    std_logic;

        -- Hold the software data FIFO in reset. Asserted only in FLUSH, ie once a
        -- run has finished or been abandoned.
        --
        -- Note this deliberately does not extend to the flash response FIFO. DRAIN
        -- already leaves that channel synchronised by consuming exactly the bytes
        -- still owed, so resetting it would be redundant, and it is actively
        -- harmful: on a restart the next read begins within a few cycles of the
        -- flush and the backend's first bytes land while the FIFO is still
        -- recovering from reset, where they are silently dropped and the hash
        -- hangs waiting for them.
        sw_fifo_clear : out   std_logic;

        -- Flash command FIFO: word 0 is the byte address, word 1 the byte count
        cmd_fifo_wdata : out   std_logic_vector(31 downto 0);
        cmd_fifo_write : out   std_logic;

        -- Flash response FIFO, showahead
        rsp_fifo_rdata  : in    std_logic_vector(7 downto 0);
        rsp_fifo_rdack  : out   std_logic;
        rsp_fifo_rempty : in    std_logic
    );
end entity;

architecture rtl of hash_feeder is

    -- The XPM FIFOs need their reset held for more than one cycle. The eSPI
    -- subsystem stretches its clear the same way.
    constant CLEAR_CYCLES : natural := 15;

    type state_t is (IDLE, PRIME, CMD_ADDR, CMD_LEN, RUN, WAIT_DIGEST, DRAIN, FLUSH);

    type reg_t is record
        state       : state_t;
        total_len   : unsigned(31 downto 0);
        prepend_cnt : unsigned(31 downto 0);
        -- Bytes asked of the flash for this run, and how many have come back
        flash_req   : unsigned(31 downto 0);
        flash_rx    : unsigned(31 downto 0);
        -- Bytes still owed by an abandoned flash read
        drain_left  : unsigned(31 downto 0);
        fed         : unsigned(31 downto 0);
        addr        : std_logic_vector(31 downto 0);
        src_qspi    : std_logic;
        clear_cnt   : natural range 0 to CLEAR_CYCLES;
        -- Set when the flush should be followed by a new run rather than idling
        restart     : std_logic;
        -- Set when the flush is following a hash that actually completed
        finished    : std_logic;
        -- Set once this run's flash command has been pushed
        cmd_sent    : std_logic;
        busy        : std_logic;
        done        : std_logic;
        aborted     : std_logic;
        cfg_err     : std_logic;
        init        : std_logic;
    end record;

    constant REG_RESET : reg_t := (
        state       => IDLE,
        total_len   => (others => '0'),
        prepend_cnt => (others => '0'),
        flash_req   => (others => '0'),
        flash_rx    => (others => '0'),
        drain_left  => (others => '0'),
        fed         => (others => '0'),
        addr        => (others => '0'),
        src_qspi    => '0',
        clear_cnt   => 0,
        restart     => '0',
        finished    => '0',
        cmd_sent    => '0',
        busy        => '0',
        done        => '0',
        aborted     => '0',
        cfg_err     => '0',
        init        => '0'
    );

    signal r, rin : reg_t;

    -- Combinational view of the byte we are currently offering the core
    signal in_prepend : std_logic;
    signal src_data   : std_logic_vector(7 downto 0);
    signal src_valid  : std_logic;
    signal beat       : std_logic;

begin

    in_prepend <= '1' when r.fed < r.prepend_cnt else '0';

    src_data <= x"FF" when in_prepend = '1' else
                rsp_fifo_rdata when r.src_qspi = '1' else
                sw_fifo_rdata;

    src_valid <= '1' when in_prepend = '1' else
                 not rsp_fifo_rempty when r.src_qspi = '1' else
                 not sw_fifo_rempty;

    msg_if.valid <= '1' when r.state = RUN and src_valid = '1' else '0';
    msg_if.data  <= src_data;
    msg_if.last  <= '1' when r.state = RUN and r.fed = r.total_len - 1 else '0';

    beat <= '1' when r.state = RUN and src_valid = '1' and msg_if.ready = '1' else '0';

    -- Pop the source FIFO on an accepted beat, and keep popping in DRAIN to throw
    -- away the tail of an abandoned flash read.
    sw_fifo_rdack <= '1' when beat = '1' and in_prepend = '0' and r.src_qspi = '0' else '0';

    rsp_fifo_rdack <= '1' when (beat = '1' and in_prepend = '0' and r.src_qspi = '1') or
                               (r.state = DRAIN and rsp_fifo_rempty = '0' and r.drain_left > 0)
                      else '0';

    cmd_fifo_wdata <= r.addr when r.state = CMD_ADDR else
                      std_logic_vector(r.flash_req);
    cmd_fifo_write <= '1' when r.state = CMD_ADDR or r.state = CMD_LEN else '0';

    busy      <= r.busy;
    done      <= r.done;
    aborted   <= r.aborted;
    cfg_err   <= r.cfg_err;
    bytes_fed <= std_logic_vector(r.fed);
    sha3_init <= r.init;

    sw_fifo_clear <= '1' when r.state = FLUSH else '0';

    comb: process(all)

        variable v        : reg_t;
        variable accepted : boolean;
        variable do_begin : boolean;
        variable stop_run : boolean;

    begin
        v := r;

        v.init   := '0';
        do_begin := false;
        stop_run := false;

        -- A start is refused outright if the configuration cannot produce a
        -- message: the core has no way to express a zero length one, and a prepend
        -- longer than the message is simply nonsense.
        accepted := start_strobe = '1' and
                    unsigned(msg_length.count) /= 0 and
                    unsigned(prepend.count) <= unsigned(msg_length.count);

        if start_strobe = '1' and not accepted then
            v.cfg_err := '1';
        end if;

        -- Latch configuration the moment a start is accepted, whether from idle or
        -- as a restart part way through a run.
        if accepted then
            v.total_len   := unsigned(msg_length.count);
            v.prepend_cnt := unsigned(prepend.count);
            v.flash_req   := unsigned(msg_length.count) - unsigned(prepend.count);
            v.addr        := flash_addr.addr;
            v.src_qspi    := '1' when cfg.source = HOST_QSPI else '0';
            v.cfg_err     := '0';
            v.aborted     := '0';
            v.done        := '0';
            v.busy        := '1';

            if r.state = IDLE then
                -- Nothing to abandon and the FIFOs were flushed when the previous
                -- run ended, so start straight away.
                do_begin := true;
            else
                v.restart := '1';
                stop_run  := true;
            end if;
        elsif abort_strobe = '1' and r.state /= IDLE then
            v.aborted := '1';
            v.done    := '0';
            v.restart := '0';
            stop_run  := true;
        end if;

        if stop_run then
            -- Work out what the flash still owes us so DRAIN can swallow it.
            v.drain_left := r.flash_req - r.flash_rx;
            v.finished   := '0';
            v.state      := DRAIN;
        else

            case r.state is

                when IDLE =>
                    null;

                when PRIME =>
                    -- One cycle so the core sees sha3_init before we offer it a
                    -- byte. Without this the reset and the first beat land on the
                    -- same edge and the byte is swallowed.
                    v.state := RUN;

                when CMD_ADDR =>
                    v.state := CMD_LEN;

                when CMD_LEN =>
                    v.cmd_sent := '1';
                    v.state    := RUN;

                when RUN =>
                    -- Ask for the flash only once the prepend has been fed, never
                    -- before it. The backend starts fetching the moment the
                    -- command lands and has no way to be told to wait, so issuing
                    -- it up front means the response FIFO fills while we are still
                    -- feeding 0xFF and the bytes past its depth are dropped on the
                    -- floor. The hash then waits forever for data that was thrown
                    -- away. Deferring costs one flash latency and removes the
                    -- window entirely.
                    --
                    -- in_prepend has just gone low here, and the response FIFO is
                    -- empty, so no beat is being passed up by diverting.
                    if r.src_qspi = '1' and r.cmd_sent = '0' and
                       r.flash_req > 0 and in_prepend = '0' then
                        v.state := CMD_ADDR;
                    elsif beat = '1' then
                        v.fed := r.fed + 1;

                        if in_prepend = '0' and r.src_qspi = '1' then
                            v.flash_rx := r.flash_rx + 1;
                        end if;

                        if r.fed = r.total_len - 1 then
                            v.state := WAIT_DIGEST;
                        end if;
                    end if;

                when WAIT_DIGEST =>
                    if digest_valid then
                        -- The digest registers are fed straight from the core, so
                        -- there is nothing to latch. Flush before reporting done so
                        -- that done also means "ready to run again".
                        v.finished  := '1';
                        v.clear_cnt := CLEAR_CYCLES;
                        v.state     := FLUSH;
                    end if;

                when DRAIN =>
                    -- Discard the tail of an abandoned flash read. For a software
                    -- fed hash there is nothing owed and this falls straight
                    -- through.
                    if rsp_fifo_rdack = '1' then
                        v.drain_left := r.drain_left - 1;
                    end if;

                    if r.drain_left = 0 then
                        v.clear_cnt := CLEAR_CYCLES;
                        v.state     := FLUSH;
                    end if;

                when FLUSH =>
                    if r.clear_cnt = 0 then
                        if r.restart = '1' then
                            do_begin := true;
                        else
                            v.busy  := '0';
                            v.done  := r.finished;
                            v.state := IDLE;
                        end if;
                    else
                        v.clear_cnt := r.clear_cnt - 1;
                    end if;

            end case;
        end if;

        if do_begin then
            v.restart  := '0';
            v.finished := '0';
            v.cmd_sent := '0';
            v.init     := '1';
            v.fed      := (others => '0');
            v.flash_rx := (others => '0');
            v.state    := PRIME;
        end if;

        rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset then
            r <= REG_RESET;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

end rtl;
