-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

-- Source-synchronous eSPI link layer.
--
-- Replaces the oversampling `link_layer`, keeping the same port list so the
-- swap at the top level is a drop-in, with two differences: `cs_n` and `sclk`
-- must now arrive raw rather than synchronized into the fabric domain. SCLK is
-- used as a clock here, so the tools infer a clock buffer on it.
--
-- Split into a PHY clocked by SCLK and a bookkeeper clocked by the fabric
-- clock. The dividing line is "does this have to work when SCLK is not
-- running": alerts and the packet FIFOs do, the serdes does not.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.espi_base_types_pkg.all;
use work.link_layer_pkg.all;

entity espi_link_layer is
    port (
        --! Fabric clock (200MHz).
        clk   : in    std_logic;
        reset : in    std_logic;

        -- PHY signals, raw from the pins
        cs_n         : in    std_logic;
        sclk         : in    std_logic;
        io           : in    std_logic_vector(3 downto 0);
        io_o         : out   std_logic_vector(3 downto 0);
        io_oe        : out   std_logic_vector(3 downto 0);
        --! "Fake" chip select to help saleae decode the response stream, which
        --! is offset from the command stream by the turnaround.
        response_csn : out   std_logic;

        --! Command FIFO interface, data from host goes into this fifo
        cmd_to_fifo : view byte_source;
        --! Response FIFO interface, data to host comes out of this fifo
        resp_from_fifo : view byte_sink;

        -- System interface (from slow domain, already sync'd)
        wait_states  : in    std_logic_vector(3 downto 0);
        qspi_mode    : in    qspi_mode_t;
        --! Launch a half period early; only valid at the top frequency. See the
        --! serializer in espi_phy.
        early_launch : in    std_logic;
        alert_needed : in    std_logic;

        --! Registered in the fabric domain, synchronized onward externally.
        espi_reset : out   std_logic
    );
end entity;

architecture rtl of espi_link_layer is

    signal cs_n_syncd : std_logic;

    signal rx_byte   : std_logic_vector(7 downto 0);
    signal rx_toggle : std_logic;

    signal resp_wdata : std_logic_vector(7 downto 0);
    signal resp_wren  : std_logic;
    signal resp_wfull : std_logic;
    signal resp_rdata : std_logic_vector(7 downto 0);
    signal resp_rdack : std_logic;
    signal resp_rempty : std_logic;

    signal phy_io_o : std_logic_vector(3 downto 0);
    signal resp_oe  : std_logic_vector(3 downto 0);

    signal active_alert : std_logic;

begin

    phy: entity work.espi_phy
        port map (
            sclk      => sclk,
            cs_n      => cs_n,
            io        => io,
            io_o      => phy_io_o,
            resp_oe   => resp_oe,
            qspi_mode => qspi_mode,
            early_launch => early_launch,
            rx_byte   => rx_byte,
            rx_toggle => rx_toggle,
            tx_data   => resp_rdata,
            tx_empty  => resp_rempty,
            tx_rdack  => resp_rdack
        );

    bookkeeper: entity work.link_txn_bookkeeper
        port map (
            clk            => clk,
            reset          => reset,
            cs_n           => cs_n,
            cs_n_syncd_o   => cs_n_syncd,
            rx_byte        => rx_byte,
            rx_toggle      => rx_toggle,
            resp_wdata     => resp_wdata,
            resp_wren      => resp_wren,
            resp_wfull     => resp_wfull,
            cmd_to_fifo    => cmd_to_fifo,
            resp_from_fifo => resp_from_fifo,
            wait_states    => wait_states,
            espi_reset     => espi_reset
        );

    -- Cleared by chip select, so every transaction starts with an empty
    -- response buffer regardless of how the previous one ended.
    resp_buffer: entity work.resp_byte_xfifo
        port map (
            clear  => cs_n,
            wclk   => clk,
            wdata  => resp_wdata,
            wren   => resp_wren,
            wfull  => resp_wfull,
            rclk   => sclk,
            rdata  => resp_rdata,
            rdack  => resp_rdack,
            rempty => resp_rempty
        );

    -- The in-band alert has to be driven with no SCLK running, so it lives in
    -- the fabric domain and is merged with the PHY's response-phase drive
    -- here. The two are mutually exclusive in time: alerts are only issued
    -- while chip select is deasserted.
    alert_gen_inst: entity work.alert_gen
        port map (
            clk          => clk,
            reset        => reset,
            alert_needed => alert_needed,
            cs_n         => cs_n_syncd,
            active_alert => active_alert
        );

    io_oe <= resp_oe or "0010" when active_alert = '1' else resp_oe;

    -- IO[1] doubles as the alert pin per the AMD convention. The alert works by
    -- asserting the output enable alone: the PHY idles IO[1] low while chip
    -- select is deasserted, so no mux is needed here, which keeps the PHY's
    -- output register adjacent to the pad and packable into the IOB.
    io_o <= phy_io_o;

    -- Debug aid only: mark the window where we are driving the response.
    saleae_response_cs_gen: process(clk, reset)
    begin
        if reset then
            response_csn <= '1';
        elsif rising_edge(clk) then
            if cs_n_syncd = '1' then
                response_csn <= '1';
            elsif resp_oe /= "0000" then
                response_csn <= '0';
            end if;
        end if;
    end process;

end rtl;
