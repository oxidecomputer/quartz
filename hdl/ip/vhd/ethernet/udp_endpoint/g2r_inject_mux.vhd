-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Arbitrates the g2r stream into rgmii_tx between forwarded traffic (from
-- gmii_pkt_buf) and locally-built response frames (from eth_frame_tx).
-- Forwarded traffic has priority; a response is injected only at a frame
-- boundary after a full inter-frame gap.
--
-- rgmii_tx decimates by free-running sampling: one sample per byte period at
-- an arbitrary phase. Everything emitted here therefore holds each octet for
-- exactly speed_cycles_per_byte cycles with no mid-frame gaps -- one sample
-- then lands in every octet window regardless of the phase offset. All
-- decisions happen on the window-boundary tick, so dv edges and idle gaps
-- are whole byte periods too.
--
-- Injected frames are wrapped here: preamble+SFD prepended, zero-padded to
-- the 60-byte minimum, FCS computed and appended. The frame builder supplies
-- only DA-through-payload bytes. The CRC absorbs each byte on the tick that
-- ends its window, so on the tick that starts the FCS the combinational
-- crc_next -- which includes the final byte being absorbed at that same
-- edge -- provides the first FCS octet even at 1000M where the byte rate
-- equals the clock rate.

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.gmii_pkg.all;

entity g2r_inject_mux is
    generic (
        INJ_ADDR_BITS : positive := 9    -- response buffer byte-address width
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        speed : in    eth_speed_t;

        -- forwarded traffic (gmii_pkt_buf show-ahead)
        head_valid  : in    std_logic;
        head_marker : in    std_logic;
        head_er     : in    std_logic;
        head_data   : in    std_logic_vector(7 downto 0);
        pop         : out   std_logic;

        -- response frame (eth_frame_tx): DA..payload, no preamble/FCS
        inj_valid   : in    std_logic;
        inj_len     : in    unsigned(10 downto 0);
        inj_rd_addr : out   unsigned(INJ_ADDR_BITS - 1 downto 0);
        inj_rd_data : in    std_logic_vector(7 downto 0);   -- combinational
        inj_done    : out   std_logic;

        -- to rgmii_tx
        g2r : out   gmii_t;

        -- forward path popped empty mid-frame; design-error indicator
        underrun : out   std_logic
    );
end entity;

architecture rtl of g2r_inject_mux is

    constant MIN_FRAME_BYTES : natural := 60;   -- DA..payload, before FCS
    constant IFG_BYTES : natural := 12;

    type state_t is (IDLE, FWD, FWD_END, INJ_PRE, INJ_BODY, INJ_FCS);
    signal state : state_t := IDLE;

    signal phase   : natural range 0 to 99 := 0;
    signal tick    : std_logic;
    signal ifg_cnt : natural range 0 to 63 := 0;
    signal ifg_ok  : std_logic;

    signal gout : gmii_t := GMII_IDLE;

    signal cnt     : natural range 0 to 8 := 0;      -- preamble/FCS position
    signal out_cnt : unsigned(10 downto 0) := (others => '0');
    signal addr    : unsigned(INJ_ADDR_BITS - 1 downto 0) := (others => '0');
    signal flen    : unsigned(10 downto 0);

    signal crc_en    : std_logic;
    signal crc_clear : std_logic;
    signal crc_out   : std_logic_vector(31 downto 0);
    signal crc_next  : std_logic_vector(31 downto 0);
    signal fcs_reg   : std_logic_vector(31 downto 0) := (others => '0');

    signal underrun_sticky : std_logic := '0';

begin

    tick <= '1' when phase = speed_cycles_per_byte(speed) - 1 else '0';
    ifg_ok <= '1' when ifg_cnt >= IFG_BYTES else '0';

    flen <= inj_len when inj_len >= MIN_FRAME_BYTES else
            to_unsigned(MIN_FRAME_BYTES, flen'length);

    pop <= '1' when tick = '1' and head_valid = '1' and
                    ((state = IDLE and (head_marker = '1' or ifg_ok = '1')) or
                     state = FWD) else
           '0';

    -- each octet is absorbed on the tick that ends its window; body/pad
    -- windows only
    crc_en    <= '1' when tick = '1' and state = INJ_BODY else '0';
    crc_clear <= '1' when state = INJ_PRE or state = IDLE else '0';

    crc: entity work.crc32_8wide
        port map (
            clk      => clk,
            reset    => reset,
            data_in  => gout.data,
            enable   => crc_en,
            clear    => crc_clear,
            crc_out  => crc_out,
            crc_next => crc_next
        );

    g2r <= gout;
    underrun <= underrun_sticky;
    inj_rd_addr <= addr;

    mux_proc: process (clk, reset) is
    begin
        if reset = '1' then
            state    <= IDLE;
            phase    <= 0;
            ifg_cnt  <= 0;
            gout     <= GMII_IDLE;
            cnt      <= 0;
            out_cnt  <= (others => '0');
            addr     <= (others => '0');
            fcs_reg  <= (others => '0');
            inj_done <= '0';
            underrun_sticky <= '0';
        elsif rising_edge(clk) then
            inj_done <= '0';

            if tick = '1' then
                phase <= 0;
            else
                phase <= phase + 1;
            end if;

            if tick = '1' then
                -- inter-frame gap bookkeeping for the window just ended
                if gout.dv = '0' then
                    if ifg_cnt /= 63 then
                        ifg_cnt <= ifg_cnt + 1;
                    end if;
                else
                    ifg_cnt <= 0;
                end if;

                case state is
                    when IDLE =>
                        gout <= GMII_IDLE;
                        if head_valid = '1' and head_marker = '1' then
                            -- stray marker (e.g. from a frame dropped at
                            -- birth); discard, no output
                            null;
                        elsif head_valid = '1' and ifg_ok = '1' then
                            gout <= (data => head_data, dv => '1', er => head_er);
                            state <= FWD;
                        elsif inj_valid = '1' and ifg_ok = '1' then
                            gout  <= (data => X"55", dv => '1', er => '0');
                            cnt   <= 1;
                            state <= INJ_PRE;
                        end if;

                    when FWD =>
                        if head_valid = '0' then
                            -- reader outran the writer; should be impossible
                            -- with the same-rate design, but fail visibly
                            gout <= GMII_IDLE;
                            state <= IDLE;
                            underrun_sticky <= '1';
                        elsif head_marker = '1' then
                            if head_er = '1' then
                                -- truncated frame: one error octet so the
                                -- link partner sees the invalidation too
                                gout <= (data => X"00", dv => '1', er => '1');
                                state <= FWD_END;
                            else
                                gout <= GMII_IDLE;
                                state <= IDLE;
                            end if;
                        else
                            gout <= (data => head_data, dv => '1', er => head_er);
                        end if;

                    when FWD_END =>
                        gout <= GMII_IDLE;
                        state <= IDLE;

                    -- the CRC absorbs each octet on the tick that ends its
                    -- window, gated on state = INJ_BODY; the state must
                    -- therefore change only on the edge that *starts* the
                    -- first frame octet's window, which is why that octet is
                    -- placed from here and not from INJ_BODY
                    when INJ_PRE =>
                        if cnt = 8 then
                            gout.data <= inj_rd_data;
                            addr      <= addr + 1;
                            out_cnt   <= to_unsigned(1, out_cnt'length);
                            state     <= INJ_BODY;
                        elsif cnt = 7 then
                            gout.data <= X"D5";
                            addr      <= (others => '0');
                            cnt       <= 8;
                        else
                            gout.data <= X"55";
                            cnt       <= cnt + 1;
                        end if;

                    when INJ_BODY =>
                        if out_cnt = flen then
                            -- crc_next includes the final octet being
                            -- absorbed at this same edge
                            gout.data <= not crc_next(7 downto 0);
                            fcs_reg   <= not crc_next;
                            cnt       <= 1;
                            state     <= INJ_FCS;
                        else
                            if out_cnt < inj_len then
                                gout.data <= inj_rd_data;
                            else
                                gout.data <= X"00";   -- min-frame padding
                            end if;
                            addr    <= addr + 1;
                            out_cnt <= out_cnt + 1;
                        end if;

                    when INJ_FCS =>
                        if cnt = 4 then
                            gout     <= GMII_IDLE;
                            state    <= IDLE;
                            inj_done <= '1';
                        else
                            gout.data <= fcs_reg(8 * cnt + 7 downto 8 * cnt);
                            cnt       <= cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture;
