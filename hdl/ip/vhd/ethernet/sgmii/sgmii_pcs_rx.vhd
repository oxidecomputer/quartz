-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- SGMII PCS receive datapath: 8B10B decode of the already comma-aligned 10-bit
-- code groups followed by an ordered-set receive state machine. It strips idle
-- ordered sets, recovers frames (/S/ -> preamble + data -> /T//R/), maps /V/ and
-- code/disparity errors to rx_er, and extracts /C/ config ordered sets to the
-- auto-neg block.
--
-- The PCS is rate-agnostic: one GMII octet per data code group. At 100/10 Mbps
-- the line carries each octet replicated 10x/100x; that replicated octet stream
-- is decimated downstream at the RGMII<->GMII boundary, not here.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.helper_8b10b_pkg.all;
use work.gmii_pkg.all;
use work.sgmii_pkg.all;

entity sgmii_pcs_rx is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- aligned 1.25 Gbaud code-group input (one per clock when valid)
        rx_code       : in    std_logic_vector(9 downto 0);
        rx_code_valid : in    std_logic;

        -- recovered GMII octet stream
        gmii : out   gmii_t;

        -- extracted config ordered set to auto-neg
        rx_config_word  : out   std_logic_vector(15 downto 0);
        rx_config_valid : out   std_logic
    );
end entity;

architecture rtl of sgmii_pcs_rx is

    -- receive ordered-set state machine. RX_OS is entered after a comma while
    -- the following code groups classify the ordered set (idle vs config).
    type rx_state_t is (RX_QUIET, RX_OS, RX_FRAME);

    signal state    : rx_state_t;
    signal os_idx   : unsigned(1 downto 0);          -- code-group index after comma
    signal cfg_lo   : std_logic_vector(7 downto 0);
    signal rx_disp  : std_logic;

    -- combinational decoder outputs
    signal dec_data : std_logic_vector(8 downto 0);  -- {k, data}
    signal dec_disp : std_logic;
    signal code_err : std_logic;
    signal disp_err : std_logic;

    alias dec_k    : std_logic is dec_data(8);
    alias dec_byte : std_logic_vector(7 downto 0) is dec_data(7 downto 0);

begin

    dec_inst: entity work.decode_8b10b
        port map (
            datain   => rx_code,
            dispin   => rx_disp,
            dataout  => dec_data,
            dispout  => dec_disp,
            code_err => code_err,
            disp_err => disp_err
        );

    rx: process (clk, reset) is
        variable is_comma : boolean;
        variable is_sop   : boolean;
        variable is_eop   : boolean;
        variable is_cext  : boolean;
        variable is_errp  : boolean;
        variable any_err  : boolean;
    begin
        if reset = '1' then
            state           <= RX_QUIET;
            os_idx          <= (others => '0');
            cfg_lo          <= (others => '0');
            rx_disp         <= '0';
            gmii            <= GMII_IDLE;
            rx_config_word  <= (others => '0');
            rx_config_valid <= '0';
        elsif rising_edge(clk) then
            -- single-cycle strobes default low
            gmii.dv         <= '0';
            gmii.er         <= '0';
            rx_config_valid <= '0';

            if rx_code_valid = '1' then
                rx_disp <= dec_disp;

                is_comma := dec_k = '1' and dec_byte = K28_5;
                is_sop   := dec_k = '1' and dec_byte = K27_7;
                is_eop   := dec_k = '1' and dec_byte = K29_7;
                is_cext  := dec_k = '1' and dec_byte = K23_7;
                is_errp  := dec_k = '1' and dec_byte = K30_7;
                any_err  := code_err = '1' or disp_err = '1';

                case state is
                    when RX_QUIET =>
                        if is_sop then
                            gmii.data <= x"55";    -- /S/ -> regenerate preamble octet
                            gmii.dv   <= '1';
                            state     <= RX_FRAME;
                        elsif is_comma then
                            state  <= RX_OS;
                            os_idx <= to_unsigned(1, os_idx'length);
                        end if;

                    when RX_OS =>
                        -- code groups following a comma
                        if is_comma then
                            os_idx <= to_unsigned(1, os_idx'length);  -- restart ordered set
                        elsif is_sop then
                            gmii.data <= x"55";
                            gmii.dv   <= '1';
                            state     <= RX_FRAME;
                        elsif os_idx = 1 then
                            -- second code group: D21.5/D2.2 => config, else idle/end
                            if dec_k = '0' and (dec_byte = D21_5 or dec_byte = D2_2) then
                                os_idx <= to_unsigned(2, os_idx'length);
                            else
                                state <= RX_QUIET;  -- idle ordered set complete
                            end if;
                        elsif os_idx = 2 then
                            cfg_lo <= dec_byte;     -- config_reg[7:0]
                            os_idx <= to_unsigned(3, os_idx'length);
                        else
                            rx_config_word  <= dec_byte & cfg_lo;  -- config_reg[15:8]
                            rx_config_valid <= '1';
                            state           <= RX_QUIET;
                        end if;

                    when RX_FRAME =>
                        if is_eop or is_comma then
                            state <= RX_QUIET;       -- /T/ ends the frame
                        elsif is_cext then
                            null;                    -- /R/ carrier extend, drop
                        elsif is_errp or any_err then
                            gmii.dv <= '1';
                            gmii.er <= '1';
                        else
                            gmii.data <= dec_byte;   -- data octet
                            gmii.dv   <= '1';
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture;
