-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--

-- Note: Documentation can be rendered in VSCode using the TerosHDL
-- plugin: https://terostechnology.github.io/terosHDLdoc/

-- A register layer for the eSPI specification registers, that can
-- be read and written in-band by the eSPI host.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use work.espi_spec_regs_pkg.all;
use work.espi_spec_regs_view_pkg.all;
use work.link_layer_pkg.all;
use work.espi_base_types_pkg.all;

entity espi_spec_regs is
    generic (
        --! Hard ceiling on the advertised operating frequency, in MHz. Rounded
        --! down to the nearest eSPI-defined step.
        max_freq_mhz : natural := 66
    );
    port (
        clk   : in    std_logic;
        reset : in    std_logic;

        regs_if : view regs_side;
        espi_reset : in std_logic;

        --! What to advertise to the host as supported, owned by the SP via the
        --! AXI register block. These also cap what the host is allowed to
        --! select -- see the clamp below.
        adv_io_mode_support : in std_logic_vector(1 downto 0);
        adv_op_freq_support : in std_logic_vector(2 downto 0);

        -- Read-only view of all spec registers for the sys_regs block
        spec_regs_view : view spec_regs_source;

        --! Launch response bits a half period early. Only correct at the top
        --! frequency, where the flight time back to the controller still exceeds
        --! a half SCLK period -- see the serializer in espi_phy.
        early_launch         : out   std_logic;

        qspi_mode            : out   qspi_mode_t;
        wait_states          : out   std_logic_vector(3 downto 0);
        oob_enabled          : out   std_logic;
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
    constant ch3_capabilities2 : ch3_capabilities2_type := rec_reset;
    signal readdata_valid   : std_logic;
    signal readdata         : std_logic_vector(31 downto 0);
    signal qspi_freq        : qspi_freq_t;
    signal eff_io_mode_sel     : general_capabilities_io_mode_sel;
    signal eff_op_freq_select  : general_capabilities_op_freq_select;

    --! The highest eSPI-defined frequency step at or below `max_mhz`.
    function op_freq_support_cap (
        constant max_mhz : natural
    ) return general_capabilities_op_freq_support is
    begin
        if max_mhz >= 66 then
            return SIXTYSIX;
        elsif max_mhz >= 50 then
            return FIFTY;
        elsif max_mhz >= 33 then
            return THIRTYTHREE;
        elsif max_mhz >= 25 then
            return TWENTYFIVE;
        else
            return TWENTY;
        end if;
    end function;

    constant freq_cap : general_capabilities_op_freq_support := op_freq_support_cap(max_freq_mhz);

    --! Is `sel` within what `support` advertises? Note the support encoding is
    --! not ordered the way the selection is: QUAD means "single and quad only",
    --! with dual excluded, so this cannot be a numeric comparison.
    function mode_is_allowed (
        constant sel     : general_capabilities_io_mode_sel;
        constant support : general_capabilities_io_mode_support
    ) return boolean is
    begin
        case support is
            when SINGLE => return sel = SINGLE;
            when DUAL   => return sel = SINGLE or sel = DUAL;
            when QUAD   => return sel = SINGLE or sel = QUAD;
            when ANY    => return sel = SINGLE or sel = DUAL or sel = QUAD;
        end case;
    end function;

begin

    regs_if.rdata_valid <= readdata_valid;
    regs_if.rdata       <= readdata;
    regs_if.enforce_crcs <= gen_capabilities.crc_en = '1';

    flash_channel_enable <= ch3_capabilities.flash_channel_enable = '1';
    oob_enabled <= ch2_capabilities.chan_en;

    spec_regs_view.device_id            <= device_id;
    spec_regs_view.general_capabilities <= gen_capabilities;
    spec_regs_view.ch0_capabilities     <= ch0_capabilities;
    spec_regs_view.ch1_capabilities     <= ch1_capabilities;
    spec_regs_view.ch2_capabilities     <= ch2_capabilities;
    spec_regs_view.ch3_capabilities     <= ch3_capabilities;
    spec_regs_view.ch3_capabilities2    <= ch3_capabilities2;

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
                -- clean up RO fields by keeping current val. io_mode_support and
                -- op_freq_support are handled once at the end of this process
                -- instead, since they are driven by the SP rather than held.
                gen_capabilities.alert_support <= gen_capabilities.alert_support;
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

            -- CH2 is OOB which we use for IPCC
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

            if espi_reset then
                -- Reset all registers on eSPI reset
                gen_capabilities <= rec_reset;
                ch0_capabilities <= rec_reset;
                ch1_capabilities <= rec_reset;
                ch2_capabilities <= rec_reset;
                ch3_capabilities <= rec_reset;
            end if;

            -- Last word wins, so this one assignment covers the host write path,
            -- the in-band reset above, and steady state alike. That matters:
            -- what the target advertises belongs to the SP, and an in-band reset
            -- happens at the start of every boot, so letting it fall back to the
            -- register default would drop the link to single/20MHz for good.
            gen_capabilities.io_mode_support <= encode(adv_io_mode_support);
            -- Whichever is lower: what the SP asked us to advertise, or what this
            -- implementation was built to support. The generic is the backstop --
            -- software cannot talk a build into a frequency its timing does not
            -- close at.
            if general_capabilities_op_freq_support'pos(encode(adv_op_freq_support)) >
               general_capabilities_op_freq_support'pos(freq_cap) then
                gen_capabilities.op_freq_support <= freq_cap;
            else
                gen_capabilities.op_freq_support <= encode(adv_op_freq_support);
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

    -- The host is not supposed to select beyond what we advertise, but clamping
    -- it in hardware means a host that does cannot drive the link somewhere the
    -- design has not been constrained for. Falls back to the advertised maximum
    -- rather than refusing outright, so the link stays usable.
    eff_io_mode_sel <= gen_capabilities.io_mode_sel
                       when mode_is_allowed(gen_capabilities.io_mode_sel,
                                            gen_capabilities.io_mode_support)
                       else SINGLE;

    -- Frequency really is ordered, and the support field is a maximum, so this
    -- one is a positional comparison. The two enums share an ordering, hence the
    -- pos/val hop between them.
    eff_op_freq_select <= gen_capabilities.op_freq_select
                          when general_capabilities_op_freq_select'pos(gen_capabilities.op_freq_select) <=
                               general_capabilities_op_freq_support'pos(gen_capabilities.op_freq_support)
                          else general_capabilities_op_freq_select'val(
                               general_capabilities_op_freq_support'pos(gen_capabilities.op_freq_support));

    qspi_mode <= quad when eff_io_mode_sel = quad else
                 dual when eff_io_mode_sel = dual else
                 single;

    -- Early launch is valid only where the flight time back to the controller
    -- still exceeds a half SCLK period; below that the next bit has already
    -- replaced this one by the controller's capture edge and the response shifts
    -- by a bit. Measured flight on cosmo is about 12ns, so the boundary sits
    -- between 33MHz (half period 15.2ns) and 50MHz (10ns) -- which is exactly
    -- where the simulation sweeps start failing if this is forced on, so the
    -- threshold is verified rather than assumed.
    --
    -- 66MHz *needs* it. 50MHz does not -- a full period covers the flight with
    -- about 1ns to spare -- but it is included anyway so that the falling-edge
    -- path is only ever used at 33MHz and below, where it has better than twice
    -- the budget it needs. That is what makes it safe to exclude the late path
    -- from the 66MHz timing analysis instead of leaving it reported as failing.
    early_launch <= '1' when eff_op_freq_select = SIXTYSIX or
                             eff_op_freq_select = FIFTY else '0';

    qspi_freq <= sixtysix when eff_op_freq_select = sixtysix else
                 fifty when eff_op_freq_select = fifty else
                 thirtythree when eff_op_freq_select = thirtythree else
                 twentyfive when eff_op_freq_select = twentyfive else
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
