-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.axil8x32_pkg;
use work.sequencer_io_pkg.all;

entity sp5_seq_sim_th is
end entity;

architecture th of sp5_seq_sim_th is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

begin

    -- set up a fastish clock for the sim env
    -- and release reset after a bit of time
    clk   <= not clk after 4 ns;
    reset <= '0' after 200 ns;

    -- instantiate the sequencer
    -- dut: entity work.sp5_sequencer
    --  generic map(
    --     CNTS_P_MS => CNTS_P_MS
    -- )
    --  port map(
    --     clk => clk,
    --     reset => reset,
    --     axi_if => axi_if,
    --     a0_ok => a0_ok,
    --     a0_idle => a0_idle,
    --     early_power_pins => early_power_pins,
    --     ddr_bulk_pins => ddr_bulk_pins,
    --     group_a_pins => group_a_pins,
    --     group_b_pins => group_b_pins,
    --     group_c_pins => group_c_pins,
    --     sp5_seq_pins => sp5_seq_pins,
    --     nic_rails_pins => nic_rails_pins,
    --     nic_seq_pins => nic_seq_pins,
    --     sp5_t6_power_en => sp5_t6_power_en,
    --     sp5_t6_perst_l => sp5_t6_perst_l
    -- );

    -- sp5_model_inst: entity work.sp5_model
    --  port map(
    --     clk => clk,
    --     reset => reset,
    --     sp5_pins => sp5_pins
    -- );

    -- nic_model_inst: entity work.nic_model
    --  port map(
    --     clk => clk,
    --     reset => reset,
    --     nic_rails => nic_rails
    -- );

end th;