-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil8x32_pkg;
use work.versal_flash_regs_pkg.all;

-- Control of the mux on schematic sheet 137 that hands the Versal's QSPI boot
-- flash to the FPGA, so a Versal image can be read back or written without a
-- separate programmer. The controller that drives the flash is the spi_nor in
-- the eSPI1 wrapper at the top level, which is how the SP5 reaches it over
-- SAFS as well as the SP over registers; this block only decides whether it
-- may drive the part.
--
-- The mux is switched to the FPGA when the sequencer asks for it, to measure
-- the image before boot and to hand the flash to the SP5 once the Versal has
-- booted, and on the SP's request while the sequencer is holding the Versal in
-- POR. Either way the Versal is never driving the flash at the same time. The
-- SP's request is a level, not a pulse: if the Versal is released while the SP
-- still holds the request, ownership drops on its own.
entity versal_flash_subsystem is
    port(
        clk : in std_logic;
        reset : in std_logic;

        -- Control and status for the mux itself
        ctrl_axi_if : view axil8x32_pkg.axil_target;

        -- From the sequencer: high while POR_B is asserted and will stay so
        versal_held_in_reset : in std_logic;
        -- From the sequencer: it wants the flash on the FPGA side itself
        flash_owned_by_seq : in std_logic;

        -- Mux control pins
        flash_qspi_mux_sel : out std_logic;
        flash_qspi_mux_en_l : out std_logic;

        -- To the flash controller: high while it may drive the flash. Goes
        -- to spi_nor_top's bus_enable, which parks the pins at the IOB flops
        -- when low; muxing the pins here instead would pull those flops out
        -- of the IOBs.
        flash_bus_enable : out std_logic
    );
end entity;

architecture rtl of versal_flash_subsystem is

    signal active_read : std_logic;
    signal active_write : std_logic;
    signal rdata : std_logic_vector(31 downto 0);
    signal mux_ctrl : mux_ctrl_type;
    signal mux_status : mux_status_type;
    signal granted : std_logic;

begin

    -- The interlock. The SP requesting is not enough; the sequencer has to be
    -- holding the Versal off the flash as well. The sequencer's own claim
    -- needs no request.
    granted <= flash_owned_by_seq or (mux_ctrl.request and versal_held_in_reset);
    flash_qspi_mux_sel <= granted;
    flash_qspi_mux_en_l <= not granted;

    -- The controller parks its pins whenever we do not own the flash, so
    -- losing the grant mid-transaction stops driving within a clock.
    flash_bus_enable <= granted;

    mux_status <= (
        granted => granted,
        mux_sel => granted,
        mux_en_l => not granted,
        versal_held_in_reset => versal_held_in_reset,
        seq_owned => flash_owned_by_seq
    );

    axil_target_txn_inst: entity work.axil_target_txn
     port map(
        clk => clk,
        reset => reset,
        arvalid => ctrl_axi_if.read_address.valid,
        arready => ctrl_axi_if.read_address.ready,
        awvalid => ctrl_axi_if.write_address.valid,
        awready => ctrl_axi_if.write_address.ready,
        wvalid => ctrl_axi_if.write_data.valid,
        wready => ctrl_axi_if.write_data.ready,
        bvalid => ctrl_axi_if.write_response.valid,
        bready => ctrl_axi_if.write_response.ready,
        bresp => ctrl_axi_if.write_response.resp,
        rvalid => ctrl_axi_if.read_data.valid,
        rready => ctrl_axi_if.read_data.ready,
        rresp => ctrl_axi_if.read_data.resp,
        active_read => active_read,
        active_write => active_write
    );
    ctrl_axi_if.read_data.data <= rdata;

    write_logic: process(clk, reset)
    begin
        if reset then
            mux_ctrl <= rec_reset;
        elsif rising_edge(clk) then
            if active_write then
                case to_integer(ctrl_axi_if.write_address.addr) is
                    when MUX_CTRL_OFFSET => mux_ctrl <= unpack(ctrl_axi_if.write_data.data);
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    read_logic: process(clk, reset)
    begin
        if reset then
            rdata <= (others => '0');
        elsif rising_edge(clk) then
            if active_read then
                case to_integer(ctrl_axi_if.read_address.addr) is
                    when MUX_CTRL_OFFSET => rdata <= pack(mux_ctrl);
                    when MUX_STATUS_OFFSET => rdata <= pack(mux_status);
                    when others => rdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;

end rtl;
