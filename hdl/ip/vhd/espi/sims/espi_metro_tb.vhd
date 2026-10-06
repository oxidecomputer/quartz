-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- The same harness as espi_tb, built as a metro. Which board the target
-- reports is a generic, so it takes a second elaboration to see the other
-- value; anything that does not depend on the board belongs in espi_tb.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.espi_controller_vc_pkg.all;
use work.espi_platform_regs_pkg.all;

entity espi_metro_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of espi_metro_tb is
begin

    th: entity work.espi_th generic map (BOARD => METRO);

    bench: process
        alias    sim_reset     is <<signal th.reset : std_logic>>;
        variable status        : std_logic_vector(15 downto 0);
        variable response_code : std_logic_vector(7 downto 0);
        variable data_32       : std_logic_vector(31 downto 0);
        variable crc_ok        : boolean;
    begin
        test_runner_setup(runner, runner_cfg);
        wait until sim_reset = '0';
        wait for 500 ns;

        while test_suite loop
            if run("board_id_reads_metro") then
                get_config(net, BOARD_ID_OFFSET, data_32, response_code, status, crc_ok);
                check(crc_ok, "CRC Check failed");
                check_equal(data_32, std_logic_vector'(x"00000001"), "Expected board_id to read as metro");
            end if;
        end loop;

        wait for 2 us;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);
end tb;
