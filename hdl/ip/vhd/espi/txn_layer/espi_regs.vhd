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
use work.espi_regs_pkg.all;
use work.qspi_link_layer_pkg.all;
use work.espi_base_types_pkg.all;

entity espi_regs is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        regs_if : view regs_side;

        qspi_mode : out   qspi_mode_t
    );
end entity;

architecture rtl of espi_regs is

    signal device_id        : device_id_type;
    signal gen_capabilities : general_capabilities_type;
    signal ch0_capabilities : ch0_capabilities_type;
    signal readdata_valid   : std_logic;
    signal readdata         : std_logic_vector(31 downto 0);

begin

    regs_if.rdata_valid <= readdata_valid;
    regs_if.rdata       <= readdata;
    -- Write-side of the spec-defined registers
    write_reg: process(clk, reset)
    begin
        if reset then
            device_id <= rec_reset;
            gen_capabilities <= rec_reset;
            ch0_capabilities <= rec_reset;
        elsif rising_edge(clk) then
            if regs_if.addr = GENERAL_CAPABILITIES_OFFSET and regs_if.write = '1' then
                gen_capabilities <= unpack(regs_if.wdata);
                -- clean up RO fields by keeping current val
                gen_capabilities.io_mode_support <= gen_capabilities.io_mode_support;
                gen_capabilities.alert_support <= gen_capabilities.alert_support;
                gen_capabilities.op_freq_support <= gen_capabilities.op_freq_support;
                gen_capabilities.flash_support <= gen_capabilities.flash_support;
                gen_capabilities.oob_support <= gen_capabilities.oob_support;
                gen_capabilities.virt_wire_support <= gen_capabilities.virt_wire_support;
                gen_capabilities.periph_support <= gen_capabilities.periph_support;
            end if;

            if regs_if.addr = CH0_CAPABILITIES_OFFSET and regs_if.write = '1' then
                ch0_capabilities <= unpack(regs_if.wdata);
                -- clean up RO fields by keeping current val
                ch0_capabilities.max_payload_support <= ch0_capabilities.max_payload_support;
                ch0_capabilities.chan_rdy <= ch0_capabilities.chan_rdy;
            end if;
        end if;
    end process;

    output_reg: process(clk, reset)
    begin
        if reset then
            readdata_valid <= '0';
            readdata <= (others => '0');
        elsif rising_edge(clk) then
            -- reads are always valid the cycle after request, no side effects
            readdata_valid <= regs_if.read;
            -- Address decode
            case to_integer(regs_if.addr) is
                when DEVICE_ID_OFFSET =>
                    readdata <= pack(device_id);
                when GENERAL_CAPABILITIES_OFFSET =>
                    readdata <= pack(gen_capabilities);
                when CH0_CAPABILITIES_OFFSET =>
                    readdata <= pack(ch0_capabilities);
                when others =>
                    readdata <= (others => '0');
            end case;
        end if;
    end process;

    qspi_mode <= quad when gen_capabilities.io_mode_sel = quad else
                 dual when gen_capabilities.io_mode_sel = dual else
                 single;

end rtl;
