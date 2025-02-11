-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- Take an array of records from each of the 10 CEMs and generate
-- input synchronizers for each of them, and give back an output
-- array post-synchronization.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cem_hp_io_pkg.all;

entity cem_sync is
    port(
        clk : in std_logic;
        from_cem : in from_cem_t;
        from_cem_syncd : out from_cem_t
    );
end entity;

architecture rtl of cem_sync is
    -- we need to reconstruct the inner records from an array
    -- so making an array of arrays is easier for the generate loop
    -- than dealing with an array of records.
    signal from_cem_syncd_vec  : interim_sync_t;
begin

    -- We have an array of 10 CEMs, each with 6 bit inputs, each needing
    -- a synchronizer. We munge this stuff into arrays so we can for-generate this
    per_cem_gen: for i in from_cem'range generate
        per_cem_bit_gen: for j in 0 to CEM_INPUT_BIT_COUNT - 1 generate
        meta_sync_inst: entity work.meta_sync
         port map(
            async_input => to_vec(from_cem(i))(j),
            clk => clk,
            sycnd_output => from_cem_syncd_vec(i)(j)
        );

         end generate;
    end generate;

        from_cem_syncd <=  to_record_array(from_cem_syncd_vec);

end rtl;