-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tristate_if_pkg.all;
use work.i2c_common_pkg.all;
use work.axi_st8_pkg;
use work.arbiter_pkg.arbiter_mode;
use work.spd_proxy_pkg.all;

-- This block encapsulates the i2c proxy logic for one "channel", meaning
-- one i2c bus from the big CPU,  one i2c  bus to  some  number of DIMMs,
-- and provides the SPD caching for all of those DIMMs. It is build to be
-- instantiated multiple times to cover our needs (2x in the SP5 design, 6xDIMMS/bus)

entity proxy_fpga_i2c_logic is
    generic (
        NUM_DIMMS_ON_BUS : natural := 6;
        CLK_PER_NS  : positive;
        I2C_MODE    : mode_t
    );
    port(
        clk         : in std_logic;
        reset       : in std_logic;
        -- Local register interface T
        regs_if : view channel_side;

        bus_request : out std_logic;
        bus_grant : in std_logic;

         -- FPGA <-> CPU
        abort_or_finish : in std_logic;
        fpga_controller_idle : out std_logic;

        -- FPGA <-> DIMMs
        fpga_scl_if : view tristate_if;
        fpga_sda_if : view tristate_if;


    );
end entity;

architecture rtl of proxy_fpga_i2c_logic is
    signal selected : std_logic_vector(NUM_DIMMS_ON_BUS - 1 downto 0);
    signal spd_present : std_logic_vector(NUM_DIMMS_ON_BUS - 1 downto 0);
    signal sm_done : std_logic;
    signal selected_dimm_idx : natural range 0 to NUM_DIMMS_ON_BUS - 1;
    signal i2c_rx_st_if : axi_st8_pkg.axi_st_t;
    signal i2c_rx_st_if_cache : axi_st8_pkg.axi_st_t;
    signal i2c_tx_st_if : axi_st8_pkg.axi_st_t;
    signal i2c_tx_st_if_sm : axi_st8_pkg.axi_st_t;
    signal i2c_cmd_final : cmd_t;
    signal i2c_command_sm : cmd_t;
    signal i2c_command_sm_valid : std_logic;
    signal i2c_cmd_valid_final : std_logic;
    signal requests : std_logic_vector(1 downto 0);
    signal grants : std_logic_vector(1 downto 0);
    signal i2c_ctrlr_status : txn_status_t;
    signal spd_rom_waddr : std_logic_vector(9 downto 0);
    type rdata_array_t is array (0 to NUM_DIMMS_ON_BUS - 1) of std_logic_vector(31 downto 0);
    signal cache_rdata : rdata_array_t;
    signal req_arbiter : std_logic_vector(1 downto 0);

begin

    regs_if.done_prefetch <= sm_done;

    -- This adds a 1 clock delay to the rd-data to ease timing paths.
    -- Hubris can't turn around back-to-back clock reads so this should
    -- be a don't care, but provides an additional clock of prop delay
    reg_rd_mux: process(clk, reset)
    begin
        if reset then
            regs_if.rd_data <= (others => '0');
        elsif rising_edge(clk) then
            regs_if.rd_data <= (others => '0');
            for i in 0 to NUM_DIMMS_ON_BUS - 1 loop
                if regs_if.selected_dimm(i) = '1' then
                    regs_if.rd_data <= cache_rdata(i);
                end if;
            end loop;
        end if;
    end process;

    -- For-generate our cache blocks here, one for each possible DIMM
    cache_gen: for i in 0 to NUM_DIMMS_ON_BUS - 1 generate
        dimm_cache_inst: entity work.spd_cache
            port map(
                clk => clk,
                reset => reset,
                selected => selected(i),
                waddr => spd_rom_waddr,
                rdata =>cache_rdata(i),
                raddr => regs_if.rd_addr,
                i2c_rx_st_if => i2c_rx_st_if_cache
            );
    end generate;
    
    -- We deal with the DIMMs sequentially with a common state machine
    -- so we need to know which DIMM is selected and gate the cache
    -- blocks with that information. They otherwise see all the responses
    -- from the i2c controller in parallel so they need to filter and
    -- only respond to their own.
    cache_mux: process(clk, reset)
    begin
        if reset then
            selected <= (others => '0');
        elsif rising_edge(clk) then
            selected <= (others => '0');
            if not sm_done then
                selected(selected_dimm_idx) <= '1';
            end if;
        end if;
    end process;

    -- One state machine for this channel, will pre-fetch all the RAM info
    spd_sm_inst: entity work.spd_sm
     generic map(
        NUM_DIMMS_ON_BUS => NUM_DIMMS_ON_BUS
    )
     port map(
        clk => clk,
        reset => reset,
        fetch_spd_info => regs_if.start_prefetch,
        dimm_idx => selected_dimm_idx,
        sm_done => sm_done,
        arb_req => requests(0),
        arb_grant => grants(0),
        spd_present => spd_present,
        spd_rom_addr => spd_rom_waddr,
        i2c_ctrlr_status => i2c_ctrlr_status,
        i2c_command => i2c_command_sm,
        i2c_command_valid => i2c_command_sm_valid,
        i2c_tx_st_if => i2c_tx_st_if_sm,
        i2c_rx_st_if => i2c_rx_st_if_cache
    );

    regs_if.spd_present <= std_logic_vector(resize(unsigned(spd_present), regs_if.spd_present'length));

    -- One arbiter for this channel going to the actual bus controller
    -- In general, we'll allow the registers interface to run, except when
    -- the SPD pre-fetcher is running.
    -- we need to get granted from the main arbiter before we can arbitrate here.
    bus_request <= or requests;

    -- we cascade arbiters, so we only want to request from this arbiter if we already have
    -- been granted from the main bus arbiter.
    req_arbiter <= (requests(1) and bus_grant) & (requests(0) and bus_grant);
    arbiter_inst: entity work.arbiter
     generic map(
        mode => round_robin
    )
     port map(
        clk => clk,
        reset => reset,
        requests => req_arbiter,
        grants => grants
    );

    requests(1) <= regs_if.req;
    regs_if.grant <= grants(1);
    i2c_arb_mux: process(all)
    begin
        regs_if.i2c_rx_st_if.data <= i2c_rx_st_if.data; -- ok to always be connected gated by valid
        i2c_rx_st_if_cache.data <= i2c_rx_st_if.data;  -- ok to always be connected gated by valid

        if grants(0) = '1' then
            i2c_cmd_final <= i2c_command_sm;
            i2c_cmd_valid_final <= i2c_command_sm_valid;
            -- Data to i2c controller
            i2c_tx_st_if.data <= i2c_tx_st_if_sm.data;
            i2c_tx_st_if.valid <= i2c_tx_st_if_sm.valid;
            i2c_tx_st_if_sm.ready <= i2c_tx_st_if.ready;
            -- register interface
            regs_if.i2c_tx_st_if.ready <= '0';  -- reg not selected can't be ready
            regs_if.i2c_rx_st_if.valid <= '0'; -- Don't write to registers if not selected
            -- to/from spd_cache block
            i2c_rx_st_if_cache.valid <= i2c_rx_st_if.valid;
            i2c_rx_st_if.ready <= i2c_rx_st_if_cache.ready;  -- allow cache block to back-pressure
        elsif grants(1) = '1' then
            i2c_cmd_final <= regs_if.i2c_cmd;
            i2c_cmd_valid_final <= regs_if.i2c_cmd_valid;
            -- Data to i2c controller (connected to register interface)
            i2c_tx_st_if.valid <= regs_if.i2c_tx_st_if.valid;
            i2c_tx_st_if.data <= regs_if.i2c_tx_st_if.data;
            i2c_tx_st_if_sm.ready <= '0';
            -- register interface
            regs_if.i2c_tx_st_if.ready <= i2c_tx_st_if.ready;
            regs_if.i2c_rx_st_if.valid <= i2c_rx_st_if.valid;
            -- to/from spd_cache block (not connected)
            i2c_rx_st_if_cache.valid <= '0'; -- Don't write to cache if not selected
            i2c_rx_st_if.ready <= regs_if.i2c_rx_st_if.ready;

        else
            i2c_cmd_final <= regs_if.i2c_cmd;
            i2c_cmd_valid_final <= '0';
            -- Data to i2c controller (connected to register interface)
            i2c_tx_st_if.valid <= '0';
            i2c_tx_st_if.data <= regs_if.i2c_tx_st_if.data;
            i2c_tx_st_if_sm.ready <= '0';
            -- register interface
            regs_if.i2c_tx_st_if.ready <= i2c_tx_st_if.ready;
            regs_if.i2c_rx_st_if.valid <= i2c_rx_st_if.valid;
            -- to/from spd_cache block (not connected)
            i2c_rx_st_if_cache.valid <= '0'; -- Don't write to cache if not selected
            i2c_rx_st_if.ready <= regs_if.i2c_rx_st_if.ready; 
        end if;
    end process;

     -- FPGA I2C controller
    i2c_ctrl_txn_layer_inst: entity work.i2c_ctrl_txn_layer
        generic map(
            CLK_PER_NS  => CLK_PER_NS,
            MODE        => I2C_MODE
        )
        port map(
            clk         => clk,
            reset       => reset,
            scl_if      => fpga_scl_if,
            sda_if      => fpga_sda_if,
            cmd         => i2c_cmd_final,
            cmd_valid   => i2c_cmd_valid_final,
            abort       => abort_or_finish,
            txn_status  => i2c_ctrlr_status,
            core_ready  => fpga_controller_idle,
            tx_st_if    => i2c_tx_st_if,
            rx_st_if    => i2c_rx_st_if
        );

        regs_if.i2c_done  <= fpga_controller_idle;
        regs_if.i2c_aborted <= '1' when i2c_ctrlr_status = (ABORTED, '1', '0' ) else '0';

end rtl;