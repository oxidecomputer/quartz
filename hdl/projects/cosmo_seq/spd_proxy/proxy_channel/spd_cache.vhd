-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2025 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.axi_st8_pkg;

-- This block encapsulates is a dual-port ram representing the SPD cache
-- for a single DIMM. 1024 bytes of data

entity spd_cache is
    port(
        clk         : in std_logic;
        reset       : in std_logic;
        -- Local register interface TBD
        -- available bytes by waddr pos
        selected: in std_logic;
        waddr       : in std_logic_vector(9 downto 0);
        raddr       : in std_logic_vector(7 downto 0);
        rdata       : out std_logic_vector(31 downto 0);
        -- streaming bus from i2c controller
        i2c_rx_st_if        : view axi_st8_pkg.axi_st_sink

    );
end entity;


architecture rtl of spd_cache is
    signal write_enable : std_logic;

begin

    write_enable <= i2c_rx_st_if.valid and i2c_rx_st_if.ready and selected;
    i2c_rx_st_if.ready <= '1';  -- No reason to back pressure

    mixed_width_simple_dpr_inst: entity work.mixed_width_simple_dpr
     generic map(
        write_width => 8,
        read_width => 32,
        write_num_words => 1024
    )
     port map(
        wclk => clk,
        waddr => waddr,
        wdata => i2c_rx_st_if.data,
        wren => write_enable,
        rclk => clk,
        raddr => raddr,
        rdata => rdata
    );
    -- we're going to have read addresses in terms of 32-bit words
    -- fifo_rem_data <= 
    -- rx_fifo_data_avail.data <= resize(rx_dpr_waddr, rx_fifo_data_avail.data'length);


end rtl;