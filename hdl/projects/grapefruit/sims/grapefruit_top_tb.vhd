-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
    context vunit_lib.vunit_context;

-- Analysis-only smoke test: it does not drive the top level, its job is to
-- make a simulator compile the whole design tree, which the synthesis-only
-- build rules do not do on their own.
entity grapefruit_top_tb is
    generic (
        runner_cfg : string
    );
end entity;

architecture tb of grapefruit_top_tb is
begin
    bench: process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("analyses") then
                info("grapefruit_top and its dependencies analysed");
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;
end tb;
