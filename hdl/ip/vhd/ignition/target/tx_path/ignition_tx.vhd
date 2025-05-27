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

entity ignition_tx is
    generic(
        NUM_LEDS : positive := 2;
        NUM_BITS_IGNITION_ID : positive := 6
    );
    port(
        clk : in std_logic;
        reset : in std_logic;

        system_type_pins : in std_logic_vector(NUM_BITS_IGNITION_ID-1 downto 0);
        serdes_10b_datain : out std_logic_vector(9 downto 0);
        serdes_10b_datain_valid : out std_logic;
        serdes_10b_datain_ready : in std_logic;
        send_strobe : in std_logic;  -- timer or status change.
        packet_sent : out std_logic; -- packet has been sent
        system_status : in system_status_t;
        request_status : in request_status_t;
        system_faults : in system_faults_t;
        link0_status : in link_status_t;
        link0_events : in link_events_t;
        link1_status : in link_status_t;
        link1_events : in link_events_t

    );
end entity;

architecture rtl of ignition_tx is
    type state_t is (
        SND_K28_5, SND_IDLE1, SND_IDLE2, SND_SOP, SND_VERSION, SND_MSG_TYPE, SND_SYSTEM_TYPE, 
        SND_SYSTEM_STATUS, SND_SYSTEM_FAULTS, SND_REQUEST_STATUS,
        SND_LINK0_STATUS, SND_LINK0_EVENTS, SND_LINK1_STATUS, SND_LINK1_EVENTS,
        SND_CRC, SND_EOP1, SND_EOP2);

    type reg_t is record
        state : state_t;
        send_pend : std_logic;
        valid: std_logic;
        odd : std_logic;
        pkt_done : std_logic;
    end record;
    constant rec_reset : reg_t := (
        state => SND_K28_5,
        send_pend => '0',
        valid => '0',
        odd => '0',
        pkt_done => '0'
    );
    signal r, rin : reg_t;
    signal crc_clear : std_logic;
    signal crc_data : std_logic_vector(7 downto 0);
    signal enable_crc : std_logic;
    signal tx_dispin : std_logic;
    signal tx_dispout : std_logic;

    signal pre_encode_data_out : std_logic_vector(8 downto 0);
begin
    packet_sent <= r.pkt_done;
    pre_encode_data_out <=  '1' & K28_5 when r.state = SND_K28_5 else
                            '0' & IDLE1B when r.state = SND_IDLE1 else
                            '0' & IDLE2B when r.state = SND_IDLE2 else
                            '1' & START_OF_MESSAGE when r.state = SND_SOP else
                            9x"1" when r.state = SND_VERSION else
                            to_std_logic_vector(msg_type_t'pos(STATUS) + 1, 9) when r.state = SND_MSG_TYPE else
                            resize(system_type_pins, 9) when r.state = SND_SYSTEM_TYPE else
                            to_9b_slv(system_status) when r.state = SND_SYSTEM_STATUS else
                            to_9b_slv(request_status) when r.state = SND_REQUEST_STATUS else
                            to_9b_slv(system_faults) when r.state = SND_SYSTEM_FAULTS else
                            to_9b_slv(link0_status) when r.state = SND_LINK0_STATUS else
                            to_9b_slv(link0_events) when r.state = SND_LINK0_EVENTS else
                            to_9b_slv(link1_status) when r.state = SND_LINK1_STATUS else
                            to_9b_slv(link1_events) when r.state = SND_LINK1_EVENTS else
                            '0' & crc_data when r.state = SND_CRC else
                            '1' & END_OF_MESSAGE when r.state = SND_EOP1 else
                            '1' & BONUS_END_CHAR when r.state = SND_EOP2 else
                            (others => '0');
    serdes_10b_datain_valid <= '1';
    enable_crc <= serdes_10b_datain_ready when r.state > SND_SOP and r.state < SND_CRC else '0';
    
    crc8autostar_8wide_inst: entity work.crc8autostar_8wide
    generic map(
        -- see ignition_pkg.vhd for CRC parameters and reasoning
        FINAL_XOR_VALUE => CRC_XOR_FINAL_VALUE
    )
     port map(
        clk => clk,
        reset => reset,
        data_in => pre_encode_data_out(7 downto 0), -- no control char
        enable => enable_crc,
        clear => crc_clear,
        crc_out => crc_data
    );
    crc_clear <= '1' when r.state = SND_SOP else '0';
    -- TX logic
    -- We need to send something to both link partners every 25ms
    -- We send status messages on the timer or change in state.
    sm: process(all)
        variable v : reg_t;
    begin
        v := r;
        v.pkt_done := '0';

        if send_strobe = '1' then
            v.send_pend := '1';
        end if;

        case r.state is
            when SND_K28_5 =>
                if serdes_10b_datain_ready = '1' then
                    v.odd := not r.odd;
                    -- Backwards compat with legacy ignition.
                    -- There isn't valid rationale for this, but it is matching
                    -- the legacy implementation.
                    -- If we're in the k28.5 and have a positive disparity
                    -- then we need to send the IDLE1B
                    if tx_dispout = '1' then
                        v.state := SND_IDLE1;
                    else
                        v.state := SND_IDLE2;
                    end if;
                end if;
            when SND_IDLE1 | SND_IDLE2 =>
                if serdes_10b_datain_ready = '1' then
                    if v.send_pend then  -- want current combo send
                        v.state := SND_SOP;
                        v.send_pend := '0';
                    else -- nothing to send go back to sending IDLEs.
                        v.state := SND_K28_5;
                    end if;
                end if;
            when SND_EOP2 =>
                if serdes_10b_datain_ready = '1' then
                    v.state := SND_K28_5;
                    v.pkt_done := '1';
                end if;
            when others =>
                if serdes_10b_datain_ready = '1' then
                    -- move forward when ack'd
                    v.state := state_t'val(state_t'pos(r.state) + 1);
                end if;
        end case;

        rin <= v;
    end process;
  

    reg: process(clk, reset)
    begin
        if reset = '1' then
            r <= rec_reset;
            tx_dispin <= '0';
        elsif rising_edge(clk) then
            r <= rin;
            if serdes_10b_datain_valid = '1' and serdes_10b_datain_ready = '1' then
                tx_dispin <= tx_dispout;
            end if;
        end if;
    end process;



    encode_8b10b_inst: entity work.encode_8b10b
     port map(
        datain => pre_encode_data_out,
        dispin => tx_dispin,
        dataout => serdes_10b_datain,
        dispout => tx_dispout
    );
end rtl;