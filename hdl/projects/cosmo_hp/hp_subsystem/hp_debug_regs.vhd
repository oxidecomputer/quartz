-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.hp_debug_regs_pkg.all;

entity hp_debug_regs is
    port (
        clk   : in    std_logic;
        reset : in    std_logic;
        -- System Interface
        -- axi interface. This is not using VHDL2019 views so that it's compatible with
        -- GHDL/yosys based toolchains
        -- write address channel
        awvalid : in std_logic;
        awready : out std_logic;
        awaddr : in std_logic_vector(7 downto 0) ;
        -- write data channel
        wvalid : in std_logic;
        wready : out std_logic;
        wdata : in std_logic_vector(31 downto 0);
        wstrb : in std_logic_vector(3 downto 0); -- un-used
        -- write response channel
        bvalid : out std_logic;
        bready : in std_logic;
        bresp : out std_logic_vector(1 downto 0);
        -- read address channel
        arvalid : in std_logic;
        arready : out std_logic;
        araddr : in std_logic_vector(7 downto 0);
        -- read data channel
        rvalid : out std_logic;
        rready : in std_logic;
        rdata : out std_logic_vector(31 downto 0);
        rresp : out std_logic_vector(1 downto 0);

        -- 
        clk_buff_cema_force_oe_l : out std_logic;
        clk_buff_cemb_force_oe_l : out std_logic;
        clk_buff_cemc_force_oe_l : out std_logic;
        clk_buff_cemd_force_oe_l : out std_logic;
        clk_buff_ceme_force_oe_l : out std_logic;
        clk_buff_cemf_force_oe_l : out std_logic;
        clk_buff_cemg_force_oe_l : out std_logic;
        clk_buff_cemh_force_oe_l : out std_logic;
        clk_buff_cemi_force_oe_l : out std_logic;
        clk_buff_cemj_force_oe_l : out std_logic;
        clk_buff_ufl_force_oe_l : out std_logic

    );
end entity;

architecture rtl of hp_debug_regs is

    signal clk_buf_force : clk_buf_force_type;
    signal active_read: std_logic;
    signal active_write: std_logic;

begin

    axil_target_txn_inst: entity work.axil_target_txn
    port map(
       clk => clk,
       reset => reset,
       arvalid => arvalid,
       arready => arready,
       awvalid => awvalid,
       awready =>awready,
       wvalid => wvalid,
       wready => wready,
       bvalid => bvalid,
       bready => bready,
       bresp => bresp,
       rvalid => rvalid,
       rready => rready,
       rresp =>rresp,
       active_read => active_read,
       active_write => active_write
   );



    write_logic: process(clk, reset)
    begin
        if reset then
            clk_buf_force <= rec_reset;
        elsif rising_edge(clk) then
            if active_write then
                case to_integer(awaddr) is
                    when CLK_BUF_FORCE_OFFSET => clk_buf_force <= write_byte_enable(clk_buf_force, wdata, wstrb);
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
                case to_integer(araddr) is
                    when CLK_BUF_FORCE_OFFSET => rdata <= pack(clk_buf_force);
                    when others =>
                        rdata <= (others => '0');
                end case;
            end if;
        end if;
    end process;


    clk_buff_cema_force_oe_l <= not clk_buf_force.cema_clk_buf_force_on;
    clk_buff_cemb_force_oe_l <= not clk_buf_force.cemb_clk_buf_force_on;
    clk_buff_cemc_force_oe_l <= not clk_buf_force.cemc_clk_buf_force_on;
    clk_buff_cemd_force_oe_l <= not clk_buf_force.cemd_clk_buf_force_on;
    clk_buff_ceme_force_oe_l <= not clk_buf_force.ceme_clk_buf_force_on;
    clk_buff_cemf_force_oe_l <= not clk_buf_force.cemf_clk_buf_force_on;
    clk_buff_cemg_force_oe_l <= not clk_buf_force.cemg_clk_buf_force_on;
    clk_buff_cemh_force_oe_l <= not clk_buf_force.cemh_clk_buf_force_on;
    clk_buff_cemi_force_oe_l <= not clk_buf_force.cemi_clk_buf_force_on;
    clk_buff_cemj_force_oe_l <= not clk_buf_force.cemj_clk_buf_force_on;
    clk_buff_ufl_force_oe_l <= not clk_buf_force.ufl_clk_buf_force_on;

end rtl;