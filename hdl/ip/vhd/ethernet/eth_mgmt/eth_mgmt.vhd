-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- The management protocol engine: a pure client of udp_endpoint's datagram
-- interface (no L2/L3 knowledge). Implements docs/mgmt_protocol.adoc:
-- IDENTIFY, SET_SERIAL, SET_MAC, FLASH_ERASE/WRITE/READ, all stop-and-wait
-- and idempotent. Write operations must echo the current serial number.
--
-- At boot the MAC and serial are read from their identity sectors; an
-- all-0xFF (erased) field falls back to the generic default. mac_valid
-- tells the endpoint its MAC (and therefore its link-local address) is
-- settled; mac_is_default is reported in IDENTIFY so unprovisioned units
-- are recognizable.
--
-- One request is processed at a time. While a flash operation is in flight
-- the receive side keeps listening: a well-formed request that arrives gets
-- an immediate BUSY response (built without touching flash) instead of
-- silence, so a retrying peer backs off rather than spamming. The completed
-- status of the last altering command is cached against its sequence
-- number, so a retransmission seen after completion receives the real
-- result instead of being re-executed.
--
-- The datagram buffer is a single simple-dual-port RAM; header fields are
-- walked out into registers once per request so the RAM needs only one read
-- port (shared between the header walk and the flash-program byte pull).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.eth_hdr_pkg.all;
use work.udp_endpoint_pkg.all;
use work.eth_mgmt_pkg.all;

entity eth_mgmt is
    generic (
        -- Identity to fall back on when the flash sector is blank. The
        -- value here is a non-address placeholder: a project is expected
        -- to pass the allocated one.
        DEFAULT_MAC    : mac_addr_t := X"0A0B0C0D0E0F";
        DEFAULT_SERIAL : std_logic_vector(8 * SERIAL_BYTES - 1 downto 0) := (others => '0');
        -- flash map; values are project decisions
        APP_IMAGE_BASE : unsigned(31 downto 0) := X"00100000";
        APP_IMAGE_SIZE : unsigned(31 downto 0) := X"00E00000";
        IDENTITY_BASE  : unsigned(31 downto 0) := X"00F00000"
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- identity and status
        fpga_version    : in    std_logic_vector(31 downto 0);
        endpoint_status : in    endpoint_status_t;
        mac             : out   mac_addr_t;
        mac_valid       : out   std_logic;
        -- the flash identity sector was blank; running on DEFAULT_MAC
        mac_is_default  : out   std_logic;

        -- datagram interface (udp_endpoint client)
        rx       : in    udp_st_t;
        rx_meta  : in    udp_rx_meta_t;
        rx_ready : out   std_logic;
        tx       : out   udp_st_t;
        tx_meta  : out   udp_tx_meta_t;
        tx_ready : in    std_logic;

        -- flash sequencer (mgmt_flash)
        f_req      : out   std_logic;
        f_op       : out   flash_op_t;
        f_addr     : out   std_logic_vector(31 downto 0);
        f_len      : out   unsigned(8 downto 0);
        f_busy     : in    std_logic;
        f_done     : in    std_logic;
        f_wr_data  : out   std_logic_vector(7 downto 0);
        f_wr_ack   : in    std_logic;
        f_rd_data  : in    std_logic_vector(7 downto 0);
        f_rd_valid : in    std_logic
    );
end entity;

architecture rtl of eth_mgmt is

    constant SERIAL_SECTOR_OFF : unsigned(31 downto 0) := X"00001000";
    constant BUF_BYTES : natural := 512;

    -- fixed request layout offsets (see mgmt_protocol.adoc)
    constant OFF_ECHO  : natural := 8;                       -- serial echo
    constant OFF_ARG   : natural := OFF_ECHO + SERIAL_BYTES; -- 40
    constant HDR_WALK_BYTES : natural := 46;                 -- covers all fixed fields

    -- ---- datagram buffer, written by the capture process ------------------
    type buf_t is array (0 to BUF_BYTES - 1) of std_logic_vector(7 downto 0);
    signal buf : buf_t;
    signal buf_rd  : std_logic_vector(7 downto 0);
    signal rd_idx  : unsigned(8 downto 0) := (others => '0');

    signal dgram_ready : std_logic := '0';
    signal dgram_taken : std_logic := '0';
    -- the main FSM owns the buffer from HDR_WALK through CLEANUP; capture
    -- may fill it any other time (including while a BUSY response streams)
    signal buf_owned : std_logic := '0';
    signal dgram_len   : unsigned(10 downto 0) := (others => '0');
    signal dgram_meta  : udp_rx_meta_t;

    -- header of a request that arrived while busy, for the BUSY response
    signal breq_ready : std_logic := '0';
    signal breq_taken : std_logic := '0';
    signal breq_cmd   : std_logic_vector(7 downto 0) := (others => '0');
    signal breq_seq   : std_logic_vector(15 downto 0) := (others => '0');
    signal breq_magic_ok : std_logic := '0';
    signal breq_meta  : udp_rx_meta_t;

    -- ---- parsed request ---------------------------------------------------
    type hdr_arr_t is array (0 to HDR_WALK_BYTES - 1) of std_logic_vector(7 downto 0);
    signal hdrb : hdr_arr_t := (others => (others => '0'));

    signal r_cmd  : std_logic_vector(7 downto 0);
    signal r_seq  : std_logic_vector(15 downto 0);
    signal r_addr : unsigned(31 downto 0);
    signal r_len  : unsigned(15 downto 0);

    -- ---- identity ---------------------------------------------------------
    signal mac_r    : mac_addr_t := DEFAULT_MAC;
    signal serial_r : std_logic_vector(8 * SERIAL_BYTES - 1 downto 0) := DEFAULT_SERIAL;
    signal mac_ok   : std_logic := '0';
    signal mac_dflt : std_logic := '1';

    signal boot_cnt : natural range 0 to SERIAL_BYTES := 0;
    signal all_ff   : std_logic := '1';
    signal shift_in : std_logic_vector(8 * SERIAL_BYTES - 1 downto 0) := (others => '0');

    -- ---- replay cache -----------------------------------------------------
    signal cache_cmd    : std_logic_vector(7 downto 0) := (others => '0');
    signal cache_seq    : std_logic_vector(15 downto 0) := (others => '0');
    signal cache_status : std_logic_vector(7 downto 0) := (others => '0');
    signal cache_valid  : std_logic := '0';

    -- ---- response streaming -----------------------------------------------
    type pay_kind_t is (PK_NONE, PK_IDENT, PK_FLASH);
    signal resp_cmd    : std_logic_vector(7 downto 0) := (others => '0');
    signal resp_seq    : std_logic_vector(15 downto 0) := (others => '0');
    signal resp_status : std_logic_vector(7 downto 0) := (others => '0');
    signal resp_kind   : pay_kind_t := PK_NONE;
    signal resp_meta   : udp_tx_meta_t := (
        dst_ip => (others => '0'), dst_port => (others => '0'),
        src_port => (others => '0'));
    signal resp_idx    : natural range 0 to 63 := 0;
    signal pay_cnt     : unsigned(8 downto 0) := (others => '0');

    signal fp_byte  : std_logic_vector(7 downto 0) := (others => '0');
    signal fp_have  : std_logic := '0';

    signal out_st : udp_st_t := UDP_ST_IDLE;

    type state_t is (BOOT_MAC_GO, BOOT_MAC_WAIT, BOOT_SER_GO, BOOT_SER_WAIT,
                     READY, HDR_WALK, DECIDE,
                     EXEC_ERASE_GO, EXEC_ERASE_WAIT,
                     EXEC_PROG_GO, EXEC_PROG_WAIT,
                     LOAD_SERIAL,
                     RESP_HDR, RESP_IDENT, RESP_FLASH_GO, RESP_FLASH,
                     CLEANUP, WAIT_FREE);
    signal state : state_t := BOOT_MAC_GO;
    -- where a BUSY response returns to
    signal resp_ret : state_t := READY;

    signal sub  : natural range 0 to 2 := 0;
    signal wcnt : natural range 0 to 63 := 0;

    -- a BUSY interjection borrows the resp_* registers; restore them to the
    -- request actually being executed before its final response
    procedure restore_resp (
        signal cmd_o  : out std_logic_vector(7 downto 0);
        signal seq_o  : out std_logic_vector(15 downto 0);
        signal kind_o : out pay_kind_t;
        signal ret_o  : out state_t;
        signal meta_o : out udp_tx_meta_t;
        constant cmd  : in std_logic_vector(7 downto 0);
        constant seq  : in std_logic_vector(15 downto 0);
        constant meta : in udp_rx_meta_t
    ) is
    begin
        cmd_o  <= cmd;
        seq_o  <= seq;
        kind_o <= PK_NONE;
        ret_o  <= CLEANUP;
        meta_o <= (dst_ip => meta.src_ip, dst_port => meta.src_port,
                   src_port => meta.dst_port);
    end procedure;

    -- second flash step (program after erase) and its data source
    signal do_prog   : std_logic := '0';
    signal prog_addr : unsigned(31 downto 0) := (others => '0');
    signal prog_len  : unsigned(8 downto 0) := (others => '0');
    signal prog_base : unsigned(8 downto 0) := (others => '0');
    signal new_serial : std_logic := '0';

    function ident_byte (
        idx     : natural;
        mac_v   : mac_addr_t;
        stat    : endpoint_status_t;
        version : std_logic_vector(31 downto 0);
        dflt    : std_logic;
        serial  : std_logic_vector(8 * SERIAL_BYTES - 1 downto 0)
    ) return std_logic_vector is
    begin
        case idx is
            when 0 => return MGMT_VERSION;
            when 1 to 6 => return mac_v(47 - 8 * (idx - 1) downto 40 - 8 * (idx - 1));
            when 7 to 22 => return stat.ip(127 - 8 * (idx - 7) downto 120 - 8 * (idx - 7));
            when 23 to 26 => return version(31 - 8 * (idx - 23) downto 24 - 8 * (idx - 23));
            when 27 => return "000000" & dflt & stat.ip_valid;
            when 28 to 59 => return serial(serial'high - 8 * (idx - 28) downto serial'high - 7 - 8 * (idx - 28));
            when others => return X"00";
        end case;
    end function;

    function resp_hdr_byte (
        idx    : natural;
        cmd    : std_logic_vector(7 downto 0);
        seq    : std_logic_vector(15 downto 0);
        status : std_logic_vector(7 downto 0)
    ) return std_logic_vector is
    begin
        case idx is
            when 0 => return MGMT_MAGIC(31 downto 24);
            when 1 => return MGMT_MAGIC(23 downto 16);
            when 2 => return MGMT_MAGIC(15 downto 8);
            when 3 => return MGMT_MAGIC(7 downto 0);
            when 4 => return MGMT_VERSION;
            when 5 => return cmd or X"80";
            when 6 => return seq(15 downto 8);
            when 7 => return seq(7 downto 0);
            when others => return status;
        end case;
    end function;

begin

    mac       <= mac_r;
    mac_valid <= mac_ok;
    mac_is_default <= mac_dflt;
    rx_ready  <= '1';
    tx        <= out_st;
    tx_meta   <= resp_meta;

    f_wr_data <= buf_rd;

    -- ---- datagram capture -------------------------------------------------
    -- Full datagrams land in the buffer when it is free. While the main FSM
    -- owns the buffer, arriving datagrams are discarded but their header is
    -- kept so a BUSY response can be addressed to the sender.
    capture: process (clk, reset) is
        variable idx : natural range 0 to 2047 := 0;
        variable to_buf : boolean := false;
        variable magic_ok : std_logic := '0';
        variable cmd_v : std_logic_vector(7 downto 0) := (others => '0');
        variable seq_v : std_logic_vector(15 downto 0) := (others => '0');
    begin
        if reset = '1' then
            dgram_ready <= '0';
            breq_ready  <= '0';
            idx := 0;
        elsif rising_edge(clk) then
            if dgram_taken = '1' then
                dgram_ready <= '0';
            end if;
            if breq_taken = '1' then
                breq_ready <= '0';
            end if;

            if rx.valid = '1' then
                if idx = 0 then
                    -- claim the buffer for this datagram, or fall back to
                    -- header-only capture
                    to_buf := buf_owned = '0' and
                              (dgram_ready = '0' or dgram_taken = '1');
                    magic_ok := '1';
                end if;

                if to_buf then
                    if idx < BUF_BYTES then
                        buf(idx) <= rx.data;
                    end if;
                else
                    case idx is
                        when 0 =>
                            if rx.data /= MGMT_MAGIC(31 downto 24) then magic_ok := '0'; end if;
                        when 1 =>
                            if rx.data /= MGMT_MAGIC(23 downto 16) then magic_ok := '0'; end if;
                        when 2 =>
                            if rx.data /= MGMT_MAGIC(15 downto 8) then magic_ok := '0'; end if;
                        when 3 =>
                            if rx.data /= MGMT_MAGIC(7 downto 0) then magic_ok := '0'; end if;
                        when 5 => cmd_v := rx.data;
                        when 6 => seq_v(15 downto 8) := rx.data;
                        when 7 => seq_v(7 downto 0) := rx.data;
                        when others => null;
                    end case;
                end if;

                if rx.last = '1' then
                    if to_buf then
                        if idx >= MGMT_HDR_BYTES - 1 then
                            dgram_len   <= to_unsigned(minimum(idx + 1, BUF_BYTES), 11);
                            dgram_meta  <= rx_meta;
                            dgram_ready <= '1';
                        end if;
                        -- short datagrams are dropped silently
                    else
                        if idx >= MGMT_HDR_BYTES - 1 and magic_ok = '1' and
                           breq_ready = '0' then
                            breq_cmd   <= cmd_v;
                            breq_seq   <= seq_v;
                            breq_meta  <= rx_meta;
                            breq_ready <= '1';
                        end if;
                    end if;
                    idx := 0;
                else
                    if idx /= 2047 then
                        idx := idx + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- ---- main engine ------------------------------------------------------
    main: process (clk, reset) is
        variable echo_ok : boolean;
        variable v_addr  : unsigned(31 downto 0);
        variable v_len   : unsigned(15 downto 0);
    begin
        if reset = '1' then
            state <= BOOT_MAC_GO;
            sub   <= 0;
            wcnt  <= 0;
            f_req <= '0';
            f_op  <= FLASH_OP_READ;
            f_addr <= (others => '0');
            f_len  <= (others => '0');
            mac_r    <= DEFAULT_MAC;
            serial_r <= DEFAULT_SERIAL;
            mac_ok   <= '0';
            mac_dflt <= '1';
            out_st   <= UDP_ST_IDLE;
            dgram_taken <= '0';
            breq_taken  <= '0';
            buf_owned   <= '0';
            cache_valid <= '0';
            fp_have  <= '0';
            do_prog  <= '0';
            new_serial <= '0';
            rd_idx <= (others => '0');
        elsif rising_edge(clk) then
            f_req       <= '0';
            dgram_taken <= '0';
            breq_taken  <= '0';

            buf_rd <= buf(to_integer(rd_idx));

            -- flash read bytes: hold until the response stream consumes them
            if f_rd_valid = '1' then
                fp_byte <= f_rd_data;
                fp_have <= '1';
            end if;

            case state is
                -- ---- boot: load identity from flash -----------------------
                when BOOT_MAC_GO =>
                    f_op   <= FLASH_OP_READ;
                    f_addr <= std_logic_vector(IDENTITY_BASE);
                    f_len  <= to_unsigned(6, 9);
                    f_req  <= '1';
                    boot_cnt <= 0;
                    all_ff   <= '1';
                    state  <= BOOT_MAC_WAIT;

                when BOOT_MAC_WAIT =>
                    if f_rd_valid = '1' then
                        shift_in <= shift_in(shift_in'high - 8 downto 0) & f_rd_data;
                        if f_rd_data /= X"FF" then
                            all_ff <= '0';
                        end if;
                    end if;
                    if f_done = '1' then
                        if all_ff = '0' then
                            mac_r    <= shift_in(47 downto 0);
                            mac_dflt <= '0';
                        end if;
                        state <= BOOT_SER_GO;
                    end if;

                when BOOT_SER_GO =>
                    f_op   <= FLASH_OP_READ;
                    f_addr <= std_logic_vector(IDENTITY_BASE + SERIAL_SECTOR_OFF);
                    f_len  <= to_unsigned(SERIAL_BYTES, 9);
                    f_req  <= '1';
                    all_ff <= '1';
                    state  <= BOOT_SER_WAIT;

                when BOOT_SER_WAIT =>
                    if f_rd_valid = '1' then
                        shift_in <= shift_in(shift_in'high - 8 downto 0) & f_rd_data;
                        if f_rd_data /= X"FF" then
                            all_ff <= '0';
                        end if;
                    end if;
                    if f_done = '1' then
                        if all_ff = '0' then
                            serial_r <= shift_in;
                        end if;
                        mac_ok <= '1';
                        state  <= READY;
                    end if;

                -- ---- request intake ---------------------------------------
                when READY =>
                    fp_have <= '0';
                    if dgram_ready = '1' then
                        wcnt <= 0;
                        sub  <= 0;
                        buf_owned <= '1';
                        state <= HDR_WALK;
                    elsif breq_ready = '1' then
                        -- late header-only capture (race with CLEANUP):
                        -- answer BUSY, the peer will retry
                        resp_cmd    <= breq_cmd;
                        resp_seq    <= breq_seq;
                        resp_status <= STATUS_BUSY;
                        resp_kind   <= PK_NONE;
                        resp_meta   <= (dst_ip => breq_meta.src_ip,
                                        dst_port => breq_meta.src_port,
                                        src_port => breq_meta.dst_port);
                        breq_taken  <= '1';
                        resp_idx    <= 0;
                        resp_ret    <= READY;
                        state       <= RESP_HDR;
                    end if;

                when HDR_WALK =>
                    if sub = 0 then
                        rd_idx <= to_unsigned(wcnt, 9);
                        sub <= 1;
                    elsif sub = 1 then
                        sub <= 2;
                    else
                        hdrb(wcnt) <= buf_rd;
                        sub <= 0;
                        if wcnt = HDR_WALK_BYTES - 1 then
                            state <= DECIDE;
                        else
                            wcnt <= wcnt + 1;
                        end if;
                    end if;

                when DECIDE =>
                    r_cmd <= hdrb(5);
                    r_seq <= hdrb(6) & hdrb(7);
                    resp_cmd  <= hdrb(5);
                    resp_seq  <= hdrb(6) & hdrb(7);
                    resp_kind <= PK_NONE;
                    resp_idx  <= 0;
                    resp_ret  <= CLEANUP;
                    resp_meta <= (dst_ip => dgram_meta.src_ip,
                                  dst_port => dgram_meta.src_port,
                                  src_port => dgram_meta.dst_port);

                    -- serial echo for altering commands
                    echo_ok := true;
                    for i in 0 to SERIAL_BYTES - 1 loop
                        if hdrb(OFF_ECHO + i) /=
                           serial_r(serial_r'high - 8 * i downto serial_r'high - 7 - 8 * i) then
                            echo_ok := false;
                        end if;
                    end loop;

                    v_addr := unsigned(std_logic_vector'(hdrb(OFF_ARG) & hdrb(OFF_ARG + 1) &
                                       hdrb(OFF_ARG + 2) & hdrb(OFF_ARG + 3)));
                    v_len  := unsigned(std_logic_vector'(hdrb(OFF_ARG + 4) & hdrb(OFF_ARG + 5)));
                    r_addr <= v_addr;
                    r_len  <= v_len;

                    state <= RESP_HDR;   -- overridden below where needed

                    if hdrb(0) & hdrb(1) & hdrb(2) & hdrb(3) /= MGMT_MAGIC then
                        -- not ours; drop silently
                        state <= CLEANUP;
                    elsif hdrb(4) /= MGMT_VERSION then
                        resp_status <= STATUS_BAD_VERSION;
                    elsif cache_valid = '1' and hdrb(5) = cache_cmd and
                          (hdrb(6) & hdrb(7)) = cache_seq then
                        -- retransmission of a completed altering command
                        resp_status <= cache_status;
                    elsif hdrb(5) = CMD_IDENTIFY then
                        resp_status <= STATUS_OK;
                        resp_kind   <= PK_IDENT;
                    elsif hdrb(5) = CMD_FLASH_READ then
                        -- args immediately after the header, no echo
                        v_addr := unsigned(std_logic_vector'(hdrb(8) & hdrb(9) & hdrb(10) & hdrb(11)));
                        v_len  := unsigned(std_logic_vector'(hdrb(12) & hdrb(13)));
                        r_addr <= v_addr;
                        r_len  <= v_len;
                        if v_len = 0 or v_len > 256 then
                            resp_status <= STATUS_BAD_LEN;
                        else
                            resp_status <= STATUS_OK;
                            resp_kind   <= PK_FLASH;
                        end if;
                    elsif hdrb(5) /= CMD_SET_SERIAL and hdrb(5) /= CMD_SET_MAC and
                          hdrb(5) /= CMD_FLASH_ERASE and hdrb(5) /= CMD_FLASH_WRITE then
                        resp_status <= STATUS_BAD_CMD;
                    elsif not echo_ok then
                        resp_status <= STATUS_BAD_SERIAL_ECHO;
                    elsif hdrb(5) = CMD_SET_SERIAL then
                        if dgram_len < OFF_ARG + SERIAL_BYTES then
                            resp_status <= STATUS_BAD_LEN;
                        else
                            prog_addr  <= IDENTITY_BASE + SERIAL_SECTOR_OFF;
                            prog_len   <= to_unsigned(SERIAL_BYTES, 9);
                            prog_base  <= to_unsigned(OFF_ARG, 9);
                            do_prog    <= '1';
                            new_serial <= '1';
                            f_op   <= FLASH_OP_ERASE;
                            f_addr <= std_logic_vector(IDENTITY_BASE + SERIAL_SECTOR_OFF);
                            state  <= EXEC_ERASE_GO;
                        end if;
                    elsif hdrb(5) = CMD_SET_MAC then
                        if dgram_len < OFF_ARG + 6 then
                            resp_status <= STATUS_BAD_LEN;
                        else
                            prog_addr <= IDENTITY_BASE;
                            prog_len  <= to_unsigned(6, 9);
                            prog_base <= to_unsigned(OFF_ARG, 9);
                            do_prog   <= '1';
                            f_op   <= FLASH_OP_ERASE;
                            f_addr <= std_logic_vector(IDENTITY_BASE);
                            state  <= EXEC_ERASE_GO;
                        end if;
                    elsif hdrb(5) = CMD_FLASH_ERASE then
                        if v_addr(11 downto 0) /= 0 or
                           v_addr < APP_IMAGE_BASE or
                           v_addr >= APP_IMAGE_BASE + APP_IMAGE_SIZE then
                            resp_status <= STATUS_BAD_ADDR;
                        else
                            do_prog <= '0';
                            f_op   <= FLASH_OP_ERASE;
                            f_addr <= std_logic_vector(v_addr);
                            state  <= EXEC_ERASE_GO;
                        end if;
                    else   -- CMD_FLASH_WRITE
                        if v_len = 0 or v_len > 256 or
                           resize(v_addr(7 downto 0), 16) + v_len > 256 then
                            resp_status <= STATUS_BAD_LEN;
                        elsif v_addr < APP_IMAGE_BASE or
                              resize(v_addr, 33) + v_len >
                              resize(APP_IMAGE_BASE + APP_IMAGE_SIZE, 33) then
                            resp_status <= STATUS_BAD_ADDR;
                        elsif dgram_len < OFF_ARG + 6 + v_len then
                            resp_status <= STATUS_BAD_LEN;
                        else
                            prog_addr <= v_addr;
                            prog_len  <= v_len(8 downto 0);
                            prog_base <= to_unsigned(OFF_ARG + 6, 9);
                            do_prog   <= '1';
                            state     <= EXEC_PROG_GO;
                        end if;
                    end if;

                -- ---- flash execution --------------------------------------
                when EXEC_ERASE_GO =>
                    f_req <= '1';
                    state <= EXEC_ERASE_WAIT;

                when EXEC_ERASE_WAIT =>
                    if f_done = '1' then
                        if do_prog = '1' then
                            state <= EXEC_PROG_GO;
                        else
                            restore_resp(resp_cmd, resp_seq, resp_kind,
                                         resp_ret, resp_meta,
                                         r_cmd, r_seq, dgram_meta);
                            resp_status <= STATUS_OK;
                            resp_idx    <= 0;
                            state       <= RESP_HDR;
                        end if;
                    elsif breq_ready = '1' then
                        resp_cmd    <= breq_cmd;
                        resp_seq    <= breq_seq;
                        resp_status <= STATUS_BUSY;
                        resp_kind   <= PK_NONE;
                        resp_meta   <= (dst_ip => breq_meta.src_ip,
                                        dst_port => breq_meta.src_port,
                                        src_port => breq_meta.dst_port);
                        breq_taken  <= '1';
                        resp_idx    <= 0;
                        resp_ret    <= EXEC_ERASE_WAIT;
                        state       <= RESP_HDR;
                    end if;

                when EXEC_PROG_GO =>
                    -- pre-position the buffer read a byte ahead of the pull
                    rd_idx <= prog_base;
                    f_op   <= FLASH_OP_PROGRAM;
                    f_addr <= std_logic_vector(prog_addr);
                    f_len  <= prog_len;
                    f_req  <= '1';
                    state  <= EXEC_PROG_WAIT;

                when EXEC_PROG_WAIT =>
                    if f_wr_ack = '1' then
                        rd_idx <= rd_idx + 1;
                    end if;
                    if f_done = '1' then
                        if new_serial = '1' then
                            wcnt <= 0;
                            sub  <= 0;
                            state <= LOAD_SERIAL;
                        else
                            restore_resp(resp_cmd, resp_seq, resp_kind,
                                         resp_ret, resp_meta,
                                         r_cmd, r_seq, dgram_meta);
                            resp_status <= STATUS_OK;
                            resp_idx    <= 0;
                            state       <= RESP_HDR;
                        end if;
                    elsif breq_ready = '1' then
                        resp_cmd    <= breq_cmd;
                        resp_seq    <= breq_seq;
                        resp_status <= STATUS_BUSY;
                        resp_kind   <= PK_NONE;
                        resp_meta   <= (dst_ip => breq_meta.src_ip,
                                        dst_port => breq_meta.src_port,
                                        src_port => breq_meta.dst_port);
                        breq_taken  <= '1';
                        resp_idx    <= 0;
                        resp_ret    <= EXEC_PROG_WAIT;
                        state       <= RESP_HDR;
                    end if;

                -- the live serial follows a successful SET_SERIAL; re-read
                -- the new value out of the request buffer
                when LOAD_SERIAL =>
                    if sub = 0 then
                        rd_idx <= to_unsigned(OFF_ARG + wcnt, 9);
                        sub <= 1;
                    elsif sub = 1 then
                        sub <= 2;
                    else
                        serial_r <= serial_r(serial_r'high - 8 downto 0) & buf_rd;
                        sub <= 0;
                        if wcnt = SERIAL_BYTES - 1 then
                            new_serial  <= '0';
                            restore_resp(resp_cmd, resp_seq, resp_kind,
                                         resp_ret, resp_meta,
                                         r_cmd, r_seq, dgram_meta);
                            resp_status <= STATUS_OK;
                            resp_idx    <= 0;
                            state       <= RESP_HDR;
                        else
                            wcnt <= wcnt + 1;
                        end if;
                    end if;

                -- ---- response streaming -----------------------------------
                when RESP_HDR =>
                    if out_st.valid = '0' then
                        out_st.data  <= resp_hdr_byte(resp_idx, resp_cmd, resp_seq, resp_status);
                        out_st.valid <= '1';
                        if resp_idx = 8 and resp_kind = PK_NONE then
                            out_st.last <= '1';
                        end if;
                    elsif tx_ready = '1' then
                        out_st <= UDP_ST_IDLE;
                        if resp_idx = 8 then
                            case resp_kind is
                                when PK_NONE =>
                                    state <= resp_ret;
                                when PK_IDENT =>
                                    resp_idx <= 0;
                                    state <= RESP_IDENT;
                                when PK_FLASH =>
                                    pay_cnt <= (others => '0');
                                    fp_have <= '0';
                                    state <= RESP_FLASH_GO;
                            end case;
                        else
                            resp_idx <= resp_idx + 1;
                        end if;
                    end if;

                when RESP_IDENT =>
                    if out_st.valid = '0' then
                        out_st.data <= ident_byte(resp_idx, mac_r, endpoint_status,
                                                  fpga_version, mac_dflt, serial_r);
                        out_st.valid <= '1';
                        if resp_idx = IDENTIFY_PAYLOAD_BYTES - 1 then
                            out_st.last <= '1';
                        end if;
                    elsif tx_ready = '1' then
                        out_st <= UDP_ST_IDLE;
                        if resp_idx = IDENTIFY_PAYLOAD_BYTES - 1 then
                            state <= CLEANUP;
                        else
                            resp_idx <= resp_idx + 1;
                        end if;
                    end if;

                when RESP_FLASH_GO =>
                    f_op   <= FLASH_OP_READ;
                    f_addr <= std_logic_vector(r_addr);
                    f_len  <= r_len(8 downto 0);
                    f_req  <= '1';
                    state  <= RESP_FLASH;

                when RESP_FLASH =>
                    -- SPI is far slower than the stream consumer, so a
                    -- one-byte holding register never overruns
                    if out_st.valid = '0' and fp_have = '1' then
                        out_st.data  <= fp_byte;
                        out_st.valid <= '1';
                        fp_have      <= '0';
                        if pay_cnt = r_len(8 downto 0) - 1 then
                            out_st.last <= '1';
                        end if;
                    elsif out_st.valid = '1' and tx_ready = '1' then
                        out_st <= UDP_ST_IDLE;
                        if pay_cnt = r_len(8 downto 0) - 1 then
                            state <= CLEANUP;
                        else
                            pay_cnt <= pay_cnt + 1;
                        end if;
                    end if;

                when CLEANUP =>
                    out_st <= UDP_ST_IDLE;
                    -- cache the outcome of altering commands so a
                    -- retransmission is answered, not re-executed
                    if r_cmd = CMD_SET_SERIAL or r_cmd = CMD_SET_MAC or
                       r_cmd = CMD_FLASH_ERASE or r_cmd = CMD_FLASH_WRITE then
                        cache_cmd    <= r_cmd;
                        cache_seq    <= r_seq;
                        cache_status <= resp_status;
                        cache_valid  <= '1';
                    end if;
                    do_prog     <= '0';
                    dgram_taken <= '1';
                    buf_owned   <= '0';
                    wcnt        <= 0;
                    state       <= WAIT_FREE;

                -- fixed drain: dgram_ready takes two cycles to reflect the
                -- taken pulse; returning straight to READY would process the
                -- same request twice. (Not level-sensitive: a new datagram
                -- may legitimately re-raise dgram_ready in this window.)
                when WAIT_FREE =>
                    if wcnt = 1 then
                        state <= READY;
                    else
                        wcnt <= wcnt + 1;
                    end if;
            end case;
        end if;
    end process;

end architecture;
