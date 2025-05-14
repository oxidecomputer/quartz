-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.ignition_pkg.all;
use work.helper_8b10b_pkg.all;

entity pkt_parsing is
    generic(
        CHAN_ID: integer := 0
    );
    port(
        clk : in std_logic;
        reset : in std_logic;

        valid : in std_logic;
        ignit_rx : in ignit_rx_decode;
        is_aligned : in std_logic;

        pol_invert : out std_logic;
        is_locked : out std_logic;
        is_hello : out std_logic;
        is_power_on : out std_logic;
        is_power_off : out std_logic;
        is_restart : out std_logic;
        bad_crc : out std_logic


    );
end entity;

architecture rtl of pkt_parsing is
    constant MAX_PKT_SIZE : natural := 6;
    constant HEADER_IDX : natural := 0;
    constant MSG_TYPE_IDX : natural := 1;
    constant REQ_TYPE_IDX : natural := 2;
    type state_t is (IDLE, RXING);

    type reg_t is record
        idx : natural range 0 to 7;
        state : state_t;
        invalid : std_logic;
        valid_msg : std_logic;
        last_match_crc : std_logic;
        crc_error : std_logic;
        msg_type : msg_type_t;
        req_type : request_t;
        last_was_k28_5 : std_logic;
        pol_invert : std_logic;
        pol_locked : std_logic;
    end record;
    constant rec_reset : reg_t := (
        idx => 0,
        state => IDLE,
        invalid => '0',
        valid_msg => '0',
        last_match_crc => '0',
        crc_error => '0',
        msg_type => HELLO,
        req_type => SystemPowerOn,
        last_was_k28_5 => '0',
        pol_invert => '0',
        pol_locked => '0'
    );

   

    signal r, rin : reg_t;
    signal crc_out : std_logic_vector(7 downto 0);
    signal wren :std_logic;
    signal is_sop : std_logic;
    signal is_eop : std_logic;
    signal is_k28_5 : std_logic;
    signal is_for_me : std_logic;

begin

    is_hello <= '1' when r.valid_msg = '1' and r.msg_type = Hello else '0';
    is_power_on <= '1' when r.valid_msg = '1' and r.msg_type = Request and r.req_type = SystemPowerOn else '0';
    is_power_off <= '1' when r.valid_msg = '1' and r.msg_type = Request and r.req_type = SystemPowerOff else '0';
    is_restart <= '1' when r.valid_msg = '1' and r.msg_type = Request and r.req_type = SystemReset else '0';
    pol_invert <= r.pol_invert and r.pol_locked;
    is_locked <= r.pol_locked;
    bad_crc <= r.crc_error;

    crc8autostar_8wide_inst: entity work.crc8autostar_8wide
    generic map(
        FINAL_XOR_VALUE => X"FF"
    )
     port map(
        clk => clk,
        reset => reset,
        data_in => ignit_rx.data,
        enable => wren,
        clear => r.valid_msg or r.crc_error,
        crc_out => crc_out
    );

    is_sop <= '1' when ignit_rx.ctrl = '1' and ignit_rx.data = start_of_message else '0';
    is_eop <= '1' when ignit_rx.ctrl = '1' and ignit_rx.data = end_of_message else '0';
    is_k28_5 <= '1' when ignit_rx.ctrl = '1' and ignit_rx.data = K28_5 else '0';
    is_for_me <= '1' when  valid = '1' and ignit_rx.channel = To_Std_Logic_Vector(CHAN_ID,1)(0) else '0';

    sm: process(all)
        variable v : reg_t;
    begin
        v := r;
        v.valid_msg := '0'; -- single cycle flags
        v.crc_error := '0';

        if is_aligned = '0' then
            v.pol_locked := '0';
            v.pol_invert := '0';
        end if;

        -- decoder is shared so only operate when data is for our channel
        if is_for_me then
            v.last_was_k28_5 := '0';  -- clear every valid word we get.

            if ignit_rx.data = crc_out then
                v.last_match_crc := '1';
            else
                v.last_match_crc := '0';
            end if;
            case r.state is
                when IDLE =>
                    if is_sop then
                        v.idx := 0;
                        v.invalid := '0';
                        v.last_match_crc := '0';
                        v.crc_error := '0';
                        v.state := RXING;
                    end if;

                when RXING =>
                    v.idx := r.idx + 1;
                    if r.idx > MAX_PKT_SIZE or r.pol_locked = '0' then
                        v.state := IDLE;
                        v.invalid := '1';
                    elsif is_eop then
                        v.state := IDLE;
                        if r.last_match_crc = '1' and r.invalid = '0' then
                            v.valid_msg := '1';
                        else
                            v.crc_error := '1';
                            v.idx := 0;
                            v.valid_msg := '0';
                        end if;
                    end if;
            end case;
           
            -- Deal with polarity inversion here.
            -- First we keep track of IDLE characters which we'll see regardless of
            -- polarity inversion thanks to K28.5 properties.
            -- Then we check the next word after the IDLE character. It should either
            -- be an IDLE1 or  IDLE character. These were chosen because they are
            -- not polarity symmetric. If we see our expected IDLE1 or IDLE2  data
            -- payload, then we know our polarity is correct and we lock it in.
            -- If we see one of the inverted IDLE characters, we know we're inverted
            -- so we set the invert flag and lock that in. If the aligner unlocks,
            -- we reset these and will re-evaluate when the aligner next locks.
            if is_k28_5 then
                v.last_was_k28_5 := '1';
            elsif ignit_rx.ctrl = '0' and r.last_was_k28_5 = '1' and r.pol_locked = '0' then
                -- non-inverted case:
                if ignit_rx.data = D10_2 or ignit_rx.data = D19_5 then
                    v.pol_invert := '0';
                    v.pol_locked := '1';
                elsif ignit_rx.data = D21_5 or ignit_rx.data = D12_2 then
                    v.pol_invert := '1';
                    v.pol_locked := '1';
                end if;
            end if;

            -- Store data at appropriate points.
            if r.state = RXING and r.idx = HEADER_IDX and ignit_rx.data /= 8x"1" then
                v.invalid := '1';  -- Version header was not correct.
            end if;
            if r.idx = MSG_TYPE_IDX then
                if to_integer(ignit_rx.data) = 0 or to_integer(ignit_rx.data) > 3 then
                    v.invalid := '1';
                else
                    -- Our ENUM is 0 indexed, but protocol is 1 indexed. we've guarded
                    -- the math above.
                    v.msg_type := msg_type_t'val(to_integer(ignit_rx.data) - 1);
                    if v.msg_type = Status then
                        v.invalid := '1';
                    end if;
                end if;
            end if;
             if r.idx = REQ_TYPE_IDX and r.msg_type = Request then
                if to_integer(ignit_rx.data) = 0 or to_integer(ignit_rx.data) > 3 then
                    v.invalid := '1';
                else
                    -- Our ENUM is 0 indexed, but protocol is 1 indexed. we've guarded
                    -- the math above.
                    v.req_type := request_t'val(to_integer(ignit_rx.data) - 1);
                end if;
            end if;

        end if;
        rin <= v;
    end process;

    reg: process(clk, reset)
    begin
        if reset = '1' then
            r <= rec_reset;
        elsif rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    -- no control characters into the crc checker, and only payload data.
    wren <= '1' when  is_for_me = '1' and r.state = RXING  and ignit_rx.ctrl = '0' else
            '0';




end rtl;