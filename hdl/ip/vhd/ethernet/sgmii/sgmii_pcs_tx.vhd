-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII PCS transmit datapath: ordered-set / code-group generation feeding the
-- combinational 8B10B encoder. Driven by the auto-neg `xmit` mode:
--   XMIT_CONFIG -> stream /C1//C2/ config ordered sets carrying tx_config_word
--   XMIT_IDLE   -> stream /I1//I2/ idle ordered sets
--   XMIT_DATA   -> idle until gmii.dv, then /S/, data octets, /T/, /R/
--
-- The PCS is rate-agnostic: it emits one code group per GMII octet. SGMII
-- 10/100 rate adaptation (each octet replicated 10x/100x) is handled at the
-- RGMII<->GMII boundary, so at 100/10 Mbps the first preamble octet becomes
-- /S/ and the remaining replicated preamble octets are sent as data, exactly
-- per the SGMII convention.
--
-- GMII handshake (valid/ready): gmii.dv is valid, gmii_ready is a combinational
-- accept. An octet transfers on a rising edge where both are high; the producer
-- advances only then. The first frame octet (a preamble byte) is accepted and
-- replaced by /S/ on the line.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.helper_8b10b_pkg.all;
use work.gmii_pkg.all;
use work.sgmii_pkg.all;

entity sgmii_pcs_tx is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- control from auto-neg
        xmit           : in    pcs_xmit_t;
        tx_config_word : in    std_logic_vector(15 downto 0);

        -- GMII octet stream to transmit (valid/ready handshake)
        gmii       : in    gmii_t;
        gmii_ready : out   std_logic;   -- combinational accept

        -- 1.25 Gbaud code-group output (one per clock)
        tx_code       : out   std_logic_vector(9 downto 0);
        tx_code_valid : out   std_logic
    );
end entity;

architecture rtl of sgmii_pcs_tx is

    type tx_state_t is (TX_QUIET, TX_SOP, TX_FRAME, TX_EPD_R);

    signal state      : tx_state_t;
    signal idle_phase : std_logic;              -- 0 = comma, 1 = idle data
    signal cfg_phase  : unsigned(1 downto 0);   -- 0..3 within /C/ ordered set
    signal c1c2       : std_logic;              -- alternates /C1/ <-> /C2/

    signal cur_cg   : code_byte_t;
    signal tx_disp  : std_logic;
    signal enc_data : std_logic_vector(9 downto 0);
    signal enc_disp : std_logic;

    signal frame_start : std_logic;

begin

    enc_inst: entity work.encode_8b10b
        port map (
            datain  => cur_cg,
            dispin  => tx_disp,
            dataout => enc_data,
            dispout => enc_disp
        );

    tx_code_valid <= '1';

    -- a frame may start only on an idle ordered-set boundary
    frame_start <= '1' when state = TX_QUIET and xmit = XMIT_DATA
                            and gmii.dv = '1' and idle_phase = '0'
                   else '0';

    -- accept an octet when it begins the frame or while streaming frame data
    gmii_ready <= '1' when frame_start = '1'
                          or (state = TX_FRAME and gmii.dv = '1')
                  else '0';

    -- Current code group as a combinational function of state.
    comb: process (all) is
    begin
        case state is
            when TX_QUIET =>
                if xmit = XMIT_CONFIG then
                    case to_integer(cfg_phase) is
                        when 0      => cur_cg <= COMMA;
                        when 1      => cur_cg <= d_byte(D21_5) when c1c2 = '0' else d_byte(D2_2);
                        when 2      => cur_cg <= d_byte(tx_config_word(7 downto 0));
                        when others => cur_cg <= d_byte(tx_config_word(15 downto 8));
                    end case;
                elsif idle_phase = '0' then
                    cur_cg <= COMMA;
                elsif tx_disp = '1' then
                    cur_cg <= d_byte(D5_6);    -- /I1/ restores RD to negative
                else
                    cur_cg <= d_byte(D16_2);   -- /I2/ preserves RD negative
                end if;
            when TX_SOP =>
                cur_cg <= SOP;
            when TX_FRAME =>
                if gmii.dv = '1' then
                    cur_cg <= ERRP when gmii.er = '1' else d_byte(gmii.data);
                else
                    cur_cg <= EOP;             -- /T/ once the octet stream ends
                end if;
            when TX_EPD_R =>
                cur_cg <= CEXT;                -- /R/
        end case;
    end process;

    reg: process (clk, reset) is
    begin
        if reset = '1' then
            state      <= TX_QUIET;
            idle_phase <= '0';
            cfg_phase  <= (others => '0');
            c1c2       <= '0';
            tx_disp    <= '0';
            tx_code    <= (others => '0');
        elsif rising_edge(clk) then
            -- register the encoded code group and the new running disparity
            tx_code <= enc_data;
            tx_disp <= enc_disp;

            case state is
                when TX_QUIET =>
                    if xmit = XMIT_CONFIG then
                        idle_phase <= '0';
                        if cfg_phase = 3 then
                            cfg_phase <= (others => '0');
                            c1c2      <= not c1c2;
                        else
                            cfg_phase <= cfg_phase + 1;
                        end if;
                    else
                        cfg_phase  <= (others => '0');
                        idle_phase <= not idle_phase;
                        if frame_start = '1' then
                            state <= TX_SOP;   -- octet accepted, /S/ replaces it
                        end if;
                    end if;

                when TX_SOP =>
                    state <= TX_FRAME;

                when TX_FRAME =>
                    if gmii.dv = '0' then
                        state <= TX_EPD_R;     -- /T/ emitted this slot
                    end if;

                when TX_EPD_R =>
                    idle_phase <= '0';
                    state      <= TX_QUIET;
            end case;
        end if;
    end process;

end architecture;
