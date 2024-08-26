-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- Copyright 2024 Oxide Computer Company

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifos_th is
end entity;

architecture th of fifos_th is

    signal clk_a   : std_logic := '0';
    signal reset_a : std_logic := '1';

    signal clk_b   : std_logic := '0';
    signal reset_b : std_logic := '1';

    signal write_side_control : std_logic_vector(8 downto 0);
    alias  write_en           : std_logic is write_side_control(8);
    alias  write_data         : std_logic_vector(7 downto 0) is write_side_control(7 downto 0);

    signal write_side_reads : std_logic_vector(5 downto 0);
    alias  wfull            : std_logic is write_side_reads(4);
    alias  wusedwds         : std_logic_vector(4 downto 0) is write_side_reads(4 downto 0);

    signal read_req : std_logic;

    signal read_side_reads : std_logic_vector(13 downto 0);
    alias  rdata           : std_logic_vector(7 downto 0) is read_side_reads(7 downto 0);
    alias  rusedwds        : std_logic_vector(4 downto 0) is read_side_reads(12 downto 8);
    alias  rempty          : std_logic is read_side_reads(13);

    signal mixed_write : std_logic;
    signal mixed_read_req : std_logic;

    signal mixed_read_side_reads : std_logic_vector(16 downto 0);
    alias  mrdata           : std_logic_vector(7 downto 0) is mixed_read_side_reads(7 downto 0);
    alias  mrusedwds        : std_logic_vector(8 downto 0) is mixed_read_side_reads(16 downto 8);
    alias  mrempty          : std_logic is mixed_read_side_reads(13);

begin

    -- set up 2 fastish, un-related clocks for the sim
    -- environment and release reset after a bit of time
    clk_a   <= not clk_a after 4 ns;
    reset_a <= '0' after 200 ns;

    clk_b   <= not clk_b after 5 ns;
    reset_b <= '0' after 220 ns;

    --------------------------------------------------------------------------------
    -- Dual clock FIFO DUT
    --------------------------------------------------------------------------------
    -- Simple show-ahead fifo for testing
    show_ahead_dcfifo_dut: entity work.dcfifo_xpm
        generic map (
            fifo_write_depth => 16,
            data_width       => 8,
            showahead_mode   => true
        )
        port map (
            -- Write interface
            wclk => clk_a,
            -- Reset interface, sync to write clock domain
            reset                      => reset_a,
            write_en                   => write_en,
            wdata                      => write_data,
            wfull                      => wfull,
            std_logic_vector(wusedwds) => wusedwds,
            -- Read interface
            rclk                       => clk_b,
            rdata                      => rdata,
            rdreq                      => read_req,
            rempty                     => rempty,
            std_logic_vector(rusedwds) => rusedwds
        );

    write_side_gpios: entity work.sim_gpio
        generic map (
            out_num_bits => 9,
            in_num_bits  => 6,
            actor_name   => "write_side"
        )
        port map (
            clk      => clk_a,
            gpio_in  => write_side_reads,
            gpio_out => write_side_control
        );

    read_side_gpios: entity work.sim_gpio
        generic map (
            out_num_bits => 1,
            in_num_bits  => 14,
            actor_name   => "read_side"
        )
        port map (
            clk         => clk_b,
            gpio_in     => read_side_reads,
            gpio_out(0) => read_req
        );


        -- Simple show-ahead fifo for testing
    show_ahead_dcfifo_mixed_dut: entity work.dcfifo_mixed_xpm
    generic map (
        wfifo_write_depth => 16,
        wdata_width       => 32,
        rdata_width       => 8,
        showahead_mode   => true
    )
    port map (
        -- Write interface
        wclk => clk_a,
        -- Reset interface, sync to write clock domain
        reset                      => reset_a,
        write_en                   => mixed_write,
        wdata                      => X"AABBCCDD",
        wfull                      => open,
        wusedwds                   => open,
        -- Read interface
        rclk                       => clk_b,
        rdata                      => mrdata,
        rdreq                      => mixed_read_req,
        rempty                     => mrempty,
        rusedwds => open
    );

    mixed_write_side_gpios: entity work.sim_gpio
    generic map (
        out_num_bits => 1,
        in_num_bits  => 6,
        actor_name   => "mixed_write_side"
    )
    port map (
        clk      => clk_a,
        gpio_in  => write_side_reads,
        gpio_out(0) => mixed_write
    );

    mixed_read_side_gpios: entity work.sim_gpio
    generic map (
        out_num_bits => 1,
        in_num_bits  => 17,
        actor_name   => "mixed_read_side"
    )
    port map (
        clk         => clk_b,
        gpio_in     => mixed_read_side_reads,
        gpio_out(0) => mixed_read_req
    );

end th;
