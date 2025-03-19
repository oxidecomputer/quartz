-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.i2c_common_pkg.all;
use work.stream8_pkg;
use work.time_pkg.all;
use work.tristate_if_pkg.all;

entity spd_proxy_top is
    generic (
        CLK_PER_NS  : positive;
        I2C_MODE    : mode_t;
    );
    port (
        clk         : in std_logic;
        reset       : in std_logic;

        -- CPU <-> FPGA
        cpu_scl_if  : view tristate_if;
        cpu_sda_if  : view tristate_if;

        -- FPGA <-> DIMMs
        dimm_scl_if : view tristate_if;
        dimm_sda_if : view tristate_if;

        -- FPGA I2C Interface
        i2c_command         : in cmd_t;
        i2c_command_valid   : in std_logic;
        i2c_ctrlr_idle      : out std_logic;
        i2c_tx_st_if        : view stream8_pkg.st_sink_if;
        i2c_rx_st_if        : view stream8_pkg.st_source_if;
    );
end entity;

architecture rtl of spd_proxy_top is
    -- TODO: Just use a single TSP constant?
    constant DIMM_I2C_TSP_CYCLES : integer :=
        to_integer(calc_ns(get_i2c_settings(I2C_MODE).tsp_ns, CLK_PER_NS, 8));
    constant CPU_I2C_TSP_CYCLES : integer :=
        to_integer(calc_ns(get_i2c_settings(STANDARD).tsp_ns, CLK_PER_NS, 8));
    signal cpu_scl_filt         : std_logic;
    signal cpu_scl_fedge        : std_logic;
    signal cpu_scl_redge        : std_logic;
    signal cpu_sda_filt         : std_logic;
    signal cpu_sda_fedge        : std_logic;
    signal cpu_sda_redge        : std_logic;
    signal cpu_start_detected   : std_logic;
    signal cpu_stop_detected    : std_logic;
    signal cpu_busy             : std_logic;
    signal cpu_has_mux          : std_logic;
    signal cpu_first_start_seen : boolean;

    signal dimm_scl_filt        : std_logic;
    signal dimm_sda_filt        : std_logic;
    signal dimm_sda_fedge       : std_logic;
    signal dimm_sda_redge       : std_logic;

    signal cpu_sda_oe           : std_logic;
    signal dimm_sda_oe          : std_logic;

    signal ctrlr_scl_if         : tristate;
    signal ctrlr_sda_if         : tristate;
    signal ctrlr_has_int_mux    : boolean;

    signal fpga_scl_if  : tristate;
    signal fpga_sda_if  : tristate;

    constant CNTR_SIZE      : integer := 8;
    -- use the FAST_PLUS hold time since we know the targets support it
    constant START_HD_TICKS : std_logic_vector(CNTR_SIZE - 1 downto 0) :=
        calc_ns(get_i2c_settings(FAST_PLUS).sta_su_hd_ns, CLK_PER_NS, CNTR_SIZE);
    signal need_start       : boolean;
    signal scl_sim          : std_logic;
    signal sda_sim          : std_logic;
    signal sda_sim_fedge    : std_logic;
    signal start_simulated  : std_logic;

    signal cpu_seen         : boolean;
    signal fpga_txn_valid   : std_logic;

    signal cpu_has_sda      : std_logic;
    signal dimm_has_sda     : std_logic;
begin
    dimm_glitch_filter_inst: entity work.i2c_glitch_filter
        generic map(
            filter_cycles   => DIMM_I2C_TSP_CYCLES
        )
        port map(
            clk             => clk,
            reset           => reset,
            raw_scl         => dimm_scl_if.i,
            raw_sda         => dimm_sda_if.i,
            filtered_scl    => dimm_scl_filt,
            scl_redge       => open,
            scl_fedge       => open,
            filtered_sda    => dimm_sda_filt,
            sda_redge       => dimm_sda_redge,
            sda_fedge       => dimm_sda_fedge
        );

    --
    -- CPU bus monitoring
    --
    cpu_glitch_filter_inst: entity work.i2c_glitch_filter
        generic map(
            filter_cycles   => CPU_I2C_TSP_CYCLES
        )
        port map(
            clk             => clk,
            reset           => reset,
            raw_scl         => cpu_scl_if.i,
            raw_sda         => cpu_sda_if.i,
            filtered_scl    => cpu_scl_filt,
            scl_redge       => cpu_scl_redge,
            scl_fedge       => cpu_scl_fedge,
            filtered_sda    => cpu_sda_filt,
            sda_redge       => cpu_sda_redge,
            sda_fedge       => cpu_sda_fedge
        );

    -- on a START we need to request the controller abort any in-progress transaction
    cpu_start_detected  <= '1' when cpu_scl_filt = '1' and cpu_sda_fedge = '1' else '0';
    -- on a STOP we know the CPU is done and we can resume our work
    cpu_stop_detected   <= '1' when cpu_scl_filt = '1' and cpu_sda_redge = '1' else '0';

    bus_monitor: process(clk, reset)
    begin
        if reset then
            cpu_busy                <= '0';
            need_start              <= false;
            cpu_first_start_seen    <= false;
            cpu_seen                <= false;
        elsif rising_edge(clk) then
            if cpu_start_detected then
                cpu_busy                <= '1';
                cpu_first_start_seen    <= true;
            elsif cpu_stop_detected then
                cpu_busy    <= '0';
            end if;

            -- The FPGA still owns the bus and the START hold time as elapsed. This means before
            -- the mux is swapped we need to simulate a START condition .
            if i2c_ctrlr_idle = '0' and cpu_scl_fedge = '1' then
                need_start  <= true;
            elsif start_simulated then
                need_start  <= false;
            end if;

            -- TODO: enabling the internal controller should probably just be an external thing
            -- from registers the SP can set. While proxy is not enabled, we should just assume the
            -- CPU always owns the bus.
            -- after the first START/STOP detection, register that we've seen CPU activity
            if cpu_first_start_seen and cpu_stop_detected = '1' and not cpu_seen then
                cpu_seen    <= true;
            end if;
        end if;
    end process;

    start_generator: process(clk, reset)
        variable sda_sim_next   : std_logic;
    begin
        if reset then
            scl_sim         <= '1';
            sda_sim         <= '1';
            sda_sim_fedge   <= '1';
            sda_sim_next    := '1';
        elsif rising_edge(clk) then
            -- Do we need to perhaps be smarter here around sending SCL low prior to handing the
            -- bus back to the CPU? We may not need to worry about simulating a falling edge on SCL
            -- since that will happen automatically when we cut over to the CPU bus where SCL is low
            -- already, but we can't know the state of SDA. A hard cutover back to the CPU with SCL
            -- going low and SDA going high the same cycle could theoretically cause a STOP glitch?
            scl_sim <= '1';
            if need_start and not ctrlr_has_int_mux and start_simulated = '0' then
                -- create the artifical START condition
                sda_sim_next    := '0';
            else
                sda_sim_next    := '1';
            end if;

            -- use the falling edge to load the simulated START hold time counter
            sda_sim_fedge   <= '1' when sda_sim = '1' and sda_sim_next = '0' else '0';
            sda_sim         <= sda_sim_next;
        end if;
    end process;

    countdown_inst: entity work.countdown
        generic map (
            SIZE    => CNTR_SIZE
        )
        port map (
            clk     => clk,
            reset   => reset,
            count   => START_HD_TICKS,
            load    => sda_sim_fedge,
            decr    => not sda_sim,
            clear   => '0',
            done    => start_simulated
        );

    fpga_txn_valid <= '1' when cpu_seen and i2c_command_valid = '1' else '0';

    -- FPGA I2C controller
    i2c_ctrl_txn_layer_inst: entity work.i2c_ctrl_txn_layer
        generic map(
            CLK_PER_NS  => CLK_PER_NS,
            MODE        => I2C_MODE
        )
        port map(
            clk         => clk,
            reset       => reset,
            scl_if      => ctrlr_scl_if,
            sda_if      => ctrlr_sda_if,
            cmd         => i2c_command,
            cmd_valid   => fpga_txn_valid,
            abort       => cpu_busy,
            core_ready  => i2c_ctrlr_idle,
            tx_st_if    => i2c_tx_st_if,
            rx_st_if    => i2c_rx_st_if
        );

    -- for the internal bus, mux between our simulated start and internal controller
    ctrlr_has_int_mux   <= not need_start or i2c_ctrlr_idle = '0';
    fpga_scl_if.o       <= ctrlr_scl_if.o when ctrlr_has_int_mux else scl_sim;
    fpga_scl_if.oe      <= ctrlr_scl_if.oe when ctrlr_has_int_mux else '1';
    fpga_sda_if.o       <= ctrlr_sda_if.o when ctrlr_has_int_mux else sda_sim;
    fpga_sda_if.oe      <= ctrlr_sda_if.oe when ctrlr_has_int_mux else '1';

    -- Break the fpga input from the bus when it doesn't have the bus
    -- The I2C link layer filters SDA so we will feed it the unfiltered signal
    ctrlr_scl_if.i  <= '1' when cpu_has_mux else dimm_scl_filt;
    ctrlr_sda_if.i  <= '1' when cpu_has_mux else dimm_sda_if.i; 
    fpga_scl_if.i   <= ctrlr_scl_if.i;
    fpga_sda_if.i   <= ctrlr_sda_if.i;

    sda_arbiter_inst: entity work.sda_arbiter
        generic map(
            HYSTERESIS_CYCLES => DIMM_I2C_TSP_CYCLES + 7 -- 7 is a bit of a swag given Ruby testing
        )
        port map(
            clk     => clk,
            reset   => reset,
            a       => cpu_sda_filt,
            b       => dimm_sda_filt,
            enabled => cpu_has_mux,
            a_grant => cpu_has_sda,
            b_grant => dimm_has_sda
        );

    cpu_has_mux     <= '1' when cpu_busy = '1' and i2c_ctrlr_idle = '1' and not need_start 
                        else '0';
    dimm_scl_if.oe  <= '1' when cpu_has_mux else fpga_scl_if.oe;
    dimm_scl_if.o   <= cpu_scl_filt when cpu_has_mux else fpga_scl_if.o;

    dimm_sda_oe     <= not cpu_sda_filt when cpu_has_sda else '0';
    dimm_sda_if.oe  <= dimm_sda_oe when cpu_has_mux else fpga_sda_if.oe;
    dimm_sda_if.o   <= '0' when cpu_has_mux else fpga_sda_if.o;

    cpu_sda_oe      <= not dimm_sda_filt when dimm_has_sda else '0';
    cpu_sda_if.oe   <= cpu_sda_oe when cpu_has_mux else '0';
    cpu_sda_if.o    <= '0';

end architecture;