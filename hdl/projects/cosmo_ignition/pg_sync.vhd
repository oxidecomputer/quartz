-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- The power-good inputs come straight from regulators and the hot-swap
-- controller, so they are asynchronous to the system clock and need to be
-- synchronized before any logic consumes them.

library ieee;
use ieee.std_logic_1164.all;

entity pg_sync is
    port (
        clk : in std_logic;

        v3p3_fpga2_a2_pg : in std_logic;
        v1p2_fpga2_a2_pg : in std_logic;
        v2p5_fpga2_a2_pg : in std_logic;
        v5p0_sys_a2_pg : in std_logic;
        v3p3_sys_a2_pg : in std_logic;
        v1p8_sys_a2_pg : in std_logic;
        v1p0_mgmt_a2_pg : in std_logic;
        v2p5_mgmt_a2_pg : in std_logic;
        v12_sys_a2_pg_l : in std_logic;
        main_hsc_pg : in std_logic;

        v3p3_fpga2_a2_pg_syncd : out std_logic;
        v1p2_fpga2_a2_pg_syncd : out std_logic;
        v2p5_fpga2_a2_pg_syncd : out std_logic;
        v5p0_sys_a2_pg_syncd : out std_logic;
        v3p3_sys_a2_pg_syncd : out std_logic;
        v1p8_sys_a2_pg_syncd : out std_logic;
        v1p0_mgmt_a2_pg_syncd : out std_logic;
        v2p5_mgmt_a2_pg_syncd : out std_logic;
        v12_sys_a2_pg_l_syncd : out std_logic;
        main_hsc_pg_syncd : out std_logic
    );
end entity;

architecture rtl of pg_sync is
    constant NUM_PGS : integer := 10;
    signal async_pgs : std_logic_vector(NUM_PGS - 1 downto 0);
    signal syncd_pgs : std_logic_vector(NUM_PGS - 1 downto 0);
begin

    async_pgs <= (
        9 => v3p3_fpga2_a2_pg,
        8 => v1p2_fpga2_a2_pg,
        7 => v2p5_fpga2_a2_pg,
        6 => v5p0_sys_a2_pg,
        5 => v3p3_sys_a2_pg,
        4 => v1p8_sys_a2_pg,
        3 => v1p0_mgmt_a2_pg,
        2 => v2p5_mgmt_a2_pg,
        1 => v12_sys_a2_pg_l,
        0 => main_hsc_pg
    );

    sync_gen: for i in async_pgs'range generate
        meta_sync_inst: entity work.meta_sync
         generic map(
            stages => 2
        )
         port map(
            async_input => async_pgs(i),
            clk => clk,
            sycnd_output => syncd_pgs(i)
        );
    end generate;

    v3p3_fpga2_a2_pg_syncd <= syncd_pgs(9);
    v1p2_fpga2_a2_pg_syncd <= syncd_pgs(8);
    v2p5_fpga2_a2_pg_syncd <= syncd_pgs(7);
    v5p0_sys_a2_pg_syncd <= syncd_pgs(6);
    v3p3_sys_a2_pg_syncd <= syncd_pgs(5);
    v1p8_sys_a2_pg_syncd <= syncd_pgs(4);
    v1p0_mgmt_a2_pg_syncd <= syncd_pgs(3);
    v2p5_mgmt_a2_pg_syncd <= syncd_pgs(2);
    v12_sys_a2_pg_l_syncd <= syncd_pgs(1);
    main_hsc_pg_syncd <= syncd_pgs(0);

end rtl;
