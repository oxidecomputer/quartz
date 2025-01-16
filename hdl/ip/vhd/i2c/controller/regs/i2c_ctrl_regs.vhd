-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

-- AXI-accessible registers for the I2C block

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.axil8x32_pkg.all;
use work.i2c_common_pkg.all;

use work.i2c_ctrl_regs_pkg.all;

entity i2c_ctrl_regs is
    port (
        clk     : in    std_logic;
        reset   : in    std_logic;
        -- axi_if  : view  axil_target;

        start   : out   std_logic;
        command : out   cmd_t;
        txd     : out   std_logic_vector(31 downto 0);
        rxd     : in    std_logic_vector(31 downto 0);
    );
end entity;

architecture rtl of i2c_ctrl_regs is
    constant AXI_OKAY           : std_logic_vector(1 downto 0) := "00";
    signal   axi_read_ready_int : std_logic;
    signal   axi_awready        : std_logic;
    signal   axi_wready         : std_logic;
    signal   axi_bvalid         : std_logic;
    signal   axi_bready         : std_logic;
    signal   axi_arready        : std_logic;
    signal   axi_rvalid         : std_logic;
    signal   axi_rdata          : std_logic_vector(31 downto 0);

    signal  control_reg : control_type;
    signal  txd_reg     : txd_type;
    signal  rxd_reg     : rxd_type;
begin

    -- AXI wiring
    -- axi_if.write_response.resp  <= AXI_OKAY;
    -- axi_if.write_response.valid <= axi_bvalid;
    -- axi_if.read_data.resp       <= AXI_OKAY;
    -- axi_if.write_data.ready     <= axi_wready;
    -- axi_if.write_address.ready  <= axi_awready;
    -- axi_if.read_address.ready   <= axi_arready;
    -- axi_if.read_data.data       <= axi_rdata;
    -- axi_if.read_data.valid      <= axi_rvalid;

    -- axi_bready          <= axi_if.write_response.ready;
    -- axi_wready          <= axi_awready;
    -- axi_arready         <= not axi_rvalid;
    -- axi_read_ready_int  <= axi_if.read_address.valid and axi_arready;

    -- axi: process(clk, reset)
    -- begin
    --     if reset then
    --         axi_awready <= '0';
    --         axi_bvalid  <= '0';
    --         axi_rvalid  <= '0';
    --     elsif rising_edge(clk) then

    --         -- bvalid is set on every write and then cleared after bv
    --         if axi_awready then
    --             axi_bvalid  <= '1';
    --         elsif axi_bready then
    --             axi_bvalid  <= '0';
    --         end if;

    --         if axi_read_ready_int then
    --             axi_rvalid  <= '1';
    --         elsif axi_if.read_data.ready then
    --             axi_rvalid  <= '0';
    --         end if;

    --         -- can accept a new write if we're not responding to write already or the write is not
    --         -- in progress
    --         axi_awready <= not axi_awready 
    --                     and (axi_if.write_address.valid and axi_if.write_data.valid)
    --                     and (not axi_bvalid or axi_bready);
    --     end if;
    -- end process;

    -- write_logic: process(clk, reset)
    -- begin
    --     if reset then
    --         control_reg <= rec_reset;
    --     elsif rising_edge(clk) then
    --         -- self clearing
    --         control_reg.start   <= '0';

    --         if axi_wready then
    --             case to_integer(axi_if.write_address.addr) is
    --                 when CONTROL_OFFSET => control_reg <= unpack(axi_if.write_data.data);
    --                 when others => null;
    --             end case;
    --         end if;
    --     end if;
    -- end process;

    -- read_logic: process(clk, reset)
    -- begin
    --     if reset then
    --         axi_rdata <= (others => '0');
    --     elsif rising_edge(clk) then
    --         if (not axi_if.read_address.valid) or axi_arready then
    --             case to_integer(axi_if.read_address.addr) is
    --                 when CONTROL_OFFSET => axi_rdata    <= pack(control_reg);
    --                 when TXD_OFFSET     => axi_rdata    <= pack(txd_reg);
    --                 when RXD_OFFSET     => axi_rdata    <= pack(rxd_reg);
    --                 when others => null;
    --             end case;
    --         end if;
    --     end if;
    -- end process;

    -- application wiring
    -- start   <= command_reg.start;
    start       <= '1';
    -- command <= (
    --     op      => slv_to_op(command_reg.op),
    --     addr    => command_reg.addr,
    --     reg     => command_reg.reg,
    --     len     => command_reg.count
    -- );
    command <= (
        op      => READ,
        addr    => b"1010000",
        reg     => x"80",
        len     => x"0F"
    );
    txd     <= pack(txd_reg);
    rxd_reg <= unpack(rxd);


end architecture;