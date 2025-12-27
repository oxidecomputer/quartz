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
use work.time_pkg.all;

-- This block encapsulates the i2c proxy logic for one "channel", meaning
-- one i2c bus from the big CPU,  one i2c  bus to  some  number of DIMMs,
-- and provides the SPD caching for all of those DIMMs. It is build to be
-- instantiated multiple times to cover our needs (2x in the SP5 design, 6xDIMMS/bus)

entity proxy_channel_top is
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

        in_a0 : in std_logic;

         -- CPU <-> FPGA
        cpu_scl_if  : view tristate_if;
        cpu_sda_if  : view tristate_if;

        -- FPGA <-> DIMMs
        dimm_scl_if : view tristate_if;
        dimm_sda_if : view tristate_if;


    );
end entity;

architecture rtl of proxy_channel_top is
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

    signal dimm_scl_filt        : std_logic;
    signal dimm_sda_filt        : std_logic;
    signal dimm_sda_fedge       : std_logic;
    signal dimm_sda_redge       : std_logic;
    signal fpga_controller_idle  : std_logic;
    signal fpga_i2c_has_bus      : std_logic;
    signal sp5_playback_i2c_has_bus : std_logic;
    signal sp5_i2c_has_bus      : std_logic;
    signal playback_sda        : tristate;
    signal playback_scl        : tristate;
    signal cpu_driving_sda     : std_logic;
    signal dimm_driving_sda    : std_logic;
    signal fpga_scl_if         : tristate;
    signal fpga_sda_if         : tristate;
    signal requests            : std_logic_vector(1 downto 0);
    signal grants              : std_logic_vector(1 downto 0);
    signal fpga_i2c_abort_or_finish : std_logic;
begin

    --
    -- DIMM bus monitoring
    --
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

    dimm_arb_mux_inst: entity work.dimm_arb_mux
    generic map(
        CLK_PER_NS => CLK_PER_NS,
        I2C_MODE => I2C_MODE
    )
     port map(
        clk => clk,
        reset => reset,
        in_a0 => in_a0,
        cpu_scl_in => cpu_scl_filt,
        cpu_scl_fedge => cpu_scl_fedge,
        cpu_scl_redge => cpu_scl_redge,
        cpu_sda_in => cpu_sda_filt,
        cpu_sda_fedge => cpu_sda_fedge,
        cpu_sda_redge => cpu_sda_redge,
        dimm_sda => dimm_sda_filt,
        dimm_scl => dimm_scl_filt,
        playback_sda => playback_sda,
        playback_scl => playback_scl,
        bus_request => requests(0),
        bus_grant => grants(0),
        fpga_i2c_grant => grants(1),
        fpga_i2c_has_bus => fpga_i2c_has_bus,
        fpga_i2c_abort_or_finish => fpga_i2c_abort_or_finish,
        sp5_playback_i2c_has_bus => sp5_playback_i2c_has_bus,
        sp5_i2c_has_bus => sp5_i2c_has_bus
    );

    -- DIMM bus access arbiter
    -- We can only do one thing at a time on the DIMM bus, so we need some
    -- arbitration between the CPU and the FPGA controller. Priority is given
    -- to the CPU since it has async needs. It also doesn't strictly *wait* for being
    -- granted the bus, which is why we have the dimm_arb_mux block which will abort/finish
    -- any ongoing FPGA controller transaction when the CPU starts one, store the bits until
    -- handed back, and then play them back out and hand off to the CPU. We use an arbiter here
    -- to help coordinate the bus access.
    -- Upstream logic must deal with abort/retry logic
    arbiter_inst: entity work.arbiter
     generic map(
        mode => priority
    )
     port map(
        clk => clk,
        reset => reset,
        requests => requests,
        grants => grants
    );

    -- this is active when the CPU has control of the i2c bus so that it can see
    -- ACKs/READ-data from the DIMMs
    sda_arbiter_inst: entity work.sda_arbiter
        generic map(
            HYSTERESIS_CYCLES => DIMM_I2C_TSP_CYCLES + 7 -- 7 is a bit of a swag given Ruby testing
        )
        port map(
            clk     => clk,
            reset   => reset,
            a       => cpu_sda_filt,
            b       => dimm_sda_filt,
            enabled => sp5_i2c_has_bus,
            a_grant => cpu_driving_sda,
            b_grant => dimm_driving_sda
        );

    playback_scl.i <= dimm_scl_if.i;
    playback_sda.i <= dimm_sda_if.i;
    -- mux the output pins based on our state
    -- DIMM SCL:
    -- we don't support clock stretching from the DIMMs so if the SP5 has the bus, it
    -- can drive SCL hard to 0 or 1
    dimm_scl_if.oe  <= '1' when sp5_i2c_has_bus = '1' else 
                       fpga_scl_if.oe when fpga_i2c_has_bus else
                       playback_scl.oe when sp5_playback_i2c_has_bus else '0';
    dimm_scl_if.o   <= cpu_scl_filt when sp5_i2c_has_bus else 
                       fpga_scl_if.o when fpga_i2c_has_bus else
                        playback_scl.o when sp5_playback_i2c_has_bus else '0';

    -- DIMM SDA:
    -- if the SP5 has the bus, we could be driving or reading SDA depending on the phase of the
    -- transaction.  The SDA arbiter is used there.
    -- we drive the dimm bus in the following conditions:
    -- - we're in SP5 playback mode (we know this is unidirectional by design)
    -- - The SP5 has the bus and the sda arbiter says we should drive
    -- - the FPGA controller has the bus.

    dimm_sda_if.oe  <= playback_sda.oe when sp5_playback_i2c_has_bus else 
                       fpga_sda_if.oe when fpga_i2c_has_bus and not fpga_sda_if.o else
                       not cpu_sda_filt when sp5_i2c_has_bus and cpu_driving_sda else '0';
    dimm_sda_if.o   <=  playback_sda.o when sp5_playback_i2c_has_bus else 
                        fpga_sda_if.o when fpga_i2c_has_bus else
                        '0';

    -- CPU. We never drive SCL.
    -- We drive SDA only when the CPU has the bus and the sda arbiter says we should drive.                    
    cpu_sda_if.oe   <= not dimm_sda_filt when dimm_driving_sda and sp5_i2c_has_bus else '0';
    cpu_sda_if.o    <= '0';

    cpu_scl_if.oe  <= '0';
    cpu_scl_if.o   <= '0';

    fpga_scl_if.i <= dimm_scl_if.i;
    fpga_sda_if.i <= dimm_sda_if.i;
    
    proxy_fpga_i2c_logic_inst: entity work.proxy_fpga_i2c_logic
     generic map(
        NUM_DIMMS_ON_BUS => NUM_DIMMS_ON_BUS,
        CLK_PER_NS => CLK_PER_NS,
        I2C_MODE => I2C_MODE
    )
     port map(
        clk => clk,
        reset => reset,
        regs_if => regs_if,
        bus_request => requests(1),
        bus_grant => grants(1),
        abort_or_finish => fpga_i2c_abort_or_finish,
        fpga_controller_idle => fpga_controller_idle,
        fpga_scl_if => fpga_scl_if,
        fpga_sda_if => fpga_sda_if
    );
      

end rtl;