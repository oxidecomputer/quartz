-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;
    context vunit_lib.vc_context;

use work.basic_stream_pkg.all;

entity basic_source is
    generic (
        source  : basic_source_t
    );
    port (
        clk     : in std_logic;
        ready   : in std_logic;
        valid   : out std_logic := '0';
        data    : out std_logic_vector(data_length(source)-1 downto 0) := (others => '0')
    );
end entity;

architecture model of basic_source is
begin

    main: process
        variable msg        : msg_t;
        variable msg_type   : msg_type_t;
        variable rnd        : RandomPType;
    begin
        receive(net, source.p_actor, msg);
        msg_type := message_type(msg);

        if msg_type = stream_push_msg or msg_type = push_basic_stream_msg then
            -- loop until there will be valid data
            while rnd.Uniform(0.0, 1.0) > source.valid_high_probability loop
                wait until rising_edge(clk);
            end loop;
            valid   <= '1';
            data    <= pop_std_ulogic_vector(msg);

            -- wait until data should be accepted
            wait until (valid and ready) = '1' and rising_edge(clk);
            valid   <= '0';
        else
            unexpected_msg_type(msg_type);
        end if;
    end process;

end architecture;