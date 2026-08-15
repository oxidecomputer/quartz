-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Captures one Ethernet frame at a time from the deduplicated r2g tap
-- (r2g_expander byte_pop) into a BRAM, checking the FCS as bytes arrive.
-- Strictly stop-and-forward: while a validated frame is waiting for the
-- parser, or the parser is walking it, arriving frames are dropped -- the
-- management protocol is idempotent and its clients retry. Frames with a bad
-- FCS, an er octet, or an out-of-bounds length are dropped silently (the
-- link partner's own MAC counted them already if anyone cares; we are just
-- a tap).
--
-- frame_len excludes the FCS. The buffer holds DA..FCS; the parser reads
-- through the synchronous port (rd_data lags rd_addr by one cycle).

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

use work.eth_hdr_pkg.all;

entity eth_frame_rx is
    generic (
        ADDR_BITS : positive := 11    -- 2 KB: max standard frame + margin
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        -- deduplicated tap: byte strobe + frame envelope (clk domain)
        tap_data : in    std_logic_vector(7 downto 0);
        tap_er   : in    std_logic;
        tap_dv   : in    std_logic;
        tap_pop  : in    std_logic;

        -- captured frame handshake
        frame_valid : out   std_logic;                 -- held until taken
        frame_len   : out   unsigned(10 downto 0);     -- DA..data, no FCS
        frame_taken : in    std_logic;                 -- parser is done

        -- parser read port
        rd_addr : in    unsigned(ADDR_BITS - 1 downto 0);
        rd_data : out   std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of eth_frame_rx is

    constant MIN_FRAME : natural := 64;     -- DA..FCS
    constant MAX_FRAME : natural := 1522;   -- 1518 + VLAN margin

    type mem_t is array (0 to 2 ** ADDR_BITS - 1) of std_logic_vector(7 downto 0);
    signal mem : mem_t;

    type state_t is (HUNT, CAPTURE, EVAL, HOLD, FLUSH);
    signal state : state_t := HUNT;

    signal wr_ptr  : unsigned(ADDR_BITS - 1 downto 0) := (others => '0');
    signal count   : unsigned(10 downto 0) := (others => '0');
    signal bad     : std_logic := '0';
    signal dv_prev : std_logic := '0';
    -- HUNT may be entered while a frame is already in flight (we were busy
    -- when it started); only arm on a frame whose beginning we saw
    signal saw_idle : std_logic := '0';

    signal crc_out   : std_logic_vector(31 downto 0);
    signal crc_clear : std_logic;
    signal crc_en    : std_logic;

begin

    crc_clear <= '1' when state = HUNT else '0';
    crc_en    <= '1' when state = CAPTURE and tap_pop = '1' else '0';

    crc: entity work.crc32_8wide
        port map (
            clk      => clk,
            reset    => reset,
            data_in  => tap_data,
            enable   => crc_en,
            clear    => crc_clear,
            crc_out  => crc_out,
            crc_next => open
        );

    capture_proc: process (clk, reset) is
    begin
        if reset = '1' then
            state       <= HUNT;
            wr_ptr      <= (others => '0');
            count       <= (others => '0');
            bad         <= '0';
            dv_prev     <= '0';
            frame_valid <= '0';
            frame_len   <= (others => '0');
        elsif rising_edge(clk) then
            dv_prev <= tap_dv;

            if tap_dv = '0' then
                saw_idle <= '1';
            elsif state /= HUNT then
                saw_idle <= '0';
            end if;

            case state is
                when HUNT =>
                    -- swallow preamble octets; arm on the SFD. A frame
                    -- without any preamble bytes before the SFD is fine.
                    wr_ptr <= (others => '0');
                    count  <= (others => '0');
                    bad    <= '0';
                    if tap_pop = '1' and saw_idle = '1' then
                        if tap_data = X"D5" and tap_er = '0' then
                            state    <= CAPTURE;
                            saw_idle <= '0';
                        elsif tap_data /= X"55" or tap_er = '1' then
                            -- not a preamble; ignore the rest of this frame
                            state <= FLUSH;
                        end if;
                    end if;

                when CAPTURE =>
                    if tap_pop = '1' then
                        if tap_er = '1' or count = MAX_FRAME then
                            bad   <= '1';
                            state <= FLUSH;
                        else
                            mem(to_integer(wr_ptr)) <= tap_data;
                            wr_ptr <= wr_ptr + 1;
                            count  <= count + 1;
                        end if;
                    elsif tap_dv = '0' and dv_prev = '1' then
                        -- one settle cycle so the CRC of the last octet has
                        -- registered before we judge the residue
                        state <= EVAL;
                    end if;

                when EVAL =>
                    if bad = '0' and count >= MIN_FRAME and
                       crc_out = ETH_CRC32_RESIDUE then
                        frame_valid <= '1';
                        frame_len   <= count - 4;
                        state       <= HOLD;
                    else
                        state <= HUNT;
                    end if;

                when HOLD =>
                    if frame_taken = '1' then
                        frame_valid <= '0';
                        state       <= HUNT;
                    end if;

                when FLUSH =>
                    if tap_dv = '0' and dv_prev = '1' then
                        state <= HUNT;
                    end if;
            end case;

            -- a frame arriving while we are busy is dropped wholesale: if
            -- dv rises anywhere outside HUNT's reach it will simply not be
            -- captured; HOLD explicitly ignores the tap
        end if;
    end process;

    read_proc: process (clk) is
    begin
        if rising_edge(clk) then
            rd_data <= mem(to_integer(rd_addr));
        end if;
    end process;

end architecture;
