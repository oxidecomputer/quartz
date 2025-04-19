-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Provides clock-crossing between the link layer and transaction layer
-- and provides the debug mux for disconnecting the link layer and using
-- the debug mode to generate transactions.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.link_layer_pkg.all;

entity link_to_txn_bridge is
    port (
        clk_200m : in std_logic;
        reset_200m: in std_logic;

        clk   : in    std_logic;
        reset : in    std_logic;

        -- control signals
        -- slow clock domain
        txn_gen_enabled : in std_logic;
        espi_reset_slow : in std_logic;

        -- control signals
        -- fast clock domain
        espi_reset_fast : in std_logic;

        -- To/From the qspi link layer
        -- Fast clock domain
        qspi_cmd : view byte_sink;
        qspi_resp : view byte_source;
        qspi_cs_n : in std_logic;

        -- To/From the transaction generation layer
        -- Slow clock domain
        gen_cmd : view byte_sink;
        gen_resp : view byte_source;
        gen_cs_n : in std_logic;

        -- To/From the transaction layer
        -- Slow clock domain
        txn_cmd : view byte_source;
        txn_resp : view byte_sink;
        txn_csn : out std_logic;
    );
end entity;

architecture rtl of link_to_txn_bridge is
    attribute mark_debug : string;
    signal qspi_cmd_wfull : std_logic;
    signal qspi_cmd_slow_rempty : std_logic;
    signal qspi_cmd_slow_rdata : std_logic_vector(7 downto 0);
    signal qspi_cmd_rdack : std_logic;
    signal qspi_resp_rempty : std_logic;
    signal qspi_cs_n_syncd : std_logic;
    signal qspi_resp_slow_write_en : std_logic;
    attribute mark_debug of qspi_resp_slow_write_en : signal is "true";
    signal qspi_resp_rdata : std_logic_vector(7 downto 0);
    signal qspi_resp_rdack : std_logic;
    signal qspi_resp_slow_wfull : std_logic;
    signal fifo_reset_fast : std_logic;
    signal fifo_reset_slow : std_logic;
    signal cmd_rusedwds : std_logic_vector(4 downto 0);
    attribute mark_debug of cmd_rusedwds : signal is "true";
    signal resp_wusedwds : std_logic_vector(8 downto 0);
    attribute mark_debug of resp_wusedwds : signal is "true";

begin

    meta_sync_inst: entity work.meta_sync
     port map(
        async_input => qspi_cs_n,
        clk => clk,
        sycnd_output => qspi_cs_n_syncd
    );


    -- I don't love this pattern but we're going to combine the system reset with the 
    -- espi reset and clean out these FIFOs on an espi reset, which happens at the beginning
    -- of every boot.
    rst_combine:process(clk_200m, reset_200m)
     begin
        if reset_200m = '1' then
            fifo_reset_fast <= '1';
        elsif rising_edge(clk_200m) then
            fifo_reset_fast <= espi_reset_fast;
        end if;
    end process;

    rst_slow_combine:process(clk, reset)
    begin
       if reset = '1' then
            fifo_reset_slow <= '1';
       elsif rising_edge(clk) then
            fifo_reset_slow <= espi_reset_slow;
       end if;
    end process;

-- CMD Clock cross from fast to slow domains
qspi_cmd_fifo: entity work.dcfifo_xpm
 generic map(
    fifo_write_depth => 16,
    data_width => 8,
    showahead_mode => true
)
 port map(
    wclk => clk_200m,
    reset => fifo_reset_fast,
    write_en => qspi_cmd.valid and qspi_cmd.ready,
    wdata => qspi_cmd.data,
    wfull => qspi_cmd_wfull,
    wusedwds => open,
    rclk => clk,
    rdata => qspi_cmd_slow_rdata,
    rdreq => qspi_cmd_rdack,
    rempty => qspi_cmd_slow_rempty,
    rusedwds => cmd_rusedwds
);
qspi_cmd.ready <= not qspi_cmd_wfull; -- always drive this, it's a fast domain signal

-- Response cross from slow to fast domains
qspi_resp_fifo: entity work.dcfifo_xpm
 generic map(
    fifo_write_depth => 256,
    data_width => 8,
    showahead_mode => true
)
 port map(
    wclk => clk,
    reset => fifo_reset_slow,
    write_en => qspi_resp_slow_write_en,
    wdata => txn_resp.data,
    wfull => qspi_resp_slow_wfull,
    wusedwds => resp_wusedwds,
    rclk => clk_200m,
    rdata => qspi_resp_rdata,
    rdreq => qspi_resp_rdack,
    rempty => qspi_resp_rempty,
    rusedwds => open
);


    -- Response cross from slwo to fast domains, not in mux below
    qspi_resp.valid <= not qspi_resp_rempty;
    qspi_resp.data <= qspi_resp_rdata;
    qspi_resp_rdack <= qspi_resp.valid and qspi_resp.ready;

    mux: process(all)
    begin
        if txn_gen_enabled then
            -- DEBUG MODE
            txn_cmd.valid <= gen_cmd.valid;
            txn_cmd.data <= gen_cmd.data;
            gen_cmd.ready <= txn_cmd.ready;
            qspi_cmd_rdack <= '0';  -- No reads from qspi layer in debug mode

            txn_resp.ready <= gen_resp.ready;
            gen_resp.valid <= txn_resp.valid;
            gen_resp.data <= txn_resp.data;
            qspi_resp_slow_write_en <= '0'; -- No writes to qspi layer in debug mode
            txn_csn <= gen_cs_n;
        else
            -- NORMAL MODE
            txn_cmd.valid <= not qspi_cmd_slow_rempty;
            txn_cmd.data <= qspi_cmd_slow_rdata;
            gen_cmd.ready <= '0';
            -- we don't drive qspi_cmd here b/c it's a fast signal
            qspi_cmd_rdack <= txn_cmd.valid and txn_cmd.ready;
            gen_resp.valid <= '0';
            gen_resp.data <= (others => '0');
            txn_resp.ready <= not qspi_resp_slow_wfull;
            qspi_resp_slow_write_en <= txn_resp.valid and txn_resp.ready;
            txn_csn <= qspi_cs_n_syncd;
        end if;
    end process;


end rtl;

