-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/

--! A verification component that acts as a qspi controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.vwire_regs_pkg.all;
use work.espi_base_types_pkg.all;

entity vwire_block is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        espi_reset_flag: in std_logic;

        wire_tx_avail: out std_logic;

        vwire_if : view vwire_regs_side;
    );
end entity;

architecture rtl of vwire_block is

    constant irq0 : irq0_type :=rec_reset;
    constant irq1 : irq1_type :=rec_reset;
    signal sys_event2 : sys_event2_type;
    signal sys_event3 : sys_event3_type;
    signal sys_event4 : sys_event4_type;
    signal sys_event5 : sys_event5_type;
    signal sys_event6 : sys_event6_type;
    signal sys_event7 : sys_event7_type;

begin

    -- For right now, since we're only supporting 1 count at a time,
    -- we'd have to keep track of which of these wires need have changes
    -- communicated and keep wire-tx-avail high until all of them have
    -- been sent.  We're not doing this right now.

    wire_tx_avail <= '0';

    -- Write-side of the spec-defined registers
    write_reg: process(clk, reset)
    begin
        if reset then
            sys_event2 <= rec_reset;
            sys_event3 <= rec_reset;
            sys_event4 <= rec_reset;
            sys_event5 <= rec_reset;
            sys_event6 <= rec_reset;
            sys_event7 <= rec_reset;
        elsif rising_edge(clk) then
            if vwire_if.idx = SYS_EVENT2_OFFSET and vwire_if.wstrobe = '1' then
                sys_event2 <= unpack(vwire_if.dat);
            end if;
            if vwire_if.idx = SYS_EVENT3_OFFSET and vwire_if.wstrobe = '1' then
                sys_event3 <= unpack(vwire_if.dat);
            end if;
            if vwire_if.idx = SYS_EVENT4_OFFSET and vwire_if.wstrobe = '1' then
                sys_event4 <= unpack(vwire_if.dat);
            end if;
            if vwire_if.idx = SYS_EVENT5_OFFSET and vwire_if.wstrobe = '1' then
                sys_event5 <= unpack(vwire_if.dat);
            end if;
            if vwire_if.idx = SYS_EVENT6_OFFSET and vwire_if.wstrobe = '1' then
                sys_event6 <= unpack(vwire_if.dat);
            end if;
            if vwire_if.idx = SYS_EVENT7_OFFSET and vwire_if.wstrobe = '1' then
                sys_event7 <= unpack(vwire_if.dat);
            end if;
        end if;
    end process;

end architecture;