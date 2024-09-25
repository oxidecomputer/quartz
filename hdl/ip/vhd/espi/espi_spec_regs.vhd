-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/

-- A register layer for the eSPI specification registers, that can
-- be read and written in-band by the eSPI host.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.espi_spec_regs_pkg.all;
use work.link_layer_pkg.all;
use work.espi_base_types_pkg.all;

entity espi_spec_regs is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        regs_if : view regs_side;

        qspi_mode            : out   qspi_mode_t;
        wait_states          : out   std_logic_vector(3 downto 0);
        flash_channel_enable : out   boolean
    );
end entity;

architecture rtl of espi_spec_regs is

    constant device_id      : device_id_type := rec_reset;
    signal gen_capabilities : general_capabilities_type;
    signal ch0_capabilities : ch0_capabilities_type;
    signal ch1_capabilities : ch1_capabilities_type;
    signal ch2_capabilities : ch2_capabilities_type;
    signal ch3_capabilities : ch3_capabilities_type;
    signal readdata_valid   : std_logic;
    signal readdata         : std_logic_vector(31 downto 0);
    signal qspi_freq        : qspi_freq_t;

begin

    regs_if.rdata_valid <= readdata_valid;
    regs_if.rdata       <= readdata;
    regs_if.enforce_crcs <= gen_capabilities.crc_en = '1';

    flash_channel_enable <= ch3_capabilities.flash_channel_enable = '1';
    -- Write-side of the spec-defined registers
    write_reg: process(clk, reset)
    begin
        if reset then
            gen_capabilities <= rec_reset;
            ch0_capabilities <= rec_reset;
            ch1_capabilities <= rec_reset;
            ch2_capabilities <= rec_reset;
            ch3_capabilities <= rec_reset;
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
            else
                ch0_capabilities.chan_rdy <= ch0_capabilities.chan_en;
            end if;

            if regs_if.addr = CH1_CAPABILITIES_OFFSET and regs_if.write = '1' then
                ch1_capabilities <= unpack(regs_if.wdata);
                -- clean up RO fields by keeping current val
                ch1_capabilities.wire_max_supported <= ch1_capabilities.wire_max_supported;
                ch1_capabilities.chan_rdy <= ch1_capabilities.chan_rdy;
            else
                ch1_capabilities.chan_rdy <= ch1_capabilities.chan_en;
            end if;

            if regs_if.addr = CH2_CAPABILITIES_OFFSET and regs_if.write = '1' then
                ch2_capabilities <= unpack(regs_if.wdata);
                -- clean up RO fields by keeping current val
                ch2_capabilities.max_payload_support <= ch2_capabilities.max_payload_support;
                ch2_capabilities.chan_rdy <= ch2_capabilities.chan_rdy;
            else
                ch2_capabilities.chan_rdy <= ch2_capabilities.chan_en;
            end if;

            if regs_if.addr = CH3_CAPABILITIES_OFFSET and regs_if.write = '1' then
                ch3_capabilities <= unpack(regs_if.wdata);
                -- clean up RO fields by keeping current val
                ch3_capabilities.flash_cap <= ch3_capabilities.flash_cap;
                ch3_capabilities.flash_share_mode <= ch3_capabilities.flash_share_mode;
                ch3_capabilities.flash_max_payload_supported <= ch3_capabilities.flash_max_payload_supported;
                ch3_capabilities.flash_block_erase_size <= ch3_capabilities.flash_block_erase_size;
                ch3_capabilities.flash_channel_ready <= ch3_capabilities.flash_channel_ready;
            else
                -- TODO: we may want to tie this out to the flash enable mux eventually, but for now
                -- it's fine
                ch3_capabilities.flash_channel_ready <= ch3_capabilities.flash_channel_enable;
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
                when CH1_CAPABILITIES_OFFSET =>
                    readdata <= pack(ch1_capabilities);
                when CH2_CAPABILITIES_OFFSET =>
                    readdata <= pack(ch2_capabilities);
                when CH3_CAPABILITIES_OFFSET =>
                    readdata <= pack(ch3_capabilities);
                when others =>
                    readdata <= (others => '0');
            end case;
        end if;
    end process;

    qspi_mode <= quad when gen_capabilities.io_mode_sel = quad else
                 dual when gen_capabilities.io_mode_sel = dual else
                 single;

    qspi_freq <= sixtysix when gen_capabilities.op_freq_select = sixtysix else
                 fifty when gen_capabilities.op_freq_select = fifty else
                 thirtythree when gen_capabilities.op_freq_select = thirtythree else
                 twentyfive when gen_capabilities.op_freq_select = twentyfive else
                 twenty;
    

    -- we know we're going to clock-cross this so register it here 
    -- so we don't have to worry about it elsewhere
    wait_reg: process(clk, reset)
    begin
        if reset then
            wait_states <= To_Std_Logic_Vector(2, wait_states'length);
        elsif rising_edge(clk) then
            wait_states <= wait_states_from_freq_and_mode(qspi_freq, qspi_mode);
        end if;
    end process;
        

end rtl;
