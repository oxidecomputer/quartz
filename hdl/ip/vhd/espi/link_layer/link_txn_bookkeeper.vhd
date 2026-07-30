-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

-- Fabric-domain half of the link layer: everything that has to keep working
-- when SCLK is not running, plus the handoff to and from the SCLK-domain PHY.
--
-- The packet FIFOs deliberately stay on this side. dcfifo_xpm needs several
-- cycles of both clocks to complete a reset, and SCLK only exists during a
-- transaction, so an XPM FIFO clocked by SCLK could be reset between
-- transactions and never come back.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_base_types_pkg.all;
use work.espi_protocol_pkg.all;
use work.link_layer_pkg.all;

entity link_txn_bookkeeper is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        --! eSPI chip select, active low, asynchronous.
        cs_n : in    std_logic;
        --! Chip select synchronized into this domain, shared with the alert
        --! generator so there is only one synchronizer on the pin.
        cs_n_syncd_o : out   std_logic;

        -- From the PHY. `rx_byte` is held stable for a full byte time either
        -- side of the toggle, so it needs no synchronizer of its own.
        rx_byte   : in    std_logic_vector(7 downto 0);
        rx_toggle : in    std_logic;

        -- Write port of the cross-domain response buffer the PHY reads.
        resp_wdata : out   std_logic_vector(7 downto 0);
        resp_wren  : out   std_logic;
        resp_wfull : in    std_logic;

        --! Command bytes from the host, into the fast-to-slow FIFO.
        cmd_to_fifo : view byte_source;
        --! Response bytes from the slow-to-fast FIFO.
        resp_from_fifo : view byte_sink;

        --! Number of WAIT_STATE bytes to prepend to every response, decided in
        --! the 125MHz domain from the negotiated mode and frequency.
        wait_states : in    std_logic_vector(3 downto 0);

        --! Single-cycle pulse on a completed eSPI in-band reset.
        espi_reset : out   std_logic
    );
end entity;

architecture rtl of link_txn_bookkeeper is

    signal cs_n_syncd     : std_logic;
    signal cs_n_last      : std_logic;
    signal rx_toggle_sync : std_logic;
    signal rx_toggle_last : std_logic;
    signal rx_stb         : std_logic;

    -- In-band reset is two 0xFF bytes with chip select asserted, reported when
    -- chip select rises. The SCLK-domain sizer cannot report it because there
    -- is no SCLK edge left by then, so it is recognised here instead.
    signal rx_byte_idx    : natural range 0 to 2;
    signal first_is_reset : std_logic;
    signal reset_pend     : std_logic;

    signal waits_left     : std_logic_vector(3 downto 0);
    signal push_wait      : std_logic;
    signal push_from_fifo : std_logic;

begin

    cs_n_syncd_o <= cs_n_syncd;

    cs_sync: entity work.meta_sync
        port map (
            async_input  => cs_n,
            clk          => clk,
            sycnd_output => cs_n_syncd
        );

    rx_toggle_sync_inst: entity work.meta_sync
        port map (
            async_input  => rx_toggle,
            clk          => clk,
            sycnd_output => rx_toggle_sync
        );

    -- ------------------------------------------------------------------
    -- Received bytes
    -- ------------------------------------------------------------------
    -- A toggle rather than a pulse: at quad/66MHz a byte lands every 30ns, so
    -- a level strobe would only be three fabric cycles wide and is easy to
    -- miss through a synchronizer. A toggle can never be lost.
    rx_stb <= rx_toggle_sync xor rx_toggle_last;

    rx_handoff: process(clk, reset)
    begin
        if reset then
            rx_toggle_last    <= '0';
            cs_n_last         <= '1';
            cmd_to_fifo.data  <= (others => '0');
            cmd_to_fifo.valid <= '0';
            rx_byte_idx       <= 0;
            first_is_reset    <= '0';
            reset_pend        <= '0';
            espi_reset        <= '0';
        elsif rising_edge(clk) then
            rx_toggle_last    <= rx_toggle_sync;
            cs_n_last         <= cs_n_syncd;
            cmd_to_fifo.valid <= '0';
            espi_reset        <= '0';

            if rx_stb = '1' then
                cmd_to_fifo.data  <= rx_byte;
                cmd_to_fifo.valid <= '1';

                -- First two bytes both 0xFF marks an in-band reset.
                if rx_byte_idx < 2 then
                    rx_byte_idx <= rx_byte_idx + 1;
                end if;
                if rx_byte_idx = 0 then
                    first_is_reset <= '1' when rx_byte = opcode_reset else '0';
                elsif rx_byte_idx = 1 and first_is_reset = '1' and rx_byte = opcode_reset then
                    reset_pend <= '1';
                end if;
            end if;

            if cs_n_syncd = '1' and cs_n_last = '0' then
                -- Chip select rose: retire any pending in-band reset and get
                -- ready for the next transaction.
                espi_reset     <= reset_pend;
                reset_pend     <= '0';
                rx_byte_idx    <= 0;
                first_is_reset <= '0';
            end if;
        end if;
    end process;

    -- ------------------------------------------------------------------
    -- Response feed
    -- ------------------------------------------------------------------
    -- Every response is prefixed with WAIT_STATE bytes, which is what buys the
    -- time for a command to reach the transaction layer and its response to
    -- come back. They are not covered by the CRC, so they are inserted here
    -- rather than upstream.
    --
    -- Nothing is pushed when the response FIFO is empty: the PHY emits 0xFF on
    -- underflow, which is the same thing on the wire and avoids filling the
    -- buffer with padding that would delay real data arriving behind it.
    push_wait <= '1' when cs_n_syncd = '0' and waits_left > 0 and resp_wfull = '0' else '0';

    push_from_fifo <= '1' when cs_n_syncd = '0' and waits_left = 0 and
                               resp_wfull = '0' and resp_from_fifo.valid = '1' else '0';

    resp_from_fifo.ready <= push_from_fifo;
    resp_wren            <= push_wait or push_from_fifo;
    resp_wdata           <= wait_state_code when push_wait = '1' else resp_from_fifo.data;

    resp_feed: process(clk, reset)
    begin
        if reset then
            waits_left <= (others => '0');
        elsif rising_edge(clk) then
            if cs_n_syncd = '1' then
                -- Reload for the next transaction while we are idle.
                waits_left <= wait_states;
            elsif push_wait = '1' then
                waits_left <= waits_left - 1;
            end if;
        end if;
    end process;

end rtl;
