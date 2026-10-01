-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.com_context;

use work.sp5_power_pkg.all;
use work.sequencer_io_pkg.all;
use work.versal_model_msg_pkg.all;

-- Boot-side model of the VP1202. The rails are modelled separately by
-- rail_model instances in the harness; this covers the hotswap pair, whose
-- power-good pins are active low at the FPGA, and the POR_B/DONE handshake.
entity versal_model is
    generic (
        actor_name : string := "versal_model";
        -- How long after POR_B releases the device takes to assert DONE.
        boot_time : time := 50 us
    );
    port (
        clk : in std_logic;
        reset : in std_logic;

        hsc_12v : view power_rail_at_reg;
        hsc_5v : view cascade_power_rail_at_reg;

        boot : view versal_boot_at_versal
    );
end entity;

architecture model of versal_model is

    signal boot_allowed : boolean := true;
    signal force_error_out : boolean := false;
    signal done_int : std_logic := '0';
    signal error_out_int : std_logic := '0';

begin

    msg_handler : process
        variable self        : actor_t;
        variable msg_type    : msg_type_t;
        variable request_msg : msg_t;
    begin
        self := new_actor(actor_name);
        loop
            receive(net, self, request_msg);
            msg_type := message_type(request_msg);
            if msg_type = fail_boot_msg then
                info("versal_model: boot will not complete");
                boot_allowed <= false;
            elsif msg_type = allow_boot_msg then
                info("versal_model: boot allowed");
                boot_allowed <= true;
            elsif msg_type = assert_error_out_msg then
                info("versal_model: asserting ERROR_OUT");
                force_error_out <= true;
            elsif msg_type = clear_error_out_msg then
                info("versal_model: clearing ERROR_OUT");
                force_error_out <= false;
            else
                unexpected_msg_type(msg_type);
            end if;
        end loop;
        wait;
    end process;

    -- Hotswap power good is active low at the FPGA pins, and the 5V hotswap
    -- cascades off the 12V one.
    hsc_12v.pg <= not hsc_12v.enable;
    hsc_5v.pg <= not hsc_12v.enable;

    -- DONE comes up some time after POR_B releases, and drops again whenever
    -- the device is put back into reset.
    boot_sm : process
    begin
        wait until rising_edge(boot.por_b);
        if boot_allowed then
            wait for boot_time;
            if boot.por_b = '1' then
                done_int <= '1';
            end if;
        end if;
        wait until falling_edge(boot.por_b);
        done_int <= '0';
    end process;

    -- The DONE and ERROR_OUT buffers are only enabled by the sequencer once it
    -- is looking at them; before that the pins read as their idle level.
    boot.done <= done_int when boot.err_done_buff_en = '1' else '0';
    error_out_int <= '1' when force_error_out else '0';
    boot.error_out <= error_out_int when boot.err_done_buff_en = '1' else '0';

end model;
